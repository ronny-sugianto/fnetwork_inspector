## 0.4.0

**Response mocking**

- Define in-memory [`FMockRule`]s that short-circuit matching requests with a synthetic response — custom status code, content-type, body, and optional latency. Works for both the Dio and `http` interceptors.
  - Match by HTTP method (or ANY) + path pattern (`*` glob or plain substring; query string ignored).
  - Body can be plain text (JSON / HTML / XML / …) or a base64 string served as raw bytes — enough to mock images, PDFs, and other binary payloads without a file dependency.
  - Mocked non-2xx responses are surfaced realistically (Dio throws `DioException` when `validateStatus` rejects the code; `http` returns the status).
  - New **Mocks** screen in the inspector UI (bolt icon in the app bar): list, add, edit, enable/disable per rule, and a master on/off switch.
  - **Mock this response** action on the request detail screen — prefills a rule from a captured response. When a request already has a matching rule, the detail screen shows a **MOCK** section to toggle it active/off, edit, or delete the rule inline.
  - Mocked entries are tagged with a `MOCK` badge in the list and detail views.
  - Seed rules at startup via `FNetworkInspector.initialize(mockRules: [...])`, or manage them at runtime via `FNetworkInspector.mocks`.
  - Only consulted when `enableInspection` is true, so it's a complete no-op in release builds.
- **Mock scenarios** — snapshot the current rule set under a name and switch the whole mock configuration in one tap ("logged out", "empty list", "server 500"). Managed from the Mocks screen (⋮ → *Scenarios*): apply, rename, delete, share a scenario as JSON. An active scenario shows in a banner with a *Detach* button.
- **Mock import/export** — ⋮ → *Export (JSON)* / *Import (JSON)* on the Mocks screen serialises rules + scenarios + flags. `FMockStore.exportJson()` / `importJson()` in code.
- **Mock persistence** — pass `FNetworkInspector.initialize(mockPersistence: ...)` with an `FMockPersistence` delegate (back it with `shared_preferences`, a file, etc.; the package ships none) and rules + scenarios survive app restarts. Seed with `mockScenarios:` too.

**Chaos mode**

- Global fault injection: add latency to every request and fail a random fraction of them with a configurable status/body. Reachable from the inspector ⋮ menu; an amber banner shows while it's active and affected entries get a `CHAOS` badge. Configure in code via `FNetworkInspector.chaos`. Mock rules always win over chaos; both are no-ops in release builds.
- **Network profile presets** — simulate 2G, Edge, 3G, 4G or 5G (or full **Offline**) instead of only tuning a flat millisecond delay. Each preset sets round-trip latency plus throttled download/upload bandwidth (kbps); extra delay is estimated from actual payload size, so a big JSON response visibly takes longer on "3G" than "4G". Download/upload speed also have their own sliders for manual tuning, and editing any of latency/download/upload after picking a preset marks it "Custom". Offline fails every request with a connection error, bypassing the failure-rate setting. New: `FNetworkProfile`, `FChaosStore.applyProfile()/downloadKbps/uploadKbps/isOffline`.
- The inspector's floating button shows an **`M` / `C` marker** when a mock scenario is active and/or chaos mode is on.

**HAR export**

- The inspector's overflow menu (⋮) can share the whole session — or just the current filtered view — as a standard `.har` file, importable into Chrome DevTools, Charles, Proxyman, Postman, etc. "Copy session (.har)" puts the JSON on the clipboard. In-flight requests are omitted; mocked/errored entries carry `_mocked` / `_error` flags. Exposed programmatically as `FNetworkHar.export(logs)`.

**JSON body viewer**

- A collapsible, syntax-highlighted tree replaces raw text on the request/response Body tabs:
  - **Tree / Raw** toggle (Raw shows pretty-printed JSON).
  - **Filter** by key or value, matches highlighted with ancestors kept in view.
  - **Expand all / Collapse all**.
  - Tap a value to copy it; long-press any node for **Copy value / Copy path (`$.a.b[0]`) / Copy subtree**.
  - Non-JSON bodies fall back to plain selectable text; very large trees cap at 2000 rows with a hint to use Raw.
  - The tree/raw area is capped in height and scrolls internally, so large payloads are always fully reachable instead of overflowing the card.

**Other**

- Small tappable **credit line** (`rons.my.id`) in a footer strip on every inspector screen. It's also attached to content *only when it leaves the app* — copied/shared cURL and full report, exported HAR (`creator.comment`) and mock/scenario JSON (`_credit`) — never shown in the on-screen previews.
- Fixed: `NetworkLogListScreen` and `NetworkLogDetailScreen` didn't refresh while open — an in-flight request stayed on "Requesting…" until the screen was closed and reopened. Both screens now listen to `FNetworkStore` and update live as requests complete.

## 0.3.1

- `FNetworkInspectorOverlay`'s floating button is now draggable — drag it anywhere on screen instead of it being pinned to the bottom-right corner.

## 0.3.0

- Fixed: `FNetworkDioInterceptor` duplicated the base URL's path segment in the displayed/exported URL (URL, cURL, share report) when `BaseOptions.baseUrl` itself contained a path (e.g. `https://host/doctor/backend-api/doctor`). `baseUrl` is now always derived as `scheme://host[:port]` from the resolved request URI, matching `FNetworkHttpInterceptor`'s behavior.
- Path filter chips now skip trailing dynamic segments (numeric ids, uuids, hashes, codes like `Y002129`) and fall back to the nearest static segment, so chips represent endpoints (e.g. `profiles`, `doctors`) instead of request-specific ids.

## 0.2.0+1

- Fixed README images not displaying on pub.dev (switched to absolute GitHub raw URLs).

## 0.2.0

**Platform support: Android, iOS, Web.**

- Added `FNetworkHttpInterceptor` — an `http.BaseClient` interceptor for `package:http` users (`FNetworkHttpInterceptor(inner: http.Client())`).
- Renamed `FNetworkInterceptor` → `FNetworkDioInterceptor` for consistency.
- Added `onApiError` callback to `FNetworkInspector.initialize()` — called on every failed request with the completed `NetworkLog` (useful for Sentry, Crashlytics, etc.).
- Added `FNetworkInspectorOverlay` — a floating button at the bottom-right corner showing the live API call count; tapping it slides in a side panel with the full inspector. Designed as the web equivalent of `enableNotifications`.
- Added filter bottom sheet (tap the `tune` icon in the app bar) replacing inline method chips.
- Added path filter by last path segment — query params are excluded automatically.
- Method and path filters now support multiple selection.
- Fixed: tapping a request notification now pushes the list screen before the detail screen, so the back button returns to the list instead of closing the inspector.
- Web compatibility: notification service uses a no-op stub on web via conditional import.
- iOS notifications now show as banners (no sound) instead of silent delivery.

## 0.1.0

- Initial release.
- Dio interceptor to capture all HTTP requests.
- In-app inspector UI with search by path, query params, body, and status code.
- Filter by HTTP method and status (loading / success / error).
- "matched in body" badge on list tiles when search hits request/response body.
- cURL export, full-report copy & share.
- Optional Android notification overlay (opt-in via `enableNotifications`).
