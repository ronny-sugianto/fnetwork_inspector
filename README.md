# fnetwork_inspector

A Flutter network inspector for [Dio](https://pub.dev/packages/dio) and [http](https://pub.dev/packages/http). Capture, search, and filter HTTP requests from inside your app — no external proxy needed.

**Platforms: Android · iOS · Web**

## Screenshots

### Mobile (Android & IOS)

<table>
  <tr>
    <td align="center"><b>Log List</b></td>
    <td align="center"><b>Filter</b></td>
    <td align="center"><b>Log Detail</b></td>
  </tr>
  <tr>
    <td><img src="https://raw.githubusercontent.com/ronny-sugianto/fnetwork_inspector/main/doc/screenshots/01_log_list.png" width="250"/></td>
    <td><img src="https://raw.githubusercontent.com/ronny-sugianto/fnetwork_inspector/main/doc/screenshots/02_filter_sheet.png" width="250"/></td>
    <td><img src="https://raw.githubusercontent.com/ronny-sugianto/fnetwork_inspector/main/doc/screenshots/03_log_detail.png" width="250"/></td>
  </tr>
</table>

### Web

<table>
  <tr>
    <td align="center"><b>Overlay FAB</b></td>
    <td align="center"><b>Inspector Panel</b></td>
  </tr>
  <tr>
    <td><img src="https://raw.githubusercontent.com/ronny-sugianto/fnetwork_inspector/main/doc/screenshots/04_web_fab.png" width="360"/></td>
    <td><img src="https://raw.githubusercontent.com/ronny-sugianto/fnetwork_inspector/main/doc/screenshots/05_web_inspector.png" width="360"/></td>
  </tr>
</table>

## Features

- In-app inspector UI (dark theme, GitHub-style)
- **JSON body viewer** — collapsible syntax-highlighted tree with key/value filter, expand/collapse all, and copy value / path / subtree; falls back to raw text for non-JSON
- Search by **path, query params, request body, response body, status code**
- Filter by **status** (Loading / Success / Error) via summary bar
- Filter by **HTTP method** and **path endpoint** via filter sheet — both support **multiple selection**
- `~ req body` / `~ res body` badge when search matches payload
- **Response mocking** — short-circuit any request with a synthetic response (custom status, content-type, body, latency); body can be text (JSON / HTML / XML) or base64 bytes (images, PDFs). Manage rules from the **Mocks** screen or `initialize(mockRules: [...])`
- **Mock scenarios** — bundle rules into named sets ("logged out", "empty list", "server 500"), group them by feature/release, and switch them in one tap; export/import as `.fnmock.json` files (merge or replace) or load one at startup with `mockJson:`; optional persistence across restarts via an `FMockPersistence` delegate
- **Chaos mode** — simulate a connection type (2G, Edge, 3G, 4G, 5G, Offline) with realistic latency + throttled bandwidth, or tune latency/bandwidth/failure-rate manually; exercise loading / error / retry paths via `FNetworkInspector.chaos` in code or the inspector UI
- **Tester guide** — optional, localisable "before you report a bug" dialog for QA / product testers, shown at app start and reopenable from the inspector menu
- **cURL export**, full-report copy & share
- **HAR export** — share the whole session (or the filtered view) as a `.har` file for Chrome DevTools / Charles / Proxyman / Postman; also `FNetworkHar.export(logs)` in code
- **Web overlay** (`FNetworkInspectorOverlay`) — floating button at the bottom-right showing the live request count; tapping it opens a side panel with the full inspector
- Optional **push notifications** on Android (persistent status-bar) and iOS (banner); tapping navigates directly to the log detail

## Setup

### 1. Initialize in `main()`

```dart
import 'package:fnetwork_inspector/fnetwork_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FNetworkInspector.initialize(
    enableInspection: kDebugMode,     // false in production = complete no-op
    enableNotifications: true,        // optional Android status-bar overlay
    onApiError: (NetworkLog log) {    // optional — called on every 4xx/5xx/network error
      Sentry.captureException(
        log.errorMessage,
        hint: Hint.withMap({'url': '${log.baseUrl}${log.path}'}),
      );
    },
  );

  runApp(const MyApp());
}
```

### 2. Attach to your HTTP client

**Dio:**
```dart
final dio = Dio();
dio.interceptors.add(FNetworkInspector.dioInterceptor);
```

> `FNetworkInspector.dioInterceptor` returns a `FNetworkDioInterceptor` — the same class you can also instantiate directly if needed.

**package:http:**
```dart
final client = FNetworkHttpInterceptor(inner: http.Client());
```

### 3. Open the inspector

Navigate to `NetworkLogListScreen` from anywhere — a shake gesture, a hidden button, a debug menu, etc.:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NetworkLogListScreen()),
);
```

### 4. (Optional) Add the web overlay

Place `FNetworkInspectorOverlay` inside `MaterialApp` via the `builder` parameter so it has access to Material widgets across all screens:

```dart
MaterialApp(
  builder: (context, child) => FNetworkInspectorOverlay(
    enabled: kDebugMode,   // hide in production
    child: child!,
  ),
  home: const HomeScreen(),
)
```

The overlay renders a small circular button at the bottom-right corner of the screen. The border colour reflects the current request state (grey → no requests, green → all OK, orange → in-flight, red → any error). Tapping it opens a side panel with the full inspector. Tapping the scrim or the close (×) button in the panel header dismisses it.

### 5. (Optional) Mock responses

Register `FMockRule`s to serve synthetic responses for matching requests without hitting the network. Rules are held in memory and only consulted when `enableInspection` is `true`, so they can never affect a release build.

```dart
await FNetworkInspector.initialize(
  enableInspection: kDebugMode,
  mockRules: <FMockRule>[
    FMockRule.create(
      method: 'GET',                       // or null to match any method
      pathPattern: '/api/v1/users/*',      // '*' glob, or a plain substring
      statusCode: 200,
      contentType: 'application/json',
      body: '{"users": []}',
      delayMs: 400,                        // optional simulated latency
    ),
  ],
);

