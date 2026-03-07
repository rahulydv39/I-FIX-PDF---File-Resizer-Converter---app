/// Conversion Screen
/// Shows conversion progress and handles monetization flow
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../domain/entities/pdf_settings.dart';
import '../../services/ads_service.dart';
import '../../data/services/file_export_service.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/pdf_conversion/pdf_conversion_bloc.dart';
import '../bloc/pdf_conversion/pdf_conversion_event.dart';
import '../bloc/pdf_conversion/pdf_conversion_state.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../bloc/monetization/monetization_event.dart';
import '../bloc/monetization/monetization_state.dart';
import '../widgets/conversion_success_banner.dart';

/// Screen showing conversion progress
class ConversionScreen extends StatelessWidget {
  final PdfSettings settings;

  const ConversionScreen({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PdfConversionBloc>(),
      child: _ConversionScreenContent(settings: settings),
    );
  }
}

class _ConversionScreenContent extends StatefulWidget {
  final PdfSettings settings;

  const _ConversionScreenContent({required this.settings});

  @override
  State<_ConversionScreenContent> createState() =>
      _ConversionScreenContentState();
}

class _ConversionScreenContentState extends State<_ConversionScreenContent> {
  bool _hasStartedConversion = false;

  @override
  void initState() {
    super.initState();
    // Start conversion immediately (unlimited conversions)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startConversion();
    });
  }

  void _startConversion() async {
    if (_hasStartedConversion) return;
    _hasStartedConversion = true;

    // Show appropriate ad based on target size usage
    final isTargetSizeUsed = widget.settings.targetSize != null;
    final adsService = sl<AdsService>();
    await adsService.showAdIfNeeded(isTargetSizeUsed: isTargetSizeUsed);

    if (!mounted) return;
    final images = context.read<ImageSelectionBloc>().state.images;

    context.read<PdfConversionBloc>().add(StartConversion(
          images: images,
          settings: widget.settings,
        ));
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
      body: _buildConversionProgress(),
    );
  }

  /// Build ad prompt screen
  Widget _buildAdPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
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

          // Title
          const Text(
            'Free Conversions Used',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),

          // Description
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoadingAd ? null : () => _watchAd(context),
              icon: _isLoadingAd
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
                _isLoadingAd ? 'Loading Ad...' : 'Watch Ad to Convert',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cancel
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
    return BlocConsumer<PdfConversionBloc, PdfConversionState>(
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
        if (state.isCompleted && state.outputFilePath != null) {
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
  Widget _buildProgressState(PdfConversionState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress Indicator
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: state.progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.backgroundLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(state.progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      if (state.status == ConversionStatus.optimizing)
                        Text(
                          'Pass ${state.optimizationPass}/${state.totalOptimizationPasses}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Status Text
          Text(
            _getStatusText(state),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),

          // Page Progress
          if (state.totalPages > 0)
            Text(
              'Processing page ${state.currentPage} of ${state.totalPages}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
              ),
            ),
          const SizedBox(height: 40),

          // Cancel Button
          if (state.isConverting)
            TextButton.icon(
              onPressed: () {
                context
                    .read<PdfConversionBloc>()
                    .add(const CancelConversion());
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

  ///Build completed state UI
  Widget _buildCompletedState(PdfConversionState state) {
    // Only show banner for normal conversions (no target size)
    final isTargetSizeUsed = widget.settings.targetSize != null;
    final adsService = sl<AdsService>();
    final bannerAd = adsService.createBannerAdIfNeeded(
      isTargetSizeUsed: isTargetSizeUsed,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Banner Ad at the top - only for normal conversions
          if (bannerAd != null) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: bannerAd.size.width.toDouble(),
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
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

          // Title
          const Text(
            'PDF Created!',
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
                  'File Size',
                  state.formattedActualSize,
                  Icons.storage_rounded,
                ),
                const Divider(
                  color: AppColors.backgroundLight,
                  height: 24,
                ),
                _buildStatRow(
                  'Pages',
                  '${state.totalPages}',
                  Icons.description_rounded,
                ),
                const Divider(
                  color: AppColors.backgroundLight,
                  height: 24,
                ),
                _buildStatRow(
                  'Time',
                  state.formattedConversionTime,
                  Icons.timer_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Saved confirmation banner
          if (state.outputFilePath != null) ...[
            ConversionSuccessBanner(
              filePath: state.outputFilePath!,
            ),
            const SizedBox(height: 24),
          ],

          // Actions
          if (state.outputFilePath != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sharePdf(state.outputFilePath!),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPdf(state.outputFilePath!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ],
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              // Go back to home
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Build stat row
  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
          ),
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

  /// Get status text based on state
  String _getStatusText(PdfConversionState state) {
    switch (state.status) {
      case ConversionStatus.converting:
        return 'Creating PDF...';
      case ConversionStatus.optimizing:
        return 'Optimizing Size...';
      case ConversionStatus.estimating:
        return 'Calculating...';
      case ConversionStatus.cancelled:
        return 'Cancelled';
      case ConversionStatus.error:
        return 'Error';
      default:
        return 'Processing...';
    }
  }

  /// Watch rewarded ad using AdsService
  /// Shows ad and grants conversion if user earns reward
  Future<void> _watchAd(BuildContext context) async {
    // Show loading state
    setState(() => _isLoadingAd = true);

    try {
      // Get the ads service instance
      final adsService = AdsService();

      // Show the rewarded ad
      final result = await adsService.showRewardedAd();

      if (!mounted) return;

      if (result.rewarded) {
        // User earned the reward
        // Update monetization state
        context.read<MonetizationBloc>().add(const RefreshStatus());

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad watched! Starting conversion...'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Start the conversion
        _startConversion();
      } else {
        // Ad failed or was skipped
        setState(() => _isLoadingAd = false);

        // Show friendly error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Ad not available right now, please try again',
            ),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _watchAd(context),
            ),
          ),
        );
      }
    } catch (e) {
      // Handle unexpected errors
      if (!mounted) return;

      setState(() => _isLoadingAd = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad not available right now, please try again'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Loading state for ad
  bool _isLoadingAd = false;



  /// Share PDF
  void _sharePdf(String path) async {
    // Safety check: verify file exists before sharing
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. It may have been moved or deleted.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final exportService = sl<FileExportService>();
      await exportService.shareFiles([path], mimeType: 'application/pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Open PDF
  void _openPdf(String path) async {
    // Safety check: verify file exists before opening
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. It may have been moved or deleted.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final exportService = sl<FileExportService>();
      await exportService.openFile(path, mimeType: 'application/pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
