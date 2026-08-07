import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global error handling for the app, mirroring the web's ErrorBoundary +
/// ErrorScreen:
///
///  * [installErrorHandling] routes framework errors through [_report] (still
///    printing to the console) and replaces Flutter's default red error box
///    with a friendly widget for build/layout failures.
///  * [reportZoneError] handles uncaught async errors; pass it as the
///    `runZonedGuarded` handler in `main`.
///
/// There is no crash-reporting backend wired up yet, so errors are logged. A
/// reporter (Sentry, Crashlytics, …) can be dropped into [_report] later.
void installErrorHandling() {
  ErrorWidget.builder = _friendlyErrorWidget;
  FlutterError.onError = (details) {
    // Keep the console output (dev sees the full stack; release logs it too).
    FlutterError.presentError(details);
    _report(details.exception, details.stack);
  };
}

/// `runZonedGuarded` error handler for uncaught async errors.
void reportZoneError(Object error, StackTrace stack) => _report(error, stack);

void _report(Object error, StackTrace? stack) {
  debugPrint('[ArcheSpace] Uncaught error: $error');
  if (stack != null) debugPrint(stack.toString());
}

/// A friendly stand-in for Flutter's red error widget when a widget fails to
/// build. Rendered without assuming any inherited widgets (Theme/Directionality)
/// exist above it, so it's safe even for high-level failures. Technical details
/// are shown only in debug builds.
Widget _friendlyErrorWidget(FlutterErrorDetails details) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      color: const Color(0xFF121212),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: Color(0xFFEF6B6B)),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This screen ran into a problem. Go back and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text(
              details.exceptionAsString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF6B6B), fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