// …or at runtime:
FNetworkInspector.mocks.add(
  FMockRule.create(pathPattern: '/health', statusCode: 503, body: 'down'),
);
FNetworkInspector.mocks.enabled = false;  // master off switch
```

You can also open the **Mocks** screen (bolt icon in the inspector app bar) to add/edit/toggle the live rules, or hit **Mock this response** on any captured request to turn it into a rule. When a request already matches a rule, its detail screen shows a **MOCK** section to toggle, edit, or delete that rule without leaving the screen. Binary bodies: set `isBase64: true` and put a base64 string in `body`.

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NetworkMockListScreen()),
);
```

**Scenarios.** A scenario is a named set of rules you can switch to in one tap. They have their own screen — the layers icon in the inspector app bar (a blue dot shows while one is active), separate from the Mocks screen, which only shows the live rules.

- **+** creates a new scenario (name + optional group); tap a scenario to open it and **add, edit, enable/disable or delete its rules** directly, without touching the live rules. While a scenario is applied, edits you make inside it update the live rules too.
- The ▶ button on a row (or **Apply** inside the scenario) copies its rules into the live set; the banner shows which one is active, with **Detach**.
- A row's ⋮ has *Rename / group…*, *Duplicate*, *Export* and *Delete*. App bar ⋮ → *Save live rules as scenario…* snapshots whatever is live right now (saving under the same name + group overwrites it).
- Seed at startup with `initialize(mockScenarios: [...])` or `initialize(mockJson: ...)` (see below).

