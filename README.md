# fnetwork_inspector

A Flutter network inspector for [Dio](https://pub.dev/packages/dio). Capture, search, and share HTTP requests from inside your app — no external proxy needed.

## Features

- In-app inspector UI (dark theme, GitHub-style)
- Search by **path, query params, request body, response body, status code**
- Filter by **HTTP method** (GET / POST / PUT / DELETE …)
- Filter by **status** (loading / success / error)
- `~ req body` / `~ res body` badge when search matches payload
- **cURL export**, full-report copy & share
- Optional **Android notification overlay** (shows live request status in the status bar)

## Setup

### 1. Initialize in `main()`

```dart
import 'package:fnetwork_inspector/fnetwork_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FNetworkInspector.initialize(
    enableInspection: kDebugMode,     // false in production = complete no-op
    enableNotifications: true,        // optional Android status-bar overlay
  );

  runApp(const MyApp());
}
```

### 2. Attach to Dio

```dart
final dio = Dio();
dio.interceptors.add(FNetworkInspector.interceptor);
```

### 3. Open the inspector

Navigate to `NetworkLogListScreen` from anywhere — a shake gesture, a hidden button, a debug menu, etc.:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const NetworkLogListScreen()),
);
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `enableInspection` | `bool` | `true` | Master switch. When `false`, the interceptor is a complete no-op — no logging, no notifications. |
| `enableNotifications` | `bool` | `false` | Show a live Android status-bar notification during requests. Automatically ignored when `enableInspection` is `false`. Has no effect on iOS or web. |

## Notes

- `FNetworkInspector.initialize()` is idempotent — safe to call multiple times.
- Call `FNetworkInspector.dispose()` on logout or session end to cancel all notifications and reset state.
- `flutter_local_notifications` does nothing unless `enableInspection: true` and `enableNotifications: true`.
