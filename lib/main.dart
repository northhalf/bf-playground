import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

/// Root widget of the Brainfuck live-preview playground.
class MainApp extends StatelessWidget {
  /// Creates the root widget.
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
