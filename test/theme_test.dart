import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warga_app/main.dart';

void main() {
  testWidgets('CardTheme is applied correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Find a Card widget in the tree.
    final cardFinder = find.byType(Card);

    // Expect to find at least one Card widget.
    expect(cardFinder, findsWidgets);

    // Get the Card widget.
    final cardWidget = tester.widget<Card>(cardFinder.first);

    // Get the theme data.
    final theme = ThemeData();

    // Verify that the CardTheme properties are correct.
    expect(cardWidget.color, theme.cardTheme.color);
    expect(cardWidget.elevation, theme.cardTheme.elevation);
    expect(cardWidget.shape, theme.cardTheme.shape);
    expect(cardWidget.margin, theme.cardTheme.margin);
  });
}