**Groups.** Organise scenarios under a header — e.g. one group per feature or release. Give a scenario a `group` (the *New scenario*, *Save live rules…* and *Rename / group…* dialogs have a *Group* field with quick-pick chips for existing groups; a group header's ⋯ → *New scenario in group* pre-fills it); the Scenarios screen then lists them under collapsible headers, with ungrouped ones under **Other scenarios**. Groups are only for organising: applying a scenario still replaces the rule set with that one scenario's rules.

```dart
mockScenarios: [
  FMockScenario(
    id: 'health-profile',            // a fixed id lets you applyScenario('health-profile')
    name: 'Health Profile',
    group: 'Health Plan Enhancement v2.0',
    rules: [FMockRule.create(pathPattern: '/profile', body: '{...}')],
  ),
  FMockScenario(id: 'met-u', name: 'Met-U', group: 'Health Plan Enhancement v2.0', rules: [...]),
  FMockScenario(id: 'logged-out', name: 'Logged out', rules: [...]),   // → "Other scenarios"
],
```

**Mock files (`.fnmock.json`).** Scenarios can be moved around as a dedicated file, so testers can share them over chat/email and you can keep them in version control.

- **Export** — Scenarios screen: a row's ⋮ → *Export (.fnmock.json)* (one scenario), a group header's ⋯ → *Export group* (one release/feature), or the app bar's ⋮ → *Export all scenarios*. ⋮ → *Export everything (+ live rules)* also includes the live rules and the on/off flags. The file is shared through the system share sheet (copied to the clipboard where sharing isn't available).
- **Import** — app bar ⋮ → *Import from file…* opens the system file picker (⋮ → *Import from text…* takes pasted JSON). A dialog first shows what the file contains, then you choose:
  - **Merge** *(recommended)* — adds what's new and updates items that already exist (same id, or same name in the same group). Everything else is left alone, so importing the same file twice never duplicates anything.
  - **Replace** — swaps the sections present in the file (scenarios and/or rules) for the file's. Sections the file doesn't contain are untouched.
- Invalid files are rejected with a readable reason and change nothing. Older exports and bare rule arrays still import.

The format keeps each group once and nests its scenarios, so you never repeat the group name:

```json
{
  "type": "fnetwork_inspector.mocks",
  "version": 1,
  "groups": [
    {
      "name": "Health Plan Enhancement v2.0",
      "scenarios": [
        { "id": "tab-badge-all", "name": "Tab Indicator badge: All", "rules": [ { "pathPattern": "/notifications/tab-badges", "method": "GET", "statusCode": 200, "body": "{...}" } ] },
        { "id": "tab-badge-500", "name": "Tab Indicator badge: Error 500", "rules": [ ... ] }
      ]
    }
  ],
  "scenarios": [ { "id": "logged-out", "name": "Logged out", "rules": [ ... ] } ]
}
```

`groups` holds the grouped scenarios and `scenarios` the ungrouped ones; both are optional, and a `rules` section (live rules) can sit alongside. A flat `scenarios` list where each entry has its own `"group"` is still accepted.

Load a file from your app at startup, so nobody has to import it on every run:

```dart
await FNetworkInspector.initialize(
  mockJson: await rootBundle.loadString('assets/mocks.fnmock.json'),
  activeMockScenario: 'health-profile',   // optional: apply this one at launch
);
```

`mockScenarios` and `mockJson` are **upserted on every launch** (matched by id, else name + group), so your code/asset stays the source of truth for the scenarios it defines, while scenarios testers created in the UI are left alone. Seeding happens once, when the app starts: a tester's edits to a seeded scenario are kept for as long as the app keeps running, and are reset to your version the next time it is launched from scratch (closed or killed, then reopened) — even if you use `mockPersistence`. Scenarios the tester created themselves survive. `activeMockScenario` is skipped when `mockPersistence` restored a previous session — the tester's last state wins. A bad `mockJson` is reported with `debugPrint` and ignored; it never crashes startup.

> **macOS:** the file picker needs `com.apple.security.files.user-selected.read-only` in your entitlements when the app is sandboxed.

