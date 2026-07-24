/// The single-page layout of the playground.
library;

import 'package:bf_playground/code_panel.dart';
import 'package:bf_playground/tape_panel.dart';
import 'package:bf_playground/vm_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The playground home page: keypad, controls, code panel and IO boxes
/// on the left; the tape grid on the right.
final class HomePage extends StatefulWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends State<HomePage> {
  final VmController _vm = VmController();
  late final CodeTextController _codeController = CodeTextController(_vm);
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.onToast = _showToast;
  }

  @override
  void dispose() {
    _vm.dispose();
    _codeController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Appends [op] to the code box and dispatches the edit.
  ///
  /// Setting the controller value programmatically does not fire the
  /// field's onChanged, so the dispatch is explicit here.
  void _appendOperator(String op) {
    final text = _codeController.text;
    _codeController.value = TextEditingValue(
      text: text + op,
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
    _vm.onSourceChanged(text + op);
  }

  /// Clears the code box.
  ///
  /// Clearing the controller programmatically does not fire the field's
  /// onChanged; [VmController.clearSource] resets the session silently.
  void _clearCode() {
    _codeController.clear();
    _vm.clearSource();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) {
          final runtimeError = _vm.runtimeError;
          return SafeArea(
            child: Column(
              children: [
                if (runtimeError != null)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      runtimeError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Narrow or short windows (phones): tape on top, the
                      // input panel scrollable below. Wide desktop windows:
                      // fixed-width input panel on the left, tape on the right.
                      final vertical =
                          constraints.maxWidth < 720 ||
                          constraints.maxHeight < 600;
                      if (vertical) {
                        return Column(
                          children: [
                            Expanded(child: TapePanel(vm: _vm)),
                            const Divider(height: 1),
                            Expanded(child: _buildLeftPanel(scrollable: true)),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 560, child: _buildLeftPanel()),
                          const VerticalDivider(width: 1),
                          Expanded(child: TapePanel(vm: _vm)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel({bool scrollable = false}) {
    final ioRow = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildInputBox()),
        const SizedBox(width: 8),
        Expanded(child: _buildOutputBox()),
      ],
    );
    final column = Column(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKeypad(),
        const SizedBox(height: 12),
        _buildControls(),
        const SizedBox(height: 12),
        CodePanel(vm: _vm, controller: _codeController),
        const SizedBox(height: 12),
        if (scrollable)
          SizedBox(height: 160, child: ioRow)
        else
          Expanded(child: ioRow),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: scrollable ? SingleChildScrollView(child: column) : column,
    );
  }

  Widget _buildKeypad() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        for (final op in kInstructionSymbols)
          ElevatedButton(
            onPressed: () => _appendOperator(op),
            child: Text(
              op,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 22),
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    final canRun = _vm.program != null && !_vm.isHalted;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ElevatedButton(
          onPressed: canRun ? _vm.stepOnce : null,
          child: const Text('Step'),
        ),
        ElevatedButton(
          onPressed: _vm.isPlaying ? _vm.pause : (canRun ? _vm.play : null),
          child: Text(_vm.isPlaying ? 'Pause' : 'Play'),
        ),
        ElevatedButton(onPressed: _vm.reset, child: const Text('Reset')),
        ElevatedButton(onPressed: _clearCode, child: const Text('Clear')),
        SizedBox(
          width: 160,
          child: Slider(
            value: _vm.speed
                .clamp(VmController.minSpeed, VmController.sliderMaxSpeed)
                .toDouble(),
            min: VmController.minSpeed.toDouble(),
            max: VmController.sliderMaxSpeed.toDouble(),
            divisions: VmController.sliderMaxSpeed - VmController.minSpeed,
            label: '${_vm.speed} steps/s',
            onChanged: (v) => _vm.speed = v.round(),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextFormField(
            // Rebuilds with the latest speed when the slider moves.
            key: ValueKey(_vm.speed),
            initialValue: '${_vm.speed}',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              suffixText: 'steps/s',
            ),
            onFieldSubmitted: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) _vm.speed = parsed;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('input'),
        Expanded(
          child: TextField(
            key: const Key('input-field'),
            controller: _inputController,
            onChanged: _vm.onInputChanged,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('output'),
        Expanded(
          child: Container(
            key: const Key('output-view'),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _vm.outputText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
