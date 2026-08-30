# Flutter Code Quality Audit

**Score: 58/100.** The code is readable, consistently styled, and the folder layout is clean. It loses points for the absence of an architecture layer, oversized widget files, near-zero automated tests, and a few correctness/lifecycle smells.

---

## Architecture & Structure

### CQ-1 — No architecture layering (UI talks to services directly) — *Medium*
**Problem:** Screens call services and parse `jsonDecode` response shapes directly (e.g. `auth_service.dart` parses 4 different token envelope shapes inline at `120-135`, `196-205`, `267-289`). There is no domain/repository layer, no DTO ↔ entity separation. Business rules (token envelope handling, price fallbacks) are scattered across UI and services.
**Impact:** Backend response changes ripple into many files; hard to unit test; logic duplicated.
**Fix:** Introduce a thin repository layer:
```
data/   (api clients, DTOs, repositories)
domain/ (entities, use-cases)
presentation/ (screens, view-models)
```
Centralize the "extract tokens from N possible shapes" logic into one `AuthMapper`.

### CQ-2 — "God" widget files — *Medium*
**Problem:** `temple_details_screen.dart` is ~1,900 lines and contains multiple screens/sheets (`_CheckoutSheet`, success dialogs, booking flows, live chat). `consultation_chat_screen.dart` mixes WebRTC signaling, UI, and socket plumbing.
**Impact:** Hard to review, test, or reuse; high merge-conflict surface; rebuild scope is large.
**Fix:** Extract sheets/dialogs/sections into their own widgets; move WebRTC signaling into a dedicated controller class.

### CQ-3 — SOLID / SRP violations — *Medium*
- `AuthService` (465 lines) handles session, profile, membership, image upload, password — multiple responsibilities (SRP).
- `SocketService` mixes live-chat, consultation chat, **and** WebRTC signaling in one singleton.
**Fix:** Split `AuthService` into `SessionManager` + `ProfileRepository`. Split `SocketService` into `LiveChatSocket` + `ConsultationSocket`.

---

## State Management

### CQ-4 — Mixed/ad-hoc state strategy — *Medium*
**Problem:** `provider` (ChangeNotifier/ProxyProvider) for app state, but most screens load data with local `setState` + manual `_isLoading`/`_error` flags and no shared pattern. `go_router` is a dependency but **navigation is manual** (tab index in `app.dart`, `Navigator.push` elsewhere).
**Impact:** Inconsistent loading/error handling; duplicated boilerplate; `go_router` is dead weight (see DEPENDENCY_AUDIT).
**Fix:** Standardize on one async-state pattern (e.g. a small `AsyncValue<T>` or `flutter_riverpod`/`bloc`). Either adopt `go_router` properly or remove it.

### CQ-5 — Global singletons with cross-feature side-effects — *High*
**Problem:** `SocketService()` is a global singleton; `temple_details_screen.dart:81` calls `SocketService().disconnect()` in `dispose()`, tearing down the shared socket for any other screen using it (e.g. a parent `LiveChatTab`).
**Impact:** One screen's teardown breaks another's live connection — intermittent "chat stopped working" bugs.
**Fix:** Reference-count socket usage, or scope sockets per feature instead of one global instance.

---

## Lifecycle / Context / Async

### CQ-6 — `BuildContext` used across `await` without `mounted` guard — *High*
**Problem:** Several async handlers touch `context` after awaits with no guard. Confirmed: `otp_screen.dart:_handleVerify (113-135)`, `wallet_screen.dart` fetch catch (`39-42`). (Full list in BUG_REPORT.)
**Impact:** `setState`/`Navigator`/`ScaffoldMessenger` after dispose → runtime exceptions.
**Fix:** `if (!mounted) return;` (or `if (!context.mounted)`) immediately after every `await` that precedes a `context` use.

### CQ-7 — Unsafe casts / null handling on dynamic JSON — *Medium*
**Problem:** Direct `as String` / `as List` / `.isNotEmpty` on `dynamic` map values from the network: `booking.dart:30`, `pandit_card.dart:248,455`, `live_chat_tab.dart:90`, `my_orders_screen.dart:38,268`. Models do mostly use `?? fallback`, which is good, but the unguarded casts will throw `TypeError` on schema drift.
**Fix:** Prefer `value?.toString() ?? ''` and `(value as List?) ?? const []`; centralize parsing in model `fromJson`.

### CQ-8 — Inconsistent error handling — *Low*
Some services `throw ApiException`, others return `bool`, others swallow with `debugPrint` and return `false` (`auth_service.dart:361-364`, `updateProfile`). Callers can't reliably distinguish failure causes.
**Fix:** Standardize on a `Result`/typed-exception convention across services.

---

## Null Safety & Correctness

### CQ-9 — Null-assertion (`!`) on possibly-null fields — *Medium*
`home_screen.dart:314` uses `user.avatar!` after a `startsWith` check on the same nullable; `live_stream_player.dart:461` asserts `_videoController!`. These rely on invariants that aren't locally guaranteed.
**Fix:** Promote via local non-null variable: `final a = user.avatar; if (a != null) ...`.

### CQ-10 — Dead/placeholder code & scratch files in repo — *Low*
Root contains `scratch.txt`, `scratch_stream_dump.bin` (50KB binary), `rewrite_chat.py`, `update_chat.dart`, `test_api.dart`, `test_api.py`. These don't belong in a production repo.
**Fix:** Remove or move to a `tools/`/`.dev/` folder excluded from VCS.

---

## Testing

### CQ-11 — Effectively no automated tests — *High*
**Problem:** Only `test/widget_test.dart` exists, and it's a custom smoke test with a `MockApiClient`. No unit tests for `AuthService` token parsing, `CartService` math, `ApiClient` refresh logic, or payment flows — the exact areas most prone to regression.
**Impact:** No regression safety net for a payments app at scale.
**Fix:** Add unit tests for: token-envelope parsing, refresh single-flight, cart totals/stock caps, wallet/verify flows. Target the services first (pure, high-value).

---

## What's Good
- Consistent naming, formatting, and file organization by feature.
- Models use defensive `?? fallback` parsing for numbers.
- `CartService` correctly uses `UnmodifiableMapView` to protect internal state and caps quantity at stock.
- `ApiClient` refresh logic is well-designed (single-flight, multi-shape token extraction).
- Good `dispose()` discipline in the majority of stateful widgets.
- `analysis_options.yaml` uses `flutter_lints` (keep, and consider stricter rules).
