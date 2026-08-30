/// Centralized, build-time environment configuration.
///
/// All values can be overridden at build/run time with `--dart-define`, e.g.:
///   flutter run \
///     --dart-define=API_BASE=https://staging-api.metagod.in/api \
///     --dart-define=MEDIA_BASE=https://staging-api.metagod.in \
///     --dart-define=RAZORPAY_KEY=rzp_test_xxx
///
/// This removes hardcoded hosts/keys from feature code and enables
/// dev/staging/prod separation without editing source.
class Env {
  Env._();

  /// Backend REST API base (includes the `/api` suffix).
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api.metagod.in/api',
  );

  /// Origin that serves uploaded media (avatars, images). No `/api` suffix.
  static const String mediaBase = String.fromEnvironment(
    'MEDIA_BASE',
    defaultValue: 'https://api.metagod.in',
  );

  /// Base URL for live FLV/HLS streams.
  static const String liveStreamBase = String.fromEnvironment(
    'LIVE_STREAM_BASE',
    defaultValue: 'https://live.metagodcreator.com',
  );

  /// Razorpay publishable key. Safe to ship (publishable, not secret), but
  /// kept here so test/live keys are swapped via build flags, never code edits.
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_live_SlagYMOyb69p8S',
  );

  /// Resolves a possibly-relative media [path] into an absolute https URL.
  /// Returns an empty string for null/empty input (callers should show a
  /// placeholder). Absolute URLs are returned unchanged.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final sep = path.startsWith('/') ? '' : '/';
    return '$mediaBase$sep$path';
  }
}
