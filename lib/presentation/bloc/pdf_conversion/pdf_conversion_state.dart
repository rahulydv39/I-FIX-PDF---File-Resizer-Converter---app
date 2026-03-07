/// PDF Conversion BLoC States
/// Defines all states for PDF conversion process
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/pdf_settings.dart';

/// Status of PDF conversion
enum ConversionStatus {
  /// Initial state
  initial,

  /// Settings configured, ready to convert
  ready,

  /// Estimating output size
  estimating,

  /// Converting images to PDF
  converting,

  /// Size optimization in progress
  optimizing,

  /// Conversion completed successfully
  completed,

  /// Conversion failed
  error,

  /// Conversion cancelled
  cancelled,
}

/// State class for PDF conversion
class PdfConversionState extends Equatable {
  /// Current conversion status
  final ConversionStatus status;

  /// Current PDF settings
  final PdfSettings settings;

  /// Estimated output size in bytes
  final int? estimatedSizeBytes;

  /// Actual output size after conversion
  final int? actualSizeBytes;

  /// Path to generated PDF file
  final String? outputFilePath;

  /// Conversion progress (0.0 to 1.0)
  final double progress;

  /// Current page being processed
  final int currentPage;

  /// Total pages to process
  final int totalPages;

  /// Optimization pass number (if optimizing)
  final int optimizationPass;

  /// Total optimization passes
  final int totalOptimizationPasses;

  /// Error message if status is error
  final String? errorMessage;

  /// Conversion time in milliseconds
  final int? conversionTimeMs;

  const PdfConversionState({
    this.status = ConversionStatus.initial,
    this.settings = const PdfSettings(),
    this.estimatedSizeBytes,
    this.actualSizeBytes,
    this.outputFilePath,
    this.progress = 0.0,
    this.currentPage = 0,
    this.totalPages = 0,
    this.optimizationPass = 0,
    this.totalOptimizationPasses = 0,
    this.errorMessage,
    this.conversionTimeMs,
  });

  /// Check if conversion is in progress
  bool get isConverting =>
      status == ConversionStatus.converting ||
      status == ConversionStatus.optimizing;

  /// Check if conversion completed successfully
  bool get isCompleted => status == ConversionStatus.completed;

  /// Check if there's an error
  bool get hasError => status == ConversionStatus.error;

  /// Get formatted estimated size
  String get formattedEstimatedSize {
    if (estimatedSizeBytes == null) return 'Unknown';
    return _formatBytes(estimatedSizeBytes!);
  }

  /// Get formatted actual size
  String get formattedActualSize {
    if (actualSizeBytes == null) return 'Unknown';
    return _formatBytes(actualSizeBytes!);
  }

  /// Get formatted conversion time
  String get formattedConversionTime {
    if (conversionTimeMs == null) return '';
    if (conversionTimeMs! < 1000) {
      return '${conversionTimeMs}ms';
    }
    return '${(conversionTimeMs! / 1000).toStringAsFixed(1)}s';
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Initial state
  static const PdfConversionState initial = PdfConversionState();

  /// Create a copy with updated values
  PdfConversionState copyWith({
    ConversionStatus? status,
    PdfSettings? settings,
    int? estimatedSizeBytes,
    int? actualSizeBytes,
    String? outputFilePath,
    double? progress,
    int? currentPage,
    int? totalPages,
    int? optimizationPass,
    int? totalOptimizationPasses,
    String? errorMessage,
    int? conversionTimeMs,
  }) {
    return PdfConversionState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      actualSizeBytes: actualSizeBytes ?? this.actualSizeBytes,
      outputFilePath: outputFilePath ?? this.outputFilePath,
      progress: progress ?? this.progress,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      optimizationPass: optimizationPass ?? this.optimizationPass,
      totalOptimizationPasses:
          totalOptimizationPasses ?? this.totalOptimizationPasses,
      errorMessage: errorMessage,
      conversionTimeMs: conversionTimeMs ?? this.conversionTimeMs,
    );
  }

  @override
  List<Object?> get props => [
        status,
        settings,
        estimatedSizeBytes,
        actualSizeBytes,
        outputFilePath,
        progress,
        currentPage,
        totalPages,
        optimizationPass,
        totalOptimizationPasses,
        errorMessage,
        conversionTimeMs,
      ];
}
