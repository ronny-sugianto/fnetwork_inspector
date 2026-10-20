## 0.4.0

**Tester guide**

- Optional instructions dialog for testers (QA / product), shown once per app start while the inspector is enabled. It opens with a friendly "You're in a testing environment" heading and a friendly intro explaining that the steps help developers find and fix issues faster (plus a highlighted note that reports lacking steps or evidence may be returned) introduces nine steps: follow the intended flow and its prerequisites, record the screen, reproduce the issue, verify expected vs actual results, **verify the data source against the API response / database**, inspect API calls and errors, check related behavior, attach evidence while masking sensitive data, and write an actionable report and retest fixes. It asks testers to collect evidence and document findings, not to determine the root cause, and notes that a 200 status or an empty response alone proves nothing. Enable with `FNetworkInspector.initialize(testerGuide: const FTesterGuide())`; requires `FNetworkInspectorOverlay` (or call `FNetworkInspector.showTesterGuide(context)` yourself).
- Steps that must stand out can be marked with `FTesterGuideStep.warning(...)` and render highlighted in red. The default guide uses it for the sensitive-data step, because the inspector (and its cURL / HAR exports) shows real tokens, cookies and personal data.
- Fully customisable and localisable by the host app: title, intro, note, steps (title + description), and button/checkbox labels are all plain parameters of `FTesterGuide`; defaults are English. Bump `FTesterGuide.version` when you change the content and testers who chose "don't show again" will see it once more.
- The inspector's ⋮ menu gets **Tester guide** (reopen it any time) and a **Show guide at startup** switch. The choice survives restarts if you pass an `FInspectorStorage` delegate (`inspectorStorage:`); without one it simply shows once per launch. Never active when `enableInspection` is false.

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
  - The tree shows closing `}` / `]` rows like the raw JSON (previously it ended at the last leaf and looked cut off); empty objects/arrays render inline as `{}` / `[]`.
  - Small/medium bodies render inline and scroll with the page. Only genuinely large ones (40+ tree rows, or 4000+ raw characters) get their own height-capped area with an always-visible scrollbar, so it never competes with the page scroll.

**Other**

- Small tappable **credit line** (`rons.my.id`) in a footer strip on every inspector screen. It's also attached to content *only when it leaves the app* — copied/shared cURL and full report, exported HAR (`creator.comment`) and mock/scenario JSON (`_credit`) — never shown in the on-screen previews.
- Fixed: with a burst of requests, a detail page you had open could suddenly turn blank / "Request not found" — the log was evicted from the 200-entry history. The page now keeps showing the last captured data with an "Evicted from history" notice. The history size is configurable via `FNetworkInspector.initialize(maxLogs: ...)` (default 200).
- Improved performance under heavy traffic: the detail page rebuilds only when its own log changes (not on every request in the app), and the store caches its log snapshot and status counts instead of recomputing them several times per build.
- Fixed: the Body card header showed a second copy icon on top of the viewer's own — removed. Non-JSON bodies get a copy button inside the viewer instead.
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
