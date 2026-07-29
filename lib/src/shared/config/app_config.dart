/// Build-time configuration, supplied via `--dart-define` (or
/// `--dart-define-from-file=env.json`) so secrets are never committed.
///
/// These are the SAME values the web app uses (`VITE_SUPABASE_URL` /
/// `VITE_SUPABASE_ANON_KEY`) — the mobile app talks to the same Supabase project.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
