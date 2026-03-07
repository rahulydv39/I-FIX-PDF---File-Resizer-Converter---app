/// Image Picker Service
/// Handles image selection from device gallery using image_picker package
library;

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../../domain/entities/image_item.dart';
import 'heic_converter_service.dart';

/// Service for picking and loading images from device
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  final HeicConverterService _heicConverter;

  ImagePickerService({
    HeicConverterService? heicConverter,
  }) : _heicConverter = heicConverter ?? HeicConverterService();

  /// Pick a single image from gallery
  ///
  /// Returns [ImageItem] with metadata if successful, null if cancelled
  Future<ImageItem?> pickSingleImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Don't compress on pick
      );

      if (file == null) return null;

      return await _createImageItem(file.path);
    } catch (e) {
      throw ImagePickerException('Failed to pick image: $e');
    }
  }

  /// Pick multiple images from gallery
  ///
  /// Returns list of [ImageItem] with metadata
  Future<List<ImageItem>> pickMultipleImages() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage(
        imageQuality: 100, // Don't compress on pick
      );

      if (files.isEmpty) return [];

      final List<ImageItem> items = [];
      for (int i = 0; i < files.length; i++) {
        final item = await _createImageItem(files[i].path, orderIndex: i);
        if (item != null) {
          items.add(item);
        }
      }

      return items;
    } catch (e) {
      throw ImagePickerException('Failed to pick images: $e');
    }
  }

  /// Create an ImageItem from file path with metadata
  Future<ImageItem?> _createImageItem(
    String path, {
    int orderIndex = 0,
  }) async {
    try {
      final originalFile = File(path);
      if (!await originalFile.exists()) return null;

      // STEP 1: Convert HEIC to JPEG if needed
      final processableFile = await _heicConverter.convertHeicToProcessable(originalFile);
      final finalPath = processableFile.path;

      // Get file size (of the processable file)
      final int sizeBytes = await processableFile.length();

      // Decode image to get dimensions
      final bytes = await processableFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        throw ImagePickerException('Failed to decode image: $finalPath');
      }

      // Determine format from extension
      final format = _getImageFormat(finalPath);

      return ImageItem(
        id: _uuid.v4(),
        path: finalPath,
        width: decodedImage.width,
        height: decodedImage.height,
        sizeBytes: sizeBytes,
        format: format,
        orderIndex: orderIndex,
      );
    } catch (e) {
      throw ImagePickerException('Failed to create image item: $e');
    }
  }

  /// Determine image format from file extension
  ImageFormat _getImageFormat(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
        return ImageFormat.jpg;
      case 'jpeg':
        return ImageFormat.jpeg;
      case 'png':
        return ImageFormat.png;
      case 'webp':
        return ImageFormat.webp;
      case 'heic':
        return ImageFormat.heic;
      default:
        return ImageFormat.jpg; // Default fallback
    }
  }

  /// Reorder images in list (for drag & drop)
  ///
  /// Returns new list with updated order indices
  List<ImageItem> reorderImages(
    List<ImageItem> images,
    int oldIndex,
    int newIndex,
  ) {
    // Adjust index for removal
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final List<ImageItem> reorderedList = List.from(images);
    final ImageItem item = reorderedList.removeAt(oldIndex);
    reorderedList.insert(newIndex, item);

    // Update order indices
    return reorderedList.asMap().entries.map((entry) {
      return entry.value.copyWithOrder(entry.key);
    }).toList();
  }
}

/// Exception thrown when image picking fails
class ImagePickerException implements Exception {
  final String message;
  ImagePickerException(this.message);

  @override
  String toString() => 'ImagePickerException: $message';
}
