import 'dart:async';

import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/chess_ai.dart';
import '../services/chess_clock.dart';
import '../services/chess_history.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/chess_clock_bar.dart';
import '../widgets/board_frame.dart';
import '../widgets/captured_pieces.dart';
import '../widgets/sound_toggle.dart';

/// Schaken tegen de ingebouwde computer, volledig offline.
///
/// De speler kiest vooraf kleur en moeilijkheid; de computer speelt de
/// andere kant. De stelling wordt lokaal in [Chess] bijgehouden en het
/// bord volgt via [ChessBoardController].
class SinglePlayerScreen extends StatefulWidget {
  final AIDifficulty difficulty;
  final bool playerIsWhite;
  final TimeControl timeControl;

  const SinglePlayerScreen({
    super.key,
    required this.difficulty,
    required this.playerIsWhite,
    this.timeControl = TimeControl.defaultPreset,
  });

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen>
    with WidgetsBindingObserver {
  late final chess_lib.Chess _game;
  late final ChessBoardController _controller;
  bool _aiThinking = false;
  Timer? _aiTimer;
  Timer? _clockTicker;
  bool _flagged = false;
  String? _flaggedLoser; // 'w' of 'b' bij tijdsoverschrijding
  bool _showLastMove = false;
  late final ChessClockSet _clock = ChessClockSet(widget.timeControl);
  int _lastPieceCount = 32;

  bool get _aiPlaysWhite => !widget.playerIsWhite;

  @override
  void initState() {
    super.initState();
    _game = chess_lib.Chess();
    _controller = ChessBoardController.fromGame(_game);
    _lastPieceCount = ChessAI.pieceCount(_game);
    // Houd het scherm wakker tijdens het spelen (anders vergrendelt het
    // toestel tijdens het denken).
    try {
      WakelockPlus.enable();
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    _startClockTicker();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SoundService.instance.play(ChessSound.start),
    );
    // Speelt de computer wit, dan zet hij als eerste.
    if (_aiPlaysWhite) {
      _scheduleAiMove(delay: const Duration(milliseconds: 600));
    }
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _clockTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _clock.pause();
    } else if (state == AppLifecycleState.resumed) {
      _clock.resume();
    }
  }

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (_gameOverMessage != null) return; // klok staat stil bij einde spel
      final side = _game.turn == chess_lib.Chess.WHITE ? 'w' : 'b';
      setState(() {}); // ververs de weergave
      _clock.tick(side);
      final flag = _clock.flaggedSide();
      if (flag != null && !_flagged && !_game.game_over) {
        _handleFlag(flag);
      }
    });
  }

  void _handleFlag(String loser) {
    if (_flagged) return;
    setState(() {
      _flagged = true;
      _flaggedLoser = loser;
    });
    final playerColor = widget.playerIsWhite ? 'w' : 'b';
    SoundService.instance.play(loser == playerColor ? ChessSound.lose : ChessSound.win);
  }

  void _resetClock() {
    _flagged = false;
    _flaggedLoser = null;
    _clock.reset();
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
      final before = ChessAI.pieceCount(_game);
      if (move.promotion != null) {
        _controller.makeMoveWithPromotion(
          from: move.fromAlgebraic,
          to: move.toAlgebraic,
          pieceToPromoteTo: move.promotion!.name,
        );
      } else {
        _controller.makeMove(from: move.fromAlgebraic, to: move.toAlgebraic);
      }
      _announceOutcome(wasCapture: ChessAI.pieceCount(_game) < before);
      _clock.incrementFor(_aiPlaysWhite ? 'w' : 'b');
    }
    if (mounted) setState(() => _aiThinking = false);
  }

  /// Speelt het bijbehorende geluid (slag/schaak/mat/pat) en onthoudt
  /// het aantal stukken voor de volgende detectie.
  void _announceOutcome({required bool wasCapture}) {
    final over = _game.game_over;
    bool? playerWon;
    if (_game.in_checkmate) {
      final loserIsWhite = _game.turn == chess_lib.Chess.WHITE;
      playerWon = loserIsWhite != widget.playerIsWhite;
    }
    SoundService.instance.playMoveOutcome(
      wasCapture: wasCapture,
      inCheck: _game.in_check,
      gameOver: over,
      playerWon: playerWon,
    );
    _lastPieceCount = ChessAI.pieceCount(_game);
  }

  void _onUserMove() {
    final wasCapture = ChessAI.pieceCount(_game) < _lastPieceCount;
    _announceOutcome(wasCapture: wasCapture);
    _clock.incrementFor(widget.playerIsWhite ? 'w' : 'b');
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
      _lastPieceCount = ChessAI.pieceCount(_game);
    });
  }

  void _reset() {
    _aiTimer?.cancel();
    SoundService.instance.play(ChessSound.start);
    setState(() {
      _controller.resetBoard();
      _aiThinking = false;
      _lastPieceCount = 32;
      _resetClock();
    });
    _scheduleAiMove(delay: const Duration(milliseconds: 600));
  }

  String get _difficultyLabel => switch (widget.difficulty) {
        AIDifficulty.makkelijk => '🐣 Makkelijk',
        AIDifficulty.normaal => '🙂 Gemiddeld',
        AIDifficulty.moeilijk => '🦁 Moeilijk',
      };

  String? get _gameOverMessage {
    if (_flagged) {
      final loserIsPlayer =
          _flaggedLoser == (widget.playerIsWhite ? 'w' : 'b');
      return loserIsPlayer
          ? '⏰ Je tijd is op — de computer wint.'
          : '⏰ De computer was te laat — jij wint! 🎉';
    }
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
    final opponentMove = lastOpponentMove(_game, localIsWhite: widget.playerIsWhite);
    final showArrow = _showLastMove && opponentMove != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tegen de computer · $_difficultyLabel'),
        actions: [
          const SoundToggle(),
          IconButton(
            tooltip: 'Zet terugdraaien',
            icon: const Icon(Icons.undo),
            onPressed: _game.half_moves == 0 ? null : _undo,
          ),
          IconButton(
            tooltip: 'Toon tegenstanders laatste zet',
            icon: Icon(_showLastMove ? Icons.visibility : Icons.visibility_off),
            onPressed: opponentMove == null
                ? null
                : () => setState(() => _showLastMove = !_showLastMove),
          ),
          IconButton(
            tooltip: 'Opnieuw beginnen',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: Container(
        decoration: ChessTheme.backgroundDecoration,
        child: SafeArea(
          child: LayoutBuilder(
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        StatusPill(
                        icon: gameOver != null
                            ? Icons.emoji_events
                            : (_aiThinking ? Icons.smart_toy : Icons.person),
                        iconColor: gameOver != null
                            ? ChessTheme.gold
                            : (_aiThinking
                                ? ChessTheme.textDim
                                : ChessTheme.green),
                        text: gameOver ??
                            (_aiThinking ? 'Computer denkt na…' : 'Jouw zet'),
                        trailing: (_game.in_check && gameOver == null)
                            ? const Text(
                                '⚔️ Schaken!',
                                style: TextStyle(
                                  color: ChessTheme.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ChessClockBar(
                      leftLabel: widget.playerIsWhite ? 'JIJ · WIT' : 'COMPUTER · WIT',
                      leftRemaining: _clock.remaining('w'),
                      leftActive: gameOver == null && _game.turn == chess_lib.Chess.WHITE,
                      leftFlagged: _flaggedLoser == 'w',
                      rightLabel: widget.playerIsWhite ? 'COMPUTER · ZWART' : 'JIJ · ZWART',
                      rightRemaining: _clock.remaining('b'),
                      rightActive: gameOver == null && _game.turn == chess_lib.Chess.BLACK,
                      rightFlagged: _flaggedLoser == 'b',
                    ),
                    if (showArrow)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Laatste zet computer: ${opponentMove.san}',
                          style: const TextStyle(
                            color: ChessTheme.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    BoardFrame(
                      child: ChessBoard(
                        controller: _controller,
                        size: boardSize,
                        boardOrientation: orientation,
                        boardColor: BoardColor.orange,
                        enableUserMoves: myTurn && gameOver == null,
                        arrows: showArrow
                            ? [
                                BoardArrow(
                                  from: opponentMove.from,
                                  to: opponentMove.to,
                                  color: ChessTheme.gold,
                                ),
                              ]
                            : const [],
                        onMove: _onUserMove,
                      ),
                    ),
                    CapturedPiecesBar(game: _game),
                    const SizedBox(height: 16),
                    if (gameOver != null)
                      FilledButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('🔁  Nog een potje!'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
