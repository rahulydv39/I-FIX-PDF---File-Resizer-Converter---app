/// Monetization BLoC States
/// Defines all states for monetization management
library;

import 'package:equatable/equatable.dart';
import '../../../domain/repositories/ads_repository.dart';

/// Permission status for conversion
enum ConversionPermission {
  /// Allowed (unlimited conversions)
  allowed,

  /// Currently checking
  checking,
}

/// State class for monetization
class MonetizationState extends Equatable {


  /// Current ad status
  final AdStatus adStatus;

  /// Current conversion permission
  final ConversionPermission conversionPermission;

  /// Whether monetization is initialized
  final bool isInitialized;

  /// Whether ad is being shown
  final bool isShowingAd;

  /// Error message
  final String? errorMessage;

  /// Success message (e.g., "Ad watched!")
  final String? successMessage;

  const MonetizationState({
    this.adStatus = AdStatus.notLoaded,
    this.conversionPermission = ConversionPermission.checking,
    this.isInitialized = false,
    this.isShowingAd = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Check if conversion is allowed (always true for unlimited)
  bool get canConvertFreely => true;

  /// Check if ad is ready
  bool get isAdReady => adStatus == AdStatus.loaded;

  /// Initial state
  static const MonetizationState initial = MonetizationState();

  /// Create a copy with updated values
  MonetizationState copyWith({
    AdStatus? adStatus,
    ConversionPermission? conversionPermission,
    bool? isInitialized,
    bool? isShowingAd,
    String? errorMessage,
    String? successMessage,
  }) {
    return MonetizationState(
      adStatus: adStatus ?? this.adStatus,
      conversionPermission: conversionPermission ?? this.conversionPermission,
      isInitialized: isInitialized ?? this.isInitialized,
      isShowingAd: isShowingAd ?? this.isShowingAd,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        adStatus,
        conversionPermission,
        isInitialized,
        isShowingAd,
        errorMessage,
        successMessage,
      ];
}
