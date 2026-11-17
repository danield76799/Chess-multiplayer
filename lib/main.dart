import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/p2p_chess_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Vang Flutter-frameworkfouten af: loggen i.p.v. crashen met de rode
  // error-pagina. De app blijft bruikbaar voor de rest van de schermen.
  FlutterError.onError = (details) {
    debugPrint('Flutter-fout: ${details.exceptionAsString()}\n${details.stack}');
  };
  // Vang alles wat daarbuiten valt (async, timers, platform).
  runZonedGuarded(
    () => runApp(
      ChangeNotifierProvider(
        create: (_) => P2PChessService(),
        child: const MyApp(),
      ),
    ),
    (error, stack) {
      debugPrint('Onverwachte fout: $error\n$stack');
    },
  );
  // Toon een begrijpelijk scherm in plaats van de rode Flutter-foutpagina.
  ErrorWidget.builder = (details) => const _FriendlyErrorScreen();
}

class _FriendlyErrorScreen extends StatelessWidget {
  const _FriendlyErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF130E28),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('😵', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                'Oeps, hier ging iets mis.\nHerstart de app om verder te gaan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF5F0FF), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Chess',
      theme: ChessTheme.theme(),
      home: const HomeScreen(),
    );
  }
}
