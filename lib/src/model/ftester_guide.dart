import 'package:flutter/foundation.dart';

/// One numbered step in the tester guide dialog.
@immutable
class FTesterGuideStep {
  const FTesterGuideStep(this.title, [this.description]);

  final String title;
  final String? description;
}

/// Content of the "before you report a bug" dialog shown to testers (QA /
/// product) when the inspector is enabled.
///
/// Every string can be replaced, so localising it is up to the host app:
/// build an [FTesterGuide] from your own translations and pass it to
/// `FNetworkInspector.initialize(testerGuide: ...)`. Defaults are English.
@immutable
class FTesterGuide {
  const FTesterGuide({
    this.version = 1,
    this.title = 'Before you report a bug',
    this.intro =
        'Help the developers fix it faster. Please go through this before '
        'opening a ticket.',
    this.steps = defaultSteps,
    this.dontShowAgainLabel = "Don't show this again",
    this.confirmLabel = 'Got it',
    this.openInspectorLabel = 'Open inspector',
  });

  /// Bump this when you change the content: testers who chose "don't show
  /// again" for an older version will see the dialog once more.
  final int version;

  final String title;
  final String intro;
  final List<FTesterGuideStep> steps;
  final String dontShowAgainLabel;
  final String confirmLabel;
  final String openInspectorLabel;

  static const List<FTesterGuideStep> defaultSteps = <FTesterGuideStep>[
    FTesterGuideStep(
      'Record your screen',
      'Start recording before the first step so the whole flow is captured.',
    ),
    FTesterGuideStep(
      'Reproduce it',
      "Try again at least once. If you can't reproduce it, say so in the "
          'report.',
    ),
    FTesterGuideStep(
      'Check the data first',
      'If something on screen looks wrong or missing, compare it with the API '
          'response in the Network Inspector (and the database, if you have '
          'access). The problem may be in the data, not in the app.',
    ),
    FTesterGuideStep(
      'Inspect the API calls',
      'Open the Network Inspector and look at the related requests: status '
          'code, response body and any error.',
    ),
    FTesterGuideStep(
      'Attach the evidence',
      'Share the request log (full report, cURL or the .har session) together '
          'with your screen recording or screenshots.',
    ),
    FTesterGuideStep(
      'Describe it clearly',
      'Include the steps, expected vs actual result, build version, device '
          'and environment. Avoid reports like "there is a bug".',
    ),
  ];
}
