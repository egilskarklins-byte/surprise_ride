import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_consent_service.dart';

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    debugPrint(
      '🏠 ADMOB BANNER initState | canRequestAds=${AdConsentService.canRequestAds}',
    );

    if (!AdConsentService.canRequestAds) {
      debugPrint('❌ ADMOB BANNER: consent not ready');
      return;
    }

    debugPrint('📡 ADMOB BANNER: starting load');

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-9221967299206056/3827870802',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ ADMOB BANNER: loaded');

          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ ADMOB BANNER FAILED: code=${error.code} message=${error.message}',
          );

          ad.dispose();
          _bannerAd = null;

          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(
        ad: _bannerAd!,
      ),
    );
  }
}