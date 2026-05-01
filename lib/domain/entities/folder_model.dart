import 'package:equatable/equatable.dart';

class FolderModel extends Equatable {
  final String id;
  final String folderName;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.folderName,
    required this.createdAt,
  });

  FolderModel copyWith({String? id, String? folderName, DateTime? createdAt}) {
    return FolderModel(
      id: id ?? this.id,
      folderName: folderName ?? this.folderName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'folderName': folderName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FolderModel.fromMap(Map<String, dynamic> map) => FolderModel(
        id: map['id'] ?? '',
        folderName: map['folderName'] ?? '',
        createdAt: DateTime.parse(
            map['createdAt'] ?? DateTime.now().toIso8601String()),
      );

  @override
  List<Object?> get props => [id, folderName, createdAt];
}
