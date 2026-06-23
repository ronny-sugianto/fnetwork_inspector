import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_interceptor.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_notification_service.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_detail_screen.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_list_screen.dart';
import 'package:flutter/material.dart';

/// Single entry point for fnetwork_inspector.
///
/// Call [initialize] once during app startup, then attach [interceptor]
/// to your Dio instance.
///
/// ```dart
/// await FNetworkInspector.initialize(
///   enableInspection: !kReleaseMode,
///   enableNotifications: true,
/// );
/// dio.interceptors.add(FNetworkInspector.interceptor);
/// ```
class FNetworkInspector {
  FNetworkInspector._();

  static FNetworkInterceptor? _interceptor;

  /// Whether [initialize] has been called.
  static bool get isInitialized => _interceptor != null;

  /// The configured Dio interceptor. Throws if [initialize] has not been called.
  static Interceptor get interceptor {
    assert(_interceptor != null, 'Call FNetworkInspector.initialize() first.');
    return _interceptor!;
  }

  /// Initializes the inspector.
  ///
  /// - [enableInspection]: when false, the interceptor is a no-op (e.g. in production).
  /// - [enableNotifications]: show a persistent Android status-bar notification
  ///   while requests are in flight. Ignored when [enableInspection] is false.
  ///   Has no effect on iOS or web.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  static Future<void> initialize({
    bool enableInspection = true,
    bool enableNotifications = false,
  }) async {
    if (_interceptor != null) return;

    final bool notif = enableInspection && enableNotifications;

    if (notif) {
      await FNetworkNotificationService.instance.initialize();
    }

    _interceptor = FNetworkInterceptor(
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
      onRequestTap: (String requestId) => key.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => NetworkLogDetailScreen(requestId: requestId),
        ),
      ),
    );
  }

  /// Cancels all active notifications and resets the inspector state.
  /// Useful when the user logs out or the session ends.
  static Future<void> dispose() async {
    await FNetworkNotificationService.instance.cancelAll();
    _interceptor = null;
  }
}
