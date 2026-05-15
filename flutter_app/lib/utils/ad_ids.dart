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

  static bool get isUsingTestIds =>
      interstitial.startsWith('ca-app-pub-3940256099942544');
}
