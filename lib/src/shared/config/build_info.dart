/// Build provenance, injected at compile time via `--dart-define`.
///
/// Surfacing the commit hash lets users verify the app they installed matches
/// the audited, open-source release. Mirrors the web `buildInfo.js`. Pass the
/// values at build time, e.g.:
///
///   flutter build apk --release \
///     --dart-define-from-file=env.json \
///     --dart-define=APP_VERSION=$(git describe --tags --always) \
///     --dart-define=BUILD_HASH=$(git rev-parse --short HEAD) \
///     --dart-define=BUILD_TIME=$(git log -1 --format=%cI)
class BuildInfo {
  const BuildInfo._();

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
  static const String buildHash =
      String.fromEnvironment('BUILD_HASH', defaultValue: 'dev');
  static const String buildTime = String.fromEnvironment('BUILD_TIME');

  static const String repoUrl = 'https://github.com/patkarmandar/archespace-mobile';

  /// Link to the exact source commit this build was compiled from, or the repo
  /// root for unstamped ("dev") builds.
  static String get commitUrl =>
      buildHash == 'dev' ? repoUrl : '$repoUrl/commit/$buildHash';

  static bool get isStamped => buildHash != 'dev';
}
