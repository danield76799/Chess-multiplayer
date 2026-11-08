import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/p2p_chess_service.dart';
import 'game_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<P2PChessService>(context);
    final ipController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('P2P Chess')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              ElevatedButton(
                onPressed: () async {
                  await service.startHost(8080);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen()));
                },
                child: const Text('Host Game'),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextField(
                  controller: ipController,
                  decoration: const InputDecoration(labelText: 'Host IP Address'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await service.joinGame(ipController.text, 8080);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen()));
                },
                child: const Text('Join Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
