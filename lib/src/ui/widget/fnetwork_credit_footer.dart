import 'package:fnetwork_inspector/src/core/fnetwork_meta.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thin, unobtrusive credit strip. Tap to copy [kFNetworkInspectorUrl].
class FNetworkCreditFooter extends StatelessWidget {
  const FNetworkCreditFooter({super.key});

  static const Color _surface = Color(0xFF161B22);
  static const Color _border = Color(0xFF30363D);
  static const Color _textMuted = Color(0xFF8B949E);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Material(
        color: _surface,
        child: InkWell(
          onTap: () {
            Clipboard.setData(
              const ClipboardData(text: kFNetworkInspectorUrl),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('rons.my.id copied'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text(
              'fnetwork_inspector · rons.my.id',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textMuted,
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
