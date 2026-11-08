import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:provider/provider.dart';
import '../services/p2p_chess_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ChessBoardController controller = ChessBoardController();

  @override
  void initState() {
    super.initState();
    final service = Provider.of<P2PChessService>(this, listen: false);
    
    service.gameStream.listen((data) {
      if (data['type'] == 'update') {
        setState(() {
          controller.game.fen = data['fen'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<P2PChessService>(this);

    return Scaffold(
      appBar: AppBar(title: Text('Kleur: ${service.playerColor == 'w' ? 'Wit' : 'Zwart'}')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChessBoard(
            controller: controller,
            onMove: () {
              final lastMove = controller.game.history.last;
              service.makeMove(lastMove.toString());
            },
          ),
          const SizedBox(height: 20),
          Text('Status: ${service.isConnected ? 'Verbonden' : 'Verbinding maken...'}'),
        ],
      ),
    );
  }
}
