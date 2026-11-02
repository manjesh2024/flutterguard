import 'package:basic_flutter_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the notes screen and adds a row', (tester) async {
    await tester.pumpWidget(const BasicApp());

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Launch'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Extra'), findsOneWidget);
  });
}
