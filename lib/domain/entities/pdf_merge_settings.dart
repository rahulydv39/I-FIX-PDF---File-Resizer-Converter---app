/// PDF Merge Settings Entity
/// Configuration for PDF merge operations
library;

import 'package:equatable/equatable.dart';

/// Settings for PDF merge operations
class PdfMergeSettings extends Equatable {
  /// Whether to enable target size optimization
  final bool enableSizeTarget;

  /// Target size in bytes
  final int? targetSizeBytes;

  /// Whether to include bookmarks
  final bool includeBookmarks;

  /// Whether to maintain page order (vs interleaved)
  final bool maintainOrder;

  /// Custom file name for merged PDF
  final String? customFileName;

  const PdfMergeSettings({
    this.enableSizeTarget = false,
    this.targetSizeBytes,
    this.includeBookmarks = true,
    this.maintainOrder = true,
    this.customFileName,
  });

  /// Create a copy with updated values
  PdfMergeSettings copyWith({
    bool? enableSizeTarget,
    int? targetSizeBytes,
    bool? includeBookmarks,
    bool? maintainOrder,
    String? customFileName,
  }) {
    return PdfMergeSettings(
      enableSizeTarget: enableSizeTarget ?? this.enableSizeTarget,
      targetSizeBytes: targetSizeBytes ?? this.targetSizeBytes,
      includeBookmarks: includeBookmarks ?? this.includeBookmarks,
      maintainOrder: maintainOrder ?? this.maintainOrder,
      customFileName: customFileName ?? this.customFileName,
    );
  }

  @override
  List<Object?> get props => [
        enableSizeTarget,
        targetSizeBytes,
        includeBookmarks,
        maintainOrder,
        customFileName,
      ];
}

/// Represents a selected PDF file
class PdfItem extends Equatable {
  /// File path
  final String path;

  /// File name
  final String name;

  /// File size in bytes
  final int size;

  /// Number of pages (if known)
  final int? pageCount;

  const PdfItem({
    required this.path,
    required this.name,
    required this.size,
    this.pageCount,
  });

  /// Get formatted file size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  List<Object?> get props => [path, name, size, pageCount];
}
