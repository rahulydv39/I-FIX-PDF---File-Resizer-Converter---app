/// PDF Conversion BLoC Events
/// Defines all events for PDF conversion process
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/image_item.dart';
import '../../../domain/entities/pdf_settings.dart';

/// Base class for PDF conversion events
abstract class PdfConversionEvent extends Equatable {
  const PdfConversionEvent();

  @override
  List<Object?> get props => [];
}

/// Update PDF settings
class UpdatePdfSettings extends PdfConversionEvent {
  final PdfSettings settings;

  const UpdatePdfSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Start PDF conversion
class StartConversion extends PdfConversionEvent {
  final List<ImageItem> images;
  final PdfSettings settings;

  const StartConversion({
    required this.images,
    required this.settings,
  });

  @override
  List<Object?> get props => [images, settings];
}

/// Start size-optimized PDF conversion
class StartOptimizedConversion extends PdfConversionEvent {
  final List<ImageItem> images;
  final PdfSettings settings;
  final int targetSizeBytes;

  const StartOptimizedConversion({
    required this.images,
    required this.settings,
    required this.targetSizeBytes,
  });

  @override
  List<Object?> get props => [images, settings, targetSizeBytes];
}

/// Cancel ongoing conversion
class CancelConversion extends PdfConversionEvent {
  const CancelConversion();
}

/// Estimate output size
class EstimateOutputSize extends PdfConversionEvent {
  final List<ImageItem> images;
  final PdfSettings settings;

  const EstimateOutputSize({
    required this.images,
    required this.settings,
  });

  @override
  List<Object?> get props => [images, settings];
}

/// Reset conversion state
class ResetConversion extends PdfConversionEvent {
  const ResetConversion();
}

/// Share generated PDF
class SharePdf extends PdfConversionEvent {
  final String filePath;

  const SharePdf(this.filePath);

  @override
  List<Object?> get props => [filePath];
}
