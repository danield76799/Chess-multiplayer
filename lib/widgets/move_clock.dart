import 'package:flutter/material.dart';

/// Aftelklok voor per-zet-bedenktijd.
///
/// Eén gedeelde klok: alleen degene die aan zet is, verbruikt tijd.
/// Na elke zet (of bij reset) gaat de teller weer naar de volle tijd.
/// De klok "pauzeert" automatisch als de app naar de achtergrond gaat:
/// de [pause]/[resume] houden de verschoven deadline bij.
class MoveClock {
  static const int moveSeconds = 15;

  DateTime _deadline;
  DateTime? _pausedAt;

  MoveClock({DateTime? now}) : _deadline = (now ?? DateTime.now()).add(const Duration(seconds: moveSeconds));

  /// Resterende tijd; negatief als de tijd om is.
  Duration remaining([DateTime? now]) =>
      _deadline.difference(now ?? DateTime.now());

  bool get isExpired => remaining() <= Duration.zero;

  /// Hele seconden over, naar boven afgerond (start op 15, nooit negatief).
  int get secondsLeft {
    final ms = remaining().inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  void reset([DateTime? now]) {
    _deadline = (now ?? DateTime.now()).add(const Duration(seconds: moveSeconds));
    _pausedAt = null;
  }

  /// App gaat naar de achtergrond: onthoud het moment.
  void pause() {
    _pausedAt ??= DateTime.now();
  }

  /// App komt terug: schuif de deadline op met de pauzeduur,
  /// zodat er geen tijd "wegloopt" terwijl de app op de achtergrond staat.
  void resume() {
    if (_pausedAt == null) return;
    _deadline = _deadline.add(DateTime.now().difference(_pausedAt!));
    _pausedAt = null;
  }
}


/// Kleine afteltimer-pil voor naast de statuspil.
/// Wordt rood en flitst als er ≤ 5 seconden over zijn.
class MoveClockPill extends StatelessWidget {
  const MoveClockPill({super.key, required this.secondsLeft, required this.active});

  final int secondsLeft;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 5 && active;
    final color = urgent ? const Color(0xFFFF6B5E) : const Color(0xFFFFC53D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF241A3E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? color : const Color(0xFF3A2E5C), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: active ? color : const Color(0xFFB0A6D6)),
          const SizedBox(width: 6),
          Text(
            '${secondsLeft}s',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: active ? color : const Color(0xFFB0A6D6),
            ),
          ),
        ],
      ),
    );
  }
}
