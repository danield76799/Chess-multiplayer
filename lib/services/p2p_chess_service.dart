import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chess/chess.dart' as chess_lib;

enum P2PMode { host, join }

enum ChessConnectionState { idle, searching, connecting, connected, disconnected, error }

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

  final StreamController<Map<String, dynamic>> _gameStream =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _gameStream.stream;

  chess_lib.Chess game = chess_lib.Chess();

  /// 'w' of 'b'; null zolang we nog niet verbonden zijn.
  String? playerColor;

  ChessConnectionState connectionState = ChessConnectionState.idle;
  String? errorMessage;

  /// Laatst ontdekte host via UDP-broadcast, bijvoorbeeld "192.168.1.23".
  String? discoveredHostIp;

  bool get isConnected => connectionState == ChessConnectionState.connected;
  bool get isConnecting =>
      connectionState == ChessConnectionState.connecting ||
      connectionState == ChessConnectionState.searching;
  bool get isSearching => connectionState == ChessConnectionState.searching;
  bool get isHost => _mode == P2PMode.host;
  bool get isGameOver => game.game_over;

  /// Mag de lokale speler nu een zet doen?
  bool get isMyTurn {
    if (!isConnected || game.game_over) return false;
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
    if (game.in_checkmate) {
      // De kant aan zet is schaakmat en verliest dus.
      final loserIsWhite = game.turn == chess_lib.Chess.WHITE;
      return loserIsWhite ? 'Schaakmat — zwart wint!' : 'Schaakmat — wit wint!';
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
  Future<bool> startHost({int port = kGamePort}) async {
    await leaveGame();
    _mode = P2PMode.host;
    playerColor = 'w';
    game = chess_lib.Chess();
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
    // Vertel de joiner dat hij zwart speelt.
    _send({'type': 'init', 'color': 'b'});
    _gameStream.add({'type': 'connected', 'color': 'b'});
    notifyListeners();
  }

  // ────────────────────────── Joinen ────────────────────────────

  Future<bool> joinGame(String hostIp, [int port = kGamePort]) async {
    await _teardownChannel();
    await _stopDiscovery();
    _mode = P2PMode.join;
    playerColor = 'b';
    game = chess_lib.Chess();
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

  /// Zet het bord terug naar de beginstelling en meld dat aan de tegenstander.
  void resetGame() {
    game = chess_lib.Chess();
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
      case 'reset':
        game = chess_lib.Chess();
        _gameStream.add({'type': 'update', 'fen': game.fen});
        notifyListeners();
        break;
      case 'init':
        playerColor = data['color'] as String?;
        _gameStream.add({'type': 'started', 'color': playerColor});
        notifyListeners();
        break;
      default:
        debugPrint('Onbekend berichttype: ${data['type']}');
    }
  }

  void _onDisconnected(String message) {
    connectionState = ChessConnectionState.disconnected;
    errorMessage = message;
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    _gameStream.add({'type': 'disconnected', 'message': message});
    notifyListeners();
  }

  Future<void> _teardownChannel() async {
    await _channelSub?.cancel();
    _channelSub = null;
    final channel = _channel;
    _channel = null;
    try {
      // WebSocket (dart:io) en WebSocketChannel hebben allebei close().
      await (channel as dynamic)?.close();
    } catch (_) {
      // Een al gesloten socket mag geen fout geven.
    }
  }

  /// Verlaat het spel en ruim alles op (server, discovery, socket, stelling).
  Future<void> leaveGame() async {
    await _teardownChannel();
    await _stopDiscovery();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    game = chess_lib.Chess();
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
