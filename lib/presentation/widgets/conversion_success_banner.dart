/// Reusable banner shown after a successful file conversion/merge.
/// Displays a confirmation message with the real saved folder path.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A banner widget that confirms a file was saved to the device
/// and shows the real folder path.
///
/// Usage:
/// ```dart
/// ConversionSuccessBanner(filePath: '/storage/emulated/0/Download/FileConverter/output.pdf')
/// ```
class ConversionSuccessBanner extends StatelessWidget {
  /// The full absolute path of the saved file.
  final String filePath;

  const ConversionSuccessBanner({
    super.key,
    required this.filePath,
  });

  /// Extracts a user-friendly folder display from the full path.
  /// e.g. "/storage/emulated/0/Download/FileConverter/out.pdf" → "Download/FileConverter"
  String get _folderDisplay {
    final parent = File(filePath).parent.path;
    // Show last 2 segments for readability
    final segments = parent.split('/');
    if (segments.length >= 2) {
      return segments.reversed.take(2).toList().reversed.join('/');
    }
    return parent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'File saved to your device',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _folderDisplay,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show a "File saved" snackbar. Call this from BlocConsumer listeners
  /// or after setState when conversion completes.
  static void showSavedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('File saved to your device'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
