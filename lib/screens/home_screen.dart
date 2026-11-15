import 'package:flutter/material.dart';

import '../services/chess_ai.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('P2P Chess')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.sports_esports, size: 64, color: Colors.white70),
                  const SizedBox(height: 12),
                  Text(
                    'Hoe wil je spelen?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  // ── Tegen de computer ─────────────────────────────
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.smart_toy, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tegen de computer',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text('Offline — kies moeilijkheid en kleur'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Makkelijk'),
                                selected: _aiDifficulty == AIDifficulty.makkelijk,
                                onSelected: (_) =>
                                    setState(() => _aiDifficulty = AIDifficulty.makkelijk),
                              ),
                              ChoiceChip(
                                label: const Text('Gemiddeld'),
                                selected: _aiDifficulty == AIDifficulty.normaal,
                                onSelected: (_) =>
                                    setState(() => _aiDifficulty = AIDifficulty.normaal),
                              ),
                              ChoiceChip(
                                label: const Text('Moeilijk'),
                                selected: _aiDifficulty == AIDifficulty.moeilijk,
                                onSelected: (_) =>
                                    setState(() => _aiDifficulty = AIDifficulty.moeilijk),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.circle, size: 14, color: Colors.white),
                                label: const Text('Ik speel wit'),
                                selected: _playerWhite,
                                onSelected: (_) => setState(() => _playerWhite = true),
                              ),
                              ChoiceChip(
                                avatar: const Icon(Icons.circle, size: 14, color: Colors.black87),
                                label: const Text('Ik speel zwart'),
                                selected: !_playerWhite,
                                onSelected: (_) => setState(() => _playerWhite = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SinglePlayerScreen(
                                  difficulty: _aiDifficulty,
                                  playerIsWhite: _playerWhite,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start tegen de computer'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Met een vriend via Wi-Fi ──────────────────────
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MenuScreen()),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.wifi, size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Met een vriend',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('Twee toestellen op hetzelfde Wi-Fi-netwerk'),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
