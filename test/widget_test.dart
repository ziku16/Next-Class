import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/main.dart';

void main() {
  testWidgets('NextClassApp theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NextClassApp());

    expect(find.text('NextClass Design System'), findsOneWidget);
    expect(find.text('Good morning, Ali'), findsOneWidget);
    expect(find.text('Save Timetable'), findsOneWidget);
  });
}
