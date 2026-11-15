import 'dart:async';

import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import '../services/chess_ai.dart';

/// Schaken tegen de ingebouwde computer, volledig offline.
///
/// De speler kiest vooraf kleur en moeilijkheid; de computer speelt de
/// andere kant. De stelling wordt lokaal in [Chess] bijgehouden en het
/// bord volgt via [ChessBoardController].
class SinglePlayerScreen extends StatefulWidget {
  final AIDifficulty difficulty;
  final bool playerIsWhite;

  const SinglePlayerScreen({
    super.key,
    required this.difficulty,
    required this.playerIsWhite,
  });

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen> {
  late final chess_lib.Chess _game;
  late final ChessBoardController _controller;
  bool _aiThinking = false;
  Timer? _aiTimer;

  bool get _aiPlaysWhite => !widget.playerIsWhite;

  @override
  void initState() {
    super.initState();
    _game = chess_lib.Chess();
    _controller = ChessBoardController.fromGame(_game);
    // Speelt de computer wit, dan zet hij als eerste.
    if (_aiPlaysWhite) {
      _scheduleAiMove(delay: const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  bool get _isPlayerTurn {
    if (_game.game_over) return false;
    final playerColor = widget.playerIsWhite
        ? chess_lib.Chess.WHITE
        : chess_lib.Chess.BLACK;
    return _game.turn == playerColor;
  }

  bool get _isAiTurn {
    if (_game.game_over) return false;
    final aiColor = _aiPlaysWhite ? chess_lib.Chess.WHITE : chess_lib.Chess.BLACK;
    return _game.turn == aiColor;
  }

  void _scheduleAiMove({Duration delay = const Duration(milliseconds: 450)}) {
    if (!_isAiTurn || _aiThinking) return;
    setState(() => _aiThinking = true);
    _aiTimer?.cancel();
    _aiTimer = Timer(delay, _playAiMove);
  }

  void _playAiMove() {
    if (!mounted || !_isAiTurn) {
      if (mounted) setState(() => _aiThinking = false);
      return;
    }
    final move = ChessAI.pickMove(_game, difficulty: widget.difficulty);
    if (move != null) {
      if (move.promotion != null) {
        _controller.makeMoveWithPromotion(
          from: move.fromAlgebraic,
          to: move.toAlgebraic,
          pieceToPromoteTo: move.promotion!.name,
        );
      } else {
        _controller.makeMove(from: move.fromAlgebraic, to: move.toAlgebraic);
      }
    }
    if (mounted) setState(() => _aiThinking = false);
  }

  void _onUserMove() {
    setState(() {});
    if (_game.game_over) return;
    _scheduleAiMove();
  }

  void _undo() {
    if (_game.half_moves == 0) return;
    setState(() {
      _controller.undoMove(); // laatste zet (computer of speler)
      // Zolang het niet de beurt van de speler is, nog een zet terug,
      // zodat de speler weer aan zet is.
      var guard = 0;
      while (!_isPlayerTurn && _game.half_moves > 0 && guard++ < 2) {
        _controller.undoMove();
      }
    });
  }

  void _reset() {
    _aiTimer?.cancel();
    setState(() {
      _controller.resetBoard();
      _aiThinking = false;
    });
    _scheduleAiMove(delay: const Duration(milliseconds: 600));
  }

  String get _difficultyLabel => switch (widget.difficulty) {
        AIDifficulty.makkelijk => 'Makkelijk',
        AIDifficulty.normaal => 'Gemiddeld',
        AIDifficulty.moeilijk => 'Moeilijk',
      };

  String? get _gameOverMessage {
    if (_game.in_checkmate) {
      final loserIsWhite = _game.turn == chess_lib.Chess.WHITE;
      final playerWon = (loserIsWhite == widget.playerIsWhite) == false;
      return playerWon ? 'Schaakmat — jij wint! 🎉' : 'Schaakmat — de computer wint.';
    }
    if (_game.in_stalemate) return 'Patt — remise.';
    if (_game.in_draw) return 'Remise.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gameOver = _gameOverMessage;
    final myTurn = _isPlayerTurn && !_aiThinking;
    final orientation =
        widget.playerIsWhite ? PlayerColor.white : PlayerColor.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tegen de computer · $_difficultyLabel'),
        actions: [
          IconButton(
            tooltip: 'Zet terugdraaien',
            icon: const Icon(Icons.undo),
            onPressed: _game.half_moves == 0 ? null : _undo,
          ),
          IconButton(
            tooltip: 'Opnieuw beginnen',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
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
                                  : (_aiThinking
                                      ? Icons.smart_toy
                                      : Icons.person),
                              size: 20,
                              color: gameOver != null
                                  ? Colors.amber
                                  : (_aiThinking
                                      ? Colors.white54
                                      : Colors.greenAccent),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                gameOver ??
                                    (_aiThinking
                                        ? 'Computer denkt na…'
                                        : 'Jouw zet'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_game.in_check && gameOver == null)
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
                      controller: _controller,
                      size: boardSize,
                      boardOrientation: orientation,
                      enableUserMoves: myTurn && gameOver == null,
                      onMove: _onUserMove,
                    ),
                    const SizedBox(height: 16),
                    if (gameOver != null)
                      FilledButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Nog een potje'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
