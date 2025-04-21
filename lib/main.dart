import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const OsmosApp());
}

class OsmosApp extends StatelessWidget {
  const OsmosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Osmos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B77D),
          primary: const Color(0xFF00B77D),
          background: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}