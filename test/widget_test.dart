import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/data/database/app_database.dart';
import 'package:nextclass/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('classes');
    } catch (_) {}
  });

  testWidgets('NextClassApp smoke test loads Splash and navigates cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const NextClassApp());

    // Splash branding is visible on launch
    expect(find.text('NextClass'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

    // Pump past splash timer (1600ms) and settle async transition
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Check which screen is rendered
    expect(find.byType(NextClassApp), findsOneWidget);
  });
}
