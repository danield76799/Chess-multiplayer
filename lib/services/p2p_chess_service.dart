import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/local_ws_server.dart'; 
import 'package:chess/chess.dart' as chess_lib;

enum P2PMode { host, join }

class P2PChessService with ChangeNotifier {
  P2PMode? _mode;
  WebSocketChannel? _channel;
  
  final StreamController<Map<String, dynamic>> _gameStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _gameStream.stream;

  chess_lib.Chess game = chess_lib.Chess();
  String? playerColor; 
  bool isConnected = false;

  Future<void> startHost(int port) async {
    _mode = P2PMode.host;
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

  Future<void> joinGame(String hostIp, int port) async {
    _mode = P2PMode.join;
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

  void _handleConnection(WebSocketChannel socket, String color) {
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
      final move = chess_lib.Move.fromAlgebraic(data['move']);
      if (game.makeMove(move)) {
        _gameStream.add({'type': 'update', 'fen': game.fen, 'lastMove': data['move']});
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
    final move = chess_lib.Move.fromAlgebraic(algebraicMove);
    if (game.makeMove(move)) {
      sendMove({'type': 'move', 'move': algebraicMove});
      _gameStream.add({'type': 'update', 'fen': game.fen, 'lastMove': algebraicMove});
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _gameStream.close();
    super.dispose();
  }
}
