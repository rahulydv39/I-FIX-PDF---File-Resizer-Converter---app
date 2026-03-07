/// Conversion Mode Entity
/// Defines the type of conversion - PDF or Image
library;

/// Types of conversion available in the app
enum ConversionType {
  /// Convert images to PDF document
  imageToPdf,

  /// Convert/resize images to other image formats
  imageToImage,

  /// Merge multiple PDFs into one
  pdfMerge,
}

/// Conversion mode with display information
class ConversionMode {
  /// Type of conversion
  final ConversionType type;

  /// Display name
  final String name;

  /// Description
  final String description;

  /// Icon name (for UI)
  final String iconName;

  const ConversionMode({
    required this.type,
    required this.name,
    required this.description,
    required this.iconName,
  });

  /// Predefined PDF conversion mode
  static const imageToPdf = ConversionMode(
    type: ConversionType.imageToPdf,
    name: 'Photo to PDF',
    description: 'Convert images to PDF document',
    iconName: 'picture_as_pdf',
  );

  /// Predefined Image conversion mode
  static const imageToImage = ConversionMode(
    type: ConversionType.imageToImage,
    name: 'Photo to Photo',
    description: 'Resize, compress & convert images',
    iconName: 'photo_size_select_large',
  );

  /// Predefined PDF Merge mode
  static const pdfMerge = ConversionMode(
    type: ConversionType.pdfMerge,
    name: 'PDF Merge',
    description: 'Merge multiple PDFs into one',
    iconName: 'merge_type',
  );

  /// All available modes
  static const List<ConversionMode> all = [imageToPdf, imageToImage, pdfMerge];
}

