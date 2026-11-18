import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'chess_clock.dart';

enum P2PMode { host, join }

enum ChessConnectionState { idle, searching, connecting, connected, disconnected, error, reconnecting }

/// Schaak via een lokaal netwerk (LAN / zelfde Wi-Fi).
///
/// - De **host** draait een WebSocket-server op [kGamePort] en zendt elke 2s
///   een UDP-broadcast ("CHESS_HOST_ALIVE:<port>") naar poort [kDiscoveryPort]
///   zodat anderen de game automatisch kunnen vinden.
/// - De **joiner** verbindt zich met het gevonden (of handmatig ingevoerde)
///   adres en speelt zwart; de host speelt wit.
/// - Zetten worden als **FEN** gesynchroniseerd. Dat is deterministisch en
///   voorkomt parsing-verschillen tussen twee instanties van de chess-engine.
class P2PChessService with ChangeNotifier {
  static const int kGamePort = 8080;
  static const int kDiscoveryPort = 8081;
  static const String _discoveryPrefix = 'CHESS_HOST_ALIVE:';
  static const String initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  P2PMode? _mode;
  dynamic _channel; // WebSocket (host, dart:io) of WebSocketChannel (joiner)
  StreamSubscription? _channelSub;
  RawDatagramSocket? _discoverySocket;
  StreamSubscription<RawSocketEvent>? _discoverySub;
  Timer? _broadcastTimer;
  HttpServer? _server;

  /// Alleen voor tests: verbreek de verbinding abrupt (alsof er een storing is),
  /// zodat de reconnect-logica getest kan worden.
  @visibleForTesting
  Future<void> debugDropConnection() async {
    await _teardownChannel();
    _onDisconnected('test: verbinding verbroken');
  }

  /// Laatst gebruikte host (voor herverbinden) en poort.
  String? _lastHostIp;
  int _lastPort = kGamePort;

  /// Interne status voor reconnect-logica.
  bool _expectingDisconnect = false;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 8;

  /// Aantal huidige herverbindingspoginger (voor de UI-tekst).
  int get reconnectAttempt => _reconnectAttempt;
  int get maxReconnectAttempts => _maxReconnectAttempts;

  final StreamController<Map<String, dynamic>> _gameStream =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _gameStream.stream;

  chess_lib.Chess game = chess_lib.Chess();

  /// 'w' of 'b'; null zolang we nog niet verbonden zijn.
  String? playerColor;

  ChessConnectionState connectionState = ChessConnectionState.idle;
  String? errorMessage;

  /// Gekozen tijdcontrole voor dit spel (bepaald door de host).
  TimeControl timeControl = TimeControl.defaultPreset;

  /// Laatst ontdekte host via UDP-broadcast, bijvoorbeeld "192.168.1.23".
  String? discoveredHostIp;

  bool get isConnected => connectionState == ChessConnectionState.connected;
  bool get isConnecting =>
      connectionState == ChessConnectionState.connecting ||
      connectionState == ChessConnectionState.searching ||
      connectionState == ChessConnectionState.reconnecting;
  bool get isSearching => connectionState == ChessConnectionState.searching;
  bool get isHost => _mode == P2PMode.host;
  bool get isGameOver => game.game_over || flaggedLoser != null;

  /// Kleur van de speler die op tijd verloor ('w' of 'b'), of null.
  String? flaggedLoser;

  /// Mag de lokale speler nu een zet doen?
  bool get isMyTurn {
    if (!isConnected || game.game_over || flaggedLoser != null) return false;
    final localIsWhite = playerColor == 'w';
    final boardTurnIsWhite = game.turn == chess_lib.Chess.WHITE;
    return localIsWhite == boardTurnIsWhite;
  }

  String get gameStatus {
    if (game.in_checkmate) return 'checkmate';
    if (game.in_stalemate) return 'stalemate';
    if (game.in_draw) return 'draw';
    if (game.in_check) return 'check';
    return 'ongoing';
  }

  /// Nederlandstalige eind/stand-tekst voor het scherm, of null als het
  /// spel nog loopt.
  String? get gameOverMessage {
    if (flaggedLoser != null) {
      return playerColor == flaggedLoser
          ? '⏰ Je tijd is op — tegenstander wint.'
          : '⏰ Tegenstander was te laat — jij wint!';
    }
    if (game.in_checkmate) {
      // De kant aan zet is schaakmat en verliest dus.
      final loserIsWhite = game.turn == chess_lib.Chess.WHITE;
      return loserIsWhite ? '🏆 Schaakmat — zwart wint!' : '🏆 Schaakmat — wit wint!';
    }
    if (game.in_stalemate) return 'Patt — remise.';
    if (game.in_draw) return 'Remise.';
    return null;
  }

  // ───────────────────────── Discovery ─────────────────────────

