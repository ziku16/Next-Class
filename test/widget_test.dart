import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('NextClassApp smoke test loads Splash and navigates cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const NextClassApp());

    // Splash branding is visible on launch
    expect(find.text('NextClass'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

    // Pump past splash timer (1600ms)
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Reaches Welcome screen with "Get started" button
    expect(find.text('Never miss a class\nor a quiz.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
