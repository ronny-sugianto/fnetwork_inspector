import 'package:fnetwork_inspector/src/core/ftester_guide_store.dart';
import 'package:fnetwork_inspector/src/model/ftester_guide.dart';
import 'package:flutter/material.dart';

const Color _surface = Color(0xFF161B22);
const Color _border = Color(0xFF30363D);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textMuted = Color(0xFF8B949E);
const Color _blue = Color(0xFF58A6FF);
const Color _orange = Color(0xFFD29922);
const Color _red = Color(0xFFF85149);

/// The "before you report a bug" card. Used inline by
/// `FNetworkInspectorOverlay` (no Navigator needed) and wrapped in a dialog by
/// [showTesterGuideDialog].
class TesterGuideCard extends StatefulWidget {
  const TesterGuideCard({
    super.key,
    required this.guides,
    required this.onClose,
    this.initialIndex = 0,
    this.onOpenInspector,
  });

  /// One guide per audience. With more than one, a switcher is shown and the
  /// choice is remembered via [FTesterGuideStore.select].
  final List<FTesterGuide> guides;
  final int initialIndex;

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
  late int _index = widget.initialIndex.clamp(0, widget.guides.length - 1);

  void _select(int i) {
    setState(() => _index = i);
    FTesterGuideStore.instance.select(i);
  }

  void _finish({bool openInspector = false}) {
    if (_dontShowAgain) FTesterGuideStore.instance.setShowAtStartup(false);
    widget.onClose();
    if (openInspector) widget.onOpenInspector?.call();
  }

  @override
  Widget build(BuildContext context) {
    final FTesterGuide g = widget.guides[_index];
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
          if (widget.guides.length > 1) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int i = 0; i < widget.guides.length; i++)
                  _audienceChip(i, widget.guides[i]),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Intro, note and steps share one scroll area so small screens keep
          // as much room as possible for the steps; title and buttons stay put.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (g.intro.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        g.intro,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (g.note.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        g.note,
                        style: const TextStyle(
                          color: _orange,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
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
                    onChanged:
                        (bool? v) =>
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
          // Full width so `alignment: end` actually right-aligns the buttons.
          SizedBox(
            width: double.infinity,
            child: Wrap(
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
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(int i, FTesterGuide guide) {
    final bool active = i == _index;
    return GestureDetector(
      onTap: () => _select(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _blue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? _blue : _border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          guide.label ?? 'Guide ${i + 1}',
          style: TextStyle(
            color: active ? _blue : _textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _step(int n, FTesterGuideStep step) {
    final Color accent = step.emphasize ? _red : _blue;
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child:
              step.emphasize
                  ? Icon(Icons.warning_amber_rounded, size: 13, color: accent)
                  : Text(
                    '$n',
                    style: TextStyle(
                      color: accent,
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
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child:
          step.emphasize
              ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withValues(alpha: 0.45)),
                ),
                child: content,
              )
              : content,
    );
  }
}

/// Shows the tester guide in a regular dialog. Uses the guide(s) configured via
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
    builder:
        (BuildContext ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: TesterGuideCard(
              guides: guide != null ? <FTesterGuide>[guide] : _storeGuides(),
              initialIndex:
                  guide != null ? 0 : FTesterGuideStore.instance.selectedIndex,
              onClose: () => Navigator.of(ctx).pop(),
              onOpenInspector: onOpenInspector,
            ),
          ),
        ),
  );
}

/// Guides to show: the configured ones, or the English defaults.
List<FTesterGuide> _storeGuides() {
  final List<FTesterGuide> guides = FTesterGuideStore.instance.guides;
  return guides.isEmpty ? const <FTesterGuide>[FTesterGuide()] : guides;
}