**Persistence.** Rules and scenarios are in memory by default. Pass an `FMockPersistence` delegate to keep them across restarts (the package ships none — back it with `shared_preferences`, a file, Hive, …):

```dart
class PrefsMockStore implements FMockPersistence {
  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString('fnetwork_mocks');
  @override
  Future<void> save(String json) async =>
      (await SharedPreferences.getInstance()).setString('fnetwork_mocks', json);
}

await FNetworkInspector.initialize(
  enableInspection: kDebugMode,
  mockPersistence: PrefsMockStore(),
);
```

### 6. (Optional) Chaos mode

Exercise loading / error / retry paths by injecting global latency, throttled bandwidth, and a random failure rate. Open it from the inspector's ⋮ menu, or drive it from code:

```dart
FNetworkInspector.chaos
  ..enabled = true
  ..applyProfile(FNetworkProfile.threeG)  // sets latency + download/upload kbps together
  ..failRate = 0.2                        // ~20% forced failures
  ..failStatus = 503
  ..failBody = '{"error":"unavailable"}';

// or tune everything manually instead of a preset:
FNetworkInspector.chaos
  ..enabled = true
  ..latencyMs = 500     // round-trip delay added to every request
  ..downloadKbps = 750  // extra delay estimated from response size at this speed
  ..uploadKbps = 250;   // extra delay estimated from request body size
```

`FNetworkProfile` ships presets for `offline`, `twoG`, `edge`, `threeG`, `fourG` and `fiveG` — `applyProfile()` sets `latencyMs`/`downloadKbps`/`uploadKbps` together from the preset (see the table below for the numbers). Editing any of those three afterwards switches `FNetworkInspector.chaos.profile` back to `FNetworkProfile.none` ("Custom"). `FNetworkProfile.offline` fails every request with a connection error and ignores `failRate`.

Mock rules always take precedence over chaos. Affected entries carry a `CHAOS` badge, and an amber banner shows while it's on. Like mocking, it's only consulted when `enableInspection` is `true`.

### 7. (Optional) Tester guide

Show QA / product testers a short bug-reporting checklist ("You're in a testing environment") when the app opens — so tickets arrive with a screen recording, a reproduction, the API log and the evidence, instead of just "there is a bug". It appears once per app start while the inspector is enabled (never in builds where `enableInspection` is `false`) and needs `FNetworkInspectorOverlay` from step 4.

```dart
await FNetworkInspector.initialize(
  enableInspection: kDebugMode,
  testerGuide: const FTesterGuide(),          // built-in English + Indonesian text
  inspectorStorage: PrefsInspectorStorage(),  // optional: remember "don't show again"
);
```

The default dialog opens with a friendly heading ("You're in a testing environment") and a friendly intro explaining that these quick steps help developers fix issues faster (follow the intended flow, reproduce, verify the expected behavior, check the API response), plus a note that reports without clear steps or evidence may be returned. Then nine steps:

1. **Follow the intended flow** — and confirm the prerequisites (permissions, data, initial status, previous actions)
2. **Record your screen**
3. **Reproduce the issue** — at least once; say if it is intermittent or can't be reproduced
4. **Verify expected vs actual results** — don't assume a bug before confirming what is expected
5. **Verify the data source** — compare the API response in the Network Inspector (and the database, if available) with what the app shows
6. **Inspect API calls and errors** — a 200 or an empty response alone proves nothing; record what you observe
7. **Check related behavior** — only where relevant
8. **Attach evidence and protect sensitive data** — report / cURL / `.har` / logs, with tokens, cookies and personal data masked (highlighted in red, since the inspector shows real request data)
9. **Write an actionable report and retest fixes** — feature, steps, expected vs actual, frequency, impact, build, device, OS, environment

Testers are asked to collect evidence and document findings, not to determine the root cause.

