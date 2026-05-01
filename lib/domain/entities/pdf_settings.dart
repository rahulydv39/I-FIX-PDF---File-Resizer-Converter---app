/// PDF Settings Entity
/// Contains all configuration options for PDF generation
library;

import 'package:equatable/equatable.dart';

/// Page size presets for PDF generation
enum PageSizeType {
  /// Automatic sizing based on image dimensions
  auto,

  /// Standard A4 page size (210mm x 297mm)
  a4,

  /// US Letter size (8.5" x 11")
  letter,
}

/// DPI preset values for image resolution
enum DpiPreset {
  /// Screen resolution (72 DPI)
  screen(72),

  /// Standard print quality (150 DPI)
  standard(150),

  /// High quality print (300 DPI)
  highQuality(300),

  /// Custom DPI value
  custom(0);

  final int value;
  const DpiPreset(this.value);
}

/// Target size configuration for PDF optimization
class SizeTarget extends Equatable {
  /// Target size value in KB
  final int kb;

  const SizeTarget({required this.kb});

  /// Convert target size to bytes
  int get sizeInBytes => kb * 1024;

  @override
  List<Object?> get props => [kb];
}

/// PDF generation settings
///
/// Contains all configuration options for PDF creation including
/// page size, quality, DPI, dimensions, and target file size.
class PdfSettings extends Equatable {
  /// Page size type (auto, A4, letter)
  final PageSizeType pageSize;

  /// Image compression quality (0-100)
  final int quality;

  /// DPI preset selection
  final DpiPreset dpiPreset;

  /// Custom DPI value (used when dpiPreset is custom)
  final int? customDpi;

  /// Target image width in pixels (null for original)
  final int? targetWidth;

  /// Target image height in pixels (null for original)
  final int? targetHeight;

  /// Whether to maintain aspect ratio when resizing
  final bool lockAspectRatio;

  /// Target PDF file size (null for no size targeting)
  final SizeTarget? targetSize;

  /// Whether to enable size optimization
  final bool enableSizeOptimization;

  /// Whether to maintain original page order
  final bool maintainPageOrder;

  /// Custom file name to save as
  final String? customFileName;

  const PdfSettings({
    this.pageSize = PageSizeType.a4,
    this.quality = 100,
    this.dpiPreset = DpiPreset.screen,
    this.customDpi,
    this.targetWidth,
    this.targetHeight,
    this.lockAspectRatio = true,
    this.targetSize,
    this.enableSizeOptimization = false,
    this.maintainPageOrder = true,
    this.customFileName,
  });

  /// Get the effective DPI value
  int get effectiveDpi {
    if (dpiPreset == DpiPreset.custom) {
      return customDpi ?? 150;
    }
    return dpiPreset.value;
  }

  /// Create a copy with updated values
  PdfSettings copyWith({
    PageSizeType? pageSize,
    int? quality,
    DpiPreset? dpiPreset,
    int? customDpi,
    int? targetWidth,
    int? targetHeight,
    bool? lockAspectRatio,
    SizeTarget? targetSize,
    bool? enableSizeOptimization,
    bool? maintainPageOrder,
    String? customFileName,
  }) {
    return PdfSettings(
      pageSize: pageSize ?? this.pageSize,
      quality: quality ?? this.quality,
      dpiPreset: dpiPreset ?? this.dpiPreset,
      customDpi: customDpi ?? this.customDpi,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      targetSize: targetSize ?? this.targetSize,
      enableSizeOptimization: enableSizeOptimization ?? this.enableSizeOptimization,
      maintainPageOrder: maintainPageOrder ?? this.maintainPageOrder,
      customFileName: customFileName ?? this.customFileName,
    );
  }

  /// Default settings for quick conversion
  static const PdfSettings defaultSettings = PdfSettings();

  /// High quality settings for printing
  static const PdfSettings highQuality = PdfSettings(
    quality: 100,
    dpiPreset: DpiPreset.highQuality,
  );

  /// Web optimized settings (smaller file size)
  static const PdfSettings webOptimized = PdfSettings(
    quality: 60,
    dpiPreset: DpiPreset.screen,
  );

  @override
  List<Object?> get props => [
        pageSize,
        quality,
        dpiPreset,
        customDpi,
        targetWidth,
        targetHeight,
        lockAspectRatio,
        targetSize,
        enableSizeOptimization,
        customFileName,
      ];
}
