import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/chess_ai.dart';
import '../services/chess_history.dart';
import '../services/chess_stats.dart';
import '../services/game_review.dart';
import '../widgets/game_review_sheet.dart';
import '../services/p2p_chess_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../services/chess_clock.dart';
import '../widgets/board_frame.dart';
import '../widgets/last_move_highlight.dart';
import '../widgets/chess_clock_bar.dart';
import '../widgets/captured_pieces.dart';
import '../widgets/sound_toggle.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final ChessBoardController controller = ChessBoardController();
  late final P2PChessService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _pieceCount = 32;
  String? _lastSoundFen;
  late ChessClockSet _clock;
  Timer? _clockTicker;
  bool _showLastMove = false;
  bool _resultRecorded = false;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    // Houd het scherm aan tijdens het spelen.
    try {
      WakelockPlus.enable();
    } catch (_) {}
    // Het bord volgt de service via een FEN-synchronisatie. Een load() op
    // een identieke FEN is onschadelijk, dus dubbele updates zijn oké.
    WidgetsBinding.instance.addObserver(this);
    _service = context.read<P2PChessService>();
    _clock = ChessClockSet(_service.timeControl);
    _subscription = _service.gameStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'connected' || data['type'] == 'started') {
        SoundService.instance.play(ChessSound.start);
        return;
      }
      if (data['type'] == 'update' && data['fen'] is String) {
        final fen = data['fen'] as String;
        controller.loadFen(fen);
        if (fen == P2PChessService.initialFen) {
          _clock.reset();
        } else {
          // De kant die net zette krijgt de increment.
          final mover = _service.game.turn == chess_lib.Chess.WHITE ? 'b' : 'w';
          _clock.incrementFor(mover);
        }
        _announceMove(fen);
      }
      if (data['type'] == 'flag') {
        final loser = data['loser'];
        final amLoser = loser != null && loser == _service.playerColor;
        SoundService.instance.play(amLoser ? ChessSound.lose : ChessSound.win);
        _maybeRecordResult();
      }
    });
    _startClockTicker();
  }

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      if (_service.gameOverMessage != null) return; // klok staat stil
      if (_service.connectionState != ChessConnectionState.connected) return;
      final side = _service.game.turn == chess_lib.Chess.WHITE ? 'w' : 'b';
      setState(() {});
      _clock.tick(side);
      final flag = _clock.flaggedSide();
      if (flag != null && _service.flaggedLoser == null) {
        _service.flagGame(flag);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _clock.pause();
    } else if (state == AppLifecycleState.resumed) {
      _clock.resume();
    }
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
    _maybeRecordResult();
  }


  /// true = jij won, false = je verloor, null = remise/onbekend.
  bool? get _playerWonResult {
    final me = _service.playerColor;
    if (me == null) return null;
    if (_service.flaggedLoser != null) return _service.flaggedLoser != me;
    final game = _service.game;
    if (game.game_over) {
      if (game.in_checkmate) {
        // Aan zet = mat gezet
        final loserIsWhite = game.turn == chess_lib.Chess.WHITE;
        final meIsWhite = me == 'w';
        return loserIsWhite != meIsWhite;
      }
      return null; // pat of remise
    }
    return null;
  }

  bool get _gameOverNow =>
      _service.gameOverMessage != null || _service.flaggedLoser != null;

  void _maybeRecordResult() {
    if (_resultRecorded || !_gameOverNow) return;
    _resultRecorded = true;
    ChessStats.recordResult(vsAi: false, playerWon: _playerWonResult);
  }

  Future<void> _analyzeGame() async {
    if (_analyzing || !_gameOverNow) return;
    setState(() => _analyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final san = _service.game.getHistory().map((m) => m.toString()).toList();
    final review = GameReviewService.analyze(
      san,
      reviewWhite: _service.playerColor == 'w',
    );
    if (!mounted) return;
    setState(() => _analyzing = false);
    await showGameReviewSheet(
      context,
      review: review,
      sideLabel: _service.playerColor == 'w' ? 'Jij speelde wit' : 'Jij speelde zwart',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clockTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
    final opponentMove = lastOpponentMove(
      service.game,
      localIsWhite: service.playerColor != 'b',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Jij: $colorLabel'),
        actions: [
          const SoundToggle(),
          if (service.connectionState == ChessConnectionState.connected)
            IconButton(
              tooltip: 'Toon tegenstanders laatste zet',
              icon: Icon(_showLastMove ? Icons.visibility : Icons.visibility_off),
              onPressed: opponentMove == null
                  ? null
                  : () => setState(() => _showLastMove = !_showLastMove),
            ),
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
          child: _buildBody(service, opponentMove),
        ),
      ),
    );
  }

  Widget _buildBody(P2PChessService service, LastOpponentMove? opponentMove) {
    final highlight = lastMove(service.game);
    // Host wacht op een tegenstander.
    if (service.connectionState == ChessConnectionState.connecting ||
        service.connectionState == ChessConnectionState.searching) {
      return _WaitingView(isHost: service.isHost);
    }

    // Verbinding is weg en er wordt opnieuw geprobeerd.
    if (service.connectionState == ChessConnectionState.reconnecting) {
      return _ReconnectingView(
        message: service.errorMessage ?? 'Opnieuw verbinden…',
        onCancel: () => Navigator.of(context).pop(),
      );
    }

    // Verbinding mislukt of definitief verbroken.
    if (service.connectionState == ChessConnectionState.error ||
        service.connectionState == ChessConnectionState.disconnected) {
      return _ErrorView(
        message: service.errorMessage ?? 'De verbinding is verbroken.',
        onBack: () => Navigator.of(context).pop(),
        onRetry: service.retryConnection,
      );
    }

    // Verbonden: het bord.
    final gameOver = service.gameOverMessage;
    final myTurn = service.isMyTurn;
    final orientation = service.playerColor == 'b'
        ? PlayerColor.black
        : PlayerColor.white;
    final showArrow = _showLastMove && opponentMove != null;

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    StatusPill(
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
                  ],
                  ),
                ),
                const SizedBox(height: 8),
                ChessClockBar(
                  leftLabel: service.playerColor == 'w' ? 'WIT · JIJ' : 'WIT · TEGENSTANDER',
                  leftRemaining: _clock.remaining('w'),
                  leftActive: gameOver == null && service.game.turn == chess_lib.Chess.WHITE,
                  leftFlagged: _service.flaggedLoser == 'w',
                  rightLabel: service.playerColor == 'b' ? 'ZWART · JIJ' : 'ZWART · TEGENSTANDER',
                  rightRemaining: _clock.remaining('b'),
                  rightActive: gameOver == null && service.game.turn == chess_lib.Chess.BLACK,
                  rightFlagged: _service.flaggedLoser == 'b',
                ),
                if (showArrow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Laatste zet tegenstander: ${opponentMove.san}',
                      style: const TextStyle(
                        color: ChessTheme.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                BoardFrame(
                  child: SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: Stack(
                      children: [
                        ChessBoard(
                          controller: controller,
                          size: boardSize,
                          boardOrientation: orientation,
                          boardColor: BoardColor.orange,
                          enableUserMoves: myTurn && gameOver == null && service.isConnected,
                          arrows: showArrow
                              ? [
                                  BoardArrow(
                                    from: opponentMove.from,
                                    to: opponentMove.to,
                                    color: ChessTheme.gold,
                                  ),
                                ]
                              : const [],
                          onMove: () {
                            // De board heeft de zet al op controller.game toegepast;
                            // stuur de nieuwe stelling naar de tegenstander.
                            service.syncLocalMove(controller.game.fen);
                          },
                        ),
                        if (highlight != null)
                          Positioned.fill(
                            child: LastMoveHighlight(
                              from: highlight.from,
                              to: highlight.to,
                              orientation: orientation,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                CapturedPiecesBar(game: service.game),
                const SizedBox(height: 16),
                if (gameOver != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _analyzing ? null : _analyzeGame,
                        icon: _analyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.analytics_outlined),
                        label: Text(_analyzing ? 'Analyseren…' : 'Analyse'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _resultRecorded = false);
                          service.resetGame();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('🔁  Nog een potje!'),
                      ),
                    ],
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
  final Future<void> Function()? onRetry;

  const _ErrorView({required this.message, required this.onBack, this.onRetry});

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
            if (onRetry != null) ...[
              FilledButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh),
                label: const Text('Opnieuw proberen'),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Terug naar menu'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tussenscherm tijdens automatische herverbinding na een korte storing.
class _ReconnectingView extends StatelessWidget {
  final String message;
  final VoidCallback onCancel;

  const _ReconnectingView({required this.message, required this.onCancel});

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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_find, size: 22, color: Colors.amber),
                SizedBox(width: 8),
                Text('Verbinding hersteld wordt geprobeerd…',
                    style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Annuleren'),
            ),
          ],
        ),
      ),
    );
  }
}
