import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_service.dart';
import 'core/vault/vault_session.dart';
import 'features/auth/login_screen.dart';
import 'features/spaces/spaces_screen.dart';
import 'features/vault/unlock_screen.dart';

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
      home: const _RootGate(),
    );
  }
}

/// Decides which screen to show: login (no session), unlock (session but locked
/// vault), or the spaces list (session + unlocked). Locks the vault on sign-out.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  final AuthService _auth = AuthService();
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        VaultSession.instance.lock();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentSession == null) {
      return const LoginScreen();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: VaultSession.instance.unlocked,
      builder: (context, unlocked, _) =>
          unlocked ? const SpacesScreen() : const UnlockScreen(),
    );
  }
}