**Languages.** The built-in text comes in **English and Indonesian**, picked automatically from your app's locale (`id` → Indonesian, anything else → English). Make sure `id` is in your `MaterialApp.supportedLocales`; Flutter resolves an unsupported locale to your first supported one, and the dialog follows that.

Every field of `FTesterGuide` is an optional override, so you can replace any piece (or add another language) from your own translations — fields you leave out keep following the locale:

```dart
FTesterGuide(
  version: 2,                       // bump when the content changes → shown once more
  title: l10n.guideTitle,           // all of these are optional
  intro: l10n.guideIntro,
  note: l10n.guideNote,             // highlighted remark under the intro ('' hides it)
  steps: <FTesterGuideStep>[
    FTesterGuideStep(l10n.stepRecord, l10n.stepRecordHint),
    // …
  ],
  confirmLabel: l10n.gotIt,
  dontShowAgainLabel: l10n.dontShowAgain,
  openInspectorLabel: l10n.openInspector,
)
```

Testers can reopen it any time, or switch the startup popup off, from the inspector's ⋮ menu (**Tester guide** / **Show guide at startup**). To remember that choice across restarts, pass an `FInspectorStorage` — the package ships none, so back it with `shared_preferences`, a file, etc.:

```dart
class PrefsInspectorStorage implements FInspectorStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}
```

No overlay? Call `FNetworkInspector.showTesterGuide(context)` from your own menu or start-up flow.

### 8. (Optional) Wire up notification deep-links

To make push-notification taps open the correct screen, pass your navigator key once during startup:

```dart
FNetworkInspector.setNavigatorKey(_navigatorKey);
```

Tapping a request notification will push the list screen and then the detail screen, so the back button returns to the list rather than closing the inspector entirely.

## Parameters

### `FNetworkInspector.initialize()`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `enableInspection` | `bool` | `true` | Master switch. When `false`, the interceptor is a complete no-op — no logging, no notifications. |
| `enableNotifications` | `bool` | `false` | Show a live notification during requests. On Android: persistent status-bar notification that updates in real time. On iOS: banner notification for each request (no sound). Automatically ignored when `enableInspection` is `false`. Has no effect on web. |
| `onApiError` | `void Function(NetworkLog)?` | `null` | Callback invoked on every failed request (4xx, 5xx, or network error). Receives the completed `NetworkLog` — use it to forward errors to Sentry, Crashlytics, etc. |
| `maxLogs` | `int` | `200` | How many requests are kept in memory; the oldest are evicted first. Raise it if you fire thousands of calls and need to browse further back (each log holds its bodies, so very large values cost memory). |
| `testerGuide` | `FTesterGuide?` | `null` | "You're in a testing environment" instructions dialog for testers, shown once per app start (needs `FNetworkInspectorOverlay`). All text is customisable/localisable. Ignored when `enableInspection` is `false`. |
| `inspectorStorage` | `FInspectorStorage?` | `null` | Storage delegate so the guide's "don't show again" choice survives restarts. The package ships no implementation. |
| `mockRules` | `List<FMockRule>?` | `null` | Seed the in-memory mock registry. Ignored when `enableInspection` is `false` or when `mockPersistence` restored a non-empty set. Add/remove more later via `FNetworkInspector.mocks`. |
| `mockScenarios` | `List<FMockScenario>?` | `null` | Named scenarios, **upserted on every launch** (by id, else name + group). Scenarios testers created in the UI are kept. |
| `mockJson` | `String?` | `null` | Text of a `.fnmock.json` file (e.g. from `rootBundle`), merged like `mockScenarios`. Invalid content is skipped with a `debugPrint`. |
| `activeMockScenario` | `String?` | `null` | Id of a scenario to apply at startup. Ignored when `mockPersistence` restored a session. |
| `mockPersistence` | `FMockPersistence?` | `null` | Storage delegate so mock rules + scenarios survive app restarts. The package ships no implementation. |

