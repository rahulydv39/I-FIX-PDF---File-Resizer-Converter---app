/// Image Conversion State
/// State for image-to-image conversion BLoC
library;

import 'package:equatable/equatable.dart';
import '../../../data/services/image_conversion_service.dart';
import '../../../domain/entities/image_settings.dart';

/// Status of image conversion
enum ImageConversionStatus {
  initial,
  converting,
  completed,
  cancelled,
  error,
}

/// State for image conversion
class ImageConversionState extends Equatable {
  /// Current status
  final ImageConversionStatus status;

  /// Current settings
  final ImageSettings settings;

  /// Progress (0.0 to 1.0)
  final double progress;

  /// Current image being processed
  final int currentImage;

  /// Total images to process
  final int totalImages;

  /// Conversion results
  final BatchConversionResult? result;

  /// Estimated output size
  final int? estimatedSizeBytes;

  /// Error message if failed
  final String? errorMessage;

  const ImageConversionState({
    this.status = ImageConversionStatus.initial,
    this.settings = const ImageSettings(),
    this.progress = 0.0,
    this.currentImage = 0,
    this.totalImages = 0,
    this.result,
    this.estimatedSizeBytes,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        status,
        settings,
        progress,
        currentImage,
        totalImages,
        result,
        estimatedSizeBytes,
        errorMessage,
      ];

  /// Initial state
  static const initial = ImageConversionState();

  /// Whether conversion is in progress
  bool get isConverting => status == ImageConversionStatus.converting;

  /// Whether conversion is completed
  bool get isCompleted => status == ImageConversionStatus.completed;

  /// Whether there was an error
  bool get hasError => status == ImageConversionStatus.error;

  /// Formatted progress percentage
  String get progressPercent => '${(progress * 100).toInt()}%';

  /// Total size saved (formatted)
  String get formattedSizeSaved {
    if (result == null) return '0 KB';
    return result!.formattedSizeSaved;
  }

  /// Total processing time (formatted)
  String get formattedProcessingTime {
    if (result == null) return '0s';
    final seconds = result!.processingTimeMs / 1000;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds.toStringAsFixed(0)}s';
  }

  /// Create a copy with updated values
  ImageConversionState copyWith({
    ImageConversionStatus? status,
    ImageSettings? settings,
    double? progress,
    int? currentImage,
    int? totalImages,
    BatchConversionResult? result,
    int? estimatedSizeBytes,
    String? errorMessage,
  }) {
    return ImageConversionState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      progress: progress ?? this.progress,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
      result: result ?? this.result,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
