import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../data/services/document_service.dart';
import '../../domain/entities/folder_model.dart';

class FolderSelectionDialog extends StatefulWidget {
  const FolderSelectionDialog({super.key});

  @override
  State<FolderSelectionDialog> createState() => _FolderSelectionDialogState();
}

class _FolderSelectionDialogState extends State<FolderSelectionDialog> {
  final _documentService = sl<DocumentService>();
  late Future<List<FolderModel>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _foldersFuture = _documentService.getAllFolders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: const Text(
        'Move to Folder',
        style: TextStyle(color: AppColors.textPrimaryDark),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: FutureBuilder<List<FolderModel>>(
          future: _foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final folders = snapshot.data ?? [];
            if (folders.isEmpty) {
              return const Center(
                child: Text(
                  'No folders found. Create one in the Scanner section.',
                  style: TextStyle(color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_rounded, color: AppColors.primary),
                  title: Text(
                    folder.folderName,
                    style: const TextStyle(color: AppColors.textPrimaryDark),
                  ),
                  onTap: () {
                    Navigator.pop(context, folder.id);
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
