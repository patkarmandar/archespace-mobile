import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over Supabase Auth. The client is resolved lazily so the app
/// only touches `Supabase.instance` after `Supabase.initialize` has run.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
