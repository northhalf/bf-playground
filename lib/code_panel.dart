/// The code editor panel: editable code box with the current instruction
/// highlighted, parse-error/pending hints, and the instruction strip.
library;

import 'package:bf_playground/vm_controller.dart';
import 'package:flutter/material.dart';

/// Display symbols of the 8 Brainfuck instructions, in enum order.
const kInstructionSymbols = ['>', '<', '+', '-', '.', ',', '[', ']'];

/// A [TextEditingController] that highlights the source character of the
/// instruction at the current program counter.
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
    final offsets = _vm.program?.sourceOffsets;
    final pc = _vm.pc;
    final plain = TextSpan(style: style, text: text);
    if (offsets == null || pc >= offsets.length) return plain;
    final start = offsets[pc];
    if (start >= text.length) return plain;
    final base = style ?? const TextStyle();
    return TextSpan(
      style: base,
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, start + 1),
          style: base.copyWith(
            backgroundColor: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(text: text.substring(start + 1)),
      ],
    );
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Instructions: ', style: mono),
            for (var i = 0; i < program.length; i++)
              TextSpan(
                text: '${kInstructionSymbols[program.instructions[i].index]} ',
                style: i == vm.pc
                    ? mono.copyWith(
                        backgroundColor: Colors.amber,
                        fontWeight: FontWeight.bold,
                      )
                    : mono,
              ),
          ],
        ),
      ),
    );
  }
}
