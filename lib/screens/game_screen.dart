import 'dart:async';
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
  final ChessBoardController controller = ChessBoardController();
  late final P2PChessService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    // Het bord volgt de service via een FEN-synchronisatie. Een load() op
    // een identieke FEN is onschadelijk, dus dubbele updates zijn oké.
    _service = context.read<P2PChessService>();
    _subscription = _service.gameStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'update' && data['fen'] is String) {
        final fen = data['fen'] as String;
        if (controller.game.fen != fen) {
          controller.loadFen(fen);
        } else {
          controller.loadFen(fen); // zelfde stelling: board toch verversen
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Verlaat het spel bij het sluiten van het scherm; de tegenstander
    // krijgt dan "verbinding verbroken" te zien.
    unawaited(_service.leaveGame());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<P2PChessService>();
    final String colorLabel =
        service.playerColor == 'w' ? 'Wit' : (service.playerColor == 'b' ? 'Zwart' : '—');

    return Scaffold(
      appBar: AppBar(
        title: Text('Jij: $colorLabel'),
        actions: [
          if (service.connectionState == ChessConnectionState.connected)
            IconButton(
              tooltip: 'Opnieuw beginnen',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => service.resetGame(),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(service),
      ),
    );
  }

  Widget _buildBody(P2PChessService service) {
    // Host wacht op een tegenstander.
    if (service.connectionState == ChessConnectionState.connecting ||
        service.connectionState == ChessConnectionState.searching) {
      return _WaitingView(isHost: service.isHost);
    }

    // Verbinding mislukt of verbroken.
    if (service.connectionState == ChessConnectionState.error ||
        service.connectionState == ChessConnectionState.disconnected) {
      return _ErrorView(
        message: service.errorMessage ?? 'De verbinding is verbroken.',
        onBack: () => Navigator.of(context).pop(),
      );
    }

    // Verbonden: het bord.
    final gameOver = service.gameOverMessage;
    final myTurn = service.isMyTurn;
    final orientation = service.playerColor == 'b'
        ? PlayerColor.black
        : PlayerColor.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = (constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth - 24
                : constraints.maxHeight - 140)
            .clamp(200.0, 560.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          gameOver != null
                              ? Icons.emoji_events
                              : (myTurn ? Icons.play_circle_fill : Icons.hourglass_empty),
                          size: 20,
                          color: gameOver != null
                              ? Colors.amber
                              : (myTurn ? Colors.greenAccent : Colors.white54),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gameOver ??
                                (myTurn
                                    ? 'Jouw zet'
                                    : 'Tegenstander is aan zet…'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (service.gameStatus == 'check')
                          const Text(
                            'Schaak!',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ChessBoard(
                  controller: controller,
                  size: boardSize,
                  boardOrientation: orientation,
                  enableUserMoves: myTurn && gameOver == null,
                  onMove: () {
                    // De board heeft de zet al op controller.game toegepast;
                    // stuur de nieuwe stelling naar de tegenstander.
                    service.syncLocalMove(controller.game.fen);
                  },
                ),
                const SizedBox(height: 16),
                if (gameOver != null)
                  FilledButton.icon(
                    onPressed: service.resetGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Nog een potje'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingView extends StatelessWidget {
  final bool isHost;
  const _WaitingView({required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              isHost
                  ? 'Wachten op tegenstander…\nZorg dat de ander op dit netwerk het spel zoekt.'
                  : 'Verbinden met tegenstander…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuleren'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBack,
              child: const Text('Terug naar menu'),
            ),
          ],
        ),
      ),
    );
  }
}
