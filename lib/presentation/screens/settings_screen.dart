/// Settings Screen
/// PDF conversion settings with DPI, quality, and size controls
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/pdf_settings.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_selection/image_selection_state.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../bloc/monetization/monetization_state.dart';
import '../widgets/target_size_selector.dart';
import '../../core/constants/target_size_config.dart';
import '../widgets/quality_slider.dart';
import '../widgets/dpi_selector.dart';
import '../widgets/info_sheet.dart';
import 'conversion_screen.dart';

/// Screen for configuring PDF settings before conversion
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  PdfSettings _settings = const PdfSettings();

  // Target size state
  bool _enableSizeTarget = false;
  int _selectedTargetSizeKb = TargetSizeConfig.defaultSizeKb;

  // File name controller
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'converted_file');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('PDF Settings'),
        backgroundColor: AppColors.backgroundDark,
        actions: [
          // Estimated Size
          BlocBuilder<ImageSelectionBloc, ImageSelectionState>(
            builder: (context, state) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calculate_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '~${_estimateSize(state)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.backgroundMedium,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const InfoSheet(
                  title: 'Photo to PDF',
                  description: 'Convert your selected images into a PDF document.',
                  steps: [
                    'Adjust page formatting if needed',
                    'Select quality & DPI',
                    'Set a target file size (optional)',
                    'Tap Generate PDF',
                  ],
                  tips: 'Lowering the DPI reduces file size drastically.',
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Size Section
            _buildSection(
              title: 'Page Size',
              icon: Icons.aspect_ratio_rounded,
              child: _buildPageSizeSelector(),
            ),

            const SizedBox(height: 20),

            // File Name Section
            _buildSection(
              title: 'File Name',
              icon: Icons.edit_document,
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimaryDark),
                decoration: InputDecoration(
                  hintText: 'converted_file',
                  hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  _settings = _settings.copyWith(customFileName: value.trim());
                },
              ),
            ),

            const SizedBox(height: 20),

            // Quality Section
            _buildSection(
              title: 'Image Quality',
              icon: Icons.high_quality_rounded,
              child: QualitySlider(
                value: _settings.quality,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(quality: value);
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            // DPI Section
            _buildSection(
              title: 'Resolution (DPI)',
              icon: Icons.grain_rounded,
              child: DpiSelector(
                selectedPreset: _settings.dpiPreset,
                customDpi: _settings.customDpi,
                onPresetChanged: (preset) {
                  setState(() {
                    _settings = _settings.copyWith(dpiPreset: preset);
                  });
                },
                onCustomDpiChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(customDpi: value);
                  });
                },
              ),
            ),

            const SizedBox(height: 20),

            // Target Size Section (Premium Feature indicator)
            BlocBuilder<MonetizationBloc, MonetizationState>(
              builder: (context, monetizationState) {
                return _buildSection(
                  title: 'Target File Size',
                  icon: Icons.compress_rounded,
                  trailing: Switch(
                    value: _enableSizeTarget,
                    onChanged: (value) {
                      setState(() {
                        _enableSizeTarget = value;
                        _settings = _settings.copyWith(
                          enableSizeOptimization: value,
                        );
                      });
                    },
                  ),
                  child: _enableSizeTarget
                      ? TargetSizeSelector(
                          selectedSizeKb: _selectedTargetSizeKb,
                          onSizeChanged: (sizeKb) {
                            setState(() {
                              _selectedTargetSizeKb = sizeKb;
                            });
                          },
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),

            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),

      // Convert Button
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// Build section container
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    bool isPremiumFeature = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              if (isPremiumFeature) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: AppColors.premiumGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),

          // Content
          if (child is! SizedBox) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }

  /// Build page size selector
  Widget _buildPageSizeSelector() {
    return Row(
      children: [
        _buildPageSizeOption(
          label: 'Auto',
          description: 'Image size',
          isSelected: _settings.pageSize == PageSizeType.auto,
          onTap: () {
            setState(() {
              _settings = _settings.copyWith(pageSize: PageSizeType.auto);
            });
          },
        ),
        const SizedBox(width: 12),
        _buildPageSizeOption(
          label: 'A4',
          description: '210 × 297 mm',
          isSelected: _settings.pageSize == PageSizeType.a4,
          onTap: () {
            setState(() {
              _settings = _settings.copyWith(pageSize: PageSizeType.a4);
            });
          },
        ),
      ],
    );
  }

  /// Build page size option button
  Widget _buildPageSizeOption({
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build bottom action bar
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _startConversion(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_rounded),
                SizedBox(width: 8),
                Text(
                  'Generate PDF',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Estimate output size based on current settings
  String _estimateSize(ImageSelectionState state) {
    if (!state.hasImages) return '0 KB';

    // Rough estimation
    double totalSizeKb = state.totalSizeBytes / 1024;

    // Apply quality factor
    double qualityFactor = _settings.quality / 100;

    // Apply DPI factor
    double dpiFactor = 1.0;
    if (_settings.effectiveDpi < 150) {
      dpiFactor = 0.6;
    } else if (_settings.effectiveDpi > 200) {
      dpiFactor = 1.3;
    }

    double estimated = totalSizeKb * qualityFactor * dpiFactor * 0.3;

    if (estimated < 1000) {
      return '${estimated.toStringAsFixed(0)} KB';
    } else {
      return '${(estimated / 1024).toStringAsFixed(1)} MB';
    }
  }

  /// Navigate to conversion screen
  void _startConversion(BuildContext context) {
    // Build final settings with target size if enabled
    PdfSettings finalSettings = _settings;

    if (_enableSizeTarget) {
      finalSettings = finalSettings.copyWith(
        enableSizeOptimization: true,
        targetSize: SizeTarget(kb: _selectedTargetSizeKb),
      );
    }
    
    final customName = _nameCtrl.text.trim();
    if (customName.isNotEmpty) {
      finalSettings = finalSettings.copyWith(customFileName: customName);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<ImageSelectionBloc>(),
            ),
            BlocProvider.value(
              value: context.read<MonetizationBloc>(),
            ),
          ],
          child: ConversionScreen(settings: finalSettings),
        ),
      ),
    );
  }
}