  /// Start het zoeken naar hosts op het LAN via UDP-broadcast.
  /// Gevonden hosts komen in [discoveredHostIp]; de UI bepaalt of/wanneer
  /// er verbonden wordt.
  Future<void> autoDiscover() async {
    await _stopDiscovery();
    _mode = P2PMode.join;
    connectionState = ChessConnectionState.searching;
    errorMessage = null;
    notifyListeners();

    try {
      _discoverySocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, kDiscoveryPort);
      _discoverySocket!.broadcastEnabled = true;
      _discoverySub = _discoverySocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _discoverySocket?.receive();
        if (datagram == null) return;
        final message = utf8.decode(datagram.data, allowMalformed: true);
        if (!message.startsWith(_discoveryPrefix)) return;
        final hostIp = datagram.address.address;
        if (hostIp == '0.0.0.0') return;
        if (discoveredHostIp != hostIp) {
          discoveredHostIp = hostIp;
          notifyListeners();
        }
      });
    } catch (e) {
      connectionState = ChessConnectionState.error;
      errorMessage = 'Kan niet naar hosts zoeken: $e';
      notifyListeners();
    }
  }

  Future<void> _stopDiscovery() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    await _discoverySub?.cancel();
    _discoverySub = null;
    try {
      _discoverySocket?.close();
    } catch (_) {}
    _discoverySocket = null;
  }

  void _startBroadcasting(int port) {
    _stopDiscovery().then((_) async {
      try {
        // Efemerale poort, zodat de sender niet botst met een listener op
        // dezelfde machine.
        _discoverySocket =
            await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _discoverySocket!.broadcastEnabled = true;
        _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (_mode != P2PMode.host || _discoverySocket == null) {
            timer.cancel();
            return;
          }
          try {
            _discoverySocket!.send(
              utf8.encode('$_discoveryPrefix$port'),
              InternetAddress('255.255.255.255'),
              kDiscoveryPort,
            );
          } catch (e) {
            debugPrint('Discovery broadcast mislukt: $e');
          }
        });
      } catch (e) {
        debugPrint('Discovery broadcast kon niet starten: $e');
      }
    });
  }

  // ─────────────────────────── Hosten ───────────────────────────

  /// Start een host op [port]. Geeft true terug als de server draait.
  Future<bool> startHost({int port = kGamePort, TimeControl? timeControl}) async {
    await leaveGame();
    _expectingDisconnect = false;
    _reconnectAttempt = 0;
    _lastPort = port;
    this.timeControl = timeControl ?? TimeControl.defaultPreset;
    _mode = P2PMode.host;
    playerColor = 'w';
    game = chess_lib.Chess();
    flaggedLoser = null;
    connectionState = ChessConnectionState.connecting; // wacht op tegenstander
    errorMessage = null;
    notifyListeners();

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } catch (e) {
      connectionState = ChessConnectionState.error;
      errorMessage =
          'Kon geen server starten op poort $port. Is die al in gebruik? ($e)';
      notifyListeners();
      return false;
    }
    _server = server;
    _startBroadcasting(port);

    server.listen(
      (request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.upgradeRequired;
          await request.response.close();
          return;
        }
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          // Host speelt altijd wit; de joiner hoort zwart te spelen.
          _attachConnection(socket);
          // Er is precies één tegenstander; de listener mag daarna dicht.
          await _server?.close(force: false);
          _server = null;
        } catch (e) {
          debugPrint('Upgrade naar WebSocket mislukt: $e');
        }
      },
      onError: (Object e) {
        debugPrint('Serverfout: $e');
      },
    );
    return true;
  }

  void _attachConnection(dynamic socket) {
    _channel = socket;
    _channelSub = socket.listen(
      (message) => _handleIncomingMessage(message),
      onError: (_) =>
          _onDisconnected('De verbinding met de tegenstander viel weg.'),
      onDone: () => _onDisconnected('De tegenstander heeft het spel verlaten.'),
      cancelOnError: false,
    );
    // playerColor staat bij de host al op 'w' (gezet in startHost).
    connectionState = ChessConnectionState.connected;
    _reconnectAttempt = 0;
    // Vertel de joiner dat hij zwart speelt en stuur de huidige stelling,
    // zodat een herverbindende speler direct weer synchroon loopt.
    _send({'type': 'init', 'color': 'b', 'tc': timeControl.toWire()});
    _send({'type': 'sync', 'fen': game.fen});
    _gameStream.add({'type': 'connected', 'color': 'b'});
    notifyListeners();
  }

  // ────────────────────────── Joinen ────────────────────────────

  Future<bool> joinGame(String hostIp, [int port = kGamePort]) async {
    await _teardownChannel();
    await _stopDiscovery();
    _expectingDisconnect = false;
    _reconnectAttempt = 0;
    _lastHostIp = hostIp;
    _lastPort = port;
    _mode = P2PMode.join;
    playerColor = 'b';
    game = chess_lib.Chess();
    flaggedLoser = null;
    connectionState = ChessConnectionState.connecting;
    errorMessage = null;
    notifyListeners();

    final uri = Uri.parse('ws://$hostIp:$port');
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _channelSub = channel.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (_) => _onDisconnected('Verbindingsfout met de host.'),
        onDone: () =>
            _onDisconnected('De host heeft de verbinding verbroken.'),
        cancelOnError: false,
      );
      // Wacht op de echte handshake in plaats van blind "verbonden" te melden.
      await channel.ready.timeout(const Duration(seconds: 8));
      connectionState = ChessConnectionState.connected;
      notifyListeners();
      return true;
    } on TimeoutException {
      await _teardownChannel();
      connectionState = ChessConnectionState.error;
      errorMessage =
          'Geen reactie van $hostIp:$port. Controleer of de host het spel draait.';
      notifyListeners();
      return false;
    } catch (e) {
      await _teardownChannel();
      connectionState = ChessConnectionState.error;
      errorMessage = 'Verbinding met $hostIp:$port mislukt: $e';
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────── Spel ────────────────────────────

  /// Verwerk een lokale zet: ververs de eigen stelling en stuur de FEN naar
  /// de tegenstander.
  void syncLocalMove(String fen) {
    game.load(fen);
    _send({'type': 'move', 'fen': fen});
    _gameStream.add({'type': 'update', 'fen': fen});
    notifyListeners();
  }

  /// Legt vast dat [loser] op tijd verloor en meldt dit aan de tegenstander.
  /// Beide toestellen berekenen dezelfde uitkomst (de kant die aan zet was
  /// toen de klok verliep); het bericht is een extra zekerheid.
  void flagGame(String loser) {
    if (flaggedLoser != null) return;
    if (loser != 'w' && loser != 'b') return;
    flaggedLoser = loser;
    _send({'type': 'flag', 'loser': loser});
    _gameStream.add({'type': 'flag', 'loser': loser});
    notifyListeners();
  }

  /// Zet het bord terug naar de beginstelling en meld dat aan de tegenstander.
  void resetGame() {
    game = chess_lib.Chess();
    flaggedLoser = null;
    _send({'type': 'reset'});
    _gameStream.add({'type': 'update', 'fen': game.fen});
    notifyListeners();
  }

  void _handleIncomingMessage(dynamic message) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message as String) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('Onleesbare game-boodschap genegeerd: $message');
      return;
    }

    switch (data['type']) {
      case 'move':
        final fen = data['fen'];
        if (fen is String) {
          game.load(fen);
          _gameStream.add({'type': 'update', 'fen': fen});
          notifyListeners();
        }
        break;
      case 'sync':
        final fen = data['fen'];
        if (fen is String && fen != game.fen) {
          game.load(fen);
        }
        _gameStream.add({'type': 'update', 'fen': game.fen});
        break;
      case 'reset':
        game = chess_lib.Chess();
        flaggedLoser = null;
        _gameStream.add({'type': 'update', 'fen': game.fen});
        notifyListeners();
        break;
      case 'flag':
        final loser = data['loser'];
        if (loser == 'w' || loser == 'b') {
          if (flaggedLoser == null) {
            flaggedLoser = loser as String?;
            _gameStream.add({'type': 'flag', 'loser': loser});
            notifyListeners();
          }
        }
        break;
      case 'init':
        playerColor = data['color'] as String?;
        final tc = TimeControl.fromWire(data['tc']?.toString());
        if (tc != null) timeControl = tc;
        _gameStream.add({'type': 'started', 'color': playerColor});
        notifyListeners();
        break;
      default:
        debugPrint('Onbekend berichttype: ${data['type']}');
    }
  }

  /// Start/vervolgt de reconnect-pogingen. Werkt voor zowel host als joiner.
  Future<void> _startReconnect() async {
    if (connectionState == ChessConnectionState.disconnected) return; // opgegeven
    _reconnectAttempt++;
    if (_reconnectAttempt > _maxReconnectAttempts) {
      connectionState = ChessConnectionState.disconnected;
      errorMessage =
          'Verbinding verloren — na $_maxReconnectAttempts pogingen opgegeven. Tik op "Opnieuw proberen".';
      _gameStream.add({'type': 'disconnected', 'message': errorMessage});
      notifyListeners();
      return;
    }
    connectionState = ChessConnectionState.reconnecting;
    errorMessage =
        'Verbinding verloren — opnieuw verbinden (poging $_reconnectAttempt/$_maxReconnectAttempts)…';
    notifyListeners();
    if (_mode != P2PMode.host) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (connectionState != ChessConnectionState.reconnecting) return;
    }
    if (_mode == P2PMode.host) {
      await _listenForReconnect();
    } else {
      await _rejoin();
    }
  }

  /// Host: bind de server opnieuw op dezelfde poort en wacht op de joiner.
  Future<void> _listenForReconnect() async {
    try {
      await _teardownChannel();
      await _server?.close(force: true);
      final server = await HttpServer.bind(InternetAddress.anyIPv4, _lastPort,
          shared: true);
      _server = server;
      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.upgradeRequired;
          await request.response.close();
          return;
        }
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          await _server?.close(force: true);
          _server = null;
          _attachConnection(socket);
        } catch (e) {
          debugPrint('Reconnect upgrade mislukt: $e');
        }
      }, onError: (Object e) => debugPrint('Serverfout (reconnect): $e'));
      // Na 5 s zonder verbinding: nieuwe poging (of opgeven).
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (connectionState == ChessConnectionState.reconnecting) {
          _server?.close(force: true);
          _server = null;
          _startReconnect();
        }
      });
    } catch (e) {
      debugPrint('Reconnect-luisterfout: $e');
      await _startReconnect();
    }
  }

  /// Joiner: probeer opnieuw te verbinden met de host.
  Future<void> _rejoin() async {
    final ip = _lastHostIp;
    if (ip == null) {
      connectionState = ChessConnectionState.disconnected;
      errorMessage = 'Geen host-adres bekend om opnieuw mee te verbinden.';
      notifyListeners();
      return;
    }
    try {
      await _teardownChannel();
      final channel =
          WebSocketChannel.connect(Uri.parse('ws://$ip:$_lastPort'));
      _channel = channel;
      _channelSub = channel.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (_) => _onDisconnected('Verbindingsfout met de host.'),
        onDone: () => _onDisconnected('De host heeft de verbinding verbroken.'),
        cancelOnError: false,
      );
      await channel.ready.timeout(const Duration(seconds: 5));
      connectionState = ChessConnectionState.connected;
      _reconnectAttempt = 0;
      errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Reconnect poging $_reconnectAttempt mislukt: $e');
      await _startReconnect();
    }
  }

  /// Handmatig opnieuw proberen vanuit het foutscherm.
  Future<void> retryConnection() async {
    if (connectionState != ChessConnectionState.disconnected &&
        connectionState != ChessConnectionState.error) {
      return;
    }
    _reconnectAttempt = 0;
    _expectingDisconnect = false;
    await _startReconnect();
  }

  void _onDisconnected(String message) {
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    final unexpected = !_expectingDisconnect &&
        _mode != null &&
        (connectionState == ChessConnectionState.connected ||
            connectionState == ChessConnectionState.reconnecting);
    if (unexpected) {
      errorMessage = message;
      _gameStream.add({'type': 'reconnecting', 'message': message});
      _startReconnect();
      return;
    }
    connectionState = ChessConnectionState.disconnected;
    errorMessage = message;
    _gameStream.add({'type': 'disconnected', 'message': message});
    notifyListeners();
  }

  Future<void> _teardownChannel() async {
    await _channelSub?.cancel();
    _channelSub = null;
    final channel = _channel;
    _channel = null;
    try {
      // Joiner-kant: web_socket_channel heeft geen .close(), wel .sink.close().
      // Host-kant (dart:io WebSocket) heeft wel .close().
      final sink = (channel as dynamic)?.sink;
      if (sink != null) {
        await sink.close();
      } else {
        await (channel as dynamic)?.close();
      }
    } catch (_) {
      // Een al gesloten socket mag geen fout geven.
    }
  }

  /// Verlaat het spel en ruim alles op (server, discovery, socket, stelling).
  Future<void> leaveGame() async {
    _expectingDisconnect = true;
    _reconnectAttempt = 0;
    await _teardownChannel();
    await _stopDiscovery();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    game = chess_lib.Chess();
    flaggedLoser = null;
    _mode = null;
    playerColor = null;
    discoveredHostIp = null;
    errorMessage = null;
    connectionState = ChessConnectionState.idle;
    notifyListeners();
  }

  void _send(Map<String, dynamic> data) {
    final channel = _channel;
    if (channel == null) return;
    final encoded = jsonEncode(data);
    try {
      if (channel is WebSocketChannel) {
        channel.sink.add(encoded); // joiner-kant
      } else if (channel is WebSocket) {
        channel.add(encoded); // host-kant (dart:io WebSocket)
      } else {
        final sink = (channel as dynamic).sink;
        if (sink != null) {
          sink.add(encoded);
        } else {
          (channel as dynamic).add(encoded);
        }
      }
    } catch (e) {
      debugPrint('Verzenden mislukt: $e');
    }
  }

  @override
  void dispose() {
    _teardownChannel();
    _stopDiscovery();
    _server?.close(force: true);
    _gameStream.close();
    super.dispose();
  }
}
