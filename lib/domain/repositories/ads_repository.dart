/// Ads Repository Interface
/// Defines the contract for ad operations
library;

/// Status of ad loading
enum AdStatus {
  /// Ad not loaded
  notLoaded,

  /// Ad is currently loading
  loading,

  /// Ad loaded and ready to show
  loaded,

  /// Ad failed to load
  failed,

  /// Ad is showing
  showing,
}

/// Result of showing a rewarded ad
class RewardedAdResult {
  /// Whether the user earned the reward
  final bool rewarded;

  /// Reward amount (usually 1)
  final int rewardAmount;

  /// Error message if ad failed
  final String? errorMessage;

  const RewardedAdResult({
    required this.rewarded,
    this.rewardAmount = 1,
    this.errorMessage,
  });

  /// Successful reward result
  static const RewardedAdResult success = RewardedAdResult(
    rewarded: true,
    rewardAmount: 1,
  );

  /// Failed/skipped reward result
  static RewardedAdResult failed([String? message]) => RewardedAdResult(
        rewarded: false,
        rewardAmount: 0,
        errorMessage: message,
      );
}

/// Repository interface for ad operations
abstract class AdsRepository {
  /// Initialize the ads SDK
  Future<void> initialize();

  /// Preload a rewarded ad for later use
  Future<void> preloadRewardedAd();

  /// Check if a rewarded ad is ready
  bool get isRewardedAdReady;

  /// Current status of rewarded ad
  AdStatus get rewardedAdStatus;

  /// Show a rewarded ad and wait for result
  Future<RewardedAdResult> showRewardedAd();

  /// Stream of ad status updates
  Stream<AdStatus> get adStatusStream;

  /// Dispose ads resources
  void dispose();
}
