/// Monetization BLoC
/// Manages ads and conversion permissions
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/monetization_constants.dart';
import '../../../services/ads_service.dart';
import 'monetization_event.dart';
import 'monetization_state.dart';

/// BLoC for managing monetization
class MonetizationBloc extends Bloc<MonetizationEvent, MonetizationState> {
  final AdsService _adsService;

  StreamSubscription? _adStatusSubscription;

  MonetizationBloc({
    AdsService? adsService,
  })  : _adsService = adsService ?? AdsService(),
        super(MonetizationState.initial) {
    on<InitializeMonetization>(_onInitialize);
    on<WatchRewardedAd>(_onWatchAd);
    on<RefreshStatus>(_onRefreshStatus);
  }

  /// Initialize monetization services
  Future<void> _onInitialize(
    InitializeMonetization event,
    Emitter<MonetizationState> emit,
  ) async {
    try {
      // Initialize AdMob
      await _adsService.initialize();

      // Listen for ad status updates
      _adStatusSubscription = _adsService.adStatusStream.listen((status) {
        add(const RefreshStatus());
      });

      // Always allow conversions (unlimited)
      emit(state.copyWith(
        isInitialized: true,
        adStatus: _adsService.rewardedAdStatus,
        conversionPermission: ConversionPermission.allowed,
      ));
    } catch (e) {
      emit(state.copyWith(
        isInitialized: true,
        errorMessage: 'Failed to initialize: $e',
      ));
    }
  }


  /// Watch rewarded ad (optional for future monetization)
  Future<void> _onWatchAd(
    WatchRewardedAd event,
    Emitter<MonetizationState> emit,
  ) async {
    emit(state.copyWith(isShowingAd: true));

    try {
      final result = await _adsService.showRewardedAd();

      if (result.rewarded) {
        emit(state.copyWith(
          isShowingAd: false,
          successMessage: 'Thanks for watching!',
        ));
      } else {
        emit(state.copyWith(
          isShowingAd: false,
          errorMessage: result.errorMessage ?? 'Ad not completed',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isShowingAd: false,
        errorMessage: 'Failed to show ad: $e',
      ));
    }
  }

  /// Refresh monetization status
  Future<void> _onRefreshStatus(
    RefreshStatus event,
    Emitter<MonetizationState> emit,
  ) async {
    emit(state.copyWith(
      adStatus: _adsService.rewardedAdStatus,
    ));
  }

  @override
  Future<void> close() {
    _adStatusSubscription?.cancel();
    _adsService.dispose();
    return super.close();
  }
}

