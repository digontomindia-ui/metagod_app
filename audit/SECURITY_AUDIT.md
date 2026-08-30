# Security Audit

**Scale assumption:** 100,000+ users. Severity is rated for that scale.

Summary: **47/100.** Credential storage and payment verification are done correctly. The failures are in transport security, release hardening, logging, and platform permission/deep-link configuration.

| Severity | Count |
|---|---|
| 🔴 Critical | 3 |
| 🟠 High | 5 |
| 🟡 Medium | 6 |
| 🟢 Low | 3 |

---

## 🔴 CRITICAL

### SEC-C1 — Cleartext HTTP traffic enabled app-wide
**File:** `android/app/src/main/AndroidManifest.xml:13`
```xml
android:usesCleartextTraffic="true"
```
**Risk:** Permits unencrypted HTTP for every domain. Enables MITM credential/token theft on hostile networks and is a Play Store "broken/insecure" flag. The app's production APIs are HTTPS — this flag is only "needed" because of the hardcoded `http://192.168.29.158:4000` dev image URLs (which must be removed anyway, see BUG_REPORT).

**Fix:** Remove the attribute and add a network security config that blocks cleartext and (optionally) pins certs.
```xml
<!-- AndroidManifest.xml -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ... >  <!-- remove usesCleartextTraffic entirely -->
```
```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors><certificates src="system" /></trust-anchors>
    </base-config>
</network-security-config>
```

### SEC-C2 — Release build signed with the DEBUG key
**File:** `android/app/build.gradle.kts` (release buildType)
```kotlin
release { signingConfig = signingConfigs.getByName("debug") }
```
**Risk:** A debug certificate is publicly known. Anyone can sign a malicious update with the same key; Play Store rejects debug-signed uploads. This is both a **security** and a **release** blocker.
**Fix:** See `PLAYSTORE_AUDIT.md` SEC/REL-1 for the full keystore + `key.properties` setup.

### SEC-C3 — iOS will crash on first camera/mic/photo access (no usage strings) → also a security/privacy gap
**File:** `ios/Runner/Info.plist` (0 `*UsageDescription` keys present)
**Risk:** `image_picker` and `flutter_webrtc` request camera/mic/photos. On iOS, accessing these without a declared purpose string is an **immediate hard crash** and an App Store privacy violation. (Listed Critical because it is a guaranteed runtime failure.)
**Fix:**
```xml
<key>NSCameraUsageDescription</key>
<string>Used for video consultations and uploading your profile photo.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used for audio during live consultations with pandits.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to select a profile picture.</string>
```

---

## 🟠 HIGH

### SEC-H1 — Debug/PII logging left in production (90+ sites)
**Files:** project-wide (`grep debugPrint` = 92 hits). Examples leaking sensitive data:
- `payment_service.dart:102,112` — payment IDs, amounts, order IDs.
- `auth_service.dart:399,410` — full upload + profile response bodies.
- `socket_service.dart` — chat payloads, room IDs, connection URLs.

**Risk:** `debugPrint` is **not** stripped in release Flutter builds. On Android these land in logcat, readable by other apps' log readers / crash tools and anyone with ADB. Tokens/payment data exposure.
**Fix:** Route logging through a wrapper that no-ops in release, and never log tokens/bodies.
```dart
void logD(String msg) { if (kDebugMode) debugPrint(msg); }
```
Or add a release ProGuard/log-stripping step. Audit every payment/auth log for PII before keeping it.

### SEC-H2 — Secure storage silently falls back to plaintext SharedPreferences
**File:** `api_client.dart:29-48, 81-88` (and mirrored in `socket_service.dart:54-63`)
```dart
try { return await _secureStorage.read(key: 'accessToken'); }
catch (_) { return prefs.getString('accessToken'); } // plaintext fallback
```
**Risk:** On any device where Keystore/EncryptedSharedPreferences throws (known to happen on some OEMs after backup-restore), tokens get written/read in **plaintext** SharedPreferences without the user or you knowing. Long-lived refresh tokens then sit unencrypted.
**Fix:** Treat secure-storage failure as a hard auth failure (force re-login) rather than degrading to plaintext, or at minimum encrypt the fallback. Do not persist refresh tokens in plaintext.

### SEC-H3 — Android App Links auto-verify without a published `assetlinks.json`
**File:** `AndroidManifest.xml:38-46` (`android:autoVerify="true"` for `metagodcreator.com`)
**Risk:** Deep links are routed by string matching (`app.dart:66-92`) with **no signature/ownership proof** unless `/.well-known/assetlinks.json` is hosted. Without it, other apps can register the same `http(s)` host filter and intercept links → phishing / link hijacking. The deep-link handler also performs **unauthenticated navigation based purely on URL path substrings** (`path.contains('consult')`, etc.).
**Fix:** Host `https://metagodcreator.com/.well-known/assetlinks.json` with the app's release SHA-256. Validate/normalize the deep-link path against an allow-list, not `contains()`.

