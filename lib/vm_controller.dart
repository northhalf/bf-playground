/// Session core of the Brainfuck live-preview playground.
library;

import 'dart:async';
import 'dart:collection';

import 'package:brainfxxk/brainfxxk.dart';
import 'package:flutter/foundation.dart';

/// App-side [BrainfuckIO]: a preset byte queue for input and an
/// accumulating string buffer for output.
final class BfAppIO implements BrainfuckIO {
  final Queue<int> _queue = Queue<int>();
  final StringBuffer _output = StringBuffer();
  String _inputText = '';

  /// The output accumulated so far, as a string of byte char codes.
  String get outputText => _output.toString();

  /// Clears the output buffer.
  void clearOutput() => _output.clear();

  /// Replaces the preset input with [text].
  ///
  /// Appending to the previous text feeds only the new suffix, so bytes
  /// already consumed by `,` are not fed twice; any other edit refills
  /// the queue from scratch. Code units are masked to single bytes.
  void setInput(String text) {
    if (text.startsWith(_inputText)) {
      _enqueue(text.substring(_inputText.length));
    } else {
      _queue.clear();
      _enqueue(text);
    }
    _inputText = text;
  }

  /// Refills the input queue from the start of the current input text.
  void restartInput() {
    _queue.clear();
    _enqueue(_inputText);
  }

  void _enqueue(String text) {
    for (final unit in text.codeUnits) {
      _queue.add(unit & 0xFF);
    }
  }

  @override
  int? read() => _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void write(int byte) => _output.writeCharCode(byte);
}

/// The single state core of the playground.
///
/// Owns the [Stepper] session, the play timer, and the pending/error
/// state, and dispatches code-box edits per the unified execution model
/// (design spec section 5.1): appending at the end while the program
/// counter sits at the program end auto-executes the new instructions;
/// any other edit resets the session.
final class VmController extends ChangeNotifier {
  /// Creates a controller with an empty program session.
  VmController({this._speed = 5}) {
    _resetSession();
  }

  /// The slowest play speed, in steps per second.
  static const int minSpeed = 1;

  /// The fastest play speed accepted from the speed input box, in steps
  /// per second.
  static const int maxSpeed = 1000;

  /// The fastest speed selectable on the slider, in steps per second.
  static const int sliderMaxSpeed = 50;

  /// Timer ticks per second at high speeds.
  ///
  /// Above this rate each tick runs several steps instead of shortening
  /// the tick interval: browsers clamp sub-4ms periodic timers, so one
  /// step per tick would under-deliver the requested speed.
  static const int _maxTicksPerSecond = 60;

  final BfAppIO _io = BfAppIO();

  String _source = '';
  Program? _program;
  Stepper? _stepper;
  Tape _tape = Tape();

  bool _isPending = false;
  int _pendingBase = 0;
  BrainfuckParseException? _parseError;
  String? _runtimeError;
  bool _eofError = false;

  Timer? _timer;
  int _speed;
  int _stepCount = 0;
  int _maxTouched = 0;

  /// The current code-box source.
  String get source => _source;

  /// The parsed program, or null when the source does not parse.
  Program? get program => _program;

  /// The session tape.
  Tape get tape => _tape;

  /// The program counter: index of the next instruction to execute.
  int get pc => _stepper?.pc ?? 0;

  /// Whether the session has run to completion.
  bool get isHalted => _stepper?.isHalted ?? true;

  /// Whether the play timer is currently stepping.
  bool get isPlaying => _timer?.isActive ?? false;

  /// The play/auto-run speed in steps per second.
  int get speed => _speed;

  /// The number of instructions executed in this session.
  int get stepCount => _stepCount;

  /// The highest tape index the pointer has ever reached this session.
  int get maxTouched => _maxTouched;

  /// The output accumulated by the running program.
  String get outputText => _io.outputText;

  /// Whether the session waits for a `]` to balance an appended `[`.
  ///
  /// Pending is not an error: the session is preserved and nothing new
  /// executes until the source parses cleanly again.
  bool get isPending => _isPending;

  /// The parse error for a stray `]` with no matching `[`, if any.
  BrainfuckParseException? get parseError => _parseError;

  /// Called with a user-facing message when an edit resets the session
  /// automatically; the UI shows the message as a toast.
  void Function(String message)? onToast;

  /// The runtime error that paused execution, if any.
  ///
  /// The session is preserved: for an exhausted input, feeding more
  /// input clears the error and the stalled `,` can be retried.
  String? get runtimeError => _runtimeError;

  /// Replaces the preset input queue with [text].
  void onInputChanged(String text) {
    _io.setInput(text);
    if (_eofError) {
      _eofError = false;
      _runtimeError = null;
    }
    notifyListeners();
  }

