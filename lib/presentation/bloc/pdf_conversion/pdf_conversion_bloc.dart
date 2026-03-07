/// PDF Conversion BLoC
/// Manages PDF generation, progress, and size optimization
library;

import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/pdf_generator_service.dart';
import '../../../data/services/size_optimizer_service.dart';
import '../../../data/services/usage_stats_service.dart';
import '../../../data/services/conversion_history_service.dart';
import '../../../domain/entities/conversion_history_item.dart';
import '../../../core/constants/app_constants.dart';
import 'pdf_conversion_event.dart';
import 'pdf_conversion_state.dart';

/// BLoC for managing PDF conversion
class PdfConversionBloc extends Bloc<PdfConversionEvent, PdfConversionState> {
  final PdfGeneratorService _pdfGenerator;
  final SizeOptimizerService _sizeOptimizer;
  final UsageStatsService? _statsService;
  final ConversionHistoryService? _historyService;

  bool _isCancelled = false;

  PdfConversionBloc({
    PdfGeneratorService? pdfGenerator,
    SizeOptimizerService? sizeOptimizer,
    UsageStatsService? statsService,
    ConversionHistoryService? historyService,
  })  : _pdfGenerator = pdfGenerator ?? PdfGeneratorService(),
        _sizeOptimizer = sizeOptimizer ?? SizeOptimizerService(),
        _statsService = statsService,
        _historyService = historyService,
        super(PdfConversionState.initial) {
    on<UpdatePdfSettings>(_onUpdateSettings);
    on<StartConversion>(_onStartConversion);
    on<StartOptimizedConversion>(_onStartOptimizedConversion);
    on<CancelConversion>(_onCancelConversion);
    on<EstimateOutputSize>(_onEstimateSize);
    on<ResetConversion>(_onResetConversion);
    on<_UpdateProgress>(_onUpdateProgress);
    on<_UpdateOptimizationProgress>(_onUpdateOptimizationProgress);
  }

  /// Handle settings update
  void _onUpdateSettings(
    UpdatePdfSettings event,
    Emitter<PdfConversionState> emit,
  ) {
    emit(state.copyWith(
      settings: event.settings,
      status: ConversionStatus.ready,
    ));
  }

