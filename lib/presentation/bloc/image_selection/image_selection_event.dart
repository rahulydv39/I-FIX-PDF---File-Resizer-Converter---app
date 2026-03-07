/// Image Selection BLoC Events
/// Defines all events for image selection state management
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/image_item.dart';

/// Base class for image selection events
abstract class ImageSelectionEvent extends Equatable {
  const ImageSelectionEvent();

  @override
  List<Object?> get props => [];
}

/// Pick single image from gallery
class PickSingleImage extends ImageSelectionEvent {
  const PickSingleImage();
}

/// Pick multiple images from gallery
class PickMultipleImages extends ImageSelectionEvent {
  const PickMultipleImages();
}

/// Add images to existing selection
class AddImages extends ImageSelectionEvent {
  final List<ImageItem> images;

  const AddImages(this.images);

  @override
  List<Object?> get props => [images];
}

/// Remove an image from selection
class RemoveImage extends ImageSelectionEvent {
  final String imageId;

  const RemoveImage(this.imageId);

  @override
  List<Object?> get props => [imageId];
}

/// Reorder images via drag and drop
class ReorderImages extends ImageSelectionEvent {
  final int oldIndex;
  final int newIndex;

  const ReorderImages({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Clear all selected images
class ClearImages extends ImageSelectionEvent {
  const ClearImages();
}

/// Select/deselect an image (for multi-select operations)
class ToggleImageSelection extends ImageSelectionEvent {
  final String imageId;

  const ToggleImageSelection(this.imageId);

  @override
  List<Object?> get props => [imageId];
}

/// Select all images
class SelectAllImages extends ImageSelectionEvent {
  const SelectAllImages();
}

/// Deselect all images
class DeselectAllImages extends ImageSelectionEvent {
  const DeselectAllImages();
}
