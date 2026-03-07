/// Image Item Entity
/// Represents a selected image in the conversion queue
library;

import 'package:equatable/equatable.dart';

/// Supported image formats for conversion
enum ImageFormat { jpg, jpeg, png, webp, heic }

/// Entity representing a selected image
///
/// Contains metadata about the image including its path, dimensions,
/// file size, and order in the conversion queue.
class ImageItem extends Equatable {
  /// Unique identifier for the image
  final String id;

  /// Absolute file path to the image
  final String path;

  /// Image width in pixels
  final int width;

  /// Image height in pixels
  final int height;

  /// File size in bytes
  final int sizeBytes;

  /// Image format (jpg, png, webp)
  final ImageFormat format;

  /// Order index in the PDF (determines page order)
  final int orderIndex;

  /// Optional thumbnail path for faster preview loading
  final String? thumbnailPath;

  const ImageItem({
    required this.id,
    required this.path,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.format,
    required this.orderIndex,
    this.thumbnailPath,
  });

  /// Creates a copy with updated order index
  ImageItem copyWithOrder(int newIndex) {
    return ImageItem(
      id: id,
      path: path,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
      format: format,
      orderIndex: newIndex,
      thumbnailPath: thumbnailPath,
    );
  }

  /// Creates a copy with optional parameter overrides
  ImageItem copyWith({
    String? id,
    String? path,
    int? width,
    int? height,
    int? sizeBytes,
    ImageFormat? format,
    int? orderIndex,
    String? thumbnailPath,
  }) {
    return ImageItem(
      id: id ?? this.id,
      path: path ?? this.path,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      format: format ?? this.format,
      orderIndex: orderIndex ?? this.orderIndex,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  /// File name extracted from path
  String get fileName => path.split('/').last;

  /// File size formatted as human-readable string
  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Dimensions formatted as WxH string
  String get formattedDimensions => '${width}x$height';

  /// Aspect ratio of the image
  double get aspectRatio => width / height;

  @override
  List<Object?> get props => [
        id,
        path,
        width,
        height,
        sizeBytes,
        format,
        orderIndex,
        thumbnailPath,
      ];
}
