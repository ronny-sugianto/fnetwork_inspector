import 'dart:async';

import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/model/network_log.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FNetworkNotificationService {
  FNetworkNotificationService._();

  static final FNetworkNotificationService instance =
      FNetworkNotificationService._();

  static const String _channelId = 'fnetwork_inspector_channel';
  static const String _channelName = 'Network Inspector';
  static const int _summaryNotifId = 9000;
  static const int _latestRequestNotifId = 9001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Timer? _autoDismissTimer;
  String? _latestRequestId;

  String? _pendingRequestId;
  void Function()? _listCallback;
  void Function(String requestId)? _detailCallback;

  Future<void> initialize() async {
    if (_initialized) return;

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
          ),
        );

    _initialized = true;
  }

  void handleTap(String payload) {
    _onNotificationTap(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: payload,
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    if (payload == 'summary') {
      _listCallback?.call();
    } else {
      _pendingRequestId = payload;
      _detailCallback?.call(payload);
    }
  }

  void setNavigationCallback({
    required void Function() onSummaryTap,
    required void Function(String requestId) onRequestTap,
  }) {
    _listCallback = onSummaryTap;
    _detailCallback = onRequestTap;
    if (_pendingRequestId != null) {
      onRequestTap(_pendingRequestId!);
      _pendingRequestId = null;
    }
  }

  Future<void> showSummary() async {
    final FNetworkStore store = FNetworkStore.instance;
    final String body =
        'Loading: ${store.loadingCount} | Success: ${store.successCount} | Error: ${store.errorCount}'
        '\nLast: ${store.latestEndpoint}';

    await _plugin.show(
      _summaryNotifId,
      'Network Inspector',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentSound: false,
        ),
      ),
      payload: 'summary',
    );
  }

  Future<void> showRequestLoading(NetworkLog log) async {
    _autoDismissTimer?.cancel();
    _latestRequestId = log.id;

    await _plugin.show(
      _latestRequestNotifId,
      log.shortLabel,
      'Requesting...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showProgress: true,
          indeterminate: true,
          maxProgress: 0,
          progress: 0,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentSound: false,
        ),
      ),
      payload: log.id,
    );
  }

  Future<void> showRequestSuccess(NetworkLog log) async {
    if (_latestRequestId != log.id) return;
    _autoDismissTimer?.cancel();

    await _plugin.show(
      _latestRequestNotifId,
      log.shortLabel,
      log.statusLabel,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.low,
          priority: Priority.low,
          autoCancel: true,
          playSound: false,
          enableVibration: false,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentSound: false,
        ),
      ),
      payload: log.id,
    );

    _autoDismissTimer = Timer(
      const Duration(seconds: 5),
      () => _plugin.cancel(_latestRequestNotifId),
    );
  }

  Future<void> showRequestError(NetworkLog log) async {
    if (_latestRequestId != log.id) return;
    _autoDismissTimer?.cancel();

    await _plugin.show(
      _latestRequestNotifId,
      log.shortLabel,
      log.statusLabel,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          color: Color(0xFFE53935),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentSound: false,
        ),
      ),
      payload: log.id,
    );
  }

  Future<void> cancelAll() async {
    _autoDismissTimer?.cancel();
    await _plugin.cancel(_summaryNotifId);
    await _plugin.cancel(_latestRequestNotifId);
  }
}
