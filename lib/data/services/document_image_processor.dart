import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum DocumentFilter { original, grayscale, blackAndWhite, enhanced }

class DocumentImageProcessor {
  Future<Uint8List> applyFilter(String imagePath, DocumentFilter filter) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    switch (filter) {
      case DocumentFilter.original:
        return Uint8List.fromList(img.encodeJpg(image, quality: 90));
      case DocumentFilter.grayscale:
        img.Image grayscaleImage = img.grayscale(image);
        return Uint8List.fromList(img.encodeJpg(grayscaleImage, quality: 90));
      case DocumentFilter.blackAndWhite:
        img.Image bwImage = img.luminanceThreshold(image, threshold: 0.6);
        return Uint8List.fromList(img.encodeJpg(bwImage, quality: 90));
      case DocumentFilter.enhanced:
        // Adjust brightness and contrast
        img.Image enhancedImage = img.adjustColor(
          image,
          brightness: 1.2,
          contrast: 1.2,
        );
        return Uint8List.fromList(img.encodeJpg(enhancedImage, quality: 90));
    }
  }
}
