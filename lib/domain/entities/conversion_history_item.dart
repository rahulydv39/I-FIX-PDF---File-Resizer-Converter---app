/// Conversion History Item
/// Model for a single conversion history entry stored in SQLite
library;

/// Type of converted file
enum ConversionFileType {
  image,
  pdf,
}

/// Represents a single conversion history entry
class ConversionHistoryItem {
  /// Auto-incremented database ID
  final int? id;

  /// Name of the output file (e.g. IMG_20260219_120000.png)
  final String fileName;

  /// Full path to the file on disk
  final String filePath;

  /// Type of file: image or pdf
  final ConversionFileType fileType;

  /// When the conversion happened
  final DateTime createdAt;

  /// File size in bytes
  final int fileSize;

  const ConversionHistoryItem({
    this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.createdAt,
    required this.fileSize,
  });

  /// Convert to a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileType': fileType == ConversionFileType.image ? 'image' : 'pdf',
      'createdAt': createdAt.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  /// Create from a SQLite row Map
  factory ConversionHistoryItem.fromMap(Map<String, dynamic> map) {
    return ConversionHistoryItem(
      id: map['id'] as int?,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      fileType: (map['fileType'] as String) == 'image'
          ? ConversionFileType.image
          : ConversionFileType.pdf,
      createdAt: DateTime.parse(map['createdAt'] as String),
      fileSize: map['fileSize'] as int,
    );
  }

  /// Human-readable file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Human-readable date (e.g. "19 Feb 2026, 12:00 PM")
  String get formattedDate {
    final d = createdAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$min $amPm';
  }

  /// File extension (e.g. "png", "pdf")
  String get extension => fileName.split('.').last.toLowerCase();
}
