import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/chess_ai.dart';
import '../services/p2p_chess_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/board_frame.dart';
import '../widgets/captured_pieces.dart';
import '../widgets/sound_toggle.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ChessBoardController controller = ChessBoardController();
  late final P2PChessService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _pieceCount = 32;
  String? _lastSoundFen;

  @override
  void initState() {
    super.initState();
    // Houd het scherm aan tijdens het spelen.
    try {
      WakelockPlus.enable();
    } catch (_) {}
    // Het bord volgt de service via een FEN-synchronisatie. Een load() op
    // een identieke FEN is onschadelijk, dus dubbele updates zijn oké.
    _service = context.read<P2PChessService>();
    _subscription = _service.gameStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'connected' || data['type'] == 'started') {
        SoundService.instance.play(ChessSound.start);
        return;
      }
      if (data['type'] == 'update' && data['fen'] is String) {
        final fen = data['fen'] as String;
        controller.loadFen(fen);
        _announceMove(fen);
      }
    });
  }

  /// Speelt het bijbehorende geluid voor een zet (eigen of van de tegen-
  /// stander) en houdt de stukntelling bij voor de slag-detectie.
  void _announceMove(String fen) {
    if (_lastSoundFen == fen) return; // eigen/dubbele update overslaan
    _lastSoundFen = fen;
    final game = _service.game;
    final isStart = fen == P2PChessService.initialFen;
    if (isStart) {
      _pieceCount = 32;
      SoundService.instance.play(ChessSound.start);
      return;
    }
    final after = ChessAI.pieceCount(game);
    final wasCapture = after < _pieceCount;
    _pieceCount = after;
    bool? playerWon;
    if (game.in_checkmate && _service.playerColor != null) {
      final loserIsWhite = game.turn == chess_lib.Chess.WHITE;
      playerWon = loserIsWhite != (_service.playerColor == 'w');
    }
    SoundService.instance.playMoveOutcome(
      wasCapture: wasCapture,
      inCheck: game.in_check,
      gameOver: game.game_over,
      playerWon: playerWon,
    );
  }


  @override
  void dispose() {
    _subscription?.cancel();
    try {
      WakelockPlus.disable();
    } catch (_) {}
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
          const SoundToggle(),
          if (service.connectionState == ChessConnectionState.connected)
            IconButton(
              tooltip: 'Opnieuw beginnen',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => service.resetGame(),
            ),
        ],
      ),
      body: Container(
        decoration: ChessTheme.backgroundDecoration,
        child: SafeArea(
          child: _buildBody(service),
        ),
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
                ? constraints.maxWidth - 16
                : constraints.maxHeight - 190)
            .clamp(200.0, 900.0);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Center(
                  child: StatusPill(
                    icon: gameOver != null
                        ? Icons.emoji_events
                        : (myTurn ? Icons.play_circle_fill : Icons.hourglass_empty),
                    iconColor: gameOver != null
                        ? ChessTheme.gold
                        : (myTurn ? ChessTheme.green : ChessTheme.textDim),
                    text: gameOver ??
                        (myTurn ? 'Jouw zet' : 'Tegenstander is aan zet…'),
                    trailing: service.gameStatus == 'check'
                        ? const Text(
                            '⚔️ Schaken!',
                            style: TextStyle(
                              color: ChessTheme.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                BoardFrame(
                  child: ChessBoard(
                    controller: controller,
                    size: boardSize,
                    boardOrientation: orientation,
                    boardColor: BoardColor.orange,
                    enableUserMoves: myTurn && gameOver == null,
                    onMove: () {
                      // De board heeft de zet al op controller.game toegepast;
                      // stuur de nieuwe stelling naar de tegenstander.
                      service.syncLocalMove(controller.game.fen);
                    },
                  ),
                ),
                CapturedPiecesBar(game: service.game),
                const SizedBox(height: 16),
                if (gameOver != null)
                  FilledButton.icon(
                    onPressed: service.resetGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('🔁  Nog een potje!'),
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
