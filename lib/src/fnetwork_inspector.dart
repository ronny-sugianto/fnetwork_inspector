import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/src/core/fchaos_store.dart';
import 'package:fnetwork_inspector/src/core/fmock_persistence.dart';
import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_interceptor.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_notification_service.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/fmock_rule.dart';
import 'package:fnetwork_inspector/src/model/fmock_scenario.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_detail_screen.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_list_screen.dart';
import 'package:flutter/material.dart';

/// Single entry point for fnetwork_inspector.
///
/// Call [initialize] once during app startup, then attach the interceptor
/// to your HTTP client.
///
/// ```dart
/// await FNetworkInspector.initialize(
///   enableInspection: !kReleaseMode,
///   enableNotifications: true,
/// );
/// // Dio:
/// dio.interceptors.add(FNetworkInspector.dioInterceptor);
/// // http:
/// final client = FNetworkHttpInterceptor(inner: http.Client());
/// ```
class FNetworkInspector {
  FNetworkInspector._();

  static FNetworkDioInterceptor? _interceptor;

  /// Whether [initialize] has been called.
  static bool get isInitialized => _interceptor != null;

  /// The configured Dio interceptor. Throws if [initialize] has not been called.
  static Interceptor get dioInterceptor {
    assert(_interceptor != null, 'Call FNetworkInspector.initialize() first.');
    return _interceptor!;
  }

  /// In-memory mock rule registry. Add/remove [FMockRule]s here (or from the
  /// Mocks screen in the inspector UI) to short-circuit matching requests with
  /// a synthetic response. Only consulted when [initialize] was called with
  /// `enableInspection: true`.
  static FMockStore get mocks => FMockStore.instance;

  /// Global fault-injection settings (added latency + random failures).
  /// Only takes effect when [initialize] was called with
  /// `enableInspection: true`.
  ///
  /// ```dart
  /// FNetworkInspector.chaos
  ///   ..enabled = true
  ///   ..latencyMs = 500
  ///   ..failRate = 0.2;
  /// ```
  static FChaosStore get chaos => FChaosStore.instance;

  /// Initializes the inspector.
  ///
  /// - [enableInspection]: when false, the interceptor is a no-op (e.g. in production).
  /// - [enableNotifications]: show a persistent Android status-bar notification
  ///   while requests are in flight. Ignored when [enableInspection] is false.
  ///   Has no effect on iOS or web.
  /// - [onApiError]: optional callback invoked on every failed request (4xx, 5xx,
  ///   or network error). Receives the completed [NetworkLog] with full context —
  ///   useful for forwarding errors to Sentry, Crashlytics, etc.
  ///
  /// - [mockRules]: optional list of [FMockRule]s to seed the mock registry
  ///   with. Ignored when [enableInspection] is false, or when [mockPersistence]
  ///   restored a non-empty set. More can be added at runtime via [mocks] or the
  ///   Mocks screen in the inspector UI.
  /// - [mockScenarios]: optional named [FMockScenario]s to seed. Same rules as
  ///   [mockRules].
  /// - [mockPersistence]: optional storage delegate so mock rules and scenarios
  ///   survive app restarts. The package ships no implementation — see
  ///   [FMockPersistence].
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  static Future<void> initialize({
    bool enableInspection = true,
    bool enableNotifications = false,
    FNetworkErrorCallback? onApiError,
    List<FMockRule>? mockRules,
    List<FMockScenario>? mockScenarios,
    FMockPersistence? mockPersistence,
  }) async {
    if (_interceptor != null) return;

    final bool notif = enableInspection && enableNotifications;

    if (notif) {
      await FNetworkNotificationService.instance.initialize();
    }

    FNetworkStore.instance.onApiError = onApiError;

    if (enableInspection) {
      if (mockPersistence != null) {
        await FMockStore.instance.attachPersistence(mockPersistence);
      }
      if (FMockStore.instance.rules.isEmpty &&
          mockRules != null &&
          mockRules.isNotEmpty) {
        FMockStore.instance.addAll(mockRules);
      }
      if (FMockStore.instance.scenarios.isEmpty &&
          mockScenarios != null &&
          mockScenarios.isNotEmpty) {
        FMockStore.instance.addScenarios(mockScenarios);
      }
    }

    _interceptor = FNetworkDioInterceptor(
      enableInspection: enableInspection,
      enableNotifications: notif,
    );
  }

  /// Sets the navigator key so the inspector can handle notification taps
  /// and open the correct screen automatically.
  ///
  /// Call this once from your root widget's [State.initState]:
  /// ```dart
  /// FNetworkInspector.setNavigatorKey(_navigatorKey);
  /// ```
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    FNetworkNotificationService.instance.setNavigationCallback(
      onSummaryTap: () => key.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const NetworkLogListScreen()),
      ),
      onRequestTap: (String requestId) {
        key.currentState?.push(
          MaterialPageRoute<void>(builder: (_) => const NetworkLogListScreen()),
        );
        key.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => NetworkLogDetailScreen(requestId: requestId),
          ),
        );
      },
    );
  }

  /// Cancels all active notifications and resets the inspector state.
  /// Useful when the user logs out or the session ends.
  static Future<void> dispose() async {
    await FNetworkNotificationService.instance.cancelAll();
    FMockStore.instance.reset();
    FChaosStore.instance.reset();
    _interceptor = null;
  }
}
