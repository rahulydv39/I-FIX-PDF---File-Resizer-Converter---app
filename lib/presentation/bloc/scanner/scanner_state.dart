import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/document_model.dart';
import '../../../domain/entities/folder_model.dart';
import '../../../data/services/document_image_processor.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();
  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerLoading extends ScannerState {}

/// Preview after a scan – holds image bytes + filter + suggested name
class ScannerPreviewState extends ScannerState {
  final List<String> originalImagePaths;
  final List<Uint8List>? filteredImagesBytes;
  final DocumentFilter activeFilter;
  final bool isSaving;
  final String suggestedName;

  const ScannerPreviewState({
    required this.originalImagePaths,
    required this.suggestedName,
    this.filteredImagesBytes,
    this.activeFilter = DocumentFilter.original,
    this.isSaving = false,
  });

  ScannerPreviewState copyWith({
    List<String>? originalImagePaths,
    List<Uint8List>? filteredImagesBytes,
    DocumentFilter? activeFilter,
    bool? isSaving,
    String? suggestedName,
  }) =>
      ScannerPreviewState(
        originalImagePaths: originalImagePaths ?? this.originalImagePaths,
        filteredImagesBytes: filteredImagesBytes ?? this.filteredImagesBytes,
        activeFilter: activeFilter ?? this.activeFilter,
        isSaving: isSaving ?? this.isSaving,
        suggestedName: suggestedName ?? this.suggestedName,
      );

  @override
  List<Object?> get props =>
      [originalImagePaths, filteredImagesBytes, activeFilter, isSaving, suggestedName];
}

/// Emitted after successful save
class ScannerSuccessState extends ScannerState {
  final DocumentModel savedDocument;
  const ScannerSuccessState(this.savedDocument);
  @override
  List<Object?> get props => [savedDocument];
}

class ScannerError extends ScannerState {
  final String message;
  const ScannerError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Document list (with optional folder filter)
class DocumentsLoadedState extends ScannerState {
  final List<DocumentModel> documents;
  final List<FolderModel> folders;
  final String? activeFolderId;

  const DocumentsLoadedState({
    required this.documents,
    required this.folders,
    this.activeFolderId,
  });

  @override
  List<Object?> get props => [documents, folders, activeFolderId];
}

/// Folder list only
class FoldersLoadedState extends ScannerState {
  final List<FolderModel> folders;
  const FoldersLoadedState(this.folders);
  @override
  List<Object?> get props => [folders];
}

/// Search results
class SearchResultState extends ScannerState {
  final List<DocumentModel> documents;
  final String query;
  final Map<String, String> smartResults; // e.g. {"Marks": "95"}

  const SearchResultState({
    required this.documents,
    required this.query,
    required this.smartResults,
  });

  @override
  List<Object?> get props => [documents, query, smartResults];
}
