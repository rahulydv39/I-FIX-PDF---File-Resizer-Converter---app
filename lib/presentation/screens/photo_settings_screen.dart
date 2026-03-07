/// Photo Settings Screen
/// Settings for image-to-image conversion (resize, format, compress)
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/image_settings.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_selection/image_selection_state.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../widgets/quality_slider.dart';
import '../widgets/target_size_selector.dart';
import '../../core/constants/target_size_config.dart';
import 'photo_conversion_screen.dart';

/// Screen for configuring image conversion settings
class PhotoSettingsScreen extends StatefulWidget {
  const PhotoSettingsScreen({super.key});

  @override
  State<PhotoSettingsScreen> createState() => _PhotoSettingsScreenState();
}

class _PhotoSettingsScreenState extends State<PhotoSettingsScreen> {
  ImageSettings _settings = const ImageSettings();

  // Controllers for pixel dimensions
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // Target size state
  bool _enableSizeTarget = false;
  int _selectedTargetSizeKb = TargetSizeConfig.defaultSizeKb;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Photo Settings'),
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
                      Icons.photo_size_select_large_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${state.imageCount} images',
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Output Format Section
            _buildSection(
              title: 'Output Format',
              icon: Icons.image_rounded,
              child: _buildFormatSelector(),
            ),

            const SizedBox(height: 20),

            // Quality Section
            _buildSection(
              title: 'Image Quality',
              icon: Icons.high_quality_rounded,
              subtitle: _settings.outputFormat == OutputFormat.png
                  ? 'PNG is lossless (quality ignored)'
                  : null,
              child: QualitySlider(
                value: _settings.quality,
                onChanged: _settings.outputFormat == OutputFormat.png
                    ? null
                    : (value) {
                        setState(() {
                          _settings = _settings.copyWith(quality: value);
                        });
                      },
              ),
            ),

            const SizedBox(height: 20),

            // Resize Mode Section
            _buildSection(
              title: 'Resize',
              icon: Icons.crop_rounded,
              child: _buildResizeModeSelector(),
            ),

            const SizedBox(height: 20),

            // Custom Dimensions (if custom mode selected)
            if (_settings.resizeMode == ResizeMode.custom) ...[
              _buildSection(
                title: 'Custom Dimensions',
                icon: Icons.straighten_rounded,
                child: _buildCustomDimensions(),
              ),
              const SizedBox(height: 20),
            ],

            // Percentage (if percentage mode selected)
            if (_settings.resizeMode == ResizeMode.percentage) ...[
              _buildSection(
                title: 'Resize Percentage',
                icon: Icons.percent_rounded,
                child: _buildPercentageSlider(),
              ),
              const SizedBox(height: 20),
            ],

            // Extra Options Section
            _buildSection(
              title: 'Extra Options',
              icon: Icons.tune_rounded,
              child: _buildExtraOptions(),
            ),

            const SizedBox(height: 20),

