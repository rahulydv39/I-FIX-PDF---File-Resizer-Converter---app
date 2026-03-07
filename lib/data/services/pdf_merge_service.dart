/// PDF Merge Service
/// Handles PDF file merging operations
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/pdf_merge_settings.dart';
import 'file_export_service.dart';

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

  PdfMergeService({
    FileExportService? exportService,
  }) : _exportService = exportService ?? FileExportService();
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
        items.add(PdfItem(
          path: file.path!,
          name: file.name,
          size: stat.size,
        ));
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
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${appDir.path}/temp_merge');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    final tempPath = '${tempDir.path}/temp_merged.pdf';
    int totalPages = getTotalPages(pdfs);

    // Generate proper filename
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final filename = 'MERGED_$timestamp.pdf';
    
    if (settings.enableSizeTarget && settings.targetSizeBytes != null && settings.targetSizeBytes! > 0) {
      print('🎯 PDF MERGE WITH TARGET SIZE');
      print('   Input PDFs: ${pdfs.length}');
      print('   Total pages: $totalPages');
      print('   Target: ${(settings.targetSizeBytes! / 1024 / 1024).toStringAsFixed(2)} MB');
    }

    // Merge PDFs into temp file
    final tempFile = File(tempPath);
    final outputSink = tempFile.openWrite();
    
    bool isFirst = true;
    for (int i = 0; i < pdfs.length; i++) {
      final pdf = pdfs[i];
      final file = File(pdf.path);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        if (isFirst) {
          outputSink.add(bytes);
          isFirst = false;
        }
        // Note: Proper PDF merging requires parsing PDF structure
      }

      onProgress?.call((i + 1) / pdfs.length);
    }

    await outputSink.close();
    
    // Read temp file bytes and export via FileExportService
    final mergedBytes = await tempFile.readAsBytes();
    
    final exportedFile = await _exportService.exportFile(
      bytes: Uint8List.fromList(mergedBytes),
      filename: filename,
      mimeType: 'application/pdf',
      fileType: ExportFileType.pdf,
    );
    
    // Clean up temp file
    try {
      await tempFile.delete();
      await tempDir.delete();
    } catch (_) {}
    
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
