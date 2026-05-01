/// PDF Merge Service
/// Handles PDF file merging operations
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../domain/entities/pdf_merge_settings.dart';
import '../../core/utils/target_size_optimizer.dart';
import 'file_export_service.dart';
import 'dart:ui';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

/// Result of a PDF merge operation
class PdfMergeResult {
  /// Output file path
  final String outputPath;

  /// Total size of merged PDF
  final int totalSize;

  /// Number of PDFs merged
  final int pdfCount;

  /// Total pages in merged PDF
  final int totalPages;

  /// Processing time in milliseconds
  final int processingTimeMs;

  const PdfMergeResult({
    required this.outputPath,
    required this.totalSize,
    required this.pdfCount,
    required this.totalPages,
    required this.processingTimeMs,
  });

  /// Get formatted output size
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Get formatted processing time
  String get formattedTime {
    if (processingTimeMs < 1000) return '${processingTimeMs}ms';
    return '${(processingTimeMs / 1000).toStringAsFixed(1)}s';
  }
}

/// Service for handling PDF operations
class PdfMergeService {
  final FileExportService _exportService;

  PdfMergeService({FileExportService? exportService})
    : _exportService = exportService ?? FileExportService();

  /// Pick PDF files from device
  Future<List<PdfItem>> pickPdfFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result == null) return [];

    final items = <PdfItem>[];
    for (final file in result.files) {
      if (file.path != null) {
        final stat = await File(file.path!).stat();
        items.add(PdfItem(path: file.path!, name: file.name, size: stat.size));
      }
    }

    return items;
  }

  /// Merge multiple PDFs into one
  /// With target size optimization when enabled
  Future<PdfMergeResult> mergePdfs({
    required List<PdfItem> pdfs,
    required PdfMergeSettings settings,
    Function(double)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Create a temp directory for intermediate work
    int totalPages = getTotalPages(pdfs);

    // Generate a UNIQUE filename every time using millisecond epoch to prevent
    // consecutive merges from overwriting each other.
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String filename;
    if (settings.customFileName != null &&
        settings.customFileName!.isNotEmpty) {
      final base = settings.customFileName!.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      filename = '${base}_$timestamp.pdf';
    } else {
      filename = 'PDF_$timestamp.pdf';
    }

    print('Output path (filename): $filename');

    // Create new PDF document
    final PdfDocument mergedDocument = PdfDocument();

    if (settings.enableSizeTarget) {
      mergedDocument.compressionLevel = PdfCompressionLevel.best;
      mergedDocument.documentInformation.author = '';
      mergedDocument.documentInformation.creator =
          'I FIX PDF'; // Standardize creator minimally
      mergedDocument.documentInformation.producer = '';
      mergedDocument.documentInformation.title = '';
      mergedDocument.documentInformation.subject = '';
      mergedDocument.documentInformation.keywords = '';
    }

    for (int i = 0; i < pdfs.length; i++) {
      final pdf = pdfs[i];
      final file = File(pdf.path);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final PdfDocument loadedDocument = PdfDocument(inputBytes: bytes);

        // Append all pages from loaded document
        for (int j = 0; j < loadedDocument.pages.count; j++) {
          final PdfPage loadedPage = loadedDocument.pages[j];
          final PdfPage addedPage = mergedDocument.pages.add();
          // Copy page size and add template
          addedPage.graphics.drawPdfTemplate(
            loadedPage.createTemplate(),
            Offset(0, 0),
          );
        }
        loadedDocument.dispose();
      }

      onProgress?.call((i + 1) / pdfs.length);
    }

    final List<int> mergedBytes = mergedDocument.saveSync();
    mergedDocument.dispose();

    // ── Apply target size if requested ──────────────────────────────────
    Uint8List finalBytes = Uint8List.fromList(mergedBytes);

    if (settings.enableSizeTarget &&
        settings.targetSizeBytes != null &&
        settings.targetSizeBytes! > 0) {
      final targetKB = settings.targetSizeBytes! ~/ 1024;
      print(
        '🎯 PDF MERGE: applying TargetSizeOptimizer → target ${targetKB} KB',
      );
      print(
        '   Merged size before optimization: ${(finalBytes.length / 1024).toStringAsFixed(1)} KB',
      );

      try {
        final compressedDoc = pw.Document();
        final pageCount = totalPages; // rough estimate
        final targetKBPerPage =
            (targetKB / (pageCount > 0 ? pageCount : 1))
                .clamp(10.0, 10000.0)
                .toInt();

        await for (final page in Printing.raster(finalBytes, dpi: 72)) {
          final pngBytes = await page.toPng();

          final compressedImageBytes =
              await TargetSizeOptimizer.processTargetSize(
                inputBytes: pngBytes,
                targetKB: targetKBPerPage,
                useTargetSize: true,
              );

          final pdfImage = pw.MemoryImage(compressedImageBytes);
          compressedDoc.addPage(
            pw.Page(
              margin: pw.EdgeInsets.zero,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                );
              },
            ),
          );
        }
        finalBytes = await compressedDoc.save();
        print(
          '   Merged size after optimization: ${(finalBytes.length / 1024).toStringAsFixed(1)} KB',
        );
      } catch (e) {
        print('⚠️ Failed to compress PDF images: $e');
      }
    }

    final exportedFile = await _exportService.exportFile(
      bytes: finalBytes,
      filename: filename,
      mimeType: 'application/pdf',
      fileType: ExportFileType.pdf,
    );

    stopwatch.stop();

    print('✅ PDF Merge exported to: ${exportedFile.path}');
    print('   Size: ${exportedFile.sizeBytes} bytes');
    print('   File exists: ${File(exportedFile.path).existsSync()}');

    return PdfMergeResult(
      outputPath: exportedFile.path,
      totalSize: exportedFile.sizeBytes,
      pdfCount: pdfs.length,
      totalPages: totalPages,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Estimate merged PDF size
  int estimateMergedSize(List<PdfItem> pdfs) {
    return pdfs.fold(0, (sum, pdf) => sum + pdf.size);
  }

  /// Get total page count
  int getTotalPages(List<PdfItem> pdfs) {
    return pdfs.fold(0, (sum, pdf) => sum + (pdf.pageCount ?? 1));
  }
}
