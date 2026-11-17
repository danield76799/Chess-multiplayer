import 'package:flutter/material.dart';

import '../services/chess_ai.dart';
import '../services/chess_clock.dart';
import '../theme.dart';
import '../widgets/time_control_picker.dart';
import '../widgets/sound_toggle.dart';
import 'menu_screen.dart';
import 'single_player_screen.dart';

/// Opstartscherm: kies tussen alleen spelen (tegen de computer)
/// of met een vriend op hetzelfde Wi-Fi-netwerk.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AIDifficulty _aiDifficulty = AIDifficulty.normaal;
  bool _playerWhite = true;
  TimeControl _timeControl = TimeControl.defaultPreset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ChessTheme.backgroundDecoration,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.topRight,
                        child: SoundToggle(),
                      ),
                      const SizedBox(height: 4),
                      const _HeroHeader(),
                      const SizedBox(height: 28),
                      _SinglePlayerCard(
                        difficulty: _aiDifficulty,
                        onDifficultyChanged: (d) =>
                            setState(() => _aiDifficulty = d),
                        playerWhite: _playerWhite,
                        onColorChanged: (w) => setState(() => _playerWhite = w),
                        timeControl: _timeControl,
                        onTimeControlChanged: (tc) =>
                            setState(() => _timeControl = tc),
                      ),
                      const SizedBox(height: 16),
                      const _MultiplayerCard(),
                      const SizedBox(height: 20),
                      const Text(
                        'Offline tegen de computer · Online met z’n tweeën',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ChessTheme.textDim,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Schaakstukken: Maurizio Monge (Fantasy)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ChessTheme.textDim,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
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

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gouden ring met schaakpaard erin.
        Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B2F1A), Color(0xFF1E1710)],
            ),
            border: Border.fromBorderSide(
              BorderSide(color: ChessTheme.gold, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x44E3B764),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '♞',
            style: TextStyle(fontSize: 56, color: ChessTheme.gold, height: 1),
          ),
        ),
        const SizedBox(height: 16),
        const _GradientTitle(text: 'Schaken!'),
        const SizedBox(height: 4),
        const Text(
          'Word de schaakkoning 👑',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: ChessTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kies je speltype',
          style: TextStyle(
            fontSize: 15,
            color: ChessTheme.textDim,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _GradientTitle extends StatelessWidget {
  final String text;
  const _GradientTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFF6E3AC), ChessTheme.gold, Color(0xFFB8893B)],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

/// Kaart met icoon, titel, subtitel en vrije inhoud.
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ChessTheme.line),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ChessTheme.surfaceHigh, ChessTheme.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ChessTheme.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: ChessTheme.gold.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: ChessTheme.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ChessTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ChessTheme.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SinglePlayerCard extends StatelessWidget {
  final AIDifficulty difficulty;
  final ValueChanged<AIDifficulty> onDifficultyChanged;
  final bool playerWhite;
  final ValueChanged<bool> onColorChanged;
  final TimeControl timeControl;
  final ValueChanged<TimeControl> onTimeControlChanged;

  const _SinglePlayerCard({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.playerWhite,
    required this.onColorChanged,
    required this.timeControl,
    required this.onTimeControlChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _ModeCard(
      icon: Icons.smart_toy_outlined,
      title: 'Tegen de computer',
      subtitle: 'Offline — kies moeilijkheid en kleur',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                AIDifficulty.makkelijk: '🐣 Makkelijk',
                AIDifficulty.normaal: '🙂 Gemiddeld',
                AIDifficulty.moeilijk: '🦁 Moeilijk',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: difficulty == entry.key,
                  onSelected: (_) => onDifficultyChanged(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.circle, size: 14, color: Colors.white),
                label: const Text('♔ Wit'),
                selected: playerWhite,
                onSelected: (_) => onColorChanged(true),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.circle, size: 14, color: Colors.black87),
                label: const Text('♚ Zwart'),
                selected: !playerWhite,
                onSelected: (_) => onColorChanged(false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TimeControlPicker(
            selected: timeControl,
            onChanged: onTimeControlChanged,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SinglePlayerScreen(
                  difficulty: difficulty,
                  playerIsWhite: playerWhite,
                  timeControl: timeControl,
                ),
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('🎮  Start tegen de computer'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiplayerCard extends StatelessWidget {
  const _MultiplayerCard();

  @override
  Widget build(BuildContext context) {
    return _ModeCard(
      icon: Icons.wifi_tethering,
      title: 'Met een vriend',
      subtitle: 'Twee toestellen op hetzelfde Wi-Fi-netwerk',
      child: FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MenuScreen()),
        ),
        icon: const Icon(Icons.people_alt_outlined),
        label: const Text('🎈  Naar de lobby'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: ChessTheme.surfaceHighest,
          foregroundColor: ChessTheme.text,
          side: const BorderSide(color: ChessTheme.line),
        ),
      ),
    );
  }
}
