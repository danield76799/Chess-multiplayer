import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/p2p_chess_service.dart';
import 'screens/menu_screen.dart';

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
      theme: ThemeData.dark(useMaterial3: true),
      home: const MenuScreen(),
    );
  }
}
