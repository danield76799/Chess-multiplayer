import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Geluidseffecten voor het schaken: zetten, slaan, schaak en einde spel.
///
/// De geluiden zijn offline gegenereerde WAV's in assets/sounds/.
/// Ze zijn kort en zacht; faalt het afspelen, dan gaat het spel gewoon door.
enum ChessSound { move, capture, check, start, win, draw, lose }

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  /// Globale aan/uit-knop (volume-icoon in de speel-schermen en op het menu).
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static const Map<ChessSound, String> _files = {
    ChessSound.move: 'assets/sounds/move.wav',
    ChessSound.capture: 'assets/sounds/capture.wav',
    ChessSound.check: 'assets/sounds/check.wav',
    ChessSound.start: 'assets/sounds/start.wav',
    ChessSound.win: 'assets/sounds/win.wav',
    ChessSound.draw: 'assets/sounds/draw.wav',
    ChessSound.lose: 'assets/sounds/lose.wav',
  };

  Future<void> play(ChessSound sound) async {
    if (!enabled.value) return;
    final player = AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.release);
      unawaited(player.onPlayerComplete.first.then((_) => player.dispose()));
      await player.play(AssetSource(_files[sound]!), volume: 0.9);
    } catch (e) {
      // Geluid is bijzaak; het spel mag hier nooit op falen.
      debugPrint('Geluid kon niet worden afgespeeld: $e');
      await player.dispose();
    }
  }

  /// Speelt het geluid dat bij de uitkomst van een zet hoort.
  ///
  /// [wasCapture]   er is een stuk geslagen
  /// [inCheck]      de tegenstander (of jijzelf) staat schaak na de zet
  /// [gameOver]     het spel is voorbij
  /// [playerWon]    true = lokale speler won, false = verloor,
  ///                null = remise of niet van toepassing
  Future<void> playMoveOutcome({
    required bool wasCapture,
    required bool inCheck,
    required bool gameOver,
    required bool? playerWon,
  }) {
    final ChessSound sound;
    if (gameOver) {
      if (playerWon == null) {
        sound = ChessSound.draw;
      } else {
        sound = playerWon ? ChessSound.win : ChessSound.lose;
      }
    } else if (inCheck) {
      sound = ChessSound.check;
    } else if (wasCapture) {
      sound = ChessSound.capture;
    } else {
      sound = ChessSound.move;
    }
    return play(sound);
  }
}
