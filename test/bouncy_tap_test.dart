import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/ui/shared/bouncy_tap.dart';

void main() {
  testWidgets('BouncyTap renders child and responds to tap down and up', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BouncyTap(
              onTap: () => tapped = true,
              child: const Text('Bouncy Button'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bouncy Button'), findsOneWidget);

    await tester.tap(find.text('Bouncy Button'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
