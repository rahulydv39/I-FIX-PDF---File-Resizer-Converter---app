/// Image Conversion Events
/// Events for image-to-image conversion BLoC
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/image_item.dart';
import '../../../domain/entities/image_settings.dart';

/// Base event for image conversion
abstract class ImageConversionEvent extends Equatable {
  const ImageConversionEvent();

  @override
  List<Object?> get props => [];
}

/// Update image settings
class UpdateImageSettings extends ImageConversionEvent {
  final ImageSettings settings;

  const UpdateImageSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Start batch conversion
class StartImageConversion extends ImageConversionEvent {
  final List<ImageItem> images;
  final ImageSettings settings;

  const StartImageConversion({
    required this.images,
    required this.settings,
  });

  @override
  List<Object?> get props => [images, settings];
}

/// Cancel ongoing conversion
class CancelImageConversion extends ImageConversionEvent {
  const CancelImageConversion();
}

/// Reset conversion state
class ResetImageConversion extends ImageConversionEvent {
  const ResetImageConversion();
}

/// Estimate output size
class EstimateImageSize extends ImageConversionEvent {
  final List<ImageItem> images;
  final ImageSettings settings;

  const EstimateImageSize({
    required this.images,
    required this.settings,
  });

  @override
  List<Object?> get props => [images, settings];
}
