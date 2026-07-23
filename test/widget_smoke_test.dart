import 'package:bf_playground/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders keypad, code box and tape grid; tapping + sets cell 0 to 1',
    (tester) async {
      await tester.pumpWidget(const MainApp());
      for (final op in ['>', '<', '+', '-', '.', ',', '[', ']']) {
        expect(
          find.widgetWithText(ElevatedButton, op),
          findsOneWidget,
          reason: 'keypad button $op should exist',
        );
      }
      expect(find.byKey(const Key('code-field')), findsOneWidget);
      expect(find.byKey(const Key('tape-cell-0')), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '+'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('tape-cell-0')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('narrow screens stack the tape above the input panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MainApp());
    await tester.pump();

    expect(find.byKey(const Key('code-field')), findsOneWidget);
    expect(find.byKey(const Key('tape-cell-0')), findsOneWidget);
    expect(find.byKey(const Key('output-view')), findsOneWidget);

    final tapeY = tester.getCenter(find.byKey(const Key('tape-cell-0'))).dy;
    final codeY = tester.getCenter(find.byKey(const Key('code-field'))).dy;
    expect(
      tapeY,
      lessThan(codeY),
      reason: 'tape should sit above the code box',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Clear button empties the code box and resets the session', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    await tester.tap(find.widgetWithText(ElevatedButton, '+'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('tape-cell-0')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Clear'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('code-field')));
    expect(field.controller!.text, isEmpty);
    expect(
      find.descendant(
        of: find.byKey(const Key('tape-cell-0')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });
}
