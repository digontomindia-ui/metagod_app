# Final Production Checklist

Status legend: ❌ not done / blocker · ⚠️ partial · ✅ done. Each item links to the report with the fix.

---

## 🚫 MUST FIX BEFORE RELEASE (release is blocked until all are ✅)

### Release / Build
- [ ] ❌ Replace **debug signing** with a real upload keystore + `key.properties`; enroll in Play App Signing — *PLAYSTORE REL-1*
- [ ] ❌ Change **applicationId/namespace** off `com.example.app2` (permanent once published) — *PLAYSTORE REL-2*
- [ ] ❌ Enable **R8 / resource shrinking** (`isMinifyEnabled=true`, `isShrinkResources=true`) and test a release build end-to-end — *PLAYSTORE REL-3*
- [ ] ⚠️ Confirm **targetSdk = 35** resolves from the Flutter SDK — *PLAYSTORE REL-8*
- [ ] ❌ Build & validate the **App Bundle** with `--obfuscate --split-debug-info` — *PLAYSTORE*

### Security
- [ ] ❌ Remove `usesCleartextTraffic="true"` + add **network security config** (no cleartext) — *SECURITY SEC-C1*
- [ ] ❌ Strip/▶gate **90+ debugPrint** calls; remove all token/payment/PII logging — *SECURITY SEC-H1*
- [ ] ❌ Stop **plaintext fallback** for tokens (fail-closed to re-login) — *SECURITY SEC-H2*
- [ ] ❌ Move **Razorpay key** to `--dart-define`; verify backend locks order amounts — *SECURITY SEC-H4*
- [ ] ⚠️ Make `verifyRazorpayPayment` **required** (fail closed) — *SECURITY SEC-H5 / BUG-10*
- [ ] ❌ Publish **`assetlinks.json`** + validate deep-link paths against an allow-list — *SECURITY SEC-H3*

### Platform / Crashes
- [ ] ❌ Add iOS **camera/mic/photo usage strings** (else instant iOS crash) — *BUG-2 / SEC-C3*
- [ ] ❌ Fix hardcoded **`192.168.29.158` image URLs** (broken for all users) — *BUG-1 / PERF-1*
- [ ] ❌ Add **`mounted` guards** after awaits in OTP verify & wallet fetch & live-stream `_skipAd` — *BUG-3, BUG-5, BUG-6*
- [ ] ❌ Add **HTTP request timeouts** (no infinite spinners) — *BUG-9 / DEP-4*

### Operations
- [ ] ❌ Integrate **crash reporting** (Crashlytics or Sentry) into existing error handlers — *INFRA INF-4*
- [ ] ❌ Provide **Privacy Policy URL** + complete **Data Safety** form — *PLAYSTORE REL-5*
- [ ] ❌ Implement **in-app account deletion** (Play requirement) — *PLAYSTORE REL-6*
- [ ] ⚠️ Ensure **keystore & key.properties are git-ignored**; rotate any leaked secret keys — *INFRA INF-8*

---

## 🔧 RECOMMENDED FIXES (strongly advised before scaling to 100k)

- [ ] Add **`cached_network_image`** and replace all `Image.network`/`NetworkImage` — *PERF-2*
- [ ] Add **`errorBuilder`** to remaining network images — *PERF-3/5*
- [ ] **Pagination** for orders/products/temples/experts/transactions — *FUTURE FR-H1*
- [ ] **Environment separation** via `--dart-define` + Android flavors (dev/staging/prod) — *INFRA INF-1*
- [ ] Fix **Provider rebuild storms** in marketplace grid (`Selector`/`context.select`) — *PERF-3*
- [ ] **Debounce** product search — *PERF-4*
- [ ] Re-scope/reference-count the **global SocketService** to stop cross-screen teardown — *BUG-7 / FR-H4*
- [ ] Defensive JSON parsing (replace `as String`/`as List`/`.isNotEmpty` on dynamics) — *BUG-8, BUG-11–15*
- [ ] In-memory **token cache** in `ApiClient` (avoid per-request secure-storage reads) — *PERF-12*
- [ ] Add **`connectivity_plus`** + offline/retry UX — *FR-M6*
- [ ] Verify **`flutter_vlc_player_16kb`** 16KB compliance; pin native plugins — *DEPENDENCY DEP-1*
- [ ] Verify **Socket.IO** client/server protocol versions match — *DEP-3*
- [ ] Add **`mounted` guards / safe navigation** for delayed success dialogs — *BUG-16*
- [ ] Service-level **unit tests** (token refresh, cart math, payment verify) — *CODE QUALITY CQ-11*
- [ ] Set up **CI/CD** (analyze + test + signed build) — *INFRA INF-7*

---

## 💡 NICE TO HAVE (quality & maintainability)

- [ ] Remove unused **`go_router`** (or adopt it for navigation) — *DEP-2 / CQ-4*
- [ ] Delete scratch/dev files from repo (`scratch.txt`, `scratch_stream_dump.bin`, `rewrite_chat.py`, `update_chat.dart`, `test_api.*`) — *CQ-10*
- [ ] Decompose **god-widgets** (`temple_details_screen.dart` ~1,900 lines; consultation chat) — *CQ-2*
- [ ] Introduce a **repository/domain layer**; centralize token-envelope parsing — *CQ-1*
- [ ] Standardize **branding/ids** (temple / MetaGodCreator / App2 / com.example) — *FR-L2*
- [ ] Re-evaluate enabling **Impeller** on Android — *PERF-10*
- [ ] Add **analytics**/observability (payment funnel, API latency) — *INFRA INF-6*
- [ ] Consider **certificate pinning** for `api.metagod.in` — *SECURITY SEC-M2*
- [ ] Add **`FLAG_SECURE`** to wallet/payment screens — *SECURITY SEC-L2*
- [ ] Remove unneeded `CHANGE_NETWORK_STATE` permission if unused — *PLAYSTORE REL-7*
- [ ] Standardize service **error-handling** convention (`Result`/typed exceptions) — *CQ-8*

---

## Release Go/No-Go Gate

| Gate | Requirement | Current |
|---|---|---|
| **G1** | All MUST-FIX items ✅ | ❌ 0 / 20 |
| **G2** | Crash-free monitoring live | ❌ |
| **G3** | Privacy Policy + Data Safety submitted | ❌ |
| **G4** | Release `.aab` installs & passes payment/socket/video smoke test on a physical device | ⛔ untested (debug-signed) |

**Current gate status: 🔴 NO-GO.** Re-run this checklist after the MUST-FIX block is cleared.
