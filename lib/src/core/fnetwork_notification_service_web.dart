import 'package:fnetwork_inspector/src/model/network_log.dart';

class FNetworkNotificationService {
  FNetworkNotificationService._();

  static final FNetworkNotificationService instance =
      FNetworkNotificationService._();

  String? _pendingRequestId;
  void Function()? _listCallback;
  void Function(String requestId)? _detailCallback;

  Future<void> initialize() async {}

  void handleTap(String payload) {
    if (payload.isEmpty) return;
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

  Future<void> showSummary() async {}
  Future<void> showRequestLoading(NetworkLog log) async {}
  Future<void> showRequestSuccess(NetworkLog log) async {}
  Future<void> showRequestError(NetworkLog log) async {}
  Future<void> cancelAll() async {}
}
