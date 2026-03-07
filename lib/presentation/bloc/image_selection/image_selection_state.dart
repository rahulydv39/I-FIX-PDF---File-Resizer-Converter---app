/// Image Selection BLoC States
/// Defines all states for image selection state management
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/image_item.dart';

/// Status of image selection operations
enum ImageSelectionStatus {
  /// Initial state, no images loaded
  initial,

  /// Currently picking images
  loading,

  /// Images loaded successfully
  loaded,

  /// Error occurred during image picking
  error,
}

/// State class for image selection
class ImageSelectionState extends Equatable {
  /// Current status
  final ImageSelectionStatus status;

  /// List of selected images
  final List<ImageItem> images;

  /// Set of selected image IDs (for multi-select)
  final Set<String> selectedIds;

  /// Error message if status is error
  final String? errorMessage;

  /// Whether image picking is in progress
  final bool isPickingImages;

  const ImageSelectionState({
    this.status = ImageSelectionStatus.initial,
    this.images = const [],
    this.selectedIds = const {},
    this.errorMessage,
    this.isPickingImages = false,
  });

  /// Check if there are any images selected
  bool get hasImages => images.isNotEmpty;

  /// Get the number of images
  int get imageCount => images.length;

  /// Get total size of all images in bytes
  int get totalSizeBytes {
    return images.fold(0, (sum, img) => sum + img.sizeBytes);
  }

  /// Get formatted total size
  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if all images are selected
  bool get allSelected =>
      images.isNotEmpty && selectedIds.length == images.length;

  /// Check if any images are selected (for multi-select operations)
  bool get hasSelection => selectedIds.isNotEmpty;

  /// Get selected images
  List<ImageItem> get selectedImages {
    return images.where((img) => selectedIds.contains(img.id)).toList();
  }

  /// Initial state factory
  static const ImageSelectionState initial = ImageSelectionState();

  /// Create a copy with updated values
  ImageSelectionState copyWith({
    ImageSelectionStatus? status,
    List<ImageItem>? images,
    Set<String>? selectedIds,
    String? errorMessage,
    bool? isPickingImages,
  }) {
    return ImageSelectionState(
      status: status ?? this.status,
      images: images ?? this.images,
      selectedIds: selectedIds ?? this.selectedIds,
      errorMessage: errorMessage,
      isPickingImages: isPickingImages ?? this.isPickingImages,
    );
  }

  @override
  List<Object?> get props => [
        status,
        images,
        selectedIds,
        errorMessage,
        isPickingImages,
      ];
}
