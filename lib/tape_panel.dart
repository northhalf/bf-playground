/// The tape grid visualization: cells wrap onto multiple rows connected
/// by lines, with pointer highlight, follow scrolling, and a flash
/// animation on value changes.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:bf_playground/vm_controller.dart';
import 'package:flutter/material.dart';

const double _cellWidth = 52;
const double _cellHeight = 52;
const double _gapX = 10;
const double _arrowHeight = 18;
const double _rowGap = 16;
const double _padX = 12;
const double _pitchX = _cellWidth + _gapX;
const double _pitchY = _arrowHeight + _cellHeight + _rowGap;

/// The tape grid panel.
final class TapePanel extends StatefulWidget {
  /// Creates the panel.
  const TapePanel({required this.vm, super.key});

  /// The session controller.
  final VmController vm;

  @override
  State<TapePanel> createState() => _TapePanelState();
}

final class _TapePanelState extends State<TapePanel> {
  final ScrollController _scroll = ScrollController();
  int _cols = 1;

  VmController get _vm => widget.vm;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _followPointer());
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _cols = math.max(
                1,
                (constraints.maxWidth - 2 * _padX + _gapX) ~/ _pitchX,
              );
              // Fill the viewport with cells even before any execution.
              final fillRows = (constraints.maxHeight / _pitchY).ceil();
              final cellCount = math.max(
                math.max(_vm.maxTouched, _vm.tape.pointer) + 1,
                _cols * fillRows,
              );
              final rows = (cellCount + _cols - 1) ~/ _cols;
              final contentHeight = rows * _pitchY - _rowGap;
              return SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: contentHeight,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(constraints.maxWidth, contentHeight),
                        painter: _ConnectorPainter(
                          cellCount: cellCount,
                          cols: _cols,
                        ),
                      ),
                      for (var i = 0; i < cellCount; i++)
                        Positioned(
                          left: _padX + (i % _cols) * _pitchX,
                          top: (i ~/ _cols) * _pitchY,
                          child: TapeCell(
                            key: ValueKey('tape-cell-$i'),
                            index: i,
                            value: _vm.tape[i],
                            isPointer: i == _vm.tape.pointer,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'pc: ${_vm.pc}   pointer: ${_vm.tape.pointer}   '
            'steps: ${_vm.stepCount}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _followPointer() {
    if (!_scroll.hasClients) return;
    final top = (_vm.tape.pointer ~/ _cols) * _pitchY;
    final viewTop = _scroll.offset;
    final viewBottom = viewTop + _scroll.position.viewportDimension;
    if (top + _pitchY > viewBottom || top < viewTop) {
      unawaited(
        _scroll.animateTo(
          math.max(0, top - 16),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }
  }
}

/// Draws the connector lines between adjacent cells: a straight segment
/// within a row, and an elbow from each row's last cell around to the
/// next row's first cell.
final class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.cellCount, required this.cols});

  final int cellCount;
  final int cols;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB08968)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i + 1 < cellCount; i++) {
      final col = i % cols;
      final y = (i ~/ cols) * _pitchY + _arrowHeight + _cellHeight / 2;
      final xRight = _padX + col * _pitchX + _cellWidth;
      if (col + 1 < cols) {
        canvas.drawLine(Offset(xRight, y), Offset(xRight + _gapX, y), paint);
      } else {
        final laneY = y + _cellHeight / 2 + _rowGap / 2;
        final nextY = y + _pitchY;
        final path = Path()
          ..moveTo(xRight, y)
          ..lineTo(xRight + _gapX, y)
          ..lineTo(xRight + _gapX, laneY)
          ..lineTo(_padX - _gapX, laneY)
          ..lineTo(_padX - _gapX, nextY)
          ..lineTo(_padX, nextY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.cellCount != cellCount || oldDelegate.cols != cols;
}

/// A single tape cell: decimal value plus ASCII rendering, flashing when
/// the value changes.
final class TapeCell extends StatelessWidget {
  /// Creates a cell.
  const TapeCell({
    required this.index,
    required this.value,
    required this.isPointer,
    super.key,
  });

  /// The cell index on the tape.
  final int index;

  /// The cell value, 0–255.
  final int value;

  /// Whether the tape pointer is on this cell.
  final bool isPointer;

  @override
  Widget build(BuildContext context) {
    final base = isPointer ? Colors.amber.shade300 : const Color(0xFFF3E9D7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _arrowHeight,
          child: isPointer
              ? const Text('▼', style: TextStyle(fontSize: 12))
              : null,
        ),
        TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (context, t, _) {
            return Container(
              width: _cellWidth,
              height: _cellHeight,
              decoration: BoxDecoration(
                color: Color.lerp(Colors.deepOrange.shade300, base, t),
                border: Border.all(color: const Color(0xFFB08968)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _asciiLabel(value),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.brown.shade300,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _asciiLabel(int value) =>
    value >= 32 && value <= 126 ? String.fromCharCode(value) : '·';
