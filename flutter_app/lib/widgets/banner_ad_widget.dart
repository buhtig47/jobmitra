// lib/widgets/banner_ad_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_ids.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  // MediumRectangle (300x250) earns 3-5x more per impression than the old
  // 320x50 banner because advertisers bid much higher for the larger format
  // and Google's mediation prefers it. Inline feed placement is the canonical
  // home for 300x250.
  static const AdSize _adSize = AdSize.mediumRectangle;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!mounted) return; // widget was disposed during retry backoff
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: _adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          // Network call survived dispose: dropping the ad cleanly avoids both
          // a setState-on-disposed crash and a native-side BannerAd leak.
          if (!mounted) { loadedAd.dispose(); return; }
          _retryAttempt = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          // Exponential backoff retry — capped at 5 minutes. Without this,
          // a single transient load failure would leave the slot empty for
          // the entire user session = lost impressions. Cap retries at 6 so
          // we don't hammer if AdMob is genuinely refusing this slot.
          _retryAttempt++;
          if (_retryAttempt > 6 || !mounted) return;
          final delay = Duration(seconds: (1 << _retryAttempt).clamp(2, 300));
          _retryTimer = Timer(delay, _loadAd);
        },
      ),
    )..load();
    _ad = ad;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      alignment: Alignment.center,
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
