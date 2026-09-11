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
- **Mock scenarios** — bundle rules into named sets ("logged out", "empty list", "server 500") and switch them in one tap; import/export as JSON; optional persistence across restarts via an `FMockPersistence` delegate
- **Chaos mode** — simulate a connection type (2G, Edge, 3G, 4G, 5G, Offline) with realistic latency + throttled bandwidth, or tune latency/bandwidth/failure-rate manually; exercise loading / error / retry paths via `FNetworkInspector.chaos` in code or the inspector UI
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

You can also open the **Mocks** screen (bolt icon in the inspector app bar) to add/edit/toggle rules, or hit **Mock this response** on any captured request to turn it into a rule. When a request already matches a rule, its detail screen shows a **MOCK** section to toggle, edit, or delete that rule without leaving the screen. Binary bodies: set `isBase64: true` and put a base64 string in `body`.

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NetworkMockListScreen()),
);
```

**Scenarios.** On the Mocks screen, ⋮ → *Save as scenario…* snapshots the current rules under a name. ⋮ → *Scenarios* lists them — tap to apply (swaps the whole rule set), or rename / delete / share as JSON. ⋮ → *Export (JSON)* / *Import (JSON)* moves rules + scenarios between devices or into version control. Seed at startup with `initialize(mockScenarios: [...])`.

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

### 7. (Optional) Wire up notification deep-links

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
| `mockRules` | `List<FMockRule>?` | `null` | Seed the in-memory mock registry. Ignored when `enableInspection` is `false` or when `mockPersistence` restored a non-empty set. Add/remove more later via `FNetworkInspector.mocks`. |
| `mockScenarios` | `List<FMockScenario>?` | `null` | Seed named scenarios. Same rules as `mockRules`. |
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
