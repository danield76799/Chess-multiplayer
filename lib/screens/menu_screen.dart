import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/p2p_chess_service.dart';
import 'game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _hostGame() async {
    final service = context.read<P2PChessService>();
    final ok = await service.startHost();
    if (!mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
    // Bij falen toont de build() de foutmelding van de service.
  }

  Future<void> _joinGame({String? host}) async {
    final service = context.read<P2PChessService>();
    final target = (host ?? _ipController.text).trim();
    final ipPattern = RegExp(r'^[a-zA-Z0-9.\-]+$');
    if (target.isEmpty || !ipPattern.hasMatch(target)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voer een geldig IP-adres of hostnaam in.')),
      );
      return;
    }
    setState(() => _joining = true);
    final ok = await service.joinGame(target);
    if (!mounted) return;
    setState(() => _joining = false);
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
    // Bij falen toont de build() de foutmelding van de service.
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<P2PChessService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('P2P Chess')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.sports_esports, size: 72, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              'Schaak met een tegenstander op hetzelfde Wi-Fi-netwerk',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            // Hosten
            FilledButton.icon(
              onPressed: service.isConnecting ? null : _hostGame,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Nieuw spel host'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 8),

            // Auto-detectie
            Row(
              children: [
                const Expanded(
                  child: Text('Zoek een spel op dit netwerk',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (service.isSearching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: () => service.autoDiscover(),
                    child: const Text('Zoeken'),
                  ),
              ],
            ),
            if (service.isSearching) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text('Zoeken naar hosts…',
                        style: TextStyle(fontSize: 13, color: Colors.white60)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await service.leaveGame();
                      setState(() {});
                    },
                    child: const Text('Annuleer'),
                  ),
                ],
              ),
            ],
            if (service.discoveredHostIp != null)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.sports_esports),
                  title: Text('Host gevonden op ${service.discoveredHostIp}'),
                  subtitle: const Text('Tik om te verbinden'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _joinGame(host: service.discoveredHostIp),
                ),
              ),
            const SizedBox(height: 16),

            // Handmatig verbinden
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Host IP-adres (bijv. 192.168.1.23)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lan),
              ),
              onSubmitted: (_) => _joinGame(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: (service.isConnecting || _joining) ? null : _joinGame,
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text('Verbinden met host'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),

            // Foutmeldingen (bv. host onbereikbaar)
            if (service.connectionState == ChessConnectionState.error &&
                service.errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          service.errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
