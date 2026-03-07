/// Image Selection BLoC
/// Manages image selection, ordering, and preview state
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/image_picker_service.dart';
import '../../../domain/entities/image_item.dart';
import 'image_selection_event.dart';
import 'image_selection_state.dart';

/// BLoC for managing image selection and ordering
class ImageSelectionBloc
    extends Bloc<ImageSelectionEvent, ImageSelectionState> {
  final ImagePickerService _imagePickerService;

  ImageSelectionBloc({
    ImagePickerService? imagePickerService,
  })  : _imagePickerService = imagePickerService ?? ImagePickerService(),
        super(ImageSelectionState.initial) {
    // Register event handlers
    on<PickSingleImage>(_onPickSingleImage);
    on<PickMultipleImages>(_onPickMultipleImages);
    on<AddImages>(_onAddImages);
    on<RemoveImage>(_onRemoveImage);
    on<ReorderImages>(_onReorderImages);
    on<ClearImages>(_onClearImages);
    on<ToggleImageSelection>(_onToggleImageSelection);
    on<SelectAllImages>(_onSelectAllImages);
    on<DeselectAllImages>(_onDeselectAllImages);
  }

  /// Handle single image picking
  Future<void> _onPickSingleImage(
    PickSingleImage event,
    Emitter<ImageSelectionState> emit,
  ) async {
    emit(state.copyWith(
      status: ImageSelectionStatus.loading,
      isPickingImages: true,
    ));

    try {
      final image = await _imagePickerService.pickSingleImage();

      if (image != null) {
        final updatedImages = [...state.images, image];
        // Update order indices
        final reindexed = _reindexImages(updatedImages);

        emit(state.copyWith(
          status: ImageSelectionStatus.loaded,
          images: reindexed,
          isPickingImages: false,
        ));
      } else {
        // User cancelled
        emit(state.copyWith(
          status: state.hasImages
              ? ImageSelectionStatus.loaded
              : ImageSelectionStatus.initial,
          isPickingImages: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ImageSelectionStatus.error,
        errorMessage: e.toString(),
        isPickingImages: false,
      ));
    }
  }

  /// Handle multiple image picking
  Future<void> _onPickMultipleImages(
    PickMultipleImages event,
    Emitter<ImageSelectionState> emit,
  ) async {
    emit(state.copyWith(
      status: ImageSelectionStatus.loading,
      isPickingImages: true,
    ));

    try {
      final images = await _imagePickerService.pickMultipleImages();

      if (images.isNotEmpty) {
        final updatedImages = [...state.images, ...images];
        // Update order indices
        final reindexed = _reindexImages(updatedImages);

        emit(state.copyWith(
          status: ImageSelectionStatus.loaded,
          images: reindexed,
          isPickingImages: false,
        ));
      } else {
        // User cancelled or no images selected
        emit(state.copyWith(
          status: state.hasImages
              ? ImageSelectionStatus.loaded
              : ImageSelectionStatus.initial,
          isPickingImages: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ImageSelectionStatus.error,
        errorMessage: e.toString(),
        isPickingImages: false,
      ));
    }
  }

  /// Handle adding images to existing selection
  void _onAddImages(
    AddImages event,
    Emitter<ImageSelectionState> emit,
  ) {
    final updatedImages = [...state.images, ...event.images];
    final reindexed = _reindexImages(updatedImages);

    emit(state.copyWith(
      status: ImageSelectionStatus.loaded,
      images: reindexed,
    ));
  }

  /// Handle removing an image
  void _onRemoveImage(
    RemoveImage event,
    Emitter<ImageSelectionState> emit,
  ) {
    final updatedImages =
        state.images.where((img) => img.id != event.imageId).toList();
    final reindexed = _reindexImages(updatedImages);

    // Also remove from selected IDs
    final updatedSelectedIds = Set<String>.from(state.selectedIds)
      ..remove(event.imageId);

    emit(state.copyWith(
      status: updatedImages.isEmpty
          ? ImageSelectionStatus.initial
          : ImageSelectionStatus.loaded,
      images: reindexed,
      selectedIds: updatedSelectedIds,
    ));
  }

  /// Handle reordering images (drag and drop)
  void _onReorderImages(
    ReorderImages event,
    Emitter<ImageSelectionState> emit,
  ) {
    final reorderedImages = _imagePickerService.reorderImages(
      state.images,
      event.oldIndex,
      event.newIndex,
    );

    emit(state.copyWith(images: reorderedImages));
  }

  /// Handle clearing all images
  void _onClearImages(
    ClearImages event,
    Emitter<ImageSelectionState> emit,
  ) {
    emit(ImageSelectionState.initial);
  }

  /// Handle toggling individual image selection
  void _onToggleImageSelection(
    ToggleImageSelection event,
    Emitter<ImageSelectionState> emit,
  ) {
    final updatedSelectedIds = Set<String>.from(state.selectedIds);

    if (updatedSelectedIds.contains(event.imageId)) {
      updatedSelectedIds.remove(event.imageId);
    } else {
      updatedSelectedIds.add(event.imageId);
    }

    emit(state.copyWith(selectedIds: updatedSelectedIds));
  }

  /// Handle selecting all images
  void _onSelectAllImages(
    SelectAllImages event,
    Emitter<ImageSelectionState> emit,
  ) {
    final allIds = state.images.map((img) => img.id).toSet();
    emit(state.copyWith(selectedIds: allIds));
  }

  /// Handle deselecting all images
  void _onDeselectAllImages(
    DeselectAllImages event,
    Emitter<ImageSelectionState> emit,
  ) {
    emit(state.copyWith(selectedIds: {}));
  }

  /// Reindex images to ensure consecutive order indices
  List<ImageItem> _reindexImages(List<ImageItem> images) {
    return images.asMap().entries.map((entry) {
      return entry.value.copyWithOrder(entry.key);
    }).toList();
  }
}
