import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

import 'scanner_event.dart';
import 'scanner_state.dart';
import '../../../data/services/document_service.dart';
import '../../../data/services/ocr_service.dart';
import '../../../data/services/document_image_processor.dart';
import '../../../data/services/pdf_generator_service.dart';
import '../../../data/services/file_export_service.dart';
import '../../../domain/entities/image_item.dart';
import '../../../domain/entities/pdf_settings.dart';
import '../../../domain/entities/document_model.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final DocumentService _documentService;
  final OCRService _ocrService;
  final DocumentImageProcessor _imageProcessor;
  final PdfGeneratorService _pdfGeneratorService;

  ScannerBloc(
    this._documentService,
    this._ocrService,
    this._imageProcessor,
    this._pdfGeneratorService,
  ) : super(ScannerInitial()) {
    on<StartScanEvent>(_onStartScan);
    on<ScanCompletedEvent>(_onScanCompleted);
    on<ApplyFilterEvent>(_onApplyFilter);
    on<SaveDocumentEvent>(_onSaveDocument);
    on<LoadDocumentsEvent>(_onLoadDocuments);
    on<SearchDocumentsEvent>(_onSearchDocuments);
    on<DeleteDocumentEvent>(_onDeleteDocument);
    on<RenameDocumentEvent>(_onRenameDocument);
    on<MoveToFolderEvent>(_onMoveToFolder);
    on<LoadFoldersEvent>(_onLoadFolders);
    on<CreateFolderEvent>(_onCreateFolder);
    on<DeleteFolderEvent>(_onDeleteFolder);
  }

  // ── Scanning ─────────────────────────────────────────────────────

  Future<void> _onStartScan(
      StartScanEvent event, Emitter<ScannerState> emit) async {
    try {
      // Permission is verified by the UI layer (ScanCaptureScreen)
      // before this event is dispatched — no permission logic here.
      final pictures = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
      );
      if (pictures != null && pictures.isNotEmpty) {
        add(ScanCompletedEvent(pictures));
      } else {
        emit(ScannerInitial());
      }
    } catch (e) {
      emit(ScannerError('Scanning failed: $e'));
    }
  }

  Future<void> _onScanCompleted(
      ScanCompletedEvent event, Emitter<ScannerState> emit) async {
    try {
      // 1. Read initial bytes for display for all images
      final bytesList = <Uint8List>[];
      for (final path in event.imagePaths) {
         final bytes = await _imageProcessor.applyFilter(path, DocumentFilter.original);
         bytesList.add(bytes);
      }

      // 2. Run OCR immediately to derive a smart name from FIRST page
      final extractedText = await _ocrService.extractText(event.imagePaths.first);
      final suggestedName = _suggestName(extractedText);

      emit(ScannerPreviewState(
        originalImagePaths: event.imagePaths,
        filteredImagesBytes: bytesList,
        activeFilter: DocumentFilter.original,
        suggestedName: suggestedName,
      ));
    } catch (e) {
      emit(ScannerError('Failed to process scan: $e'));
    }
  }

  Future<void> _onApplyFilter(
      ApplyFilterEvent event, Emitter<ScannerState> emit) async {
    if (state is! ScannerPreviewState) return;
    final cur = state as ScannerPreviewState;
    emit(cur.copyWith(isSaving: true, activeFilter: event.filter));
    try {
      final bytesList = <Uint8List>[];
      for (final path in cur.originalImagePaths) {
         final bytes = await _imageProcessor.applyFilter(path, event.filter);
         bytesList.add(bytes);
      }
      emit(cur.copyWith(filteredImagesBytes: bytesList, isSaving: false,
          activeFilter: event.filter));
    } catch (e) {
      emit(cur.copyWith(isSaving: false));
      emit(ScannerError('Filter failed: $e'));
    }
  }

  Future<void> _onSaveDocument(
      SaveDocumentEvent event, Emitter<ScannerState> emit) async {
    if (state is! ScannerPreviewState) return;
    final cur = state as ScannerPreviewState;
    emit(cur.copyWith(isSaving: true));

    try {
      // 1. Write filtered bytes to temp file
      final tempDir = await getTemporaryDirectory();
      
      final imageItems = <ImageItem>[];
      String? firstFilteredPath;

      for (int i = 0; i < cur.originalImagePaths.length; i++) {
        final filteredPath = '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final originalPath = cur.originalImagePaths[i];
        
        final bytes = cur.filteredImagesBytes?[i] ??
            await _imageProcessor.applyFilter(originalPath, DocumentFilter.original);
            
        await File(filteredPath).writeAsBytes(bytes);
        
        if (i == 0) firstFilteredPath = filteredPath;

        imageItems.add(ImageItem(
          id: 'scan_tmp_$i',
          path: filteredPath,
          format: ImageFormat.jpg,
          width: 794,
          height: 1123,
          sizeBytes: bytes.length,
          orderIndex: i,
        ));
      }

      // 2. OCR on the FIRST filtered image to get text representation
      final extractedText = await _ocrService.extractText(firstFilteredPath!);

      // Find folder name if folderId is provided
      String? folderName;
      if (event.folderId != null) {
        final folders = await _documentService.getAllFolders();
        try {
          folderName = folders.firstWhere((f) => f.id == event.folderId).folderName;
        } catch (_) {}
      }

      // 3. Generate PDF
      final pdfResult = await _pdfGeneratorService.generatePdf(
        images: imageItems,
        settings: const PdfSettings(
          pageSize: PageSizeType.a4,
          quality: 85,
          dpiPreset: DpiPreset.screen,
        ),
        fileType: ExportFileType.scanned,
        subFolder: folderName,
      );

      // 4. Determine final file name
      final fileName = (event.customName != null && event.customName!.trim().isNotEmpty)
          ? _sanitize(event.customName!)
          : cur.suggestedName;

      // 5. Persist to DB
      final saved = await _documentService.saveDocument(
        filePath: pdfResult.filePath,
        fileName: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
        extractedText: extractedText,
        fileType: 'pdf',
        folderId: event.folderId,
        thumbnailPath: firstFilteredPath,
      );

      emit(ScannerSuccessState(saved));
    } catch (e) {
      emit(cur.copyWith(isSaving: false));
      emit(ScannerError('Failed to save document: $e'));
    }
  }

  // ── Documents ────────────────────────────────────────────────────

  Future<void> _onLoadDocuments(
      LoadDocumentsEvent event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final docs = await _documentService.getAllDocuments(
          folderId: event.folderId, isRoot: event.isRoot);
      final folders = await _documentService.getAllFolders();
      emit(DocumentsLoadedState(
          documents: docs, folders: folders, activeFolderId: event.folderId));
    } catch (e) {
      emit(ScannerError('Failed to load documents: $e'));
    }
  }

  Future<void> _onSearchDocuments(
      SearchDocumentsEvent event, Emitter<ScannerState> emit) async {
    emit(ScannerLoading());
    try {
      final docs = await _documentService.searchDocuments(event.query);
      final smartResults = _extractSmartResults(event.query, docs);
      emit(SearchResultState(
          documents: docs, query: event.query, smartResults: smartResults));
    } catch (e) {
      emit(ScannerError('Search failed: $e'));
    }
  }

  Future<void> _onDeleteDocument(
      DeleteDocumentEvent event, Emitter<ScannerState> emit) async {
    try {
      await _documentService.deleteDocument(event.id);
      add(const LoadDocumentsEvent());
    } catch (e) {
      emit(ScannerError('Delete failed: $e'));
    }
  }

  Future<void> _onRenameDocument(
      RenameDocumentEvent event, Emitter<ScannerState> emit) async {
    try {
      await _documentService.renameDocument(event.id, event.newName);
      add(const LoadDocumentsEvent());
    } catch (e) {
      emit(ScannerError('Rename failed: $e'));
    }
  }

  Future<void> _onMoveToFolder(
      MoveToFolderEvent event, Emitter<ScannerState> emit) async {
    try {
      await _documentService.moveToFolder(event.docId, event.folderId);
      add(const LoadDocumentsEvent());
    } catch (e) {
      emit(ScannerError('Move failed: $e'));
    }
  }

  // ── Folders ──────────────────────────────────────────────────────

  Future<void> _onLoadFolders(
      LoadFoldersEvent event, Emitter<ScannerState> emit) async {
    try {
      final folders = await _documentService.getAllFolders();
      emit(FoldersLoadedState(folders));
    } catch (e) {
      emit(ScannerError('Failed to load folders: $e'));
    }
  }

  Future<void> _onCreateFolder(
      CreateFolderEvent event, Emitter<ScannerState> emit) async {
    try {
      await _documentService.createFolder(event.name);
      add(const LoadDocumentsEvent());
    } catch (e) {
      emit(ScannerError('Failed to create folder: $e'));
    }
  }

  Future<void> _onDeleteFolder(
      DeleteFolderEvent event, Emitter<ScannerState> emit) async {
    try {
      await _documentService.deleteFolder(event.id);
      add(const LoadDocumentsEvent());
    } catch (e) {
      emit(ScannerError('Failed to delete folder: $e'));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Auto-name based on OCR keywords
  String _suggestName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('aadhaar') || lower.contains('aadhar')) {
      return 'Aadhaar_Card';
    }
    if (lower.contains('marksheet') || lower.contains('mark sheet') ||
        lower.contains('result')) {
      return 'Marksheet';
    }
    if (lower.contains('pan') && lower.contains('income tax')) {
      return 'PAN_Card';
    }
    if (lower.contains('passport')) return 'Passport';
    if (lower.contains('voter')) return 'Voter_ID';
    if (lower.contains('driving') || lower.contains('licence')) {
      return 'Driving_Licence';
    }
    if (lower.contains('receipt') || lower.contains('invoice')) {
      return 'Receipt';
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'Document_$ts';
  }

  String _sanitize(String name) =>
      name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  /// Extract structured info from OCR text matching the query
  Map<String, String> _extractSmartResults(
      String query, List<DocumentModel> docs) {
    final result = <String, String>{};
    final q = query.toLowerCase();

    for (final doc in docs) {
      final text = doc.extractedText;

      if (q.contains('mark') || q.contains('marks') || q.contains('score')) {
        final match =
            RegExp(r'(?:marks?|score|total)[:\s]+(\d+)', caseSensitive: false)
                .firstMatch(text);
        if (match != null) result['Marks'] = match.group(1) ?? '';
      }
      if (q.contains('name')) {
        final match =
            RegExp(r'(?:name)[:\s]+([A-Z][a-zA-Z\s]+)', caseSensitive: false)
                .firstMatch(text);
        if (match != null) result['Name'] = match.group(1)?.trim() ?? '';
      }
      if (q.contains('dob') || q.contains('date of birth') ||
          q.contains('birth')) {
        final match = RegExp(
                r'(?:dob|date of birth|born)[:\s]+([\d/\-]+)',
                caseSensitive: false)
            .firstMatch(text);
        if (match != null) result['Date of Birth'] = match.group(1) ?? '';
      }
      if (q.contains('roll') || q.contains('roll number')) {
        final match =
            RegExp(r'(?:roll\s*(?:no|number)?)[:\s]+(\d+)',
                    caseSensitive: false)
                .firstMatch(text);
        if (match != null) result['Roll Number'] = match.group(1) ?? '';
      }
      if (q.contains('aadhaar') || q.contains('aadhar')) {
        final match =
            RegExp(r'\b(\d{4}\s\d{4}\s\d{4})\b').firstMatch(text);
        if (match != null) result['Aadhaar Number'] = match.group(1) ?? '';
      }
    }
    return result;
  }
}
