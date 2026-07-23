import 'package:bf_playground/code_panel.dart';
import 'package:bf_playground/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Palette pinned by the design spec, section 5.5.
const _indigo = Color(0xFF303F9F);
const _deepOrange = Color(0xFFD84315);
const _teal = Color(0xFF00796B);
const _purple = Color(0xFF7B1FA2);
const _pink = Color(0xFFC2185B);
const _grey = Color(0xFF757575);

/// Expands a span tree into one style record per character.
List<({Color? color, Color? background, FontWeight? weight})> _expand(
  TextSpan span,
) {
  final out = <({Color? color, Color? background, FontWeight? weight})>[];
  void visit(TextSpan node) {
    final text = node.text;
    if (text != null) {
      for (var i = 0; i < text.length; i++) {
        out.add((
          color: node.style?.color,
          background: node.style?.backgroundColor,
          weight: node.style?.fontWeight,
        ));
      }
    }
    for (final child in node.children ?? const <InlineSpan>[]) {
      visit(child as TextSpan);
    }
  }

  visit(span);
  return out;
}

CodeTextController _controller(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byKey(const Key('code-field')));
  return field.controller! as CodeTextController;
}

TextSpan _buildSpan(WidgetTester tester) {
  return _controller(tester).buildTextSpan(
    context: tester.element(find.byKey(const Key('code-field'))),
    withComposing: false,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
  );
}

void main() {
  testWidgets(
    'code box colors instructions by category, brackets by nesting depth, '
    'comments grey, and overlays the pc character in amber',
    (tester) async {
      await tester.pumpWidget(const MainApp());
      await tester.enterText(
        find.byKey(const Key('code-field')),
        '>[[+]]<., hi',
      );
      await tester.pumpAndSettle();

      // The `,` stalls on exhausted input, leaving the pc on it.
      var chars = _expand(_buildSpan(tester));
      expect(chars.map((c) => c.color).toList(), [
        _indigo, _purple, _pink, _deepOrange, _pink, _purple, //
        _indigo, _teal, _teal, _grey, _grey, _grey,
      ]);
      final comma = chars[8];
      expect(comma.background, Colors.amber);
      expect(comma.weight, FontWeight.bold);
      expect(comma.color, _teal, reason: 'pc overlay keeps the syntax color');
      for (var i = 0; i < chars.length; i++) {
        if (i != 8) expect(chars[i].background, isNull);
      }

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset'));
      await tester.pump();

      chars = _expand(_buildSpan(tester));
      expect(chars[0].background, Colors.amber);
      expect(chars[0].color, _indigo);
      expect(chars[8].background, isNull);
    },
  );

  testWidgets(
    'colors stay lexical under parse errors: a stray `]` clamps to depth 0',
    (tester) async {
      await tester.pumpWidget(const MainApp());
      await tester.enterText(find.byKey(const Key('code-field')), ']+[');
      await tester.pump();

      final chars = _expand(_buildSpan(tester));
      expect(
        chars.map((c) => c.color).toList(),
        [_purple, _deepOrange, _purple],
      );
    },
  );
}
