import 'package:bf_playground/vm_controller.dart';
import 'package:brainfxxk/brainfxxk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [text] to [vm] one character at a time, simulating typing at
/// the end of the code box.
void typeChars(VmController vm, String text) {
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    buffer.write(ch);
    vm.onSourceChanged(buffer.toString());
  }
}

void main() {
  group('BfAppIO', () {
    test('write accumulates bytes into output text', () {
      final io = BfAppIO()
        ..write(72)
        ..write(105);
      expect(io.outputText, 'Hi');
    });

    test('read consumes the input queue in order and returns null at EOF', () {
      final io = BfAppIO()..setInput('AB');
      expect(io.read(), 65);
      expect(io.read(), 66);
      expect(io.read(), isNull);
    });

    test('appending to the input text feeds only the new suffix', () {
      final io = BfAppIO()..setInput('A');
      expect(io.read(), 65);
      io.setInput('AB');
      expect(io.read(), 66);
      expect(io.read(), isNull);
    });
  });

  group('append auto-execution', () {
    test('a single appended operator executes immediately', () {
      final vm = VmController()..onSourceChanged('+');
      expect(vm.tape[0], 1);
      expect(vm.pc, 1);
      expect(vm.isHalted, isTrue);
      expect(vm.stepCount, 1);
    });

    test('typing operators one by one keeps tape state across appends', () {
      final vm = VmController()..appendAll('+++>++');
      expect(vm.tape[0], 3);
      expect(vm.tape[1], 2);
      expect(vm.tape.pointer, 1);
      expect(vm.pc, 6);
      expect(vm.stepCount, 6);
    });

    test('executed output accumulates in the IO output buffer', () {
      final vm = VmController()..appendAll('${'+' * 65}.');
      expect(vm.outputText, 'A');
    });
  });

  group('pending (unbalanced brackets)', () {
    test('appending [ enters pending and preserves the session', () {
      final vm = VmController()..appendAll('++[');
      expect(vm.isPending, isTrue);
      expect(vm.tape[0], 2);
      expect(vm.pc, 2);
      expect(vm.parseError, isNull);
    });

    test('stays pending while the appended text keeps brackets unbalanced', () {
      final vm = VmController()..appendAll('++[-');
      expect(vm.isPending, isTrue);
      expect(vm.tape[0], 2);
    });

    test('balancing the brackets resumes execution of the whole segment', () {
      final vm = VmController()..onSourceChanged('[');
      expect(vm.isPending, isTrue);
      vm.onSourceChanged('[]');
      expect(vm.isPending, isFalse);
      expect(vm.program?.length, 2);
      expect(vm.isHalted, isTrue);
    });

    testWidgets('a balanced loop segment animates to completion', (
      tester,
    ) async {
      final vm = VmController()
        ..speed = 60
        ..appendAll('++[-]');
      await tester.pump(const Duration(seconds: 1));
      expect(vm.isPending, isFalse);
      expect(vm.tape[0], 0);
      expect(vm.isHalted, isTrue);
      expect(vm.isPlaying, isFalse);
      vm.dispose();
    });

    test('appending a stray ] keeps the session and reports a parse error', () {
      final vm = VmController()..appendAll('++]');
      expect(vm.parseError, isA<UnexpectedClosingBracketException>());
      expect(vm.isPending, isFalse);
      expect(vm.tape[0], 2);
      expect(vm.pc, 2);
    });
  });

  group('session reset on edits', () {
    test('editing in the middle resets the session and fires a toast', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('++')
        ..onSourceChanged('+>+');
      expect(vm.tape[0], 0);
      expect(vm.pc, 0);
      expect(vm.stepCount, 0);
      expect(vm.outputText, isEmpty);
      expect(toasts, hasLength(1));
    });

    test('deleting text resets the session and fires a toast', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('+++')
        ..onSourceChanged('++');
      expect(vm.tape[0], 0);
      expect(vm.pc, 0);
      expect(toasts, hasLength(1));
    });

    test('appending while pc is not at the program end resets the session', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        // Paused mid-program (pc 1 of 3): an append is a mid-program edit
        // per spec section 5.1 and resets the session with a toast.
        ..onSourceChanged('+++')
        ..pause();
      expect(vm.pc, 1);
      vm.onSourceChanged('++++');
      expect(vm.tape[0], 0);
      expect(vm.stepCount, 0);
      expect(vm.pc, 0);
      expect(vm.program?.length, 4);
      expect(toasts, hasLength(1));
    });

    test('appending after an input stall re-runs without a toast', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..onSourceChanged(',');
      expect(vm.runtimeError, isNotNull);
      // The session is pristine (nothing executed), so the append simply
      // re-runs from scratch: it stalls at ',' again, with no toast.
      vm.onSourceChanged(',+');
      expect(toasts, isEmpty);
      expect(vm.runtimeError, contains('Input exhausted'));
      expect(vm.program?.length, 2);
    });

    testWidgets('appending to a pristine session runs it fresh, silently', (
      tester,
    ) async {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('++')
        ..onSourceChanged('+>+'); // mid-edit reset: one toast
      expect(toasts, hasLength(1));
      vm.onSourceChanged('+>++'); // append on pristine session: runs fresh
      expect(toasts, hasLength(1));
      expect(vm.tape[0], 1); // first step is synchronous
      await tester.pump(const Duration(seconds: 2));
      expect(vm.tape[1], 2);
      expect(vm.stepCount, 4);
      expect(vm.isHalted, isTrue);
      vm.dispose();
    });

    testWidgets('appending during animation extends without reset', (
      tester,
    ) async {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..onSourceChanged('+++++');
      expect(vm.isPlaying, isTrue);
      await tester.pump(const Duration(milliseconds: 250)); // 2 steps done
      expect(vm.tape[0], 2);
      vm.onSourceChanged('++++++'); // append one more '+' mid-animation
      expect(toasts, isEmpty);
      expect(vm.tape[0], 2); // no reset: accumulated value kept
      expect(vm.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(vm.tape[0], 6);
      expect(vm.isHalted, isTrue);
      expect(toasts, isEmpty);
      vm.dispose();
    });

    test('no toast fires when there is no live session to reset', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('++')
        ..onSourceChanged(']'); // reset #1 leaves an unparsable source
      expect(toasts, hasLength(1));
      vm.onSourceChanged(']a'); // no live session anymore: silent reset
      expect(toasts, hasLength(1));
    });

    test('manual reset clears state without firing a toast', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('+++')
        ..reset();
      expect(vm.tape[0], 0);
      expect(vm.pc, 0);
      expect(vm.stepCount, 0);
      expect(toasts, isEmpty);
    });

    test('clearSource empties the source and resets without a toast', () {
      final toasts = <String>[];
      final vm = VmController()
        ..onToast = toasts.add
        ..appendAll('+++');
      expect(vm.tape[0], 3);
      vm.clearSource();
      expect(vm.source, isEmpty);
      expect(vm.tape[0], 0);
      expect(vm.pc, 0);
      expect(vm.stepCount, 0);
      expect(toasts, isEmpty);
    });
  });

  group('runtime errors', () {
    test('reading at end of input pauses with an exhausted-input error', () {
      final vm = VmController()..onSourceChanged(',');
      expect(vm.runtimeError, contains('Input exhausted'));
      expect(vm.isPlaying, isFalse);
      expect(vm.pc, 0); // pc unchanged: the failed instruction is retriable
    });

    test('after feeding input the stalled instruction can resume', () {
      final vm = VmController()..onSourceChanged(',');
      expect(vm.runtimeError, isNotNull);
      vm.onInputChanged('A');
      expect(vm.runtimeError, isNull);
      vm.play();
      expect(vm.tape[0], 65);
      expect(vm.isHalted, isTrue);
      expect(vm.runtimeError, isNull);
    });

    testWidgets('a runtime error during play pauses the animation', (
      tester,
    ) async {
      final vm = VmController()..onSourceChanged('+,');
      expect(vm.isPlaying, isTrue); // '+' done, ',' pending on the timer
      await tester.pump(const Duration(milliseconds: 250));
      expect(vm.runtimeError, contains('Input exhausted'));
      expect(vm.isPlaying, isFalse);
      expect(vm.pc, 1);
      vm.dispose();
    });

    test('moving left of cell 0 reports the library error message', () {
      final vm = VmController()..onSourceChanged('<');
      expect(vm.runtimeError, contains('left of cell 0'));
      expect(vm.pc, 0);
    });
  });

  group('playback controls', () {
    testWidgets('pasting multiple instructions animates to completion', (
      tester,
    ) async {
      final vm = VmController()..onSourceChanged('+++++');
      expect(vm.tape[0], 1); // first step runs synchronously
      expect(vm.isPlaying, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(vm.tape[0], 5);
      expect(vm.isHalted, isTrue);
      expect(vm.isPlaying, isFalse);
      expect(vm.stepCount, 5);
      vm.dispose();
    });

    testWidgets('pause freezes the program counter', (tester) async {
      final vm = VmController()..onSourceChanged('++++++++++');
      await tester.pump(const Duration(milliseconds: 450));
      vm.pause();
      final frozenPc = vm.pc;
      await tester.pump(const Duration(seconds: 1));
      expect(vm.pc, frozenPc);
      expect(vm.isPlaying, isFalse);
      vm.dispose();
    });

    test('speed is clamped to the supported range', () {
      final vm = VmController()..speed = 0;
      expect(vm.speed, VmController.minSpeed);
      vm.speed = 100;
      expect(vm.speed, VmController.maxSpeed);
    });

    test('reset restarts the input queue from the beginning', () {
      final vm = VmController()
        ..onInputChanged('A')
        ..onSourceChanged(',');
      expect(vm.tape[0], 65);
      vm.reset();
      expect(vm.tape[0], 0);
      expect(vm.pc, 0);
      vm.play();
      expect(vm.tape[0], 65); // 'A' is fed again after reset
    });

    test('stepOnce executes exactly one instruction', () {
      // pause stops the auto-run timer after the synchronous step.
      final vm = VmController()
        ..onSourceChanged('+++')
        ..pause();
      expect(vm.pc, 1);
      vm.stepOnce();
      expect(vm.pc, 2);
      expect(vm.tape[0], 2);
      expect(vm.isPlaying, isFalse);
    });
  });
}

/// Types source text into a [VmController], one append per call.
extension on VmController {
  void appendAll(String text) => typeChars(this, text);
}
