/// Image History Screen
/// Shows list of all converted image files
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../data/services/conversion_history_service.dart';
import '../../data/services/file_export_service.dart';
import '../../domain/entities/conversion_history_item.dart';

/// Screen showing all converted image history
class ImageHistoryScreen extends StatefulWidget {
  const ImageHistoryScreen({super.key});

  @override
  State<ImageHistoryScreen> createState() => _ImageHistoryScreenState();
}

class _ImageHistoryScreenState extends State<ImageHistoryScreen> {
  final _historyService = sl<ConversionHistoryService>();
  final _exportService = sl<FileExportService>();
  late Future<List<ConversionHistoryItem>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  void _loadImages() {
    _imagesFuture = _historyService.getAllImages();
  }

  void _refresh() {
    setState(() {
      _loadImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Converted Images'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: FutureBuilder<List<ConversionHistoryItem>>(
        future: _imagesFuture,
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

          final images = snapshot.data ?? [];

          if (images.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return _buildHistoryItem(images[index]);
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
            Icons.photo_library_outlined,
            size: 80,
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No converted images yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your converted images will appear here',
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
              // Thumbnail
              _buildThumbnail(item),
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

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryDark,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ConversionHistoryItem item) {
    final file = File(item.filePath);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: file.existsSync()
          ? Image.file(
              file,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                color: AppColors.secondary,
                size: 28,
              ),
            )
          : const Icon(
              Icons.image_not_supported_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
    );
  }

  void _openFile(ConversionHistoryItem item) async {
    try {
      final ext = item.extension;
      String mimeType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/*';
      }
      await _exportService.openFile(item.filePath, mimeType: mimeType);
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
      final ext = item.extension;
      String mimeType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/*';
      }
      await _exportService.shareFiles([item.filePath], mimeType: mimeType);
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
}
