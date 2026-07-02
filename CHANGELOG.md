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
