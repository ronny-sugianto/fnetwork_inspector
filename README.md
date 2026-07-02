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
- Search by **path, query params, request body, response body, status code**
- Filter by **status** (Loading / Success / Error) via summary bar
- Filter by **HTTP method** and **path endpoint** via filter sheet — both support **multiple selection**
- `~ req body` / `~ res body` badge when search matches payload
- **cURL export**, full-report copy & share
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

### 5. (Optional) Wire up notification deep-links

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
