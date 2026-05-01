import 'package:equatable/equatable.dart';
import '../../../data/services/document_image_processor.dart';
import '../../../domain/entities/document_model.dart';
import '../../../domain/entities/folder_model.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

/// ── Scanning ──────────────────────────────────────────────────────
class StartScanEvent extends ScannerEvent {}

class ScanCompletedEvent extends ScannerEvent {
  final List<String> imagePaths;
  const ScanCompletedEvent(this.imagePaths);
  @override
  List<Object?> get props => [imagePaths];
}

class ApplyFilterEvent extends ScannerEvent {
  final DocumentFilter filter;
  const ApplyFilterEvent(this.filter);
  @override
  List<Object?> get props => [filter];
}

/// Save with an optional custom file name
class SaveDocumentEvent extends ScannerEvent {
  final String? customName;
  final String? folderId;
  const SaveDocumentEvent({this.customName, this.folderId});
  @override
  List<Object?> get props => [customName, folderId];
}

/// ── Document list ─────────────────────────────────────────────────
class LoadDocumentsEvent extends ScannerEvent {
  final String? folderId;
  final bool isRoot;
  const LoadDocumentsEvent({this.folderId, this.isRoot = false});

  @override
  List<Object?> get props => [folderId, isRoot];
}

class SearchDocumentsEvent extends ScannerEvent {
  final String query;
  const SearchDocumentsEvent(this.query);
  @override
  List<Object?> get props => [query];
}

class DeleteDocumentEvent extends ScannerEvent {
  final String id;
  const DeleteDocumentEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class RenameDocumentEvent extends ScannerEvent {
  final String id;
  final String newName;
  const RenameDocumentEvent(this.id, this.newName);
  @override
  List<Object?> get props => [id, newName];
}

class MoveToFolderEvent extends ScannerEvent {
  final String docId;
  final String? folderId; // null = remove from folder
  const MoveToFolderEvent(this.docId, this.folderId);
  @override
  List<Object?> get props => [docId, folderId];
}

/// ── Folders ───────────────────────────────────────────────────────
class LoadFoldersEvent extends ScannerEvent {}

class CreateFolderEvent extends ScannerEvent {
  final String name;
  const CreateFolderEvent(this.name);
  @override
  List<Object?> get props => [name];
}

class DeleteFolderEvent extends ScannerEvent {
  final String id;
  const DeleteFolderEvent(this.id);
  @override
  List<Object?> get props => [id];
}
