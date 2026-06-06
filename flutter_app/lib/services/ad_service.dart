// lib/services/ad_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_ids.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;
  int _interstitialRetry = 0;
  Timer? _interstitialRetryTimer;

  // Minimum gap between two interstitial impressions. Users open 5+ job details
  // per session; without this floor we'd show 5 fullscreen ads in 90s and lose
  // the install. Industry standard for content apps is 60-120s.
  static const _minIntervalMs = 90 * 1000;
  DateTime? _lastShownAt;

  // ── App Open Ad ─────────────────────────────────────────────
  // Highest-eCPM format (~3-5x banner). Shown once per 4h on app resume.
  // AdMob auto-suppresses if another fullscreen ad is already displayed.
  AppOpenAd? _appOpenAd;
  bool _appOpenReady = false;
  int _appOpenRetry = 0;
  DateTime? _appOpenLoadedAt;    // ads expire after 4h
  DateTime? _appOpenShownAt;
  static const _appOpenMaxAge = Duration(hours: 4);
  static const _appOpenMinGap = Duration(hours: 4);

  static Future<void> initialize() async {
    // Safety net: if a release build ships with Google's test ad IDs we'd be
    // serving non-monetizing test creatives forever ($0 revenue). Record a
    // non-fatal in Crashlytics so we see it in the dashboard within hours of
    // a bad build reaching real devices — without crashing the user's app.
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
        try {
          FirebaseCrashlytics.instance.recordError(
            StateError('Release build shipped with AdMob test IDs'),
            StackTrace.current,
            reason: 'ad-revenue-misconfig',
            fatal: false,
          );
        } catch (_) {}
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
    _interstitialRetryTimer?.cancel();
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialRetry = 0;
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
              loadInterstitial(); // try to recover so next exit still earns
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
          // Without retry, a single transient network blip at startup would
          // leave us with zero interstitial inventory for the entire session.
          // Cap at 5 attempts so we don't hammer AdMob if the unit is broken.
          _interstitialRetry++;
          if (_interstitialRetry > 5) return;
          final delay = Duration(seconds: (1 << _interstitialRetry).clamp(2, 300));
          _interstitialRetryTimer = Timer(delay, loadInterstitial);
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

  // ── App Open Ad ──────────────────────────────────────────────
  void loadAppOpen() {
    _appOpenRetry = 0;
    _loadAppOpenInternal();
  }

  void _loadAppOpenInternal() {
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenRetry = 0;
          _appOpenAd = ad;
          _appOpenReady = true;
          _appOpenLoadedAt = DateTime.now();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _appOpenAd = null;
              _appOpenReady = false;
              _loadAppOpenInternal(); // preload next
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _appOpenAd = null;
              _appOpenReady = false;
              _loadAppOpenInternal();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _appOpenReady = false;
          _appOpenRetry++;
          if (_appOpenRetry > 4) return;
          final delay = Duration(seconds: (1 << _appOpenRetry).clamp(4, 300));
          Future.delayed(delay, _loadAppOpenInternal);
        },
      ),
    );
  }

  /// Show App Open Ad on resume. Returns true if shown.
  /// AdMob SDK blocks the show if another fullscreen ad is already visible,
  /// so no extra guard needed against interstitial collision.
  bool showAppOpen() {
    if (!_appOpenReady || _appOpenAd == null) return false;
    final now = DateTime.now();
    // Reject if the loaded creative is older than 4h (AdMob requirement).
    if (_appOpenLoadedAt != null &&
        now.difference(_appOpenLoadedAt!) > _appOpenMaxAge) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
      _appOpenReady = false;
      _loadAppOpenInternal();
      return false;
    }
    // Frequency cap: don't show more than once per 4h.
    if (_appOpenShownAt != null &&
        now.difference(_appOpenShownAt!) < _appOpenMinGap) {
      return false;
    }
    _appOpenAd!.show();
    _appOpenShownAt = now;
    return true;
  }
}
