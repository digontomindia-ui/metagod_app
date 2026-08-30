# Dependency Audit

Resolved from `pubspec.lock`. Most direct dependencies are current. The concerns are one single-maintainer native fork, one entirely unused dependency, and several **missing** packages a production app at this scale needs.

## Direct dependencies

| Package | Resolved | Assessment |
|---|---|---|
| `http` | 1.6.0 | ✅ Current. ⚠️ But used with **no timeouts/retry/interceptors** — see DEP-4. |
| `shared_preferences` | 2.5.5 | ✅ Current. |
| `provider` | 6.1.5+1 | ✅ Current. |
| `url_launcher` | 6.3.2 | ✅ Current. Validate URLs before launching (untrusted content). |
| `youtube_player_flutter` | 9.1.3 | ✅ Maintained. Pulls in `flutter_inappwebview` (WebView attack surface). |
| `visibility_detector` | 0.4.0+2 | ✅ Stable (low release cadence, but simple/safe). |
| `flutter_vlc_player_16kb` | 7.4.7 | 🟠 **Single-maintainer community fork** — see DEP-1. |
| `video_player` | 2.11.1 | ✅ Official, current. |
| `razorpay_flutter` | 1.4.5 | ✅ Current official SDK. |
| `socket_io_client` | 2.0.3+1 | 🟡 Works with Socket.IO 3/4 servers — confirm server version match (see DEP-3). |
| `flutter_secure_storage` | 9.2.4 | ✅ Current 9.x. |
| `flutter_widget_from_html` | 0.17.2 | 🟡 Renders HTML → XSS surface if content is user-generated (SEC-M4). |
| `flutter_webrtc` | 1.4.1 | ✅ Maintained; heavy native dependency. Pin and test per OS upgrade. |
| `permission_handler` | 12.0.3 | ✅ Current. |
| `image_picker` | 1.2.2 | ✅ Current. |
| `go_router` | 17.3.0 | 🔴 **Declared but never used** — dead dependency (DEP-2). |
| `app_links` | 7.0.0 | ✅ Current. |
| `cupertino_icons` | 1.0.8 | ✅ Current. |
| `flutter_lints` (dev) | 6.0.0 | ✅ Current. |
| `flutter_launcher_icons` (dev) | 0.14.1 | ✅ Current. |

---

## Findings

### DEP-1 — `flutter_vlc_player_16kb` is a single-maintainer fork — *Medium risk*
This is a community fork of `flutter_vlc_player` created to add **16 KB memory-page support** (an Android 15 / API 35 requirement). It addresses a real need, but:
- It is **not the official package**; security/bug fixes from upstream may not be merged.
- Supply-chain risk: a forked native-video plugin runs native code with broad access.
**Recommendation:** Track whether the **official** `flutter_vlc_player` now ships 16KB support and migrate back if so; otherwise pin this fork to an exact version, monitor its repo, and review its native source before each bump. Confirm 16KB compliance is actually met (required for Play submissions targeting API 35).

### DEP-2 — `go_router` is unused — *Low risk (cleanup)*
No `GoRouter`/`context.go` usage exists anywhere in `lib/`. Navigation is done via manual tab indices (`app.dart`) and `Navigator.push`.
**Recommendation:** Either **remove** `go_router` (smaller build, fewer transitive deps) **or** adopt it to fix the ad-hoc navigation (CQ-4). Don't ship an unused router.

### DEP-3 — Confirm Socket.IO client/server protocol match — *Medium risk*
`socket_io_client 2.0.x` speaks the Socket.IO v3/v4 protocol. A mismatch with the backend's Socket.IO major version causes silent connection failures (handshake 400). Given live chat + consultations depend on it, verify the server is v3/v4 and lock both sides.

### DEP-4 — No HTTP timeout/retry/interceptor layer — *High risk at scale*
`ApiClient` uses bare `http.get/post` with **no `.timeout(...)`**. On flaky mobile networks a stalled request hangs the UI's loading state indefinitely (no error, no retry). There is custom 401-refresh logic but nothing for connection timeouts, 5xx, or offline.
**Recommendation:** Add per-request timeouts now:
```dart
await http.post(uri, headers: headers, body: bodyStr)
    .timeout(const Duration(seconds: 20));
```
Consider migrating to `dio` for built-in timeouts, retries, interceptors (auth, logging, error mapping) and cancellation.

---

## Missing dependencies a 100k-user app should add

| Need | Suggested package | Why |
|---|---|---|
| Image caching | `cached_network_image` | Eliminates repeated downloads/jank (PERF-2). |
| Crash reporting | `firebase_crashlytics` **or** `sentry_flutter` | You are currently blind in production (INFRA). |
| Connectivity awareness | `connectivity_plus` | Graceful offline UX; avoid hung requests. |
| Env/config | `--dart-define` (built-in) or `envied` | Remove hardcoded keys/URLs; dev/stage/prod separation. |
| Robust networking | `dio` (+ `pretty_dio_logger`) | Timeouts, retries, interceptors (DEP-4). |

---

## Upgrade / action plan
1. **Remove** `go_router` (or adopt it).
2. **Add** `cached_network_image`, a crash reporter, and `connectivity_plus`.
3. **Add request timeouts** (or move to `dio`).
4. **Verify** `flutter_vlc_player_16kb` 16KB compliance & pin it; watch upstream.
5. Run `flutter pub outdated` in CI and review monthly; pin exact versions for native plugins (`flutter_webrtc`, vlc, razorpay).
