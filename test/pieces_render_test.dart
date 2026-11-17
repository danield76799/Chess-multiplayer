import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alle stukken renderen zonder fouten', (tester) async {
    final pieces = <Widget>[
      const WhitePawn(), const BlackPawn(), const WhiteRook(), const BlackRook(),
      const WhiteKnight(), const BlackKnight(), const WhiteBishop(), const BlackBishop(),
      const WhiteQueen(), const BlackQueen(), const WhiteKing(), const BlackKing(),
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
