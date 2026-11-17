/// Minimale vervanger voor het originele chess_vectors_flutter-pakket.
///
/// Rendert de "Reillycraig" schaakstukken (tekeningen van Reilly Craig,
/// gebruikt in lichess/pychess) als SVG-assets in plaats van de ingebouwde
/// paden. De publieke API (de 12 stuk-klassen) is compatibel met wat
/// flutter_chess_board verwacht.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class _ReillyPiece extends StatelessWidget {
  const _ReillyPiece(this.asset, {this.size = 45.0});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/reillycraig/$asset',
        package: 'chess_vectors_flutter',
        width: size,
        height: size,
      );
}

class WhitePawn extends StatelessWidget {
  const WhitePawn({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wP.svg', size: _size);
}

class WhiteRook extends StatelessWidget {
  const WhiteRook({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wR.svg', size: _size);
}

class WhiteKnight extends StatelessWidget {
  const WhiteKnight({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wN.svg', size: _size);
}

class WhiteBishop extends StatelessWidget {
  const WhiteBishop({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wB.svg', size: _size);
}

class WhiteQueen extends StatelessWidget {
  const WhiteQueen({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wQ.svg', size: _size);
}

class WhiteKing extends StatelessWidget {
  const WhiteKing({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('wK.svg', size: _size);
}

class BlackPawn extends StatelessWidget {
  const BlackPawn({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bP.svg', size: _size);
}

class BlackRook extends StatelessWidget {
  const BlackRook({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bR.svg', size: _size);
}

class BlackKnight extends StatelessWidget {
  const BlackKnight({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bN.svg', size: _size);
}

class BlackBishop extends StatelessWidget {
  const BlackBishop({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bB.svg', size: _size);
}

class BlackQueen extends StatelessWidget {
  const BlackQueen({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bQ.svg', size: _size);
}

class BlackKing extends StatelessWidget {
  const BlackKing({super.key, double size = 45.0}) : _size = size;
  final double _size;
  @override
  Widget build(BuildContext context) => _ReillyPiece('bK.svg', size: _size);
}
