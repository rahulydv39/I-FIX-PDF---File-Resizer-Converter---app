/// PDF History Screen
/// Shows list of all converted PDF files
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../data/services/conversion_history_service.dart';
import '../../data/services/file_export_service.dart';
import '../../data/services/document_service.dart';
import '../../domain/entities/conversion_history_item.dart';
import '../widgets/folder_selection_dialog.dart';

/// Screen showing all converted PDF history
class PdfHistoryScreen extends StatefulWidget {
  const PdfHistoryScreen({super.key});

  @override
  State<PdfHistoryScreen> createState() => _PdfHistoryScreenState();
}

class _PdfHistoryScreenState extends State<PdfHistoryScreen> {
  final _historyService = sl<ConversionHistoryService>();
  final _exportService = sl<FileExportService>();
  late Future<List<ConversionHistoryItem>> _pdfsFuture;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  void _loadPdfs() {
    _pdfsFuture = _historyService.getAllPDFs();
  }

  void _refresh() {
    setState(() {
      _loadPdfs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Converted PDFs'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: FutureBuilder<List<ConversionHistoryItem>>(
        future: _pdfsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading history: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final pdfs = snapshot.data ?? [];

          if (pdfs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pdfs.length,
            itemBuilder: (context, index) {
              return _buildHistoryItem(pdfs[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 80,
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No converted PDFs yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your converted PDFs will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ConversionHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openFile(item),
        onLongPress: () => _showOptionsSheet(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // PDF icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.formattedSize}  •  ${item.formattedDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondaryDark, size: 22),
                color: AppColors.cardDark,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: AppColors.textPrimaryDark))),
                  const PopupMenuItem(value: 'move', child: Text('Move to Folder', style: TextStyle(color: AppColors.textPrimaryDark))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                ],
                onSelected: (value) {
                  if (value == 'rename') _renameFile(item);
                  if (value == 'move') _moveToFolder(item);
                  if (value == 'delete') _deleteFile(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(ConversionHistoryItem item) async {
    try {
      await _exportService.openFile(item.filePath, mimeType: 'application/pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _shareFile(ConversionHistoryItem item) async {
    try {
      await _exportService.shareFiles([item.filePath], mimeType: 'application/pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _deleteFile(ConversionHistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text(
          'Delete File?',
          style: TextStyle(color: AppColors.textPrimaryDark),
        ),
        content: Text(
          'This will permanently delete "${item.fileName}" from your device.',
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await _historyService.deleteHistory(item.id!);
      _refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted')),
      );
    }
  }

  void _showOptionsSheet(ConversionHistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textSecondaryDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // File name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  item.fileName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              // Share
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.primary),
                title: const Text(
                  'Share',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareFile(item);
                },
              ),
              // Rename
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text(
                  'Rename',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameFile(item);
                },
              ),
              // Move 
              ListTile(
                leading: const Icon(Icons.drive_file_move_rounded, color: AppColors.primary),
                title: const Text(
                  'Move to Folder',
                  style: TextStyle(color: AppColors.textPrimaryDark),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveToFolder(item);
                },
              ),
              // Delete
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFile(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _renameFile(ConversionHistoryItem item) async {
    final ctrl = TextEditingController(text: item.fileName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Rename File', style: TextStyle(color: AppColors.textPrimaryDark)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimaryDark),
          decoration: const InputDecoration(
            hintText: 'New file name',
            hintStyle: TextStyle(color: AppColors.textSecondaryDark),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Rename')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != item.fileName) {
      if (item.id != null) {
        await _historyService.renameHistory(item.id!, newName);
        _refresh();
      }
    }
  }

  void _moveToFolder(ConversionHistoryItem item) async {
    final folderId = await showDialog<String>(
      context: context,
      builder: (_) => const FolderSelectionDialog(),
    );

    if (folderId != null) {
      final docService = sl<DocumentService>();
      await docService.saveDocument(
        filePath: item.filePath,
        fileName: item.fileName,
        extractedText: 'Converted PDF', // Or empty
        fileType: 'pdf',
        folderId: folderId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File copied to folder')),
      );
    }
  }
}