### SEC-H4 — Razorpay live key hardcoded as a default parameter
**File:** `payment_service.dart:66` → `String keyId = 'rzp_live_SlagYMOyb69p8S'`
**Risk:** The Razorpay *publishable* key is client-side by design, so the secret is not exposed — **but** hardcoding the live key inline (with the test key in a comment right above) makes accidental test/live mix-ups and key rotation painful, and the live key is now in git history. Real abuse risk is "create orders against your account" if the backend doesn't bind order amounts.
**Fix:** Inject the key via build-time config (`--dart-define=RAZORPAY_KEY=...`) and read with `String.fromEnvironment`. Ensure the **backend** sets/locks the order amount; never trust client `amount`.

### SEC-H5 — Payment success assumed when no verifier is supplied
**File:** `universal_payment_modal.dart:143-148`
```dart
} else { // verifyRazorpayPayment == null
  ScaffoldMessenger...('Payment Successful!');
  Navigator.of(context).pop('razorpay');
}
```
**Risk:** If any caller invokes the modal without `verifyRazorpayPayment`, the app marks payment successful purely on the client SDK callback — spoofable. Today all 5 callers pass a verifier (good), but the unsafe default is a landmine for the next feature.
**Fix:** Make `verifyRazorpayPayment` **required**, or treat a missing verifier as failure. Never grant entitlements on client-only success.

---

## 🟡 MEDIUM

### SEC-M1 — `/chat` and `/experts` treated as fully public (no auth header)
**File:** `api_client.dart:123-134` — `isPublic` includes `/chat`.
**Risk:** Any path starting `/chat` is sent with **no Authorization header**. If the AI-pandit chat is meant to be per-user/rate-limited, this enables anonymous API abuse and cost amplification. Verify backend enforces auth/rate-limits independently.
**Fix:** Narrow the public allow-list; send the token for `/chat` if it is user-scoped.

### SEC-M2 — No certificate pinning
**Files:** all `http` calls. **Risk:** With a user-installed root CA, traffic (including tokens) is interceptable. For a payments/wallet app at scale, pinning is expected.
**Fix:** Pin `api.metagod.in` via `SecurityContext`/`http` client with pinned certs, or use a `dio` + `certificate_pinning` interceptor.

### SEC-M3 — No client-side rate limiting / abuse guards on OTP & auth
**File:** `auth_service.dart:229-302` (`sendOtp`, `verifyOtp`).
**Risk:** OTP send/verify can be spammed (SMS/email cost, brute force). Ensure backend throttles; add client cooldown UI.
**Fix:** Server-side rate limit + lockout (primary); client resend cooldown timer (secondary).

### SEC-M4 — WebView / HTML rendering of server content
**Files:** `flutter_widget_from_html` usage; `youtube_player_flutter`→`flutter_inappwebview`.
**Risk:** Rendering server-supplied HTML can execute unexpected markup/links. If any rendered HTML is user-generated (chat, descriptions), XSS-style link/script injection is possible.
**Fix:** Sanitize/allow-list tags server-side; disable JS in any embedded WebView that renders untrusted content; validate URLs before `url_launcher`.

### SEC-M5 — `allowBackup` handled, but no explicit `android:exported` review on data
**File:** `AndroidManifest.xml`. `allowBackup="false"` is good. MainActivity `exported="true"` is required for launcher, fine. No content providers exposed. Keep monitoring as plugins are added.

### SEC-M6 — Tokens cached in plain `user_data` SharedPreferences
**File:** `auth_service.dart:69,145,207` — full user JSON (email, phone, wallet balance) in SharedPreferences.
**Risk:** PII at rest in plaintext on device. Lower severity (not credentials) but still PII.
**Fix:** Store the user profile in secure storage too, or treat as cache only and don't persist sensitive fields.

---

## 🟢 LOW

### SEC-L1 — `app_links` initial link handled before auth state known
`app.dart:45-64` processes deep links that switch tabs even when unauthenticated; harmless today but validate target screens guard auth.

### SEC-L2 — No screenshot/FLAG_SECURE protection on payment/wallet screens
Consider `FLAG_SECURE` on wallet/payment screens to prevent screen capture of balances.

### SEC-L3 — Verbose error messages surfaced to UI
`universal_payment_modal.dart:153` shows raw exception text to users; sanitize to avoid leaking internal details.

---

## Verified-Good Security Controls
- Server-side Razorpay signature verification (`temple_service.dart:325,379`, `wallet_service.dart:64`).
- Secure storage primary path for tokens.
- Single-flight refresh (`api_client.dart:192-205`) prevents token-refresh races.
- `allowBackup=false`, `dataExtractionRules` set.
- No hardcoded backend secrets/JWT signing keys in the client (checked).