  /// Handle standard conversion
  Future<void> _onStartConversion(
    StartConversion event,
    Emitter<PdfConversionState> emit,
  ) async {
    _isCancelled = false;

    emit(state.copyWith(
      status: ConversionStatus.converting,
      progress: 0.0,
      currentPage: 0,
      totalPages: event.images.length,
    ));

    try {
      final result = await _pdfGenerator.generatePdf(
        images: event.images,
        settings: event.settings,
        onProgress: (current, total) {
          if (!_isCancelled) {
            add(_UpdateProgress(current: current, total: total));
          }
        },
      );

      if (_isCancelled) {
        emit(state.copyWith(status: ConversionStatus.cancelled));
        return;
      }

      emit(state.copyWith(
        status: ConversionStatus.completed,
        progress: 1.0,
        outputFilePath: result.filePath,
        actualSizeBytes: result.sizeBytes,
        conversionTimeMs: result.generationTimeMs,
      ));

      // Increment PDF created counter
      if (_statsService != null) {
        await _statsService!.incrementPdfCreated();
      }

      // Save to history
      if (_historyService != null) {
        try {
          final file = File(result.filePath);
          final fileName = result.filePath.split('/').last;
          final fileSize = await file.exists() ? await file.length() : result.sizeBytes;
          await _historyService!.addHistory(ConversionHistoryItem(
            fileName: fileName,
            filePath: result.filePath,
            fileType: ConversionFileType.pdf,
            createdAt: DateTime.now(),
            fileSize: fileSize,
          ));
        } catch (e) {
          print('⚠️ Failed to save PDF history: $e');
        }
      }
    } catch (e) {
      emit(state.copyWith(
        status: ConversionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Handle size-optimized conversion
  Future<void> _onStartOptimizedConversion(
    StartOptimizedConversion event,
    Emitter<PdfConversionState> emit,
  ) async {
    _isCancelled = false;

    emit(state.copyWith(
      status: ConversionStatus.optimizing,
      progress: 0.0,
      optimizationPass: 0,
      totalOptimizationPasses: AppConstants.maxOptimizationPasses,
    ));

    try {
      final result = await _sizeOptimizer.generateOptimizedPdf(
        images: event.images,
        initialSettings: event.settings,
        targetSizeBytes: event.targetSizeBytes,
        onOptimizationProgress: (pass, total) {
          if (!_isCancelled) {
            add(_UpdateOptimizationProgress(pass: pass, total: total));
          }
        },
      );

      if (_isCancelled) {
        emit(state.copyWith(status: ConversionStatus.cancelled));
        return;
      }

      emit(state.copyWith(
        status: ConversionStatus.completed,
        progress: 1.0,
        outputFilePath: result.filePath,
        actualSizeBytes: result.finalSizeBytes,
        settings: result.finalSettings,
      ));

      // Increment PDF created counter
      if (_statsService != null) {
        await _statsService!.incrementPdfCreated();
      }

      // Save to history
      if (_historyService != null) {
        try {
          final file = File(result.filePath);
          final fileName = result.filePath.split('/').last;
          final fileSize = await file.exists() ? await file.length() : result.finalSizeBytes;
          await _historyService!.addHistory(ConversionHistoryItem(
            fileName: fileName,
            filePath: result.filePath,
            fileType: ConversionFileType.pdf,
            createdAt: DateTime.now(),
            fileSize: fileSize,
          ));
        } catch (e) {
          print('⚠️ Failed to save PDF history: $e');
        }
      }
    } catch (e) {
      emit(state.copyWith(
        status: ConversionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Handle conversion cancellation
  void _onCancelConversion(
    CancelConversion event,
    Emitter<PdfConversionState> emit,
  ) {
    _isCancelled = true;
    emit(state.copyWith(status: ConversionStatus.cancelled));
  }

  /// Handle size estimation
  Future<void> _onEstimateSize(
    EstimateOutputSize event,
    Emitter<PdfConversionState> emit,
  ) async {
    emit(state.copyWith(status: ConversionStatus.estimating));

    try {
      final estimate = await _sizeOptimizer.estimateSize(
        images: event.images,
        settings: event.settings,
      );

      emit(state.copyWith(
        status: ConversionStatus.ready,
        estimatedSizeBytes: estimate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ConversionStatus.ready,
        estimatedSizeBytes: null,
      ));
    }
  }

  /// Handle reset
  void _onResetConversion(
    ResetConversion event,
    Emitter<PdfConversionState> emit,
  ) {
    _isCancelled = false;
    emit(PdfConversionState.initial);
  }

  /// Handle progress update
  void _onUpdateProgress(
    _UpdateProgress event,
    Emitter<PdfConversionState> emit,
  ) {
    emit(state.copyWith(
      progress: event.current / event.total,
      currentPage: event.current,
      totalPages: event.total,
    ));
  }

  /// Handle optimization progress update
  void _onUpdateOptimizationProgress(
    _UpdateOptimizationProgress event,
    Emitter<PdfConversionState> emit,
  ) {
    emit(state.copyWith(
      optimizationPass: event.pass,
      totalOptimizationPasses: event.total,
      progress: event.pass / event.total,
    ));
  }
}

/// Internal event for progress updates
class _UpdateProgress extends PdfConversionEvent {
  final int current;
  final int total;

  const _UpdateProgress({required this.current, required this.total});
}

/// Internal event for optimization progress
class _UpdateOptimizationProgress extends PdfConversionEvent {
  final int pass;
  final int total;

  const _UpdateOptimizationProgress({required this.pass, required this.total});
}
