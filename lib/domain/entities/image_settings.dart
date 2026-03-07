/// Image Settings Entity
/// Settings for image-to-image conversion (resize, compress, format change)
library;

import 'package:equatable/equatable.dart';

/// Supported output image formats
enum OutputFormat {
  jpeg,
  png,
  webp,
  heic,
}

/// Extension for OutputFormat
extension OutputFormatExtension on OutputFormat {
  String get extension {
    switch (this) {
      case OutputFormat.jpeg:
        return 'jpg';
      case OutputFormat.png:
        return 'png';
      case OutputFormat.webp:
        return 'webp';
      case OutputFormat.heic:
        return 'heic';
    }
  }

  String get displayName {
    switch (this) {
      case OutputFormat.jpeg:
        return 'JPEG';
      case OutputFormat.png:
        return 'PNG';
      case OutputFormat.webp:
        return 'WebP';
      case OutputFormat.heic:
        return 'HEIC';
    }
  }

  String get mimeType {
    switch (this) {
      case OutputFormat.jpeg:
        return 'image/jpeg';
      case OutputFormat.png:
        return 'image/png';
      case OutputFormat.webp:
        return 'image/webp';
      case OutputFormat.heic:
        return 'image/heic';
    }
  }
}

/// Resize mode for images
enum ResizeMode {
  /// Keep original dimensions
  original,

  /// Resize by percentage
  percentage,

  /// Resize to specific dimensions
  custom,

  /// Preset sizes (social media, etc.)
  preset,
}

/// Preset dimension options
enum DimensionPreset {
  /// Instagram Square (1080x1080)
  instagramSquare,

  /// Instagram Portrait (1080x1350)
  instagramPortrait,

  /// Instagram Story (1080x1920)
  instagramStory,

  /// Facebook Post (1200x630)
  facebookPost,

  /// Twitter Post (1200x675)
  twitterPost,

  /// YouTube Thumbnail (1280x720)
  youtubeThumbnail,

  /// HD (1280x720)
  hd720,

  /// Full HD (1920x1080)
  fullHd1080,

  /// 4K (3840x2160)
  uhd4k,

  /// Passport Photo (35x45mm at 300dpi)
  passportPhoto,

  /// A4 at 300dpi
  a4Print,
}

/// Extension for DimensionPreset
extension DimensionPresetExtension on DimensionPreset {
  String get displayName {
    switch (this) {
      case DimensionPreset.instagramSquare:
        return 'Instagram Square';
      case DimensionPreset.instagramPortrait:
        return 'Instagram Portrait';
      case DimensionPreset.instagramStory:
        return 'Instagram Story';
      case DimensionPreset.facebookPost:
        return 'Facebook Post';
      case DimensionPreset.twitterPost:
        return 'Twitter/X Post';
      case DimensionPreset.youtubeThumbnail:
        return 'YouTube Thumbnail';
      case DimensionPreset.hd720:
        return 'HD 720p';
      case DimensionPreset.fullHd1080:
        return 'Full HD 1080p';
      case DimensionPreset.uhd4k:
        return '4K UHD';
      case DimensionPreset.passportPhoto:
        return 'Passport Photo';
      case DimensionPreset.a4Print:
        return 'A4 Print (300 DPI)';
    }
  }

  int get width {
    switch (this) {
      case DimensionPreset.instagramSquare:
        return 1080;
      case DimensionPreset.instagramPortrait:
        return 1080;
      case DimensionPreset.instagramStory:
        return 1080;
      case DimensionPreset.facebookPost:
        return 1200;
      case DimensionPreset.twitterPost:
        return 1200;
      case DimensionPreset.youtubeThumbnail:
        return 1280;
      case DimensionPreset.hd720:
        return 1280;
      case DimensionPreset.fullHd1080:
        return 1920;
      case DimensionPreset.uhd4k:
        return 3840;
      case DimensionPreset.passportPhoto:
        return 413; // 35mm at 300dpi
      case DimensionPreset.a4Print:
        return 2480; // 210mm at 300dpi
    }
  }

  int get height {
    switch (this) {
      case DimensionPreset.instagramSquare:
        return 1080;
      case DimensionPreset.instagramPortrait:
        return 1350;
      case DimensionPreset.instagramStory:
        return 1920;
      case DimensionPreset.facebookPost:
        return 630;
      case DimensionPreset.twitterPost:
        return 675;
      case DimensionPreset.youtubeThumbnail:
        return 720;
      case DimensionPreset.hd720:
        return 720;
      case DimensionPreset.fullHd1080:
        return 1080;
      case DimensionPreset.uhd4k:
        return 2160;
      case DimensionPreset.passportPhoto:
        return 531; // 45mm at 300dpi
      case DimensionPreset.a4Print:
        return 3508; // 297mm at 300dpi
    }
  }

