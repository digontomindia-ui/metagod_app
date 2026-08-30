# Bug Detection Report

Concrete, line-cited defects: crash risks, null/type exceptions, lifecycle (`context`-after-`await`) bugs, race conditions, and network-failure handling gaps. Severity assumes 100k-user production.

| Severity | Count |
|---|---|
| 🔴 Critical | 4 |
| 🟠 High | 6 |
| 🟡 Medium | 7 |
| 🟢 Low | 4 |

---

## 🔴 Critical

### BUG-1 — Hardcoded LAN dev IP → broken images + cleartext for all users
**Files:** `home_screen.dart:314`, `live_chat_tab.dart:198-199`, `consultation_chat_screen.dart:1056`
**Description:** Relative avatar paths resolve to `http://192.168.29.158:4000/...` (a private dev IP). In production every such image fails, retries, and (when `usesCleartextTraffic` is removed) is also blocked. User/chat avatars are broken for 100% of users.
**Fix:** Centralize media URL building on the configured host (see PERF-1); never reference LAN IPs.

### BUG-2 — iOS hard crash on first camera/mic/photo use
**File:** `ios/Runner/Info.plist` (no `NS*UsageDescription` keys)
**Description:** `image_picker` (profile photo) and `flutter_webrtc` (consultations) trigger an immediate iOS crash without usage strings.
**Fix:** Add `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription` (SEC-C3).

### BUG-3 — `setState` after dispose in live-stream ad callbacks
**File:** `live_stream_player.dart:449` (`_skipAd`)
**Description:** `_skipAd` calls `setState` with **no `mounted` check** and is reachable from YT/HTML5 ad-ended microtasks (`419`, `432`) that can fire after the widget is disposed → "setState() called after dispose()" exception / leak.
**Fix:**
```dart
void _skipAd() {
  if (!mounted) return;
  setState(() { ... });
}
```
Also remove the ad-controller listeners before disposing.

### BUG-4 — Web video controller null-assert in `_skipAd`
**File:** `live_stream_player.dart:461`
**Description:** `_videoController!.setVolume(...)` on the `kIsWeb` branch asserts non-null without checking, unlike the sibling VLC branch which checks `_vlcController != null`. If the web controller was nulled on error, this throws.
**Fix:** `if (kIsWeb && _videoController != null) _videoController!.setVolume(...);`

---

## 🟠 High

### BUG-5 — `context` used after `await` without `mounted` (OTP verify)
**File:** `otp_screen.dart:113-135` (`_handleVerify`)
**Description:** After multiple `await`s the method calls `_showSnackBar(context...)` and `Navigator.of(context)` with no `mounted` guard. Leaving the screen mid-request crashes.
**Fix:** `if (!mounted) return;` after each await before touching `context`.

### BUG-6 — Wallet fetch error path uses `context` without `mounted`
**File:** `wallet_screen.dart:33, 39-42`
**Description:** The loading `setState` (33) and the catch-block `ScaffoldMessenger.of(context)` (39-42) run after an `await` with no `mounted` check. A failed wallet load after navigation crashes.
**Fix:** Guard `setState` and the SnackBar with `if (mounted)`.

### BUG-7 — Global socket disconnect tears down other screens
**File:** `temple_details_screen.dart:81` → `SocketService().disconnect()`
**Description:** `dispose()` disconnects the **shared singleton** socket, killing live chat for any other still-mounted consumer. Produces intermittent "chat froze" reports.
**Fix:** Only cancel this screen's own subscription; reference-count or scope the socket (FR-H4).

### BUG-8 — Unguarded `as`/parse on order timestamps breaks the whole list
**File:** `my_orders_screen.dart:38-39 (sort), 268 (_formatDate arg)`
**Description:** `DateTime.parse(a['createdAt'] as String)` in the sort comparator and `as String` at line 268 throw if `createdAt` is null/missing. One malformed record breaks the entire orders screen (exception during `setState`/build).
**Fix:** Null-safe parse with fallback; sort with a safe key:
```dart
DateTime _ts(dynamic v) => DateTime.tryParse(v?.toString() ?? '') ?? DateTime(0);
list.sort((a,b) => _ts(b['createdAt']).compareTo(_ts(a['createdAt'])));
```