### `FMockRule.create()`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `pathPattern` | `String` | — | Matched against the request path (query string stripped). Contains `*` → anchored glob; otherwise a substring match. |
| `method` | `String?` | `null` | HTTP method to match (case-insensitive). `null` matches any method. |
| `statusCode` | `int` | `200` | Status code of the mocked response. Non-2xx behaves like a real error (Dio throws when `validateStatus` rejects it). |
| `contentType` | `String` | `application/json` | `Content-Type` header of the mocked response. |
| `body` | `String` | `''` | Response body. Plain text unless `isBase64` is set. |
| `isBase64` | `bool` | `false` | When `true`, `body` is a base64 string decoded to raw bytes — use for images, PDFs, and other binary payloads. |
| `delayMs` | `int` | `0` | Artificial latency before the mocked response resolves. |
| `enabled` | `bool` | `true` | Per-rule switch. There is also a global `FNetworkInspector.mocks.enabled`. |

### `FNetworkInspector.chaos` (`FChaosStore`)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `false` | Master switch for fault injection. |
| `latencyMs` | `int` | `0` | Round-trip delay added to every request while enabled. Setting it directly resets `profile` to `none`. |
| `downloadKbps` | `int` | `0` | Throttled download throughput. `0` = unthrottled. Extra delay is estimated from response body size. Setting it directly resets `profile` to `none`. |
| `uploadKbps` | `int` | `0` | Throttled upload throughput. `0` = unthrottled. Extra delay is estimated from request body size. Setting it directly resets `profile` to `none`. |
| `profile` | `FNetworkProfile` | `none` | Read-only marker of the last preset applied via `applyProfile()`; `none` means "Custom" (manual latency/bandwidth). |
| `applyProfile(FNetworkProfile)` | method | — | Sets `latencyMs` + `downloadKbps` + `uploadKbps` together from a preset. |
| `isOffline` | `bool` | — | `true` when `enabled` and `profile == FNetworkProfile.offline`. |
| `failRate` | `double` | `0` | Fraction of requests (0–1) forced to fail. Ignored while `isOffline` (everything fails). |
| `failStatus` | `int` | `500` | Status code for forced failures. |
| `failBody` | `String` | `{"error":"chaos"}` | Body returned for forced failures. |
| `failContentType` | `String` | `application/json` | `Content-Type` for forced failures. |

### `FNetworkProfile` presets

Approximate figures — real carriers vary widely. `latencyMs` is a one-off round-trip delay; `downloadKbps`/`uploadKbps` throttle throughput.

| Profile | Latency | Download | Upload |
|---|---|---|---|
| `offline` | — | fails every request | — |
| `twoG` | 800 ms | 50 kbps | 20 kbps |
| `edge` | 400 ms | 250 kbps | 200 kbps |
| `threeG` | 150 ms | 1 Mbps | 500 kbps |
| `fourG` | 40 ms | 6 Mbps | 3 Mbps |
| `fiveG` | 5 ms | 50 Mbps | 20 Mbps |

### `FNetworkInspectorOverlay`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | — | The widget to wrap (typically the `child` from `MaterialApp.builder`). |
| `enabled` | `bool` | `true` | When `false` the overlay is completely hidden. Use `enabled: kDebugMode` to disable it in production. |

## Notes

- `FNetworkInspector.initialize()` is idempotent — safe to call multiple times.
- Call `FNetworkInspector.dispose()` on logout or session end to cancel all notifications and reset state.
- `flutter_local_notifications` does nothing unless `enableInspection: true` and `enableNotifications: true`.
- `FNetworkInspectorOverlay` must be placed inside `MaterialApp` (e.g. via `builder`) — placing it above `MaterialApp` will cause errors.
- Mock rules, scenarios and chaos settings are never consulted when `enableInspection` is `false`, and are cleared by `FNetworkInspector.dispose()`. Without an `FMockPersistence` delegate they live in memory only.
