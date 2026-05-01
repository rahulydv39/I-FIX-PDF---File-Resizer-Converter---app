/// File Export Service
/// Centralized service for exporting files with proper platform-specific handling
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Exported file information
class ExportedFile {
  /// Full file path (always accessible to the app)
  final String path;

  /// File size in bytes
  final int sizeBytes;

  /// MIME type
  final String mimeType;

  /// Whether file was published to MediaStore (Android only)
  final bool addedToMediaStore;

  const ExportedFile({
    required this.path,
    required this.sizeBytes,
    required this.mimeType,
    this.addedToMediaStore = false,
  });

  /// Get formatted file size
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Get file extension
  String get extension => path.split('.').last;
}

/// File type for categorizing exports
enum ExportFileType {
  image,
  pdf,
  scanned,
}

/// Service for handling file exports with platform-specific optimizations
class FileExportService {
  /// Export a file with proper platform-specific handling.
  ///
  /// Strategy:
  ///   Android — write to app-private external storage
  ///             (`getExternalStorageDirectory()` → always writable, no
  ///             MANAGE_EXTERNAL_STORAGE needed), then publish a copy to
  ///             MediaStore so the file appears in Downloads / Gallery.
  ///   iOS     — write to app Documents directory, then the user can access
  ///             via Files app.
  ///
  /// Returns an [ExportedFile] whose [path] is always readable by the app
  /// (for Open / Share).
  Future<ExportedFile> exportFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    ExportFileType fileType = ExportFileType.image,
    String? subFolder,
  }) async {
    print('📁 EXPORTING FILE: $filename');
    print('   MIME: $mimeType');
    print('   Bytes: ${bytes.length} (${(bytes.length / 1024).toStringAsFixed(1)} KB)');

    // ── STEP 1: Resolve writable directory ──────────────────────────────────
    final directory = await _getWritableDirectory(fileType, subFolder);
    print('   Dir: $directory');

    // ── STEP 2: Create directory if needed ──────────────────────────────────
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('   📁 Created directory: $directory');
    }

    // ── STEP 3: Write file ───────────────────────────────────────────────────
    final path = '$directory/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    // ── STEP 4: Verify file exists and is non-empty ──────────────────────────
    if (!await file.exists()) {
      throw ExportException('File write failed — file does not exist: $path');
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      throw ExportException('File write failed — file is empty: $path');
    }

    if (fileSize != bytes.length) {
      print('   ⚠️  Written size ($fileSize) != expected (${bytes.length}) — continuing');
    }

    print('   ✅ File exists: true');
    print('   ✅ File size:   $fileSize bytes');
    print('   ✅ Saved path:  $path');

    // ── STEP 5: Publish to MediaStore (Android) ──────────────────────────────
    bool addedToMediaStore = false;
    if (Platform.isAndroid) {
      try {
        await _publishToMediaStore(path, mimeType, fileType, subFolder);
        addedToMediaStore = true;
        print('   ✅ Published to MediaStore');
      } catch (e) {
        // Non-fatal — file is still accessible via its direct path
        print('   ⚠️  MediaStore publish failed (non-fatal): $e');
      }
    }

    // ── STEP 6: Re-verify file after MediaStore publish ──────────────────────
    // media_store_plus's saveFile(tempFilePath:) may move/delete the original
    // file. If that happened, re-write it so open/share always have a valid
    // file at the returned path.
    if (!await file.exists()) {
      print('   ⚠️  File was consumed by MediaStore — re-writing');
      await file.writeAsBytes(bytes, flush: true);
      print('   ✅ File re-written: ${await file.length()} bytes');
    }

    return ExportedFile(
      path: path,
      sizeBytes: fileSize,
      mimeType: mimeType,
      addedToMediaStore: addedToMediaStore,
    );
  }

  // ── Directory resolution ────────────────────────────────────────────────────

  /// Returns a directory path that is always writable by the app.
  ///
  /// Android: app-private external storage
  ///   `/storage/emulated/0/Android/data/<package>/files/FileConverter/<type>/`
  ///   No special permissions needed on any API level.
  ///
  /// iOS: app Documents directory (accessible via Files app).
  Future<String> _getWritableDirectory(ExportFileType fileType, [String? subFolder]) async {
    final folderName = _getFolderName(fileType);
    final relativePath = subFolder != null ? 'I_FIX_PDF/$folderName/$subFolder' : 'I_FIX_PDF/$folderName';

    if (Platform.isAndroid) {
      // getExternalStorageDirectory() returns the app-private external dir.
      // This is ALWAYS writable — no WRITE_EXTERNAL_STORAGE needed on API 29+.
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return '${externalDir.path}/$relativePath';
      }
      // Fallback: internal app documents (always writable)
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$relativePath';
    }

    if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$relativePath';
    }

    // Desktop / other
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  /// Public getter so callers can resolve the directory if needed.
  Future<String> getExportDirectory(ExportFileType fileType) =>
      _getWritableDirectory(fileType);

  String _getFolderName(ExportFileType fileType) {
    switch (fileType) {
      case ExportFileType.image:
      case ExportFileType.pdf:
        return 'Converted';
      case ExportFileType.scanned:
        return 'Scanner';
    }
  }

  // ── MediaStore ──────────────────────────────────────────────────────────────

  /// Publish the file to Android MediaStore so it appears in Downloads / Gallery.
  ///
  /// `MediaStore.saveFile()` copies the file from [filePath] into the
  /// MediaStore-managed location. The original file at [filePath] remains
  /// intact and is still usable by the app.
  Future<void> _publishToMediaStore(
    String filePath,
    String mimeType,
    ExportFileType fileType,
    [String? subFolder]
  ) async {
    if (!Platform.isAndroid) return;

    final mediaStore = MediaStore();
    final folderName = _getFolderName(fileType);
    final String relativeParam = subFolder != null ? 'I_FIX_PDF/$folderName/$subFolder' : 'I_FIX_PDF/$folderName';

    if (fileType == ExportFileType.image) {
      // Images → DCIM/I_FIX_PDF/Converted
      await mediaStore.saveFile(
        tempFilePath: filePath,
        dirType: DirType.photo,
        dirName: DirName.dcim,
        relativePath: relativeParam,
      );
    } else {
      // PDFs/docs → Download/I_FIX_PDF/Converted or Scanner
      await mediaStore.saveFile(
        tempFilePath: filePath,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: relativeParam,
      );
    }
  }

  // ── Gallery helper (kept for backward compat) ───────────────────────────────

  /// Save an already-exported image to the device gallery.
  Future<void> saveToGallery(String filePath, {bool isVideo = false}) async {
    try {
      if (Platform.isAndroid) {
        await _publishToMediaStore(filePath, 'image/jpeg', ExportFileType.image);
        print('✅ Saved to Android Gallery (MediaStore)');
      } else if (Platform.isIOS) {
        await Gal.putImage(filePath);
        print('✅ Saved to iOS Photos');
      }
    } catch (e) {
      print('❌ Failed to save to gallery: $e');
    }
  }

  // ── Open / Share ────────────────────────────────────────────────────────────

  /// Open a file using the system default app.
  ///
  /// [filePath] must be the path returned by [exportFile] — it is always
  /// accessible to the app without content:// URI conversion.
  Future<void> openFile(String filePath, {String? mimeType}) async {
    final file = File(filePath);

    if (!await file.exists()) {
      print('   ❌ File does not exist: $filePath');
      throw ExportException('File does not exist: $filePath');
    }

    final fileSize = await file.length();
    print('📂 Opening file: $filePath');
    print('   Size: $fileSize bytes');
    print('   MIME: ${mimeType ?? "auto-detect"}');

    final result = await OpenFilex.open(filePath, type: mimeType);
    print('   Open result: ${result.type} — ${result.message}');

    if (result.type != ResultType.done) {
      // Android 11+ FileUriExposedException is a known non-fatal warning
      if (result.message.contains('ClipData') ||
          result.message.contains('exposed beyond app')) {
        print('   ⚠️ Known Android 11+ URI warning — file may still open');
      } else {
        throw ExportException('Failed to open file: ${result.message}');
      }
    }
  }

  /// Share multiple files using the system share sheet.
  Future<void> shareFiles(List<String> filePaths, {String? mimeType}) async {
    final xFiles = <XFile>[];

    for (final filePath in filePaths) {
      final file = File(filePath);
      if (await file.exists()) {
        xFiles.add(XFile(filePath, mimeType: mimeType));
        print('   📎 Queued for share: $filePath (${file.lengthSync()} bytes)');
      } else {
        print('   ⚠️ File to share does not exist: $filePath');
      }
    }

    if (xFiles.isEmpty) {
      throw ExportException('No valid files to share');
    }

    print('📤 Sharing ${xFiles.length} file(s)');

    await Share.shareXFiles(
      xFiles,
      text: xFiles.length > 1
          ? 'Here are my converted files!'
          : 'Here is my converted file!',
    );
  }
}

/// Exception for export-related errors
class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => 'ExportException: $message';
}
