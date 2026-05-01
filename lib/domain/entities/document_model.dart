import 'package:equatable/equatable.dart';

class DocumentModel extends Equatable {
  final String id;
  final String filePath;
  final String fileName;
  final String extractedText;
  final DateTime createdAt;
  final String fileType;
  final String? folderId;        // NEW – nullable folder reference
  final String? thumbnailPath;   // NEW – optional thumbnail for list UI

  const DocumentModel({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.extractedText,
    required this.createdAt,
    required this.fileType,
    this.folderId,
    this.thumbnailPath,
  });

  DocumentModel copyWith({
    String? id,
    String? filePath,
    String? fileName,
    String? extractedText,
    DateTime? createdAt,
    String? fileType,
    String? folderId,
    String? thumbnailPath,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      extractedText: extractedText ?? this.extractedText,
      createdAt: createdAt ?? this.createdAt,
      fileType: fileType ?? this.fileType,
      folderId: folderId ?? this.folderId,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'extractedText': extractedText,
        'createdAt': createdAt.toIso8601String(),
        'fileType': fileType,
        'folderId': folderId,
        'thumbnailPath': thumbnailPath,
      };

  factory DocumentModel.fromMap(Map<String, dynamic> map) => DocumentModel(
        id: map['id'] ?? '',
        filePath: map['filePath'] ?? '',
        fileName: map['fileName'] ?? '',
        extractedText: map['extractedText'] ?? '',
        createdAt: DateTime.parse(
            map['createdAt'] ?? DateTime.now().toIso8601String()),
        fileType: map['fileType'] ?? 'pdf',
        folderId: map['folderId'],
        thumbnailPath: map['thumbnailPath'],
      );

  @override
  List<Object?> get props =>
      [id, filePath, fileName, extractedText, createdAt, fileType, folderId, thumbnailPath];
}
