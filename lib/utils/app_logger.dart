import 'package:flutter/foundation.dart';

/// Release-safe logging.
///
/// `debugPrint` is NOT stripped from Flutter release builds, so logging tokens,
/// payment identifiers or full response bodies leaks them into logcat. Route all
/// diagnostic logging through these helpers, which no-op in release.
///
/// Rule: never pass tokens, OTPs, passwords, signatures or raw response bodies.

void logD(Object? message) {
  if (kDebugMode) {
    debugPrint('$message');
  }
}

void logE(Object? message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('ERROR: $message${error != null ? ' — $error' : ''}');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
  // Future: forward to a crash reporter (Sentry/Crashlytics) here.
}
