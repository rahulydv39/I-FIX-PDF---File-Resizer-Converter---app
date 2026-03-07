/// Monetization BLoC Events
/// Defines all events for monetization state management
library;

import 'package:equatable/equatable.dart';

/// Base class for monetization events
abstract class MonetizationEvent extends Equatable {
  const MonetizationEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize monetization (load ad SDK and free conversions)
class InitializeMonetization extends MonetizationEvent {
  const InitializeMonetization();
}

/// Check if conversion is allowed
class CheckConversionPermission extends MonetizationEvent {
  const CheckConversionPermission();
}

/// Use a conversion (decrement free count)
class UseConversion extends MonetizationEvent {
  const UseConversion();
}

/// Request to watch rewarded ad
class WatchRewardedAd extends MonetizationEvent {
  const WatchRewardedAd();
}

/// Refresh monetization status
class RefreshStatus extends MonetizationEvent {
  const RefreshStatus();
}

/// Reset free conversions (for testing)
class ResetFreeConversions extends MonetizationEvent {
  const ResetFreeConversions();
}
