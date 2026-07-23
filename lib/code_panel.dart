/// The code editor panel: editable code box with the current instruction
/// highlighted, parse-error/pending hints, and the instruction strip.
library;

import 'package:bf_playground/vm_controller.dart';
import 'package:flutter/material.dart';

/// Display symbols of the 8 Brainfuck instructions, in enum order.
const kInstructionSymbols = ['>', '<', '+', '-', '.', ',', '[', ']'];

// Syntax-highlight palette (design spec section 5.5), tuned for the
// single light theme on the cream scaffold background.
const _pointerColor = Color(0xFF303F9F); // indigo 700
const _arithmeticColor = Color(0xFFD84315); // deepOrange 700
const _ioColor = Color(0xFF00796B); // teal 700
const _commentColor = Color(0xFF757575); // grey 600
const _bracketCycle = [
  Color(0xFF7B1FA2), // purple 700
  Color(0xFFC2185B), // pink 700
  Color(0xFF5D4037), // brown 700
];

/// Returns the lexical syntax-highlight color of each UTF-16 unit of
/// [text] (design spec section 5.5).
///
/// Purely lexical, no parsing: `>`/`<` indigo, `+`/`-` deepOrange,
/// `.`/`,` teal, everything else grey. Brackets are colored by nesting
/// depth cycling through purple/pink/brown: `[` takes the current depth
/// color and increments, `]` decrements (clamped at 0) and takes that
/// color, so a balanced pair always matches.
List<Color> _syntaxColors(String text) {
  final colors = <Color>[];
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    colors.add(
      switch (text[i]) {
        '>' || '<' => _pointerColor,
        '+' || '-' => _arithmeticColor,
        '.' || ',' => _ioColor,
        '[' => _bracketCycle[depth++ % _bracketCycle.length],
        ']' =>
          _bracketCycle[(depth = depth > 0 ? depth - 1 : 0) %
              _bracketCycle.length],
        _ => _commentColor,
      },
    );
  }
  return colors;
}

/// A [TextEditingController] that syntax-colors the source and highlights
/// the source character of the instruction at the current program counter.
final class CodeTextController extends TextEditingController {
  /// Creates a controller bound to the given [VmController].
  CodeTextController(this._vm);

  final VmController _vm;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final text = value.text;
    final base = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(style: base, text: text);

    final colors = _syntaxColors(text);
    final offsets = _vm.program?.sourceOffsets;
    final pc = _vm.pc;
    final pcOffset =
        offsets != null && pc < offsets.length && offsets[pc] < text.length
        ? offsets[pc]
        : null;

    TextStyle styleAt(int i) {
      final syntax = base.copyWith(color: colors[i]);
      return i == pcOffset
          ? syntax.copyWith(
              backgroundColor: Colors.amber,
              fontWeight: FontWeight.bold,
            )
          : syntax;
    }

    // Merge adjacent characters sharing a style into single spans.
    final children = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || styleAt(i) != styleAt(start)) {
        children.add(
          TextSpan(text: text.substring(start, i), style: styleAt(start)),
        );
        start = i;
      }
    }
    return TextSpan(style: base, children: children);
  }
}

/// The code panel: code box, parse-error/pending hint, instruction strip.
final class CodePanel extends StatelessWidget {
  /// Creates the panel.
  const CodePanel({required this.vm, required this.controller, super.key});

  /// The session controller.
  final VmController vm;

  /// The code box's text controller (owned by the page).
  final CodeTextController controller;

  @override
  Widget build(BuildContext context) {
    final error = vm.parseError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('code-field'),
          controller: controller,
          onChanged: vm.onSourceChanged,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type Brainfuck code here, or use the keypad above',
            isDense: true,
          ),
        ),
        if (error != null)
          Text(
            '${error.message} (line ${error.line}, column ${error.column})',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (vm.isPending)
          const Text('waiting for `]`', style: TextStyle(color: Colors.orange)),
        _InstructionStrip(vm: vm),
      ],
    );
  }
}

/// Read-only strip of the parsed instruction sequence, highlighting the
/// instruction at the current program counter.
final class _InstructionStrip extends StatelessWidget {
  const _InstructionStrip({required this.vm});

  final VmController vm;

  @override
  Widget build(BuildContext context) {
    final program = vm.program;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 14);
    if (program == null || program.length == 0) {
      return const SizedBox(height: 24);
    }
    final symbols = [
      for (var i = 0; i < program.length; i++)
        kInstructionSymbols[program.instructions[i].index],
    ];
    final colors = _syntaxColors(symbols.join());
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Instructions: ', style: mono),
            for (var i = 0; i < program.length; i++)
              TextSpan(
                text: '${symbols[i]} ',
                style:
                    (i == vm.pc
                            ? mono.copyWith(
                                backgroundColor: Colors.amber,
                                fontWeight: FontWeight.bold,
                              )
                            : mono)
                        .copyWith(color: colors[i]),
              ),
          ],
        ),
      ),
    );
  }
}
