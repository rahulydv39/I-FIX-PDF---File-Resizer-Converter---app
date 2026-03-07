/// PDF Merge Screen
/// Screen for selecting PDFs to merge with settings
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../widgets/target_size_selector.dart';
import '../widgets/conversion_success_banner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../domain/entities/pdf_merge_settings.dart';
import '../../domain/entities/conversion_history_item.dart';
import '../../data/services/pdf_merge_service.dart';
import '../../data/services/file_export_service.dart';
import '../../data/services/conversion_history_service.dart';
import '../../services/ads_service.dart';
import '../../data/services/usage_stats_service.dart';
import '../../core/constants/target_size_config.dart';

/// Screen for PDF merge with settings
class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final PdfMergeService _service = sl<PdfMergeService>();
  List<PdfItem> _selectedPdfs = [];
  PdfMergeSettings _settings = const PdfMergeSettings();
  bool _isProcessing = false;
  double _progress = 0;
  PdfMergeResult? _result;
  String? _error;

  // Target size state
  int _selectedTargetSizeKb = TargetSizeConfig.defaultSizeKb;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('PDF Merge'),
        backgroundColor: AppColors.backgroundDark,
      ),
      body: _result != null
          ? _buildCompletedState()
          : _isProcessing
              ? _buildProcessingState()
              : _buildMainContent(),
      bottomNavigationBar: _result == null && !_isProcessing
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected PDFs Section
          _buildSection(
            title: 'Selected PDFs',
            icon: Icons.picture_as_pdf_rounded,
            trailing: TextButton.icon(
              onPressed: _pickPdfs,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add PDFs'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
            child: _buildPdfList(),
          ),

          if (_selectedPdfs.isNotEmpty) ...[
            const SizedBox(height: 20),

            // Merge Options Section
            _buildSection(
              title: 'Merge Options',
              icon: Icons.settings_rounded,
              child: _buildMergeOptions(),
            ),

            const SizedBox(height: 20),

            // Target File Size Section
            _buildSection(
              title: 'Target File Size',
              icon: Icons.compress_rounded,
              trailing: Switch(
                value: _settings.enableSizeTarget,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(enableSizeTarget: value);
                  });
                },
              ),
              child: _settings.enableSizeTarget
                  ? _buildTargetSizeInput()
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Summary Section
            _buildSection(
              title: 'Summary',
              icon: Icons.summarize_rounded,
              child: _buildSummary(),
            ),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPdfList() {
    if (_selectedPdfs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No PDFs selected',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "Add PDFs" to select files',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedPdfs.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _selectedPdfs.removeAt(oldIndex);
          _selectedPdfs.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final pdf = _selectedPdfs[index];
        return _buildPdfItem(pdf, index);
      },
    );
  }

  Widget _buildPdfItem(PdfItem pdf, int index) {
    return Container(
      key: ValueKey(pdf.path),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Drag handle
          const Icon(
            Icons.drag_handle_rounded,
            color: AppColors.textSecondaryDark,
            size: 20,
          ),
          const SizedBox(width: 12),

          // PDF icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // PDF info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pdf.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pdf.formattedSize,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),

          // Order indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Remove button
          IconButton(
            onPressed: () {
              setState(() {
                _selectedPdfs.removeAt(index);
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondaryDark,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeOptions() {
    return Column(
      children: [
        // Include bookmarks
        _buildOptionRow(
          title: 'Include Bookmarks',
          subtitle: 'Keep bookmarks from source PDFs',
          icon: Icons.bookmark_rounded,
          value: _settings.includeBookmarks,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(includeBookmarks: value);
            });
          },
        ),
        const Divider(color: AppColors.backgroundLight, height: 24),
        // Maintain order
        _buildOptionRow(
          title: 'Maintain Order',
          subtitle: 'PDFs will be merged in the order shown',
          icon: Icons.sort_rounded,
          value: _settings.maintainOrder,
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(maintainOrder: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildTargetSizeInput() {
    return TargetSizeSelector(
      selectedSizeKb: _selectedTargetSizeKb,
      onSizeChanged: (sizeKb) {
        setState(() {
          _selectedTargetSizeKb = sizeKb;
          _settings = _settings.copyWith(
            targetSizeBytes: TargetSizeConfig.kbToBytes(sizeKb),
          );
        });
      },
    );
  }

  Widget _buildSummary() {
    final totalSize = _service.estimateMergedSize(_selectedPdfs);
    final formattedSize = totalSize < 1024 * 1024
        ? '${(totalSize / 1024).toStringAsFixed(1)} KB'
        : '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';

    return Column(
      children: [
        _buildSummaryRow('Total PDFs', '${_selectedPdfs.length}'),
        const SizedBox(height: 8),
        _buildSummaryRow('Estimated Size', formattedSize),
        if (_settings.enableSizeTarget) ...[
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Target Size',
            TargetSizeConfig.getLabel(_selectedTargetSizeKb),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
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

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.backgroundLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Center(
                  child: Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Merging PDFs...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing ${_selectedPdfs.length} files',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    // Only show banner for normal conversions (no target size)
    final isTargetSizeUsed = _settings.enableSizeTarget && 
                             _settings.targetSizeBytes != null;
    final adsService = sl<AdsService>();
    final bannerAd = adsService.createBannerAdIfNeeded(
      isTargetSizeUsed: isTargetSizeUsed,
    );
    
    return Center(
      child: SingleChildScrollView(
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

          const Text(
            'PDF Merged!',
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
                  'PDFs Merged',
                  '${_result!.pdfCount}',
                  Icons.picture_as_pdf_rounded,
                ),
                const Divider(color: AppColors.backgroundLight, height: 24),
                _buildStatRow(
                  'File Size',
                  _result!.formattedSize,
                  Icons.storage_rounded,
                ),
                const Divider(color: AppColors.backgroundLight, height: 24),
                _buildStatRow(
                  'Time Taken',
                  _result!.formattedTime,
                  Icons.timer_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Saved confirmation banner
          if (_result != null) ...[
            ConversionSuccessBanner(
              filePath: _result!.outputPath,
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sharePdf(_result!.outputPath),
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
              onPressed: () => _openPdf(_result!.outputPath),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
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

  Widget _buildBottomBar() {
    final canMerge = _selectedPdfs.length >= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canMerge)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Select at least 2 PDFs to merge',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: canMerge ? _startMerge : null,
                icon: const Icon(Icons.merge_rounded),
                label: Text(
                  canMerge
                      ? 'Merge ${_selectedPdfs.length} PDFs'
                      : 'Add More PDFs',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.backgroundLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdfs() async {
    final pdfs = await _service.pickPdfFiles();
    if (pdfs.isNotEmpty) {
      setState(() {
        _selectedPdfs.addAll(pdfs);
      });
    }
  }

  Future<void> _startMerge() async {
    // Start merge immediately (unlimited conversions)
    setState(() {
      _isProcessing = true;
      _progress = 0;
    });

    // Show appropriate ad based on target size usage
    final isTargetSizeUsed = _settings.enableSizeTarget &&
                             _settings.targetSizeBytes != null;
    final adsService = sl<AdsService>();
    await adsService.showAdIfNeeded(isTargetSizeUsed: isTargetSizeUsed);
    _error = null;

    try {
      final result = await _service.mergePdfs(
        pdfs: _selectedPdfs,
        settings: _settings,
        onProgress: (progress) {
          setState(() => _progress = progress);
        },
      );

      setState(() {
        _isProcessing = false;
        _result = result;
      });

      // Increment PDF created counter
      final statsService = sl<UsageStatsService>();
      await statsService.incrementPdfCreated();

      // Save to history
      try {
        final historyService = sl<ConversionHistoryService>();
        final file = File(result.outputPath);
        final fileName = result.outputPath.split('/').last;
        final fileSize = await file.exists() ? await file.length() : result.totalSize;
        await historyService.addHistory(ConversionHistoryItem(
          fileName: fileName,
          filePath: result.outputPath,
          fileType: ConversionFileType.pdf,
          createdAt: DateTime.now(),
          fileSize: fileSize,
        ));
      } catch (e) {
        print('⚠️ Failed to save merge history: $e');
      }

      print('✅ PDF Merge Complete:');

      // Show "File saved" snackbar
      if (mounted) {
        ConversionSuccessBanner.showSavedSnackBar(context);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $_error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }



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
