import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/p2p_chess_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => P2PChessService(),
      child: const MyApp(),
    ),
  );
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
