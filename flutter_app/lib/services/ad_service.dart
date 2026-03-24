// lib/services/ad_service.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // TODO: Replace with real IDs from AdMob console before release
  static const _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // ── Interstitial Ad ──────────────────────────────────────
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
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

  /// Show interstitial if ready. Returns true if shown.
  bool showInterstitial() {
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
      return true;
    }
    return false;
  }
}
