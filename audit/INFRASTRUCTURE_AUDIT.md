# Production Infrastructure Audit

(Report section 7. Covers environment handling, configuration, error/logging/monitoring, and CI/CD readiness.)

## Environment & configuration

### INF-1 — No environment separation (dev / staging / prod) — *High*
**Evidence:** `api_client.dart:8-13` hardcodes prod URLs with dev URLs commented out; `payment_service.dart:64-66` hardcodes the live Razorpay key with the test key commented out. Switching environments means **editing source and recompiling** — error-prone and the root cause of the LAN-IP leak into "production" screens.
**Fix:** Use compile-time config and build flavors.
```dart
class Env {
  static const apiBase = String.fromEnvironment('API_BASE',
      defaultValue: 'https://api.metagod.in/api');
  static const razorpayKey = String.fromEnvironment('RAZORPAY_KEY');
  static const mediaBase = String.fromEnvironment('MEDIA_BASE',
      defaultValue: 'https://api.metagod.in');
}
```
```bash
flutter run --dart-define=API_BASE=https://staging-api.metagod.in/api --dart-define=RAZORPAY_KEY=rzp_test_xxx
```
Add Android product flavors (`dev`/`staging`/`prod`) with distinct `applicationIdSuffix` so all three can coexist on a device.

### INF-2 — Inconsistent host topology — *Medium*
Three different hosts appear: `api.metagod.in` (API), `live.metagodcreator.com` (FLV streams), `metagodcreator.com` (deep links + Razorpay branding "Meta God"). The socket URL is **derived** from `ApiClient.baseUrl` by trimming `/api` (`socket_service.dart:82-85`), coupling socket host to API host. Document the canonical host map and make each independently configurable via `Env`.

### INF-3 — Firebase is referenced in expectations but **not integrated** — *Informational*
No `google-services.json`, `GoogleService-Info.plist`, or Firebase packages exist. The app uses a custom backend (`api.metagod.in`) for everything — that's a valid choice. But it means **no Firebase Crashlytics, Analytics, Remote Config, or Cloud Messaging**. If push notifications are on the roadmap, none of that infrastructure exists yet.

## Error handling, logging, monitoring

### INF-4 — No crash/error reporting backend — *High (blocker for operating at scale)*
**Evidence:** `main.dart:13-55` captures errors via `FlutterError.onError` and `runZonedGuarded` but only calls `debugPrint`. In production these errors **go nowhere**. You will not know your crash-free rate, top crashes, or affected users.
**Fix:** Wire the existing handlers into a reporter:
```dart
FlutterError.onError = (details) {
  FlutterError.presentError(details);
  Sentry.captureException(details.exception, stackTrace: details.stack);
};
runZonedGuarded(() { ... }, (e, st) => Sentry.captureException(e, stackTrace: st));
```
Use `firebase_crashlytics` or `sentry_flutter`. Symbolicate with `--split-debug-info`.

### INF-5 — Logging strategy is ad-hoc and leaks PII — *High*
90+ `debugPrint`s, several logging tokens/payment data (see SECURITY SEC-H1). No log levels, no redaction, no production gating.
**Fix:** Single `Logger` abstraction with levels; no-op or remote-only in release; never log tokens/bodies.

### INF-6 — No analytics / observability — *Medium*
No product analytics or performance monitoring (e.g., API latency, payment funnel drop-off). For a commerce app you'll want conversion/payment-failure visibility. Add privacy-compliant analytics and declare it in Data Safety.

## CI/CD readiness

### INF-7 — No CI/CD pipeline — *Medium*
No `.github/workflows`, `codemagic.yaml`, `fastlane`, or similar found. Builds and signing are manual → reproducibility and key-handling risk.
**Fix:** Add a pipeline that runs `flutter analyze`, `flutter test`, and `flutter build appbundle --release --obfuscate --split-debug-info` with secrets injected from CI vault (keystore, Razorpay key). Gate merges on analyze+test.

### INF-8 — Secrets would land in VCS under current setup — *High*
With `key.properties`/keystore not yet created, ensure they are added to `.gitignore` **before** creation. The Razorpay live key is already in source/git history (`payment_service.dart`) — rotate it if it was ever a secret key (publishable keys are lower risk, but treat the test/live split via env going forward).

## Backup & data

### INF-9 — Backup correctly disabled — *Good*
`allowBackup="false"` + `fullBackupContent="false"` + `dataExtractionRules` present prevents token/PII exfiltration via ADB backup. Keep.

---

## Infrastructure readiness scorecard
| Area | State |
|---|---|
| Env separation | ❌ None |
| Crash reporting | ❌ None |
| Logging | ⚠️ Ad-hoc, leaks PII |
| Analytics/monitoring | ❌ None |
| CI/CD | ❌ None |
| Secrets management | ⚠️ In-source today |
| Backup hardening | ✅ Good |
