/// Image Processor Service
/// Handles image resizing, quality adjustment, and DPI scaling
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/pdf_settings.dart';

/// Processed image ready for PDF generation
class ProcessedImage {
  /// Processed image bytes (encoded)
  final Uint8List bytes;

  /// Width after processing
  final int width;

  /// Height after processing
  final int height;

  /// Format of processed image
  final ImageFormat format;

  const ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });
}

/// Service for processing images before PDF generation
class ImageProcessorService {
  /// Process an image with the given settings
  ///
  /// Applies resizing, quality adjustment, and DPI scaling
  Future<ProcessedImage> processImage(
    ImageItem imageItem,
    PdfSettings settings,
  ) async {
    return compute(_processImageIsolated, {
      'path': imageItem.path,
      'format': imageItem.format,
      'settings': settings,
    });
  }

  /// Calculate dimensions based on DPI setting
  ///
  /// When DPI changes, we scale pixels accordingly:
  /// - Higher DPI = more pixels for same physical size
  /// - Formula: newPixels = originalPixels * (targetDPI / originalDPI)
  img.Image _applyDpiScaling(
    img.Image image,
    ImageItem originalItem,
    PdfSettings settings,
  ) {
    // Assume original images are at 72 DPI (standard screen resolution)
    const double originalDpi = 72.0;
    final double targetDpi = settings.effectiveDpi.toDouble();

    // If DPI is same as original, no scaling needed
    if (targetDpi == originalDpi) return image;

    // Calculate scale factor
    // Note: Higher DPI means we want MORE pixels, so we scale up
    // But for PDF, we typically want to keep physical size same,
    // which means we should scale down if DPI increases
    final double scaleFactor = originalDpi / targetDpi;

    final int newWidth = (image.width * scaleFactor).round();
    final int newHeight = (image.height * scaleFactor).round();

    // Only resize if dimensions actually change
    if (newWidth != image.width || newHeight != image.height) {
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    return image;
  }

  /// Apply custom dimensions with optional aspect ratio lock
  img.Image _applyCustomDimensions(img.Image image, PdfSettings settings) {
    final int? targetWidth = settings.targetWidth;
    final int? targetHeight = settings.targetHeight;

    // No custom dimensions specified
    if (targetWidth == null && targetHeight == null) {
      return image;
    }

    int newWidth = targetWidth ?? image.width;
    int newHeight = targetHeight ?? image.height;

    // Lock aspect ratio if enabled
    if (settings.lockAspectRatio) {
      final double aspectRatio = image.width / image.height;

      if (targetWidth != null && targetHeight == null) {
        // Width specified, calculate height
        newHeight = (targetWidth / aspectRatio).round();
      } else if (targetHeight != null && targetWidth == null) {
        // Height specified, calculate width
        newWidth = (targetHeight * aspectRatio).round();
      } else {
        // Both specified - fit within bounds while maintaining ratio
        final double widthRatio = targetWidth! / image.width;
        final double heightRatio = targetHeight! / image.height;
        final double ratio =
            widthRatio < heightRatio ? widthRatio : heightRatio;

        newWidth = (image.width * ratio).round();
        newHeight = (image.height * ratio).round();
      }
    }

    // Resize if dimensions changed
    if (newWidth != image.width || newHeight != image.height) {
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    return image;
  }

  /// Encode image to bytes with quality setting
  Uint8List _encodeImage(img.Image image, ImageFormat format, int quality) {
    switch (format) {
      case ImageFormat.jpg:
      case ImageFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageFormat.png:
        // PNG doesn't have quality, it's lossless
        // But we can optimize by reducing colors for smaller size
        return Uint8List.fromList(img.encodePng(image));
      case ImageFormat.webp:
        // WebP encoding with quality
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageFormat.heic:
        // HEIC encoding fallback to JPEG
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
  }

  /// Estimate the output size of a processed image
  Future<int> estimateProcessedSize(
    ImageItem imageItem,
    PdfSettings settings,
  ) async {
    // Quick estimation without full processing
    // Based on: size ≈ width × height × bytesPerPixel × qualityFactor

    double scaleFactor = 72.0 / settings.effectiveDpi.toDouble();
    int estimatedWidth = (imageItem.width * scaleFactor).round();
    int estimatedHeight = (imageItem.height * scaleFactor).round();

    // Apply custom dimensions if specified
    if (settings.targetWidth != null) {
      estimatedWidth = settings.targetWidth!;
    }
    if (settings.targetHeight != null) {
      estimatedHeight = settings.targetHeight!;
    }

    // JPEG compression ratios (approximate)
    // Quality 100 ≈ 1:4 compression
    // Quality 80 ≈ 1:10 compression
    // Quality 50 ≈ 1:20 compression
    double compressionRatio;
    if (settings.quality >= 90) {
      compressionRatio = 0.25;
    } else if (settings.quality >= 70) {
      compressionRatio = 0.10;
    } else if (settings.quality >= 50) {
      compressionRatio = 0.05;
    } else {
      compressionRatio = 0.03;
    }

    // Estimate: width × height × 3 (RGB) × compression ratio
    int estimatedBytes =
        (estimatedWidth * estimatedHeight * 3 * compressionRatio).round();

    return estimatedBytes;
  }
}

/// Exception thrown when image processing fails
class ImageProcessorException implements Exception {
  final String message;
  ImageProcessorException(this.message);

  @override
  String toString() => 'ImageProcessorException: $message';
}

/// Top level function for isolate processing
Future<ProcessedImage> _processImageIsolated(Map<String, dynamic> args) async {
  final String path = args['path'];
  final ImageFormat format = args['format'];
  final PdfSettings settings = args['settings'];

  final file = File(path);
  final bytes = file.readAsBytesSync();
  img.Image? image = img.decodeImage(bytes);

  if (image == null) {
    throw ImageProcessorException('Failed to decode image: $path');
  }

  // Apply DPI scaling
  const double originalDpi = 72.0;
  final double targetDpi = settings.effectiveDpi.toDouble();

  if (targetDpi != originalDpi) {
    final double scaleFactor = originalDpi / targetDpi;
    final int newWidth = (image.width * scaleFactor).round();
    final int newHeight = (image.height * scaleFactor).round();

    if (newWidth != image.width || newHeight != image.height) {
      image = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }
  }

 // Apply custom dimensions safely
final int? targetWidth = settings.targetWidth;
final int? targetHeight = settings.targetHeight;

// Ensure image dimensions are valid
final int originalWidth = image.width ?? 1;
final int originalHeight = image.height ?? 1;

if (targetWidth != null || targetHeight != null) {
  int newWidth = targetWidth ?? originalWidth;
  int newHeight = targetHeight ?? originalHeight;

  if (settings.lockAspectRatio) {
    final double aspectRatio = originalWidth / originalHeight;

    if (targetWidth != null && targetHeight == null) {
      newHeight = (targetWidth / aspectRatio).round();
    } else if (targetHeight != null && targetWidth == null) {
      newWidth = (targetHeight * aspectRatio).round();
    } else if (targetWidth != null && targetHeight != null) {
      // Scale proportionally
      final double widthRatio = targetWidth / originalWidth;
      final double heightRatio = targetHeight / originalHeight;
      final double ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

      newWidth = (originalWidth * ratio).round();
      newHeight = (originalHeight * ratio).round();
    }
  }

  // Prevent invalid dimensions
  newWidth = newWidth <= 0 ? 1 : newWidth;
  newHeight = newHeight <= 0 ? 1 : newHeight;

  // Resize only if needed
  if (newWidth != originalWidth || newHeight != originalHeight) {
    image = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }
}

  // Encode with quality setting
  Uint8List processedBytes;
  switch (format) {
    case ImageFormat.jpg:
    case ImageFormat.jpeg:
      processedBytes = Uint8List.fromList(img.encodeJpg(image, quality: settings.quality));
      break;
    case ImageFormat.png:
      processedBytes = Uint8List.fromList(img.encodePng(image));
      break;
    case ImageFormat.webp:
      processedBytes = Uint8List.fromList(img.encodeJpg(image, quality: settings.quality));
      break;
    case ImageFormat.heic:
      processedBytes = Uint8List.fromList(img.encodeJpg(image, quality: settings.quality));
      break;
  }

  return ProcessedImage(
    bytes: processedBytes,
    width: image.width,
    height: image.height,
    format: format,
  );
}
