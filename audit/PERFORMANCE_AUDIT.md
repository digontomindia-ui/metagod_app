# Performance Audit

**Score: 57/100.** Strong fundamentals (disposal hygiene is good, no network/heavy work in `build()`), undermined by zero image caching, broken hardcoded image hosts, and Provider rebuild storms in list screens.

---

## 🔴 Critical

### PERF-1 — Hardcoded LAN dev IP for images breaks every production user
**Files:**
- `home_screen.dart:314` (user avatar)
- `live_chat_tab.dart:198-199` (chat avatars)
- `consultation_chat_screen.dart:1056` (chat avatar)

```dart
'http://192.168.29.158:4000${user.avatar!}'
```
Every relative avatar resolves to a private LAN address that does not exist for real users → infinite broken-image loads, error rebuilds, wasted network attempts. **Also a security item** (forces cleartext).
**Fix:** Derive from a single configured host:
```dart
String mediaUrl(String path) =>
  path.startsWith('http') ? path : '${ApiClient.mediaBaseUrl}$path';
```

### PERF-2 — No image caching anywhere (`cached_network_image` not in pubspec)
Every `Image.network` / `NetworkImage` re-downloads on each rebuild, scroll recycle, and screen re-entry. At 100k users this is large repeated egress + UI jank + memory churn. Affected (representative): `temple_details_screen.dart:691,1304,1524,1873`, `home_screen.dart:540,812`, `divine_marketplace_screen.dart:469`, `pandit_card.dart:250,457`, `hero_banner.dart:202`, `bookings_screen.dart:229`, `my_orders_screen.dart:294`, `order_summary_screen.dart:399`, `booking_sheet.dart:239`, `live_chat_tab.dart:221`.
**Fix:** Add `cached_network_image: ^3.4.1`; replace usages:
```dart
CachedNetworkImage(
  imageUrl: mediaUrl(url),
  fadeInDuration: Duration.zero,
  memCacheWidth: 600, // downscale to display size
  placeholder: (c, _) => const ColoredBox(color: AppColors.card),
  errorWidget: (c, _, __) => const Icon(Icons.broken_image),
);
```

---

## 🟠 High

### PERF-3 — Provider rebuild storms in the marketplace grid
**File:** `divine_marketplace_screen.dart:133, 418, 433`
Top-level `context.watch<CartService>()` plus a per-card `context.watch<CartService>()` inside `_buildProductCard`. Every `+`/`–` tap rebuilds the **entire grid and every card**.
**Fix:** Use `Selector`/`context.select` for the cart badge, and pass quantity into each card instead of watching globally:
```dart
final qty = context.select<CartService,int>((c) => c.quantityOf(product.id));
```

### PERF-4 — Unbounded, un-debounced client-side search filter
**File:** `divine_marketplace_screen.dart:33, 85-108`
`_searchController.addListener` → `_applyFilter` runs `List.from` + two `.where().toList()` passes on **every keystroke**, inside `setState`. Fine for 20 items, costly as the catalog grows.
**Fix:** Debounce 250–300ms; filter off the main list once per settle.

### PERF-5 — Missing `errorBuilder` on most network images
Failed images throw a visible red error widget mid-list and force a rebuild. Missing on `temple_details_screen.dart:691,1304,1524,1873`, `home_screen.dart:540,812`, `divine_marketplace_screen.dart:469`, `booking_sheet.dart:239`, `bookings_screen.dart:229`. (Good examples already exist at `my_orders_screen.dart:294`, `vr_thumbnail_player.dart:70` — copy that pattern, or get it for free via `CachedNetworkImage`.)

---

## 🟡 Medium

### PERF-6 — No pagination on any list endpoint
`temple_service.dart` fetches full collections (`/orders/my`, products, temples, experts). At scale these payloads grow unbounded → slow first paint, high memory, OOM risk on low-end devices.
**Fix:** Server cursor/offset pagination + `ListView.builder` infinite scroll. Load 20 per page.

### PERF-7 — `shrinkWrap: true` + `NeverScrollableScrollPhysics` lists inside scroll views
**Files:** `wallet_screen.dart:186`, `temple_details_screen.dart:1278`
Builds all children eagerly (no virtualization). Acceptable for small fixed lists; will jank if transaction/puja counts grow.
**Fix:** Use a single `CustomScrollView` + slivers so the outer scroll virtualizes children.

### PERF-8 — Whole-screen `context.watch` at the top of large `build()` methods
`order_summary_screen.dart:224`, `home_screen.dart:206,271,282`, `universal_payment_modal.dart:164`. A single cart/auth change rebuilds the whole scaffold subtree.
**Fix:** Push `watch`/`Selector` down to the smallest widget that needs the value.

### PERF-9 — Live stream + WebRTC resource pressure
`live_stream_player.dart` (VLC/video + ad controllers) and `consultation_chat_screen.dart` (WebRTC renderers). These are heavy; ensure only one is alive at a time and that leaving the screen fully tears down renderers (mostly handled — see MEM findings in BUG_REPORT).

---

## 🟢 Low / Startup

### PERF-10 — Impeller disabled on Android
`AndroidManifest.xml:53-55` sets `EnableImpeller=false`, falling back to Skia. Often done to dodce a plugin issue, but Impeller reduces shader-compilation jank. Re-test with Impeller enabled before launch.

### PERF-11 — No `const` on many static subtrees
Large `build()` methods (e.g. `pandit_card.dart` profile sheet 208-361) rebuild identical decoration/Text trees. Add `const` where children are static to cut rebuild cost.

### PERF-12 — Synchronous SharedPreferences/secure-storage reads on hot paths
`api_client.dart` reads the token from secure storage on **every** request. Cache the in-memory token after first read and invalidate on refresh/logout to avoid repeated platform-channel round-trips per call.

---

## Quick Wins (highest ROI first)
1. Remove the 3 hardcoded `192.168.29.158` URLs (PERF-1).
2. Add `cached_network_image` and swap all remote images (PERF-2/5).
3. `Selector`-ize the cart in the marketplace grid (PERF-3).
4. Debounce search (PERF-4).
5. In-memory token cache in `ApiClient` (PERF-12).
