import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chess/chess.dart' as chess_lib;

enum P2PMode { host, join }

class P2PChessService with ChangeNotifier {
  P2PMode? _mode;
  dynamic _channel;
  RawDatagramSocket? _discoverySocket;
  
  final StreamController<Map<String, dynamic>> _gameStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _gameStream.stream;

  chess_lib.Chess game = chess_lib.Chess();
  String? playerColor; 
  bool isConnected = false;
  bool isSearching = false;

  // --- DISCOVERY LOGICA ---

  void _startBroadcasting(int port) async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _discoverySocket!.broadcastsEnabled = true;
      
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_mode != P2PMode.host) {
          timer.cancel();
          return;
        }
        final message = utf8.encode("CHESS_HOST_ALIVE:$port");
        _discoverySocket!.send(message, InternetAddress('255.255.255.255'), 8081);
      });
    } catch (e) {
      debugPrint('Discovery broadcast error: $e');
    }
  }

  void _startListening() async {
    isSearching = true;
    notifyListeners();

    try {
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _discoverySocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _discoverySocket!.receive();
          if (dg != null) {
            final message = utf8.decode(dg.data);
            if (message.startsWith("CHESS_HOST_ALIVE")) {
              final port = int.parse(message.split(':')[1]);
              final hostIp = dg.address?.address;
              if (hostIp != null) {
                debugPrint('Host gevonden op $hostIp:$port');
                joinGame(hostIp, port);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Discovery listen error: $e');
      isSearching = false;
      notifyListeners();
    }
  }

  // --- HOST LOGICA ---

  Future<void> startHost(int port) async {
    _mode = P2PMode.host;
    _startBroadcasting(port);
    
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    server.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleConnection(socket, 'b'); 
        server.close(); 
      }
    });

    playerColor = 'w'; 
    notifyListeners();
  }

  // --- JOIN LOGICA ---

  Future<void> joinGame(String hostIp, int port) async {
    _mode = P2PMode.join;
    _discoverySocket?.close();
    isSearching = false;

    try {
      final uri = Uri.parse('ws://$hostIp:$port');
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen((message) {
        _handleIncomingMessage(message);
      });

      playerColor = 'b'; 
      isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Verbindingsfout: $e');
    }
  }

  void autoDiscover() {
    _startListening();
  }

  void _handleConnection(dynamic socket, String color) {
    _channel = socket;
    isConnected = true;
    
    _channel!.stream.listen((message) {
      _handleIncomingMessage(message);
    });

    sendMove({'type': 'init', 'color': color});
    notifyListeners();
  }

  void _handleIncomingMessage(dynamic message) {
    final data = jsonDecode(message as String);
    
    if (data['type'] == 'move') {
      final moveStr = data['move'];
      if (game.move(moveStr)) {
        _gameStream.add({'type': 'update', 'fen': game.fen, 'lastMove': moveStr});
      }
    } else if (data['type'] == 'init') {
      playerColor = data['color'];
      _gameStream.add({'type': 'started', 'color': playerColor});
    }
    notifyListeners();
  }

  void sendMove(Map<String, dynamic> moveData) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(moveData));
    }
  }

  void makeMove(String algebraicMove) {
    if (game.move(algebraicMove)) {
      sendMove({'type': 'move', 'move': algebraicMove});
      _gameStream.add({'type': 'update', 'fen': game.fen, 'lastMove': algebraicMove});
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _discoverySocket?.close();
    _gameStream.close();
    super.dispose();
  }
}
