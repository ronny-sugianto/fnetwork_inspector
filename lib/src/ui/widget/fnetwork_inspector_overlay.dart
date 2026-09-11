import 'package:fnetwork_inspector/src/core/fchaos_store.dart';
import 'package:fnetwork_inspector/src/core/fmock_store.dart';
import 'package:fnetwork_inspector/src/core/fnetwork_store.dart';
import 'package:fnetwork_inspector/src/ui/screen/network_log_list_screen.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that renders a small floating button in the bottom-right
/// corner showing the total API call count.
///
/// Tapping the button opens the network inspector in a side panel that slides
/// in from the right. Navigation within the panel (list → detail → back) is
/// fully self-contained.
///
/// Designed as the web equivalent of `enableNotifications` on mobile.
/// Place it inside `MaterialApp` via the `builder` parameter so it has access
/// to Material widgets and the correct `MediaQuery` across all screens:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FNetworkInspectorOverlay(
///     enabled: kDebugMode,
///     child: child!,
///   ),
///   home: const HomeScreen(),
/// )
/// ```
class FNetworkInspectorOverlay extends StatefulWidget {
  const FNetworkInspectorOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// When false the overlay is completely invisible — no FAB, no panel.
  /// Use this to disable it in production: `enabled: kDebugMode`.
  final bool enabled;

  @override
  State<FNetworkInspectorOverlay> createState() =>
      _FNetworkInspectorOverlayState();
}

class _FNetworkInspectorOverlayState extends State<FNetworkInspectorOverlay>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  static const double _fabSize = 52;
  static const double _fabMargin = 16;

  /// Top-left position of the FAB. Null until the first build, when it's
  /// initialized to the bottom-right corner.
  Offset? _fabOffset;

  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textMuted = Color(0xFF8B949E);
  static const Color _green = Color(0xFF3FB950);
  static const Color _red = Color(0xFFF85149);
  static const Color _orange = Color(0xFFD29922);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPanel() {
    setState(() => _open = true);
    _controller.forward();
  }

  void _close() {
    _controller.reverse().whenComplete(() => setState(() => _open = false));
  }

  void _toggle() => _open ? _close() : _openPanel();

  double _clampD(double value, double min, double max) =>
      value < min ? min : (value > max ? max : value);

  void _onFabPanUpdate(DragUpdateDetails details, Size size) {
    final Offset current = _fabOffset ??
        Offset(
          size.width - _fabSize - _fabMargin,
          size.height - _fabSize - _fabMargin,
        );
    setState(() {
      _fabOffset = Offset(
        _clampD(current.dx + details.delta.dx, 0, size.width - _fabSize),
        _clampD(current.dy + details.delta.dy, 0, size.height - _fabSize),
      );
    });
  }

  Color _statusColor(FNetworkStore store) {
    if (store.errorCount > 0) return _red;
    if (store.loadingCount > 0) return _orange;
    if (store.successCount > 0) return _green;
    return _border;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final Offset offset = _fabOffset ??
            Offset(
              size.width - _fabSize - _fabMargin,
              size.height - _fabSize - _fabMargin,
            );
        // Re-clamp on every build so a resized/rotated screen never leaves
        // the FAB stranded off-screen.
        final Offset fabPosition = Offset(
          _clampD(offset.dx, 0, size.width - _fabSize),
          _clampD(offset.dy, 0, size.height - _fabSize),
        );

        return Stack(
          children: <Widget>[
            widget.child,

            // Scrim — tap outside to close
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: const ColoredBox(color: Color(0x80000000)),
                ),
              ),

            // Side panel
            if (_open)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slide,
                  child: _InspectorPanel(onClose: _close),
                ),
              ),

            // Floating action button — draggable anywhere on screen
            Positioned(
              left: fabPosition.dx,
              top: fabPosition.dy,
              child: ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  FNetworkStore.instance,
                  FMockStore.instance,
                  FChaosStore.instance,
                ]),
                builder: (BuildContext context, Widget? child) => _Fab(
                  store: FNetworkStore.instance,
                  statusColor: _statusColor(FNetworkStore.instance),
                  textPrimary: _textPrimary,
                  textMuted: _textMuted,
                  surface: _surface,
                  mockActive: FMockStore.instance.activeCount > 0,
                  chaosActive: FChaosStore.instance.enabled,
                  onTap: _toggle,
                  onPanUpdate: (DragUpdateDetails details) =>
                      _onFabPanUpdate(details, size),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({
    required this.store,
    required this.statusColor,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.mockActive,
    required this.chaosActive,
    required this.onTap,
    required this.onPanUpdate,
  });

  final FNetworkStore store;
  final Color statusColor;
  final Color textPrimary;
  final Color textMuted;
  final Color surface;
  final bool mockActive;
  final bool chaosActive;
  final VoidCallback onTap;
  final ValueChanged<DragUpdateDetails> onPanUpdate;

  static const Color _mock = Color(0xFFD29922);
  static const Color _chaos = Color(0xFFF85149);

  @override
  Widget build(BuildContext context) {
    final int total = store.logs.length;
    final Color? modeColor =
        chaosActive ? _chaos : (mockActive ? _mock : null);
    final Color ringColor = modeColor ?? statusColor;

    return GestureDetector(
      onTap: onTap,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor,
            width: modeColor != null ? 2 : 1.5,
          ),
          boxShadow: <BoxShadow>[
            const BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
            if (modeColor != null)
              BoxShadow(
                color: modeColor.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 1.5,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              Icons.network_check,
              color: total == 0 ? textMuted : textPrimary,
              size: 20,
            ),
            if (total > 0)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: surface, width: 1.5),
                  ),
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (mockActive || chaosActive)
              Positioned(
                left: 0,
                right: 0,
                bottom: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (mockActive) _modeChip(Icons.bolt, _mock),
                    if (mockActive && chaosActive) const SizedBox(width: 2),
                    if (chaosActive)
                      _modeChip(Icons.local_fire_department, _chaos),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(IconData icon, Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: surface, width: 1.5),
      ),
      child: Icon(icon, size: 9, color: Colors.white),
    );
  }
}

// ---------------------------------------------------------------------------

class _InspectorPanel extends StatefulWidget {
  const _InspectorPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<_InspectorPanel> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double panelWidth = screenWidth > 640 ? 440.0 : screenWidth;

    return SizedBox(
      width: panelWidth,
      child: ClipRect(
        child: HeroControllerScope.none(
          child: ScaffoldMessenger(
            child: Navigator(
              key: _navKey,
              onGenerateRoute: (RouteSettings settings) {
                return MaterialPageRoute<void>(
                  builder: (_) => _PanelRoot(onClose: widget.onClose),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// The list screen wrapped with a PopScope so that pressing "back" when the
// list is the root of the panel navigator closes the panel instead of doing
// nothing.
class _PanelRoot extends StatelessWidget {
  const _PanelRoot({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) onClose();
      },
      child: NetworkLogListScreen(
        onOverlayClose: onClose,
      ),
    );
  }
}
