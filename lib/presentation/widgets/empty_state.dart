/// Empty State Widget
/// Displayed when no images are selected
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_selection/image_selection_event.dart';

/// Empty state widget for home screen
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    this.title = 'Select Images',
    this.subtitle =
        'Choose images from your gallery to convert them into a single PDF document',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Supported formats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFormatChip('JPG'),
                const SizedBox(width: 8),
                _buildFormatChip('PNG'),
                const SizedBox(width: 8),
                _buildFormatChip('WEBP'),
                const SizedBox(width: 8),
                _buildFormatChip('HEIC'),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Quick action button
          ElevatedButton.icon(
            onPressed: () {
              context.read<ImageSelectionBloc>().add(const PickMultipleImages());
            },
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Choose from Gallery'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build format chip
  Widget _buildFormatChip(String format) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        format,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
      ),
    );
  }
}
