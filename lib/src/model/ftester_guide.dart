import 'dart:ui' show Locale;

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

/// Fully resolved dialog text for one locale; see [FTesterGuide.resolve].
typedef FTesterGuideText =
    ({
      String title,
      String intro,
      String note,
      List<FTesterGuideStep> steps,
      String dontShowAgainLabel,
      String confirmLabel,
      String openInspectorLabel,
    });

/// Content of the instructions dialog shown to testers (QA / product) when
/// the inspector is enabled.
///
/// Out of the box the text is built in — English, or Indonesian when the app's
/// locale is `id` — so `const FTesterGuide()` just works. Every field is an
/// optional override: pass your own (e.g. from your app's translations) to
/// replace that piece for every locale.
@immutable
class FTesterGuide {
  const FTesterGuide({
    this.version = 1,
    this.title,
    this.intro,
    this.note,
    this.steps,
    this.dontShowAgainLabel,
    this.confirmLabel,
    this.openInspectorLabel,
  });

  /// Bump this when you change the content: testers who chose "don't show
  /// again" for an older version will see the dialog once more.
  final int version;

  final String? title;
  final String? intro;

  /// Optional extra remark shown as a highlighted note under [intro]. Pass an
  /// empty string to hide it.
  final String? note;
  final List<FTesterGuideStep>? steps;
  final String? dontShowAgainLabel;
  final String? confirmLabel;
  final String? openInspectorLabel;

  /// The text to show for [locale]: your overrides, falling back to the
  /// built-in Indonesian (`id`) or English text.
  FTesterGuideText resolve(Locale locale) {
    final FTesterGuideText d = _isIndonesian(locale) ? _id : _en;
    return (
      title: title ?? d.title,
      intro: intro ?? d.intro,
      note: note ?? d.note,
      steps: steps ?? d.steps,
      dontShowAgainLabel: dontShowAgainLabel ?? d.dontShowAgainLabel,
      confirmLabel: confirmLabel ?? d.confirmLabel,
      openInspectorLabel: openInspectorLabel ?? d.openInspectorLabel,
    );
  }

  static bool _isIndonesian(Locale l) =>
      l.languageCode == 'id' || l.languageCode == 'in';

  static const FTesterGuideText _en = (
    title: "You're in a testing environment",
    intro:
        'Thanks for helping us test! These quick steps help developers find '
        'and fix issues faster: follow the intended flow, reproduce the '
        'issue, verify the expected behavior, and check the relevant API '
        'response. The more evidence you attach, the faster we can '
        'investigate.',
    note:
        'Reports that lack clear reproduction steps or sufficient evidence '
        'may be returned for further investigation.',
    steps: defaultSteps,
    dontShowAgainLabel: "Don't show this again",
    confirmLabel: 'Got it',
    openInspectorLabel: 'Open inspector',
  );

  static const FTesterGuideText _id = (
    title: 'Anda sedang berada di lingkungan testing',
    intro:
        'Terima kasih sudah membantu testing! Langkah singkat ini membantu '
        'developer menemukan dan memperbaiki masalah lebih cepat: ikuti alur '
        'yang seharusnya, reproduksi masalahnya, pastikan perilaku yang '
        'diharapkan, dan periksa response API yang terkait. Semakin lengkap '
        'bukti yang dilampirkan, semakin cepat kami bisa menyelidikinya.',
    note:
        'Laporan tanpa langkah reproduksi yang jelas atau bukti yang cukup '
        'dapat dikembalikan untuk diselidiki lebih lanjut.',
    steps: defaultStepsId,
    dontShowAgainLabel: 'Jangan tampilkan lagi',
    confirmLabel: 'Mengerti',
    openInspectorLabel: 'Buka inspector',
  );

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

  /// Indonesian counterpart of [defaultSteps] (same steps, same order).
  static const List<FTesterGuideStep> defaultStepsId = <FTesterGuideStep>[
    FTesterGuideStep(
      'Ikuti alur yang seharusnya',
      'Jalankan skenario tes dari awal sampai akhir tanpa melewati langkah '
          'atau membuka layar di luar urutan. Pastikan dulu prasyaratnya '
          'terpenuhi: izin akun, data yang dibutuhkan, status awal, dan aksi '
          'sebelumnya.',
    ),
    FTesterGuideStep(
      'Rekam layar Anda',
      'Mulai merekam sebelum langkah pertama dan tangkap seluruh alur, '
          'termasuk hal yang mengarah ke masalah dan yang terjadi '
          'sesudahnya.',
    ),
    FTesterGuideStep(
      'Reproduksi masalahnya',
      'Ulangi alur yang sama minimal sekali. Catat langkah persisnya, '
          'seberapa sering terjadi, dan dalam kondisi apa. Sebutkan dengan '
          'jelas jika masalahnya muncul sesekali atau tidak bisa '
          'direproduksi.',
    ),
    FTesterGuideStep(
      'Bandingkan hasil yang diharapkan dengan hasil aktual',
      'Bandingkan yang terjadi dengan perilaku yang diharapkan pada skenario '
          'tes: navigasi, kondisi loading, pesan error, data yang tampil, dan '
          'hasil setelah submit atau refresh. Jangan menganggap perilaku '
          'tak terduga sebagai bug sebelum memastikan apa yang seharusnya '
          'terjadi.',
    ),
    FTesterGuideStep(
      'Pastikan sumber datanya',
      'Jika data kosong, hilang, atau salah, bandingkan response API terkait '
          'di Network Inspector dengan yang tampil di aplikasi (dan database, '
          'jika Anda punya akses). Catat apakah datanya memang tidak ada di '
          'sumber atau aplikasi gagal memproses atau menampilkannya.',
    ),
    FTesterGuideStep(
      'Periksa API call dan error',
      'Periksa request terkait: URL, method, status code, parameter, '
          'response body, dan detail error, serta log aplikasi jika ada. '
          'Status 200 atau response kosong saja belum membuktikan API benar '
          'atau salah; catat apa yang Anda amati.',
    ),
    FTesterGuideStep(
      'Periksa perilaku terkait',
      'Jika relevan, periksa layar, kondisi pengguna, dan alur lain yang '
          'berhubungan. Catat cakupan, dampak, dan kondisinya, tanpa menguji '
          'hal yang tidak berkaitan.',
    ),
    FTesterGuideStep.warning(
      'Lampirkan bukti dan lindungi data sensitif',
      'Lampirkan rekaman layar atau screenshot dan bukti teknis seperti '
          'laporan Network Inspector, perintah cURL, sesi HAR, atau log '
          'aplikasi. Semuanya bisa berisi token, cookie, dan data pribadi '
          'asli: samarkan sebelum dibagikan.',
    ),
    FTesterGuideStep(
      'Tulis laporan yang bisa ditindaklanjuti dan uji ulang perbaikan',
      'Sertakan fitur yang terdampak, langkah reproduksi yang persis, hasil '
          'yang diharapkan dan hasil aktual, frekuensi, dampak, versi build, '
          'perangkat, OS, dan environment, beserta temuan dan bukti Anda. '
          'Hindari laporan seperti "ada bug", "tidak berfungsi", atau "datanya '
          'kosong". Setelah perbaikan tersedia, ulangi skenario awal untuk '
          'memastikan masalahnya sudah teratasi.',
    ),
  ];
}
