import 'package:fnetwork_inspector/src/core/ftester_guide_store.dart';
import 'package:fnetwork_inspector/src/model/ftester_guide.dart';
import 'package:flutter/material.dart';

const Color _surface = Color(0xFF161B22);
const Color _border = Color(0xFF30363D);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _blue = Color(0xFF58A6FF);

/// The "before you report a bug" card. Used inline by
/// `FNetworkInspectorOverlay` (no Navigator needed) and wrapped in a dialog by
/// [showTesterGuideDialog].
class TesterGuideCard extends StatefulWidget {
  const TesterGuideCard({
    super.key,
    required this.guide,
    required this.onClose,
    this.onOpenInspector,
  });

  final FTesterGuide guide;

  /// Called after the tester dismisses the guide.
  final VoidCallback onClose;

  /// When non-null an "Open inspector" button is shown; it runs this after
  /// dismissing the guide.
  final VoidCallback? onOpenInspector;

  @override
  State<TesterGuideCard> createState() => _TesterGuideCardState();
}

class _TesterGuideCardState extends State<TesterGuideCard> {
  bool _dontShowAgain = false;

  void _finish({bool openInspector = false}) {
    if (_dontShowAgain) FTesterGuideStore.instance.setShowAtStartup(false);
    widget.onClose();
    if (openInspector) widget.onOpenInspector?.call();
  }

  @override
  Widget build(BuildContext context) {
    final FTesterGuide g = widget.guide;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x80000000), blurRadius: 24),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.bug_report_outlined, color: _blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  g.title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (g.intro.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              g.intro,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < g.steps.length; i++)
                    _step(i + 1, g.steps[i]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: _dontShowAgain,
                    activeColor: _blue,
                    side: const BorderSide(color: _textMuted),
                    onChanged: (bool? v) =>
                        setState(() => _dontShowAgain = v ?? false),
                  ),
                ),
                Expanded(
                  child: Text(
                    g.dontShowAgainLabel,
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Wrap (not Row) so long translated labels flow onto a second line.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (widget.onOpenInspector != null)
                OutlinedButton(
                  onPressed: () => _finish(openInspector: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _border),
                  ),
                  child: Text(g.openInspectorLabel),
                ),
              FilledButton(
                onPressed: _finish,
                style: FilledButton.styleFrom(backgroundColor: _blue),
                child: Text(
                  g.confirmLabel,
                  style: const TextStyle(color: Color(0xFF0D1117)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(int n, FTesterGuideStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: _blue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (step.description != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    step.description!,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the tester guide in a regular dialog. Uses the guide configured via
/// `FNetworkInspector.initialize(testerGuide: ...)` unless [guide] is given,
/// falling back to the English defaults.
Future<void> showTesterGuideDialog(
  BuildContext context, {
  FTesterGuide? guide,
  VoidCallback? onOpenInspector,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: TesterGuideCard(
          guide: guide ?? FTesterGuideStore.instance.guide ?? const FTesterGuide(),
          onClose: () => Navigator.of(ctx).pop(),
          onOpenInspector: onOpenInspector,
        ),
      ),
    ),
  );
}
