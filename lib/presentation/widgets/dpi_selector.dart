/// DPI Selector Widget
/// Widget for selecting DPI/PPI resolution presets
library;

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/pdf_settings.dart';

/// Widget for selecting DPI preset or custom value
class DpiSelector extends StatefulWidget {
  final DpiPreset selectedPreset;
  final int? customDpi;
  final ValueChanged<DpiPreset> onPresetChanged;
  final ValueChanged<int> onCustomDpiChanged;

  const DpiSelector({
    super.key,
    required this.selectedPreset,
    this.customDpi,
    required this.onPresetChanged,
    required this.onCustomDpiChanged,
  });

  @override
  State<DpiSelector> createState() => _DpiSelectorState();
}

class _DpiSelectorState extends State<DpiSelector> {
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.customDpi != null) {
      _customController.text = widget.customDpi.toString();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preset buttons
        Row(
          children: [
            _buildPresetButton(
              preset: DpiPreset.screen,
              label: '72',
              description: 'Screen',
            ),
            const SizedBox(width: 8),
            _buildPresetButton(
              preset: DpiPreset.standard,
              label: '150',
              description: 'Standard',
            ),
            const SizedBox(width: 8),
            _buildPresetButton(
              preset: DpiPreset.highQuality,
              label: '300',
              description: 'Print',
            ),
            const SizedBox(width: 8),
            _buildPresetButton(
              preset: DpiPreset.custom,
              label: 'Custom',
              description: 'Set DPI',
            ),
          ],
        ),

        // Custom DPI input
        if (widget.selectedPreset == DpiPreset.custom) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom DPI',
                    hintText: 'Enter DPI value',
                    suffixText: 'DPI',
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    final dpi = int.tryParse(value);
                    if (dpi != null && dpi > 0 && dpi <= 1200) {
                      widget.onCustomDpiChanged(dpi);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Quick set buttons
              _buildQuickDpiButton(96),
              const SizedBox(width: 8),
              _buildQuickDpiButton(120),
              const SizedBox(width: 8),
              _buildQuickDpiButton(200),
            ],
          ),
        ],

        // Info text
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.info,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getDpiDescription(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build preset button
  Widget _buildPresetButton({
    required DpiPreset preset,
    required String label,
    required String description,
  }) {
    final isSelected = widget.selectedPreset == preset;

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onPresetChanged(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build quick DPI set button
  Widget _buildQuickDpiButton(int dpi) {
    return GestureDetector(
      onTap: () {
        _customController.text = dpi.toString();
        widget.onCustomDpiChanged(dpi);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$dpi',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ),
    );
  }

  /// Get description for current DPI selection
  String _getDpiDescription() {
    final dpi = widget.selectedPreset == DpiPreset.custom
        ? widget.customDpi ?? 150
        : widget.selectedPreset.value;

    if (dpi <= 72) {
      return 'Best for screen viewing, smallest file size';
    } else if (dpi <= 150) {
      return 'Good balance of quality and file size';
    } else if (dpi <= 300) {
      return 'High quality for printing, larger file size';
    } else {
      return 'Very high resolution, significantly larger files';
    }
  }
}
