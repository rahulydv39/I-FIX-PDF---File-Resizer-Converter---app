/// Image Grid Widget
/// Displays selected images in a reorderable grid
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/image_item.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_selection/image_selection_event.dart';

/// Grid of draggable image tiles
class ImageGrid extends StatelessWidget {
  final List<ImageItem> images;

  const ImageGrid({
    super.key,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          return _ImageTile(
            key: ValueKey(image.id),
            image: image,
            index: index,
            onRemove: () {
              context.read<ImageSelectionBloc>().add(RemoveImage(image.id));
            },
          );
        },
        onReorder: (oldIndex, newIndex) {
          context.read<ImageSelectionBloc>().add(
                ReorderImages(oldIndex: oldIndex, newIndex: newIndex),
              );
        },
        placeholderBuilder: (dragIndex, dropIndex, dragWidget) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Individual image tile in the grid
class _ImageTile extends StatelessWidget {
  final ImageItem image;
  final int index;
  final VoidCallback onRemove;

  const _ImageTile({
    super.key,
    required this.image,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Image.file(
              File(image.path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.backgroundLight,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textSecondaryDark,
                  ),
                );
              },
            ),

            // Gradient overlay for text visibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Page number badge
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Remove button
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),

            // File info
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Text(
                image.formattedSize,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Drag handle indicator
            Positioned(
              bottom: 6,
              right: 6,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
