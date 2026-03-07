/// Image Conversion BLoC
/// Manages image-to-image conversion state
library;

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/image_conversion_service.dart';
import '../../../data/services/usage_stats_service.dart';
import '../../../data/services/conversion_history_service.dart';
import '../../../domain/entities/conversion_history_item.dart';
import 'image_conversion_event.dart';
import 'image_conversion_state.dart';

/// BLoC for managing image-to-image conversion
class ImageConversionBloc
    extends Bloc<ImageConversionEvent, ImageConversionState> {
  final ImageConversionService _conversionService;
  final UsageStatsService? _statsService;
  final ConversionHistoryService? _historyService;
  bool _isCancelled = false;

  ImageConversionBloc({
    ImageConversionService? conversionService,
    UsageStatsService? statsService,
    ConversionHistoryService? historyService,
  })  : _conversionService = conversionService ?? ImageConversionService(),
        _statsService = statsService,
        _historyService = historyService,
        super(ImageConversionState.initial) {
    on<UpdateImageSettings>(_onUpdateSettings);
    on<StartImageConversion>(_onStartConversion);
    on<CancelImageConversion>(_onCancelConversion);
    on<ResetImageConversion>(_onResetConversion);
    on<EstimateImageSize>(_onEstimateSize);
    on<_ProgressUpdate>(_onProgressUpdate);
  }

  /// Update settings
  void _onUpdateSettings(
    UpdateImageSettings event,
    Emitter<ImageConversionState> emit,
  ) {
    emit(state.copyWith(settings: event.settings));
  }

  /// Start batch conversion
  Future<void> _onStartConversion(
    StartImageConversion event,
    Emitter<ImageConversionState> emit,
  ) async {
    _isCancelled = false;

    emit(state.copyWith(
      status: ImageConversionStatus.converting,
      progress: 0.0,
      currentImage: 0,
      totalImages: event.images.length,
      settings: event.settings,
    ));

    try {
      final result = await _conversionService.convertBatch(
        images: event.images,
        settings: event.settings,
        onProgress: (current, total) {
          if (!_isCancelled) {
            add(_ProgressUpdate(current, total));
          }
        },
      );

      if (_isCancelled) {
        emit(state.copyWith(status: ImageConversionStatus.cancelled));
        return;
      }

      emit(state.copyWith(
        status: ImageConversionStatus.completed,
        progress: 1.0,
        result: result,
      ));

      // Increment usage stats for successful conversions
      if (_statsService != null && result.successCount > 0) {
        for (int i = 0; i < result.successCount; i++) {
          await _statsService!.incrementImageConverted();
        }
      }

      // Save each successful conversion to history
      if (_historyService != null) {
        for (final r in result.results) {
          try {
            final file = File(r.outputPath);
            final fileName = r.outputPath.split('/').last;
            final fileSize = await file.exists() ? await file.length() : r.convertedSizeBytes;
            await _historyService!.addHistory(ConversionHistoryItem(
              fileName: fileName,
              filePath: r.outputPath,
              fileType: ConversionFileType.image,
              createdAt: DateTime.now(),
              fileSize: fileSize,
            ));
          } catch (e) {
            print('⚠️ Failed to save image history: $e');
          }
        }
      }
    } catch (e) {
      emit(state.copyWith(
        status: ImageConversionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Cancel ongoing conversion
  void _onCancelConversion(
    CancelImageConversion event,
    Emitter<ImageConversionState> emit,
  ) {
    _isCancelled = true;
    emit(state.copyWith(status: ImageConversionStatus.cancelled));
  }

  /// Reset conversion state
  void _onResetConversion(
    ResetImageConversion event,
    Emitter<ImageConversionState> emit,
  ) {
    emit(ImageConversionState.initial);
  }

  /// Estimate output size
  Future<void> _onEstimateSize(
    EstimateImageSize event,
    Emitter<ImageConversionState> emit,
  ) async {
    int totalEstimate = 0;
    for (final image in event.images) {
      totalEstimate += _conversionService.estimateOutputSize(
        image,
        event.settings,
      );
    }
    emit(state.copyWith(estimatedSizeBytes: totalEstimate));
  }

  /// Handle progress update
  void _onProgressUpdate(
    _ProgressUpdate event,
    Emitter<ImageConversionState> emit,
  ) {
    emit(state.copyWith(
      progress: event.current / event.total,
      currentImage: event.current,
      totalImages: event.total,
    ));
  }
}

/// Internal progress update event
class _ProgressUpdate extends ImageConversionEvent {
  final int current;
  final int total;

  const _ProgressUpdate(this.current, this.total);

  @override
  List<Object?> get props => [current, total];
}
