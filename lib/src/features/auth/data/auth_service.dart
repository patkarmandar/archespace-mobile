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

  /// Register a new account. When email confirmation is disabled in Supabase,
  /// the response carries a live [Session] and the user is signed in
  /// immediately; otherwise they must confirm via email before signing in.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Sign out of this device only. Local scope so ending the session on the
  /// phone does not revoke the user's sessions on their other devices (web or
  /// otherwise) — that would log every platform out at once. Global,
  /// all-device revocation is reserved for password changes.
  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  /// Send a password reset email. The link opens the web app's reset page
  /// (Supabase Site URL), where the user sets a new password, then signs in
  /// again here.
  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Send a 6-digit reauthentication code to the user's current email. Required
  /// before changing the account email so we can prove it's really them.
  Future<void> reauthenticate() async {
    await _client.auth.reauthenticate();
  }

  /// Change the account email. [nonce] is the reauthentication code sent to the
  /// current address; a confirmation link then goes to the new address and the
  /// change takes effect once the user opens it.
  Future<void> updateEmail(String email, String nonce) async {
    await _client.auth.updateUser(UserAttributes(email: email, nonce: nonce));
  }

  /// Change the login password (separate from the vault PIN).
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  /// Permanently delete the signed-in user's account via a database RPC, then
  /// end the local session.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_current_user');
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
