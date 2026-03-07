/// Image Repository Interface
/// Defines the contract for image operations
library;

import '../entities/image_item.dart';

/// Repository interface for image operations
abstract class ImageRepository {
  /// Pick a single image from gallery
  Future<ImageItem?> pickSingleImage();

  /// Pick multiple images from gallery
  Future<List<ImageItem>> pickMultipleImages();

  /// Get image metadata from file path
  Future<ImageItem?> getImageMetadata(String path);

  /// Delete temporary images
  Future<void> clearTemporaryImages();

  /// Reorder images in the list
  List<ImageItem> reorderImages(
    List<ImageItem> images,
    int oldIndex,
    int newIndex,
  );
}
