import 'package:flutter/material.dart';

void main() {
  runApp(const ArcheApp());
}

/// Placeholder app shell. The real UI (auth, vault unlock, spaces) is built on
/// top of the crypto layer in `lib/core/`.
class ArcheApp extends StatelessWidget {
  const ArcheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arche Space',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7C6AF7),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Arche Space')),
      ),
    );
  }
}
