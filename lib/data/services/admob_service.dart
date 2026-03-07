/// AdMob Service
/// Handles Google AdMob rewarded ad integration
library;

import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/monetization_constants.dart';
import '../../domain/repositories/ads_repository.dart';

/// Service for managing AdMob rewarded ads
class AdMobService implements AdsRepository {
  RewardedAd? _rewardedAd;
  AdStatus _adStatus = AdStatus.notLoaded;

  final StreamController<AdStatus> _adStatusController =
      StreamController<AdStatus>.broadcast();

  /// Initialize AdMob SDK
  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();

    // Request app tracking transparency (iOS)
    // await MobileAds.instance.updateRequestConfiguration(
    //   RequestConfiguration(testDeviceIds: ['YOUR_TEST_DEVICE_ID']),
    // );

    // Preload first ad
    await preloadRewardedAd();
  }

  /// Preload a rewarded ad for later use
  @override
  Future<void> preloadRewardedAd() async {
    if (_adStatus == AdStatus.loading || _adStatus == AdStatus.loaded) {
      return; // Already loading or loaded
    }

    _updateStatus(AdStatus.loading);

    await RewardedAd.load(
      adUnitId: MonetizationConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _updateStatus(AdStatus.loaded);

          // Set up ad event handlers
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _updateStatus(AdStatus.showing);
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _updateStatus(AdStatus.notLoaded);
              // Preload next ad
              preloadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _updateStatus(AdStatus.failed);
              // Try to preload again
              preloadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _updateStatus(AdStatus.failed);
          // Retry after delay
          Future.delayed(const Duration(seconds: 30), preloadRewardedAd);
        },
      ),
    );
  }

  /// Check if a rewarded ad is ready to show
  @override
  bool get isRewardedAdReady => _adStatus == AdStatus.loaded;

  /// Current ad status
  @override
  AdStatus get rewardedAdStatus => _adStatus;

  /// Show rewarded ad and wait for result
  @override
  Future<RewardedAdResult> showRewardedAd() async {
    if (_rewardedAd == null) {
      // Try to load if not available
      await preloadRewardedAd();

      // Wait briefly for ad to load
      await Future.delayed(const Duration(seconds: 2));

      if (_rewardedAd == null) {
        return RewardedAdResult.failed('Ad not available. Please try again.');
      }
    }

    final Completer<RewardedAdResult> completer = Completer();

    try {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          if (!completer.isCompleted) {
            completer.complete(RewardedAdResult(
              rewarded: true,
              rewardAmount: reward.amount.toInt(),
            ));
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(RewardedAdResult.failed('Failed to show ad: $e'));
      }
    }

    // Set timeout for ad completion
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => RewardedAdResult.failed('Ad timed out'),
    );
  }

  /// Stream of ad status updates
  @override
  Stream<AdStatus> get adStatusStream => _adStatusController.stream;

  /// Update status and notify listeners
  void _updateStatus(AdStatus status) {
    _adStatus = status;
    _adStatusController.add(status);
  }

  /// Dispose resources
  @override
  void dispose() {
    _rewardedAd?.dispose();
    _adStatusController.close();
  }
}
