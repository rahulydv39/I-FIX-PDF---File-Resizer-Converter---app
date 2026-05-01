/// Photo Conversion Screen
/// Shows image conversion progress and results
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../services/ads_service.dart';
import '../../data/services/file_export_service.dart';
import '../../domain/entities/image_settings.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_conversion/image_conversion_bloc.dart';
import '../bloc/image_conversion/image_conversion_event.dart';
import '../bloc/image_conversion/image_conversion_state.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../bloc/monetization/monetization_event.dart';
import '../bloc/monetization/monetization_state.dart';
import '../controllers/banner_ad_controller.dart';
import '../widgets/conversion_success_banner.dart';

/// Screen showing image conversion progress
class PhotoConversionScreen extends StatelessWidget {
  final ImageSettings settings;

  const PhotoConversionScreen({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ImageConversionBloc>(),
      child: _PhotoConversionScreenContent(settings: settings),
    );
  }
}

class _PhotoConversionScreenContent extends StatefulWidget {
  final ImageSettings settings;

  const _PhotoConversionScreenContent({required this.settings});

  @override
  State<_PhotoConversionScreenContent> createState() =>
      _PhotoConversionScreenContentState();
}

class _PhotoConversionScreenContentState
    extends State<_PhotoConversionScreenContent> {
  bool _hasStartedConversion = false;
  bool _showAdPrompt = false;
  BannerAdController? _bannerAdController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartConversion();
    });

    // Initialize banner ad controller for normal flows (no target size)
    if (widget.settings.targetSizeKb == null) {
      _bannerAdController = BannerAdController(
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
      );
      // Load ad after build to have context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _bannerAdController != null) {
          _bannerAdController!.loadAd(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _bannerAdController?.dispose();
    super.dispose();
  }

  void _checkAndStartConversion() {
    // Always start conversion (unlimited conversions)
    _startConversion();
  }

  void _startConversion() async {
    if (_hasStartedConversion) return;
    _hasStartedConversion = true;

    // Show appropriate ad based on target size usage
    final isTargetSizeUsed = widget.settings.targetSizeKb != null;
    final adsService = sl<AdsService>();
    await adsService.showAdIfNeeded(isTargetSizeUsed: isTargetSizeUsed);

    if (!mounted) return;
    final images = context.read<ImageSelectionBloc>().state.images;

    context.read<ImageConversionBloc>().add(StartImageConversion(
          images: images,
          settings: widget.settings,
        ));

    //Use conversion
    context.read<MonetizationBloc>().add(const UseConversion());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Converting'),
        backgroundColor: AppColors.backgroundDark,
        automaticallyImplyLeading: false,
      ),
      body: _showAdPrompt ? _buildAdPrompt() : _buildConversionProgress(),
    );
  }

  /// Build ad prompt screen
  Widget _buildAdPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              size: 80,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Free Conversions Used',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Watch a short video to continue converting.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 40),

          // Watch Ad Button
          BlocBuilder<MonetizationBloc, MonetizationState>(
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      state.isShowingAd ? null : () => _watchAd(context),
                  icon: state.isShowingAd
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    state.isShowingAd ? 'Loading Ad...' : 'Watch Ad to Convert',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build conversion progress screen
  Widget _buildConversionProgress() {
    return BlocConsumer<ImageConversionBloc, ImageConversionState>(
      listener: (context, state) {
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Conversion failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        // Show "File saved" snackbar on completion
        if (state.isCompleted && state.result != null) {
          ConversionSuccessBanner.showSavedSnackBar(context);
        }
      },
      builder: (context, state) {
        if (state.isCompleted) {
          return _buildCompletedState(state);
        }

        return _buildProgressState(state);
      },
    );
  }

  /// Build progress state UI
  Widget _buildProgressState(ImageConversionState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress Indicator
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text("Optimizing file size..."),
              ],
            ),
          ),
          const SizedBox(height: 40),

          const Text(
            'Converting Images...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Processing image ${state.currentImage} of ${state.totalImages}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 40),

          if (state.isConverting)
            TextButton.icon(
              onPressed: () {
                context
                    .read<ImageConversionBloc>()
                    .add(const CancelImageConversion());
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
              ),
            ),
        ],
      ),
    );
  }

  /// Build completed state UI
  Widget _buildCompletedState(ImageConversionState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Banner Ad at the top - only for normal conversions (controlled by controller existence)
            if (_bannerAdController != null && _bannerAdController!.isLoaded) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: _bannerAdController!.getAdWidget(),
              ),
              const SizedBox(height: 24),
            ],

            // Success Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: AppColors.success,
              ),
            ),
          const SizedBox(height: 32),

          const Text(
            'Conversion Complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 24),

          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  'Images Converted',
                  '${state.result?.successCount ?? 0}',
                  Icons.photo_library_rounded,
                ),
                const Divider(color: AppColors.backgroundLight, height: 24),
                _buildStatRow(
                  'Size Saved',
                  state.formattedSizeSaved,
                  Icons.compress_rounded,
                ),
                const Divider(color: AppColors.backgroundLight, height: 24),
                _buildStatRow(
                  'Time Taken',
                  state.formattedProcessingTime,
                  Icons.timer_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Saved confirmation banner
          if (state.result != null && state.result!.results.isNotEmpty) ...[
            ConversionSuccessBanner(
              filePath: state.result!.results.first.outputPath,
            ),
            const SizedBox(height: 24),
          ],

          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _shareImages(state),
              icon: const Icon(Icons.share_rounded),
              label: Text(
                state.result != null && state.result!.results.length > 1
                    ? 'Share ${state.result!.results.length} Images'
                    : 'Share Image',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Open Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openImages(state),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Open in Files'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

  /// Build stat row
  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }

  /// Watch rewarded ad
  void _watchAd(BuildContext context) {
    context.read<MonetizationBloc>().add(const WatchRewardedAd());

    final subscription =
        context.read<MonetizationBloc>().stream.listen((state) {
      if (!state.isShowingAd) {
        if (state.conversionPermission == ConversionPermission.allowed) {
          setState(() {
            _showAdPrompt = false;
          });
          _startConversion();
        }
      }
    });

    Future.delayed(const Duration(minutes: 2), () {
      subscription.cancel();
    });
  }

  /// Share converted images
  void _shareImages(ImageConversionState state) async {
    if (state.result == null || state.result!.results.isEmpty) return;

    // Get all output paths and verify they exist
    final allPaths = state.result!.results.map((r) => r.outputPath).toList();
    final paths = <String>[];
    for (final path in allPaths) {
      if (await File(path).exists()) {
        paths.add(path);
      } else {
        print('⚠️ Share: file not found, skipping: $path');
      }
    }

    if (paths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found. It may have been moved or deleted.')),
      );
      return;
    }

    // Determine MIME type from first result
    final firstExt = paths.first.split('.').last.toLowerCase();
    final mimeType = _getMimeTypeForExt(firstExt);

    try {
      final exportService = sl<FileExportService>();
      await exportService.shareFiles(paths, mimeType: mimeType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share files: $e')),
      );
    }
  }

  /// Show file location and open in viewer
  void _openImages(ImageConversionState state) async {
    if (state.result == null || state.result!.results.isEmpty) return;

    final firstPath = state.result!.results.first.outputPath;

    // Safety check: verify file exists before opening
    if (!await File(firstPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found. It may have been moved or deleted.')),
      );
      return;
    }

    final firstExt = firstPath.split('.').last.toLowerCase();
    final mimeType = _getMimeTypeForExt(firstExt);

    try {
      final exportService = sl<FileExportService>();
      await exportService.openFile(firstPath, mimeType: mimeType);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }
  
  /// Get MIME type from file extension
  String _getMimeTypeForExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/*';
    }
  }
}

