import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Controller for managing Banner Ads on specific screens
class BannerAdController {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  final Function(void)? onAdLoaded;

  BannerAdController({this.onAdLoaded});

  /// Get the Ad Unit ID based on release mode
  String get _adUnitId {
    if (kReleaseMode) {
      return "ca-app-pub-5549539316100784/8029769185";
    } else {
      return "ca-app-pub-3940256099942544/6300978111"; // Test ID
    }
  }

  /// Load an adaptive banner ad
  Future<void> loadAd(BuildContext context) async {
    // Get the window width for adaptive size
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      print('⚠️ BannerAdController: Failed to get adaptive size');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('💰 BannerAdController: Ad loaded');
          _isLoaded = true;
          onAdLoaded?.call(null);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('💰 BannerAdController: Failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isLoaded = false;
        },
      ),
    );

    await _bannerAd!.load();
  }

  /// Get the loaded ad widget
  Widget getAdWidget() {
    if (_bannerAd != null && _isLoaded) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }

  /// Check if ad is loaded
  bool get isLoaded => _isLoaded;

  /// Dispose the ad
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }
}
