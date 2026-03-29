// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app1/main.dart';

void main() {
  testWidgets('CivicVisionApp renders HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CivicVisionApp());

    // Verify that HomeScreen is rendered (adjust selector based on HomeScreen content)
    expect(
      find.text('CivicVision'),
      findsOneWidget,
    ); // Update with actual HomeScreen text if different
  });
}
