/// Monetization constants for the freemium model
/// Defines free tier limits, ad unit IDs, and subscription pricing
library;

/// Monetization configuration constants
class MonetizationConstants {
  MonetizationConstants._();

  // ========== TEST MODE ==========
  /// Set to true to enable premium features for testing
  /// IMPORTANT: Set to false before production release!
  static const bool testMode = false;

  // ========== AD MODE ==========
  /// Set to true to use TEST ad unit IDs (for development)
  /// Set to false to use PRODUCTION ad unit IDs (for release)
  /// IMPORTANT: Use test ads during development to avoid policy violations!
  static const bool useTestAds = false;

  // Free Tier Limits
  /// Number of free conversions allowed before requiring ads/premium
  static const int freeConversions = 2;

  // ========== AdMob Configuration ==========
  
  /// AdMob App ID (configured in AndroidManifest.xml)
  /// Production: ca-app-pub-5549539316100784~2277835355
  /// Test:       ca-app-pub-3940256099942544~3347511713
  static const String admobAppId = 'ca-app-pub-5549539316100784~2277835355';

  /// Rewarded Ad Unit ID - TEST (for development)
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Rewarded Ad Unit ID - PRODUCTION (for release)
  static const String _prodRewardedAdUnitId =
      'ca-app-pub-5549539316100784/2501444059';

  /// Get the appropriate Rewarded Ad Unit ID based on [useTestAds] flag
  /// ⚠️ IMPORTANT: Set [useTestAds] to false before releasing to production!
  static String get rewardedAdUnitId =>
      useTestAds ? _testRewardedAdUnitId : _prodRewardedAdUnitId;

  /// Interstitial Ad Unit ID - TEST (for development)
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Interstitial Ad Unit ID - PRODUCTION (for release)
  static const String _prodInterstitialAdUnitId =
      'ca-app-pub-5549539316100784/2501444059';

  /// Get the appropriate Interstitial Ad Unit ID based on [useTestAds] flag
  static String get interstitialAdUnitId =>
      useTestAds ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;

  /// Banner Ad Unit ID - TEST (for development)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Banner Ad Unit ID - PRODUCTION (for release)
  static const String _prodBannerAdUnitId =
      'ca-app-pub-5549539316100784/8029769185';

  /// Get the appropriate Banner Ad Unit ID based on [useTestAds] flag
  static String get bannerAdUnitId =>
      useTestAds ? _testBannerAdUnitId : _prodBannerAdUnitId;

  // Subscription Product IDs (must match Google Play Console)
  static const String monthlySubscriptionId = 'premium_monthly';
  static const String yearlySubscriptionId = 'premium_yearly';
  static const String lifetimeSubscriptionId = 'premium_lifetime';

  // Subscription Prices (in INR for display purposes)
  static const double monthlyPrice = 49.0;
  static const double yearlyPrice = 399.0;
  static const double lifetimePrice = 999.0;

  // Subscription Display Names
  static const String monthlyDisplayName = 'Monthly Premium';
  static const String yearlyDisplayName = 'Yearly Premium';
  static const String lifetimeDisplayName = 'Lifetime Premium';

  // SharedPreferences Keys
  static const String keyConversionCount = 'conversion_count';
  static const String keyIsPremium = 'is_premium';
  static const String keySubscriptionExpiry = 'subscription_expiry';
  static const String keySubscriptionType = 'subscription_type';
}
