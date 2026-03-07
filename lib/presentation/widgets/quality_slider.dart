/// Quality Slider Widget
/// Slider for adjusting image compression quality
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Slider widget for image quality selection (0-100)
class QualitySlider extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const QualitySlider({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quality labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getQualityLabel(),
              style: TextStyle(
                color: _getQualityColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getQualityColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$value%',
                style: TextStyle(
                  color: _getQualityColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _getQualityColor(),
            thumbColor: _getQualityColor(),
            overlayColor: _getQualityColor().withValues(alpha: 0.2),
            inactiveTrackColor: AppColors.backgroundLight,
          ),
          child: Slider(
            value: value.toDouble(),
            min: AppConstants.minQuality.toDouble(),
            max: AppConstants.maxQuality.toDouble(),
            divisions: 9, // 10 steps: 10, 20, 30, ..., 100
            onChanged: onChanged != null
                ? (newValue) {
                    onChanged!(newValue.round());
                  }
                : null,
          ),
        ),

        // Size indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIndicator('Smaller File', Icons.compress_rounded),
            _buildIndicator('Higher Quality', Icons.high_quality_rounded),
          ],
        ),
      ],
    );
  }

  /// Get quality label based on value
  String _getQualityLabel() {
    if (value >= 90) return 'Maximum';
    if (value >= 70) return 'High';
    if (value >= 50) return 'Medium';
    if (value >= 30) return 'Low';
    return 'Minimum';
  }

  /// Get color based on quality level
  Color _getQualityColor() {
    if (value >= 90) return AppColors.success;
    if (value >= 70) return AppColors.primary;
    if (value >= 50) return AppColors.info;
    if (value >= 30) return AppColors.warning;
    return AppColors.error;
  }

  /// Build indicator text with icon
  Widget _buildIndicator(String text, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textSecondaryDark,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}
