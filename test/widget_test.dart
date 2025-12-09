import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matriksapk/main.dart';

void main() {
  testWidgets('Matrix calculator screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MatrixApp());

    // Verify that the screen contains the title.
    expect(find.text('Matrix Solver'), findsOneWidget);

    // Verify that the screen contains the matrix input card.
    expect(find.byType(Card), findsWidgets);
  });
}
