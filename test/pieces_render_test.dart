import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alle stukken renderen zonder fouten', (tester) async {
    final pieces = <Widget>[
      WhitePawn(), BlackPawn(), WhiteRook(), BlackRook(),
      WhiteKnight(), BlackKnight(), WhiteBishop(), BlackBishop(),
      WhiteQueen(), BlackQueen(), WhiteKing(), BlackKing(),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Wrap(children: pieces.map((p) => SizedBox(width: 60, height: 60, child: p)).toList()),
      ),
    ));
    final err = tester.takeException();
    expect(err, isNull, reason: 'stuk gooide: $err');
  });
}