  /// Dispatches a code-box edit per the unified execution model.
  void onSourceChanged(String newSource) {
    final isAppend =
        newSource.length > _source.length && newSource.startsWith(_source);
    final pcAtEnd = _stepper != null && _stepper!.pc == _program!.length;
    final oldLength = _program?.length ?? 0;
    _source = newSource;
    _parseError = null;
    if (_isPending) {
      if (!isAppend) {
        _resetWithToast();
      } else {
        final result = _tryParse(newSource);
        final program = result.program;
        if (program != null) {
          _isPending = false;
          _continueRun(program, _pendingBase);
        } else if (result.error is! UnclosedBracketException) {
          _parseError = result.error;
        }
      }
    } else if (isAppend) {
      final result = _tryParse(newSource);
      final program = result.program;
      if (program != null) {
        if (pcAtEnd) {
          _continueRun(program, oldLength);
        } else if (isPlaying) {
          _hotExtend(program);
        } else if (_stepCount == 0) {
          // Pristine session (e.g. just reset or stalled on the first
          // instruction): nothing to lose, run fresh from the start.
          _runtimeError = null;
          _eofError = false;
          _continueRun(program, 0);
        } else {
          _resetWithToast();
        }
      } else if (result.error is UnclosedBracketException) {
        if (pcAtEnd || _stepCount == 0) {
          _isPending = true;
          _pendingBase = pcAtEnd ? oldLength : 0;
        } else {
          _resetWithToast();
        }
      } else {
        if (pcAtEnd || _stepCount == 0) {
          _parseError = result.error;
        } else {
          _resetWithToast();
        }
      }
    } else {
      _resetWithToast();
    }
    notifyListeners();
  }

  /// Resets the session for an edit, firing [onToast] when executed
  /// state is discarded.
  void _resetWithToast() {
    final dirty = _stepCount > 0;
    _resetSession();
    if (dirty) onToast?.call('Code edited; the session has been reset.');
  }

  /// Adopts a longer program mid-run, keeping the tape, IO, and current
  /// pc, so the running animation continues into the appended
  /// instructions instead of resetting the session.
  void _hotExtend(Program program) {
    final pc = _stepper!.pc;
    _program = program;
    _stepper = Stepper(program, io: _io, tape: _tape)..pc = pc;
  }

  /// Executes a single instruction manually.
  void stepOnce() {
    _tryStep();
    notifyListeners();
  }

  /// Starts or resumes animated execution until halt.
  void play() {
    if (_stepper == null || _stepper!.isHalted || isPlaying) return;
    if (_tryStep() && !_stepper!.isHalted) _startTimer();
    notifyListeners();
  }

  /// Pauses animated execution.
  void pause() {
    _stopTimer();
    notifyListeners();
  }

  /// Resets the session: fresh tape, pc = 0, output cleared.
  void reset() {
    _resetSession();
    notifyListeners();
  }

  /// Clears the source and resets the session, without a toast.
  ///
  /// Used by the Clear button: clearing the code box is a deliberate
  /// action, not an edit the user needs to be warned about.
  void clearSource() {
    _source = '';
    _resetSession();
    notifyListeners();
  }

  /// Sets the play speed in steps per second, clamped to the
  /// [minSpeed]..[maxSpeed] range.
  set speed(int value) {
    _speed = value.clamp(minSpeed, maxSpeed);
    if (isPlaying) _startTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  ({Program? program, BrainfuckParseException? error}) _tryParse(
    String source,
  ) {
    try {
      return (
        program: parse(source, recordSourceOffsets: true),
        error: null,
      );
    } on BrainfuckParseException catch (error) {
      return (program: null, error: error);
    }
  }

  /// Continues an append on the same tape/IO: adopts [program] and
  /// executes from instruction [from] onward with animation.
  void _continueRun(Program program, int from) {
    _program = program;
    final stepper = Stepper(program, io: _io, tape: _tape);
    _stepper = stepper;
    stepper.pc = from;
    if (_tryStep() && !stepper.isHalted) _startTimer();
  }

  void _resetSession() {
    _stopTimer();
    _tape = Tape();
    _io
      ..clearOutput()
      ..restartInput();
    _stepCount = 0;
    _maxTouched = 0;
    _isPending = false;
    _parseError = null;
    _runtimeError = null;
    _eofError = false;
    final result = _tryParse(_source);
    final program = result.program;
    _program = program;
    _stepper = program == null ? null : Stepper(program, io: _io, tape: _tape);
    if (program == null) {
      if (result.error is UnclosedBracketException) {
        _isPending = true;
        _pendingBase = 0;
      } else {
        _parseError = result.error;
      }
    }
  }

  bool _tryStep() {
    final stepper = _stepper;
    if (stepper == null || stepper.isHalted) return false;
    try {
      stepper.step();
    } on BrainfuckRuntimeException catch (error) {
      final program = _program;
      final failing = program != null && stepper.pc < program.length
          ? program.instructions[stepper.pc]
          : null;
      _eofError = failing == Instruction.input;
      _runtimeError = _eofError
          ? 'Input exhausted: feed more input to continue.'
          : error.message;
      _stopTimer();
      return false;
    }
    _stepCount++;
    if (_tape.pointer > _maxTouched) _maxTouched = _tape.pointer;
    return true;
  }

  void _startTimer() {
    _timer?.cancel();
    final stepsPerTick = (_speed / _maxTicksPerSecond).ceil();
    final ticksPerSecond = (_speed / stepsPerTick).ceil();
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ ticksPerSecond), (
      _,
    ) {
      for (var i = 0; i < stepsPerTick; i++) {
        if (!_tryStep() || _stepper!.isHalted) {
          _stopTimer();
          break;
        }
      }
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