### BUG-9 — No request timeouts → infinite spinners on flaky networks
**File:** `api_client.dart` (`_sendRequest` 141-154) and all `http` calls
**Description:** No `.timeout()` anywhere. A stalled connection leaves loading states spinning forever with no error/retry — common on mobile networks.
**Fix:** Add `.timeout(const Duration(seconds: 20))` and map `TimeoutException` to a user-facing retry (DEP-4).

### BUG-10 — Payment marked successful without verification when verifier omitted
**File:** `universal_payment_modal.dart:143-148`
**Description:** If a future caller omits `verifyRazorpayPayment`, payment is treated as successful on the client SDK callback alone (spoofable). Unsafe default.
**Fix:** Make the verifier required or fail closed (SEC-H5).

---

## 🟡 Medium

### BUG-11 — `.isNotEmpty` on `dynamic` (pandit images)
**File:** `pandit_card.dart:248, 256, 455, 463`
**Description:** `expert['image'].isNotEmpty` only null-checks, not type-checks. A non-string truthy value throws `NoSuchMethodError`.
**Fix:** `(expert['image'] as String?)?.isNotEmpty == true`.

### BUG-12 — Unguarded cast on socket history payload
**File:** `live_chat_tab.dart:90` → `data['messages'] as List`
**Description:** A malformed `chat_history` event (missing/non-list `messages`) throws inside the listener.
**Fix:** `final list = (data['messages'] as List?) ?? const [];`

### BUG-13 — Unguarded casts on chat message map
**File:** `consultation_chat_screen.dart:879-882`
**Description:** `msg['text'] as String` / `msg['time'] as DateTime` will throw if any future code adds a message missing those keys. Currently safe but brittle.
**Fix:** Use a typed message model instead of `Map<String,dynamic>`.

### BUG-14 — Transaction timestamp parse in list builder
**File:** `wallet_screen.dart:232` → `DateTime.parse(tx['createdAt'])`
**Description:** Unguarded parse inside `itemBuilder`; a malformed timestamp throws during scroll.
**Fix:** `DateTime.tryParse(...) ?? <fallback>`.

### BUG-15 — Model casts throw on schema drift
**File:** `booking.dart:30-38`
**Description:** `id`/string fields use `as String` on possibly non-string JSON. Throws `TypeError` instead of degrading.
**Fix:** `json['id']?.toString() ?? ''`.

### BUG-16 — Double-navigation after delayed success dialog
**File:** `temple_details_screen.dart:1807-1816`
**Description:** A 2s-delayed `popUntil(isFirst)` + `push(MyOrdersScreen)` relies on `popUntil` removing the still-open success dialog; if the user navigated during the delay, double navigation/duplicate screens can occur. (`booking_sheet.dart:154-166` and `order_summary_screen.dart:177-191` do this more safely with repeated `mounted` checks — use them as the pattern.)
**Fix:** Pop the dialog explicitly and re-check `mounted` before each navigation step.

### BUG-17 — Viewer-count race overwrites socket value
**File:** `temple_details_screen.dart:65-74 vs 129-134`
**Description:** Socket viewer-count updates can arrive before `_loadData` finishes; the `if (_viewerCount == 0)` guard can clobber a legitimate `0` from the socket with the API value.
**Fix:** Track "API loaded" separately from the value; prefer the socket as source of truth once connected.

---

## 🟢 Low

### BUG-18 — Verbose raw exception shown to users
**File:** `universal_payment_modal.dart:153` — surfaces `e.toString()`; sanitize messages.

### BUG-19 — In-flight socket callback may touch `context` post-dispose
**File:** `consultation_chat_screen.dart:518-521, 1014` — listeners are removed in dispose, but a callback already past its `mounted` check could still run; keep guards tight.

### BUG-20 — Deep-link navigation by `path.contains()` substring
**File:** `app.dart:66-92` — fragile matching (`contains('ai')` matches many paths) can route to the wrong tab. Use exact path segments.

### BUG-21 — `register()` fallback silently re-logs in
**File:** `auth_service.dart:216` — if the register response shape differs, it calls `login(email, password)`; a transient mismatch produces confusing double auth attempts. Log/branch explicitly.

---

## Suggested fix order
1. BUG-1, BUG-2 (broken for 100% of users / iOS crash).
2. BUG-3, BUG-4, BUG-5, BUG-6 (`mounted`/null crashes).
3. BUG-9 (timeouts) + BUG-7 (socket teardown).
4. BUG-8, BUG-11–BUG-15 (defensive JSON parsing).
5. Remaining Medium/Low.
