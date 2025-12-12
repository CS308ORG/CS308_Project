import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // 2. Allow any initial animations or async operations (like Futures) to settle
    // This helps prevent "pending timer" errors if your home screen does simple async work
    await tester.pump();

    // 3. Verify that the Store Title is present
    expect(find.text('CS308 STORE'), findsOneWidget);

    // 4. Verify that the Login button is present (since we start logged out)
    expect(find.text('Login'), findsOneWidget);
  });
}
