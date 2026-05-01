/// Ads Service
/// Dedicated service for Google AdMob Rewarded Ads
/// Handles loading, showing, and managing rewarded ads.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/monetization_constants.dart';
import '../domain/repositories/ads_repository.dart';

// Export repository types for consumers
export '../domain/repositories/ads_repository.dart';

/// Service for managing Google AdMob Rewarded Ads
class AdsService implements AdsRepository {
  /// Singleton instance
  static final AdsService _instance = AdsService._internal();

  /// Factory constructor returns singleton
  factory AdsService() => _instance;

  /// Private constructor
  AdsService._internal();

  /// The loaded rewarded ad (null if not loaded)
  RewardedAd? _rewardedAd;

  /// Current ad status
  AdStatus _status = AdStatus.notLoaded;

  /// Stream controller for ad status updates
  final StreamController<AdStatus> _statusController =
      StreamController<AdStatus>.broadcast();

  /// Get the ad unit ID (test or production based on config)
  String get _adUnitId => MonetizationConstants.rewardedAdUnitId;

  // ============ AdsRepository Implementation ============

  /// Initialize the ads service
  @override
  Future<void> initialize() async {
    // Start loading ads
    // Note: MobileAds.instance.initialize() is handled in main.dart
    await preloadRewardedAd();
    await loadInterstitialAd(); // Also load interstitial ads
  }

  /// Preload a rewarded ad for later use
  @override
  Future<void> preloadRewardedAd() async {
    // Don't load if already loading or loaded
    if (_status == AdStatus.loading || _status == AdStatus.loaded) {
      return;
    }

    _updateStatus(AdStatus.loading);

    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          // Ad loaded successfully
          onAdLoaded: (RewardedAd ad) {
            print('💰 AdMob: Rewarded ad loaded');
            _rewardedAd = ad;
            _updateStatus(AdStatus.loaded);

            // Set up callbacks for when ad is shown
            _setupAdCallbacks(ad);
          },
          // Ad failed to load
          onAdFailedToLoad: (LoadAdError error) {
            print('💰 AdMob: Failed to load rewarded ad: $error');
            _rewardedAd = null;
            _updateStatus(AdStatus.failed);

            // Retry loading after delay
            Future.delayed(const Duration(seconds: 30), () {
              preloadRewardedAd();
            });
          },
        ),
      );
    } catch (e) {
      print('💰 AdMob: Error loading ad: $e');
      _rewardedAd = null;
      _updateStatus(AdStatus.failed);
    }
  }

  /// Check if a rewarded ad is ready to show
  @override
  bool get isRewardedAdReady => _status == AdStatus.loaded && _rewardedAd != null;

  /// Current ad status
  @override
  AdStatus get rewardedAdStatus => _status;

  /// Stream of ad status updates
  @override
  Stream<AdStatus> get adStatusStream => _statusController.stream;

  /// Show a rewarded ad and return the result
  @override
  Future<RewardedAdResult> showRewardedAd() async {
    // If no ad is ready, try to load one
    if (_rewardedAd == null) {
      await preloadRewardedAd();

      // Wait a bit for ad to load
      await Future.delayed(const Duration(seconds: 2));

      // Still no ad? Return error
      if (_rewardedAd == null) {
        return RewardedAdResult.failed('Ad not available right now. Please try again.');
      }
    }

    // Completer to wait for reward callback
    final Completer<RewardedAdResult> completer = Completer<RewardedAdResult>();

    try {
      // Show the ad
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print('💰 AdMob: User earned reward: ${reward.amount} ${reward.type}');
          
          if (!completer.isCompleted) {
            completer.complete(const RewardedAdResult(
              rewarded: true,
              rewardAmount: 1, // Default reward value
            ));
          }
        },
      );

      // Wait for result with timeout
      return completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => RewardedAdResult.failed('Ad completion timed out'),
      );
    } catch (e) {
      print('💰 AdMob: Error showing ad: $e');
      if (!completer.isCompleted) {
        return RewardedAdResult.failed('Failed to show ad: $e');
      }
      return RewardedAdResult.failed('Ad error occurred');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _statusController.close();
  }

  // ============ Interstitial Ads (Video Ads) ============

  /// The loaded interstitial ad
  InterstitialAd? _interstitialAd;

  /// Interstitial ad status
  bool _interstitialAdReady = false;

  /// Lock to prevent multiple ads from showing simultaneously
  bool _isAdShowing = false;

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_interstitialAd != null) return;

    try {
      await InterstitialAd.load(
        adUnitId: MonetizationConstants.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            print('💰 AdMob: Interstitial ad loaded');
            _interstitialAd = ad;
            _interstitialAdReady = true;

            _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                ad.dispose();
                _interstitialAd = null;
                _interstitialAdReady = false;
                loadInterstitialAd(); // Preload next ad
              },
              onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
                print('💰 AdMob: Interstitial ad failed to show: $error');
                ad.dispose();
                _interstitialAd = null;
                _interstitialAdReady = false;
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('💰 AdMob: Interstitial ad failed to load: $error');
            _interstitialAd = null;
            _interstitialAdReady = false;
          },
        ),
      );
    } catch (e) {
      print('💰 AdMob: Error loading interstitial ad: $e');
    }
  }

  /// Show interstitial ad if ready
  Future<bool> showInterstitialAd() async {
    if (_interstitialAd == null || !_interstitialAdReady) {
      print('💰 AdMob: Interstitial ad not ready');
      return false;
    }

    try {
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      print('💰 AdMob: Error showing interstitial ad: $e');
      return false;
    }
  }

  /// Check if interstitial ad is ready
  bool get isInterstitialAdReady => _interstitialAdReady;

  /// Show appropriate ad based on target size usage
  /// 
  /// If [isTargetSizeUsed] is true, shows video ad (interstitial)
  /// If false, does NOT show video ad (banner will be shown on success screen)
  /// 
  /// Returns true if video ad was shown, false otherwise
  Future<bool> showAdIfNeeded({required bool isTargetSizeUsed}) async {
    // No video ad for normal conversions
    if (!isTargetSizeUsed) {
      print('💰 AdMob: Normal conversion - no video ad');
      return false;
    }

    // Prevent multiple ads from showing
    if (_isAdShowing) {
      print('💰 AdMob: Ad already showing, skipping');
      return false;
    }

    // Show video ad for target size conversions
    print('💰 AdMob: Target size used - showing video ad');
    _isAdShowing = true;
    
    try {
      final shown = await showInterstitialAd();
      return shown;
    } finally {
      _isAdShowing = false;
    }
  }



  // ============ Internal Helpers ============

  /// Set up callbacks for the loaded ad
  void _setupAdCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      // Ad started showing
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('💰 AdMob: Ad showed full screen');
        _updateStatus(AdStatus.showing);
      },
      // Ad was dismissed (user closed it)
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('💰 AdMob: Ad dismissed');
        // Dispose the shown ad
        ad.dispose();
        _rewardedAd = null;
        _updateStatus(AdStatus.notLoaded);

        // Preload the next ad immediately
        preloadRewardedAd();
      },
      // Ad failed to show
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('💰 AdMob: Ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _updateStatus(AdStatus.failed);

        // Try to load a new ad
        preloadRewardedAd();
      },
    );
  }

  /// Update the ad status and notify listeners
  void _updateStatus(AdStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  // ============ Banner Ads ============
  
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: "YOUR_BANNER_AD_ID",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }
}
