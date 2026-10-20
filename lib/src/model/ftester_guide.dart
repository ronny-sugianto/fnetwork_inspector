import 'package:flutter/foundation.dart';

/// One numbered step in the tester guide dialog.
@immutable
class FTesterGuideStep {
  const FTesterGuideStep(this.title, [this.description]) : emphasize = false;

  /// A step that must stand out (e.g. about sensitive data): highlighted in red.
  const FTesterGuideStep.warning(this.title, [this.description])
    : emphasize = true;

  final String title;
  final String? description;
  final bool emphasize;
}

/// Content of the instructions dialog shown to testers (QA / product /
/// pentesters) when the inspector is enabled.
///
/// Every string can be replaced, so localising it is up to the host app:
/// build an [FTesterGuide] from your own translations and pass it to
/// `FNetworkInspector.initialize(testerGuide: ...)`. Defaults are English.
@immutable
class FTesterGuide {
  const FTesterGuide({
    this.version = 1,
    this.label,
    this.title = "You're in a testing environment",
    this.intro =
        'Thanks for helping us test! These quick steps help developers find '
            'and fix issues faster: follow the intended flow, reproduce the '
            'issue, verify the expected behavior, and check the relevant API '
            'response. The more evidence you attach, the faster we can '
            'investigate.',
    this.note =
        'Reports that lack clear reproduction steps or sufficient evidence '
            'may be returned for further investigation.',
    this.steps = defaultSteps,
    this.dontShowAgainLabel = "Don't show this again",
    this.confirmLabel = 'Got it',
    this.openInspectorLabel = 'Open inspector',
  });

  /// Bump this when you change the content: testers who chose "don't show
  /// again" for an older version will see the dialog once more.
  final int version;

  /// Short name of the audience this guide is for (e.g. "QA", "Pentest"). When
  /// several guides are configured the dialog shows a switcher using these.
  final String? label;

  final String title;
  final String intro;

  /// Optional extra remark shown as a highlighted note under [intro]. Empty
  /// hides it.
  final String note;
  final List<FTesterGuideStep> steps;
  final String dontShowAgainLabel;
  final String confirmLabel;
  final String openInspectorLabel;

  /// Functional testing guide (QA / product), labelled for the audience
  /// switcher. Same content as `FTesterGuide()`.
  static const FTesterGuide qa = FTesterGuide(label: 'QA / Product');

  /// Security-testing guide for pentesters: scope, test data, evidence and
  /// responsible reporting — instead of "follow the intended flow".
  static const FTesterGuide pentest = FTesterGuide(
    label: 'Pentest',
    title: "You're in a testing environment",
    intro:
        'Thanks for testing the security of this app! These quick steps keep '
        'the test safe and make each finding easy to verify and fix.',
    note:
        'Stay within the agreed scope, and report findings only through the '
        'agreed channel.',
    steps: pentestSteps,
  );

  static const List<FTesterGuideStep> pentestSteps = <FTesterGuideStep>[
    FTesterGuideStep(
      'Confirm scope and authorization',
      "Test only the environment, accounts and features you've been "
          'authorized to test. If something is out of scope or you are '
          'unsure, ask before continuing.',
    ),
    FTesterGuideStep(
      'Use test accounts and data',
      "Prefer dedicated test accounts and data. Don't access, change or keep "
          "real users' data, and avoid destructive actions (deleting records, "
          'bulk requests) unless explicitly agreed.',
    ),
    FTesterGuideStep(
      'Record what you do',
      'Keep track of the steps, inputs and requests you send (screen '
          'recording, Network Inspector log) so every finding can be '
          'reproduced.',
    ),
    FTesterGuideStep(
      'Reproduce each finding',
      'Confirm the issue at least once more. Note how reliably it occurs and '
          'under which conditions: role, state and environment.',
    ),
    FTesterGuideStep.warning(
      'Handle evidence with care',
      'Request and response logs (report, cURL, HAR) can contain real tokens '
          'and personal data. Share them only through the agreed secure '
          'channel and mask anything that is not needed to show the issue.',
    ),
    FTesterGuideStep(
      'Describe the impact',
      'Explain what you observed versus what is expected, what an attacker '
          'could do and under which conditions. Report what you verified; '
          "don't overstate.",
    ),
    FTesterGuideStep(
      'Report responsibly',
      "Don't exploit an issue beyond what is needed to demonstrate it, and "
          "don't share it anywhere except the agreed channel.",
    ),
  ];

  static const List<FTesterGuideStep> defaultSteps = <FTesterGuideStep>[
    FTesterGuideStep(
      'Follow the intended flow',
      'Run the test scenario from start to finish, without skipping steps or '
          'opening screens out of order. First confirm the prerequisites: '
          'account permissions, required data, initial status and previous '
          'actions.',
    ),
    FTesterGuideStep(
      'Record your screen',
      'Start recording before the first step and capture the whole flow, '
          'including what leads to the issue and what happens after.',
    ),
    FTesterGuideStep(
      'Reproduce the issue',
      'Retry the same flow at least once. Note the exact steps, how often it '
          "happens and under what conditions. Say clearly if it's "
          "intermittent or can't be reproduced.",
    ),
    FTesterGuideStep(
      'Verify expected vs actual results',
      'Compare what happens with the expected behavior of the test scenario: '
          'navigation, loading states, error messages, displayed data and the '
          "result after submitting or refreshing. Don't assume unexpected "
          "behavior is a bug until you've confirmed what is expected.",
    ),
    FTesterGuideStep(
      'Verify the data source',
      'If data is missing, empty or wrong, compare the relevant API response '
          'in the Network Inspector with what the app shows (and the database, '
          'if you have access). Note whether the data is missing at the '
          'source or the app fails to process or display it.',
    ),
    FTesterGuideStep(
      'Inspect API calls and errors',
      'Check the related request: URL, method, status code, parameters, '
          'response body and error details, plus application logs if '
          "available. A 200 status or an empty response alone doesn't prove "
          'the API is right or wrong; record what you observe.',
    ),
    FTesterGuideStep(
      'Check related behavior',
      'When relevant, check related screens, user states and adjacent flows. '
          'Note the scope, impact and conditions, without testing unrelated '
          'areas.',
    ),
    FTesterGuideStep.warning(
      'Attach evidence and protect sensitive data',
      'Attach screen recordings or screenshots and technical evidence such '
          'as the Network Inspector report, cURL command, HAR session or '
          'application logs. These can contain real tokens, cookies and '
          'personal data: mask them before sharing.',
    ),
    FTesterGuideStep(
      'Write an actionable report and retest fixes',
      'Include the affected feature, exact reproduction steps, expected and '
          'actual result, frequency, impact, build version, device, OS and '
          'environment, plus your findings and evidence. Avoid "there is a '
          'bug", "it does not work" or "the data is empty". After a fix, '
          'repeat the original scenario to confirm it is resolved.',
    ),
  ];
}
