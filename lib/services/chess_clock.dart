/// Schaak-wedstrijdklok (tijdcontrole zoals op toernooien).
///
/// Elke kant heeft een eigen klok met dezelfde basistijd; na elke zet van een
/// speler krijgt die speler zijn increment erbij. Valt je tijd op nul, dan
/// verlies je de partij ("op tijd verloren").
library;

/// Een vooraf ingestelde tijdoptie, bijv. 5 minuten + 3 seconden per zet.
class TimeControl {
  final Duration base;
  final Duration increment;
  final String label;

  const TimeControl(this.base, this.increment, this.label);

  static const List<TimeControl> presets = [
    TimeControl(Duration(minutes: 1), Duration.zero, '1+0'),
    TimeControl(Duration(minutes: 3), Duration(seconds: 2), '3+2'),
    TimeControl(Duration(minutes: 5), Duration(seconds: 3), '5+3'),
    TimeControl(Duration(minutes: 10), Duration.zero, '10+0'),
    TimeControl(Duration(minutes: 10), Duration(seconds: 5), '10+5'),
  ];

  static const TimeControl defaultPreset = TimeControl(
    Duration(minutes: 5),
    Duration(seconds: 3),
    '5+3',
  );

  String toWire() => '${base.inSeconds}+${increment.inSeconds}';

  static TimeControl? fromWire(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('+');
    if (parts.length != 2) return null;
    final base = int.tryParse(parts[0]);
    final inc = int.tryParse(parts[1]);
    if (base == null || inc == null) return null;
    return TimeControl(Duration(seconds: base), Duration(seconds: inc), '${base ~/ 60}+$inc');
  }
}

/// Klok voor beide kleuren. De UI roept [tick] aan met de kant die aan zet
/// is; alleen die kant verliest tijd.
class ChessClockSet {
  ChessClockSet(this.control)
      : white = control.base,
        black = control.base;

  final TimeControl control;
  Duration white;
  Duration black;
  DateTime? _lastTick;

  Duration remaining(String side) => side == 'w' ? white : black;

  /// Verwerk het tijdsverloop sinds de vorige tick voor [sideToMove]
  /// ('w' of 'b'). Roep dit ~5x per seconde aan.
  void tick(String sideToMove) {
    final now = DateTime.now();
    final last = _lastTick;
    _lastTick = now;
    if (last == null) return; // eerste tick: geen tijd verrekenen
    final elapsed = now.difference(last);
    if (sideToMove == 'w') {
      white = white - elapsed;
      if (white.isNegative) white = Duration.zero;
    } else {
      black = black - elapsed;
      if (black.isNegative) black = Duration.zero;
    }
  }

  /// Pauzeer de klok (app naar achtergrond, of einde spel).
  void pause() => _lastTick = null;

  /// Hervat na een pauze (app weer actief).
  void resume() => _lastTick ??= DateTime.now();

  /// Geef [side] de increment na diens zet.
  void incrementFor(String side) {
    if (side == 'w') {
      white += control.increment;
    } else {
      black += control.increment;
    }
  }

  void reset() {
    white = control.base;
    black = control.base;
    _lastTick = null;
  }

  /// Welke kant ('w'/'b') heeft geen tijd meer, of null.
  String? flaggedSide() {
    if (white == Duration.zero && black == Duration.zero) return null;
    if (white == Duration.zero) return 'w';
    if (black == Duration.zero) return 'b';
    return null;
  }

  static String format(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (d.inSeconds < 20) {
      final tenths = (d.inMilliseconds % 1000) ~/ 100;
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
