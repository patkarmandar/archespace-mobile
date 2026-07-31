/// Build-time configuration, supplied via `--dart-define` (or
/// `--dart-define-from-file=env.json`) so secrets are never committed.
///
/// These are the SAME values the web app uses (`VITE_SUPABASE_URL` /
/// `VITE_SUPABASE_ANON_KEY`) — the mobile app talks to the same Supabase project.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether to show the "Create account" option. Mirrors the web
  /// `MULTI_USER_ENABLED` flag; sign-up must also be enabled in Supabase Auth.
  /// Defaults to on; pass `--dart-define=ALLOW_SIGNUP=false` to hide it.
  static const bool allowSignup =
      bool.fromEnvironment('ALLOW_SIGNUP', defaultValue: true);

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
