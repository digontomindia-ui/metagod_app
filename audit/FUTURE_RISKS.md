# Future Risk Analysis

Risks that may not block launch but will surface as the app scales toward 100k+ users or as the codebase grows. Classified High / Medium / Low.

---

## 🔴 High Risk

### FR-H1 — No pagination → memory & latency wall
Every list (`/orders/my`, products, temples, experts, transactions) loads in full. As catalogs and user histories grow, payload size and on-device memory grow unbounded → slow screens and OOM crashes on low-RAM devices. **Becomes a problem the moment any user has hundreds of orders or the catalog exceeds a few hundred items.** Retrofit pagination early; it's far cheaper before the data model and UI ossify.

### FR-H2 — Operating blind: no crash reporting / analytics
Without Crashlytics/Sentry and analytics (INFRA), you cannot detect or prioritize production failures, measure crash-free rate, or see payment-funnel drop-off. At 100k users this means silent revenue loss and slow incident response. **Add before launch.**

### FR-H3 — Hardcoded config & single-environment builds
`api_client.dart` / `payment_service.dart` bake URLs and the live payment key into source. This already caused dev LAN IPs to ship in production screens. As the team and environments grow, this guarantees more "wrong endpoint/key in the wrong build" incidents. Migrate to `--dart-define`/flavors (INF-1).

### FR-H4 — Global singletons with side-effects (`SocketService`, `PaymentService`)
A single global socket shared across features, torn down by individual screens (`temple_details_screen.dart:81`), will produce increasingly hard-to-reproduce "live features randomly disconnect" bugs as more screens use sockets. Reference-count or scope per feature.

---

## 🟡 Medium Risk

### FR-M1 — Architecture won't scale with team size
No repository/domain layer; response-shape parsing duplicated across UI/services (`auth_service` parses 4 token envelope shapes inline). Each backend change touches many files. As contributors increase, merge conflicts and regressions rise. Introduce a data/domain layer (CQ-1).

### FR-M2 — "God" widgets (1,900-line files)
`temple_details_screen.dart` and `consultation_chat_screen.dart` concentrate many responsibilities. These become change-bottlenecks and rebuild-performance hotspots. Decompose incrementally.

### FR-M3 — Near-zero test coverage
A payments/wallet app with one smoke test has no regression safety net. Every refactor risks silently breaking token refresh, cart math, or payment verification. Technical debt compounds. Build a service-level test suite (CQ-11).

### FR-M4 — Native plugin fragility across OS upgrades
`flutter_webrtc`, `flutter_vlc_player_16kb` (single-maintainer fork), `youtube_player_flutter`→`flutter_inappwebview` are heavy native deps. Android 15/16 and iOS yearly changes (16KB pages, privacy manifests, permission changes) regularly break such plugins. Budget for per-OS-release regression testing; keep the VLC fork pinned and monitored (DEP-1).

### FR-M5 — Socket.IO protocol coupling
Client `2.0.x` must stay protocol-compatible with the backend's Socket.IO version. A backend upgrade can silently break live chat/consultations. Version-lock both ends and add a connection health check.

### FR-M6 — No offline / poor-network strategy
No `connectivity_plus`, no request timeouts (DEP-4), no retry/backoff. On India's variable mobile networks (the target market), users will hit infinite spinners. Add timeouts + offline states.

---

## 🟢 Low Risk

### FR-L1 — Dead dependency (`go_router`) and scratch files in repo
Cosmetic/hygiene debt (`scratch.txt`, `scratch_stream_dump.bin`, `rewrite_chat.py`, `update_chat.dart`). Remove to reduce confusion and build surface.

### FR-L2 — Branding inconsistency
`temple` (pubspec) vs `MetaGodCreator` (Android label) vs `App2` (iOS) vs `com.example.app2` (id). Harmless now but causes store-listing and analytics confusion later. Standardize.

### FR-L3 — Impeller disabled on Android
Skia fallback may cause shader-compilation jank and will diverge from Flutter's default rendering path over time. Re-evaluate enabling Impeller (PERF-10).

### FR-L4 — Manual navigation state in `app.dart`
Tab index + filter strings in one `StatefulWidget`. Works for 5 tabs; will get unwieldy as flows deepen (deep links already special-case profile via `navigatorKey`). Adopt a real router when complexity grows.

---

## Risk heat map

| Risk | Likelihood | Impact | Class |
|---|---|---|---|
| No pagination (FR-H1) | High | High | 🔴 |
| Blind in prod (FR-H2) | High | High | 🔴 |
| Hardcoded config (FR-H3) | High | High | 🔴 |
| Singleton side-effects (FR-H4) | Med | High | 🔴 |
| Architecture scaling (FR-M1) | Med | Med | 🟡 |
| God widgets (FR-M2) | High | Med | 🟡 |
| No tests (FR-M3) | High | Med | 🟡 |
| Plugin fragility (FR-M4) | Med | Med | 🟡 |
| Socket coupling (FR-M5) | Low | High | 🟡 |
| Offline UX (FR-M6) | High | Med | 🟡 |
