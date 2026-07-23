import 'package:bf_playground/home_page.dart';
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
    return MaterialApp(
      title: 'bf_playground',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        scaffoldBackgroundColor: const Color(0xFFFBF3E4),
      ),
      home: const HomePage(),
    );
  }
}
