# Play Store Release Audit

**Verdict: ❌ WILL BE REJECTED.** Four hard blockers in the release/build config plus missing policy assets. None are in feature code — all fixable quickly.

## Pass/Fail Checklist

| # | Check | Status | Detail |
|---|---|---|---|
| 1 | Release signed with an **upload/release keystore** | ❌ **FAIL** | Signed with **debug** key — `build.gradle.kts` release block |
| 2 | Application ID is not `com.example.*` | ❌ **FAIL** | `applicationId = "com.example.app2"` |
| 3 | Code shrinking / R8 enabled for release | ❌ **FAIL** | `isMinifyEnabled = false`, `isShrinkResources = false` |
| 4 | No cleartext traffic (or justified) | ❌ **FAIL** | `usesCleartextTraffic="true"` |
| 5 | Privacy Policy URL provided | ❌ **FAIL** | None found in repo/store assets |
| 6 | Data Safety form mappable to actual data use | ❌ **FAIL** | Collects email, phone, photos, payment, mic/camera — no mapping doc |
| 7 | Crash reporting (Play vitals / Crashlytics) | ⚠️ **WEAK** | Only `runZonedGuarded` logging; no reporting backend |
| 8 | `targetSdk` meets current Play requirement | ⚠️ **CHECK** | Uses `flutter.targetSdkVersion` — must be **35 (Android 14)** for 2025+ submissions; verify Flutter SDK resolves to ≥35 |
| 9 | App Bundle (.aab) build path | ✅ PASS | Flutter supports `flutter build appbundle`; `multiDexEnabled=true` set |
| 10 | Permissions are all justified & used | ⚠️ PARTIAL | `CHANGE_NETWORK_STATE` likely unnecessary; others justified |
| 11 | App label / branding consistent | ⚠️ PARTIAL | Android label `MetaGodCreator`; iOS `App2`; pubspec name `temple`; namespace `com.example.app2` |
| 12 | Deep-link domain verification (assetlinks) | ❌ **FAIL** | `autoVerify=true` but no `assetlinks.json` referenced |
| 13 | 64-bit / NDK compliance | ✅ PASS | Flutter default arm64 supported |
| 14 | No debug code/logs in release | ❌ **FAIL** | 90+ `debugPrint` ship in release |
| 15 | iOS permission usage strings (if shipping iOS) | ❌ **FAIL** | Missing all `NS*UsageDescription` |

---

## Blocker Fixes

### REL-1 — Real release signing
**File:** `android/app/build.gradle.kts`
1. Generate an upload keystore:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
2. `android/key.properties` (git-ignored):
```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```
3. Wire it up:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") // not debug
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```
Add `key.properties` and `*.jks` to `.gitignore`. **Enroll in Play App Signing.**

### REL-2 — Rebrand application & namespace ids
**File:** `android/app/build.gradle.kts`
```kotlin
namespace = "in.metagod.app"          // or com.metagodcreator.app
applicationId = "in.metagod.app"
```
Update `MainActivity` package path, iOS `PRODUCT_BUNDLE_IDENTIFIER`, and any references. **The applicationId is permanent once published — choose carefully now.**

### REL-3 — Enable R8 + verify keeps
Set `isMinifyEnabled = true` / `isShrinkResources = true` (REL-1). The existing `proguard-rules.pro` already keeps Razorpay, secure-storage, inappwebview, gson — good. **Test a release build end-to-end** (payments, sockets, video) after enabling, as shrinking can strip reflective plugin classes.

### REL-4 — Remove cleartext + network security config
See `SECURITY_AUDIT.md` SEC-C1. Remove the dev-IP image URLs first (BUG_REPORT) so HTTPS-only is viable.

### REL-5 — Privacy Policy + Data Safety
The app collects: name, email, phone, profile photo (camera/gallery), payment identifiers (Razorpay), microphone/camera (consultations), chat content, approximate device/network state. You must:
- Host a Privacy Policy URL and enter it in the Play Console.
- Complete the **Data Safety** form declaring each data type, purpose, sharing (Razorpay), and encryption-in-transit.
- Declare camera/mic/photo usage and (if applicable) a data deletion mechanism (account deletion is now mandatory if you offer account creation).

### REL-6 — Account deletion requirement
Google requires apps with account sign-up to offer **in-app account deletion** and a web deletion URL. No deletion flow was found. Add a "Delete account" path (UI + backend endpoint + web URL).

### REL-7 — Permissions audit
`AndroidManifest.xml:2-7`. Justified: INTERNET, CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS (WebRTC), ACCESS_NETWORK_STATE. Review `CHANGE_NETWORK_STATE` — rarely needed; remove if `flutter_webrtc` doesn't require it to reduce the permissions footprint shown to users.

### REL-8 — targetSdk
Confirm the Flutter version resolves `flutter.targetSdkVersion` to **35**. If not, pin `targetSdk = 35` explicitly. Play blocks new apps/updates below the current target requirement.

---

## Pre-submission build commands
```bash
flutter clean
flutter build appbundle --release \
  --dart-define=RAZORPAY_KEY=rzp_live_xxx \
  --obfuscate --split-debug-info=build/symbols
```
Upload the `.aab`; keep `build/symbols` for crash de-obfuscation.
