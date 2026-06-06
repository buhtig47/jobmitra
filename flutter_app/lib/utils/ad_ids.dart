// lib/utils/ad_ids.dart
//
// Centralised AdMob unit IDs. Defaults are Google's official test IDs.
// Production: inject real IDs at build time via --dart-define:
//   flutter build apk --release \
//     --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXX/YYYY \
//     --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/ZZZZ
//
// Also update AndroidManifest.xml `com.google.android.gms.ads.APPLICATION_ID`
// with the real AdMob app ID before release.

class AdIds {
  static const String interstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  static const String banner = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  // App Open Ad — highest eCPM format (~3-5x banner). Shows on cold launch and
  // app resume from background. Create a new ad unit in AdMob console
  // (format: App open) then inject via --dart-define=ADMOB_APP_OPEN_ID=...
  static const String appOpen = String.fromEnvironment(
    'ADMOB_APP_OPEN_ID',
    defaultValue: 'ca-app-pub-3940256099942544/9257395921',
  );

  static bool get isUsingTestIds =>
      interstitial.startsWith('ca-app-pub-3940256099942544');
}
