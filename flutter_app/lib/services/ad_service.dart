// lib/services/ad_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_ids.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  // Minimum gap between two interstitial impressions. Users open 5+ job details
  // per session; without this floor we'd show 5 fullscreen ads in 90s and lose
  // the install. Industry standard for content apps is 60-120s.
  static const _minIntervalMs = 90 * 1000;
  DateTime? _lastShownAt;

  static Future<void> initialize() async {
    // Safety net: if a release build somehow ships with Google's test ad IDs
    // we'd be serving non-monetizing test creatives forever. Assert in debug,
    // and log loudly in release so it shows up in Crashlytics breadcrumbs.
    if (AdIds.isUsingTestIds) {
      assert(() {
        debugPrint('AdService: using Google test ad IDs (debug build).');
        return true;
      }());
      if (kReleaseMode) {
        debugPrint(
          'AdService WARNING: release build is using TEST ad IDs. '
          'Re-build with --dart-define=ADMOB_INTERSTITIAL_ID=... and '
          '--dart-define=ADMOB_BANNER_ID=...',
        );
      }
    }
    // Targeting + safety hints for AdMob mediation:
    //  • maxAdContentRating=T (Teen) — matches the audience for govt job
    //    listings and unlocks higher-CPM advertisers than PG while staying
    //    family-safe (no MA-rated dating/gambling).
    //  • testDeviceIds — empty in release, but in debug we tell AdMob this
    //    device is a developer so accidental clicks during dev don't risk
    //    "invalid traffic" flags on the account.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.t,
        testDeviceIds: kReleaseMode ? const [] : const ['TEST_EMULATOR'],
      ),
    );
    await MobileAds.instance.initialize();
  }

  // ── Interstitial Ad ──────────────────────────────────────
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              loadInterstitial(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
        },
      ),
    );
  }

  /// Show interstitial if ready AND the frequency-cap window has elapsed.
  /// Returns true if shown.
  bool showInterstitial() {
    if (!_interstitialReady || _interstitialAd == null) return false;
    final now = DateTime.now();
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!).inMilliseconds < _minIntervalMs) {
      return false; // capped — skip silently
    }
    _interstitialAd!.show();
    _lastShownAt = now;
    return true;
  }
}