  String get dimensions => '$width×$height';
}

/// Settings for image-to-image conversion
class ImageSettings extends Equatable {
  /// Output format
  final OutputFormat outputFormat;

  /// Quality (1-100) - applies to JPEG and WebP
  final int quality;

  /// Resize mode
  final ResizeMode resizeMode;

  /// Percentage for resize (10-200%)
  final int resizePercentage;

  /// Custom width (pixels)
  final int? customWidth;

  /// Custom height (pixels)
  final int? customHeight;

  /// Selected preset
  final DimensionPreset? dimensionPreset;

  /// Lock aspect ratio when resizing
  final bool lockAspectRatio;

  /// DPI for output image
  final int dpi;

  /// Remove EXIF metadata
  final bool removeMetadata;

  /// Apply grayscale filter
  final bool grayscale;

  /// Enable batch processing (multiple images)
  final bool batchMode;

  /// Target file size in KB (optional, for optimization)
  final int? targetSizeKb;

  /// Enable size optimization
  final bool enableSizeOptimization;

  const ImageSettings({
    this.outputFormat = OutputFormat.jpeg,
    this.quality = 85,
    this.resizeMode = ResizeMode.original,
    this.resizePercentage = 100,
    this.customWidth,
    this.customHeight,
    this.dimensionPreset,
    this.lockAspectRatio = true,
    this.dpi = 72,
    this.removeMetadata = false,
    this.grayscale = false,
    this.batchMode = true,
    this.targetSizeKb,
    this.enableSizeOptimization = false,
  });

  @override
  List<Object?> get props => [
        outputFormat,
        quality,
        resizeMode,
        resizePercentage,
        customWidth,
        customHeight,
        dimensionPreset,
        lockAspectRatio,
        dpi,
        removeMetadata,
        grayscale,
        batchMode,
        targetSizeKb,
        enableSizeOptimization,
      ];

  /// Get effective dimensions based on resize mode
  (int?, int?) get effectiveDimensions {
    switch (resizeMode) {
      case ResizeMode.original:
        return (null, null);
      case ResizeMode.percentage:
        return (null, null); // Calculated at conversion time
      case ResizeMode.custom:
        return (customWidth, customHeight);
      case ResizeMode.preset:
        if (dimensionPreset != null) {
          return (dimensionPreset!.width, dimensionPreset!.height);
        }
        return (null, null);
    }
  }

  /// Create a copy with updated values
  ImageSettings copyWith({
    OutputFormat? outputFormat,
    int? quality,
    ResizeMode? resizeMode,
    int? resizePercentage,
    int? customWidth,
    int? customHeight,
    DimensionPreset? dimensionPreset,
    bool? lockAspectRatio,
    int? dpi,
    bool? removeMetadata,
    bool? grayscale,
    bool? batchMode,
    int? targetSizeKb,
    bool? enableSizeOptimization,
  }) {
    return ImageSettings(
      outputFormat: outputFormat ?? this.outputFormat,
      quality: quality ?? this.quality,
      resizeMode: resizeMode ?? this.resizeMode,
      resizePercentage: resizePercentage ?? this.resizePercentage,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      dimensionPreset: dimensionPreset ?? this.dimensionPreset,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      dpi: dpi ?? this.dpi,
      removeMetadata: removeMetadata ?? this.removeMetadata,
      grayscale: grayscale ?? this.grayscale,
      batchMode: batchMode ?? this.batchMode,
      targetSizeKb: targetSizeKb ?? this.targetSizeKb,
      enableSizeOptimization:
          enableSizeOptimization ?? this.enableSizeOptimization,
    );
  }

  /// Default settings
  static const ImageSettings defaults = ImageSettings();

  /// High quality preset
  static const ImageSettings highQuality = ImageSettings(
    quality: 95,
    dpi: 300,
    removeMetadata: false,
  );

  /// Web optimized preset
  static const ImageSettings webOptimized = ImageSettings(
    outputFormat: OutputFormat.webp,
    quality: 80,
    dpi: 72,
    removeMetadata: true,
  );

  /// Social media preset
  static const ImageSettings socialMedia = ImageSettings(
    outputFormat: OutputFormat.jpeg,
    quality: 85,
    resizeMode: ResizeMode.preset,
    dimensionPreset: DimensionPreset.instagramSquare,
    removeMetadata: true,
  );
}