            // Target File Size Section
            _buildSection(
              title: 'Target File Size',
              icon: Icons.compress_rounded,
              trailing: Switch(
                value: _enableSizeTarget,
                onChanged: (value) {
                  setState(() => _enableSizeTarget = value);
                },
              ),
              child: _enableSizeTarget
                  ? _buildTargetSizeInput()
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 100),
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
    String? subtitle,
    Widget? trailing,
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
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// Build format selector
  Widget _buildFormatSelector() {
    return Row(
      children: OutputFormat.values.map((format) {
        final isSelected = _settings.outputFormat == format;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _settings = _settings.copyWith(outputFormat: format);
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: format != OutputFormat.values.last ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    format.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimaryDark,
                    ),
                  ),
                  Text(
                    '.${format.extension}',
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
      }).toList(),
    );
  }

  /// Build resize mode selector
  Widget _buildResizeModeSelector() {
    return Column(
      children: [
        Row(
          children: [
            _buildResizeModeOption(
              ResizeMode.original,
              'Original',
              Icons.photo_outlined,
            ),
            const SizedBox(width: 8),
            _buildResizeModeOption(
              ResizeMode.custom,
              'Custom',
              Icons.straighten_rounded,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildResizeModeOption(
              ResizeMode.percentage,
              'Percentage',
              Icons.percent_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResizeModeOption(ResizeMode mode, String label, IconData icon) {
    final isSelected = _settings.resizeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _settings = _settings.copyWith(resizeMode: mode);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build preset selector
  Widget _buildPresetSelector() {
    // Group presets by category
    final socialPresets = [
      DimensionPreset.instagramSquare,
      DimensionPreset.instagramPortrait,
      DimensionPreset.instagramStory,
      DimensionPreset.facebookPost,
      DimensionPreset.twitterPost,
      DimensionPreset.youtubeThumbnail,
    ];

    final resolutionPresets = [
      DimensionPreset.hd720,
      DimensionPreset.fullHd1080,
      DimensionPreset.uhd4k,
    ];

    final printPresets = [
      DimensionPreset.passportPhoto,
      DimensionPreset.a4Print,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Social Media',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: socialPresets
              .map((preset) => _buildPresetChip(preset))
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Resolution',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: resolutionPresets
              .map((preset) => _buildPresetChip(preset))
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Print',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              printPresets.map((preset) => _buildPresetChip(preset)).toList(),
        ),
      ],
    );
  }

  Widget _buildPresetChip(DimensionPreset preset) {
    final isSelected = _settings.dimensionPreset == preset;
    return GestureDetector(
      onTap: () {
        setState(() {
          _settings = _settings.copyWith(dimensionPreset: preset);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preset.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color:
                    isSelected ? AppColors.primary : AppColors.textPrimaryDark,
              ),
            ),
            Text(
              preset.dimensions,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Resize Unit
  String _selectedResizeUnit = 'px'; // px, cm, inch
  static const int _dpi = 300;

  /// Build custom dimensions input
  Widget _buildCustomDimensions() {
    return Column(
      children: [
        // Unit Selector
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitOption('px'),
              Container(width: 1, height: 20, color: AppColors.textSecondaryDark.withValues(alpha: 0.2)),
              _buildUnitOption('cm'),
              Container(width: 1, height: 20, color: AppColors.textSecondaryDark.withValues(alpha: 0.2)),
              _buildUnitOption('inch'),
            ],
          ),
        ),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _widthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Width (${_selectedResizeUnit})',
                  hintText: 'Width',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: _updateDimensions,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _settings = _settings.copyWith(
                    lockAspectRatio: !_settings.lockAspectRatio,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _settings.lockAspectRatio
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _settings.lockAspectRatio
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  color: _settings.lockAspectRatio
                      ? AppColors.primary
                      : AppColors.textSecondaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Height (${_selectedResizeUnit})',
                  hintText: 'Height',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: _updateDimensions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _settings.lockAspectRatio
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                size: 16,
                color: AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                _settings.lockAspectRatio
                    ? 'Aspect ratio locked'
                    : 'Aspect ratio unlocked (may distort)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitOption(String unit) {
    final isSelected = _selectedResizeUnit == unit;
    return GestureDetector(
      onTap: () => _changeUnit(unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          unit.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  void _changeUnit(String newUnit) {
    if (_selectedResizeUnit == newUnit) return;

    // Convert current values to new unit for display
    double? width = double.tryParse(_widthController.text);
    double? height = double.tryParse(_heightController.text);

    if (width != null && height != null) {
      // First convert to pixels
      double pixelsW = _toPixels(width, _selectedResizeUnit);
      double pixelsH = _toPixels(height, _selectedResizeUnit);

      // Then convert to new unit
      double newW = _fromPixels(pixelsW, newUnit);
      double newH = _fromPixels(pixelsH, newUnit);

      _widthController.text = newW.toStringAsFixed(newUnit == 'px' ? 0 : 2);
      _heightController.text = newH.toStringAsFixed(newUnit == 'px' ? 0 : 2);
    }

    setState(() {
      _selectedResizeUnit = newUnit;
    });
  }

  void _updateDimensions(String _) {
    double? width = double.tryParse(_widthController.text);
    double? height = double.tryParse(_heightController.text);

    if (width != null) {
      final pixels = _toPixels(width, _selectedResizeUnit);
      _settings = _settings.copyWith(customWidth: pixels.round());
    }
    
    if (height != null) {
      final pixels = _toPixels(height, _selectedResizeUnit);
      _settings = _settings.copyWith(customHeight: pixels.round());
    }
    
    setState(() {});
  }

  double _toPixels(double value, String unit) {
    switch (unit) {
      case 'cm':
        return (value * _dpi) / 2.54;
      case 'inch':
        return value * _dpi;
      default:
        return value;
    }
  }

  double _fromPixels(double pixels, String unit) {
    switch (unit) {
      case 'cm':
        return (pixels * 2.54) / _dpi;
      case 'inch':
        return pixels / _dpi;
      default:
        return pixels;
    }
  }

  /// Build target size input
  Widget _buildTargetSizeInput() {
    return TargetSizeSelector(
      selectedSizeKb: _selectedTargetSizeKb,
      onSizeChanged: (sizeKb) {
        setState(() {
          _selectedTargetSizeKb = sizeKb;
        });
      },
    );
  }

  /// Build percentage slider
  Widget _buildPercentageSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scale',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            Text(
              '${_settings.resizePercentage}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Slider(
          value: _settings.resizePercentage.toDouble(),
          min: 10,
          max: 200,
          divisions: 19,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(resizePercentage: value.round());
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPercentagePreset(25),
            _buildPercentagePreset(50),
            _buildPercentagePreset(75),
            _buildPercentagePreset(100),
            _buildPercentagePreset(150),
          ],
        ),
      ],
    );
  }

  Widget _buildPercentagePreset(int percentage) {
    final isSelected = _settings.resizePercentage == percentage;
    return GestureDetector(
      onTap: () {
        setState(() {
          _settings = _settings.copyWith(resizePercentage: percentage);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.backgroundLight,
          ),
        ),
        child: Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  /// Build extra options
  Widget _buildExtraOptions() {
    return Column(
      children: [
        _buildOptionRow(
          'Remove EXIF Metadata',
          'Strip location, camera info, etc.',
          _settings.removeMetadata,
          (value) {
            setState(() {
              _settings = _settings.copyWith(removeMetadata: value);
            });
          },
        ),
        const Divider(color: AppColors.backgroundLight),
        _buildOptionRow(
          'Grayscale',
          'Convert to black & white',
          _settings.grayscale,
          (value) {
            setState(() {
              _settings = _settings.copyWith(grayscale: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildOptionRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
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
              backgroundColor: AppColors.secondary,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_fix_high_rounded),
                SizedBox(width: 8),
                Text(
                  'Convert Images',
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

  /// Navigate to conversion screen
  void _startConversion(BuildContext context) {
    // Build final settings with target size if enabled
    ImageSettings finalSettings = _settings;

    if (_enableSizeTarget) {
      finalSettings = _settings.copyWith(
        targetSizeKb: _selectedTargetSizeKb,
        enableSizeOptimization: true,
      );
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
          child: PhotoConversionScreen(settings: finalSettings),
        ),
      ),
    );
  }
}
