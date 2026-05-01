import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../core/utils/permission_handler_utils.dart';
import '../../domain/entities/conversion_mode.dart';
import '../../data/services/walkthrough_service.dart';
import '../bloc/image_selection/image_selection_bloc.dart';
import '../bloc/image_selection/image_selection_event.dart';
import '../bloc/image_selection/image_selection_state.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../bloc/monetization/monetization_state.dart';
import '../widgets/image_grid.dart';
import '../widgets/empty_state.dart';
import 'settings_screen.dart';
import 'photo_settings_screen.dart';
import 'pdf_merge_screen.dart';

/// Main home screen with conversion mode selection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConversionType _selectedMode = ConversionType.imageToPdf;

  // Global keys for walkthrough targets
  final GlobalKey _photoPdfKey = GlobalKey();
  final GlobalKey _photoPhotoKey = GlobalKey();
  final GlobalKey _pdfMergeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  /// Check if first launch and start walkthrough
  Future<void> _checkAndStartWalkthrough() async {
    try {
      final walkthroughService = sl<WalkthroughService>();
      final isFirst = await walkthroughService.isFirstLaunch();
      
      if (isFirst && mounted) {
        // Find profile key from parent navigator
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          await walkthroughService.startWalkthrough(
            context,
            photoPdfKey: _photoPdfKey,
            photoPhotoKey: _photoPhotoKey,
            pdfMergeKey: _pdfMergeKey,
            profileKey: GlobalKey(), // Will be passed from main shell
          );
        }
      }
    } catch (e) {
      print('❌ Error starting walkthrough: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(context),

              // Mode Selector
              _buildModeSelector(),

              // Main Content
              Expanded(
                child: _selectedMode == ConversionType.pdfMerge
                    ? _buildPdfMergeContent()
                    : BlocBuilder<ImageSelectionBloc, ImageSelectionState>(
                        builder: (context, state) {
                          if (state.hasImages) {
                            return _buildImagePreview(context, state);
                          }
                          return EmptyState(
                            title: _selectedMode == ConversionType.imageToPdf
                                ? 'No Images Selected'
                                : 'Add Photos to Convert',
                            subtitle: _selectedMode == ConversionType.imageToPdf
                                ? 'Add images to create a PDF document'
                                : 'Select photos to resize, compress, or change format',
                          );
                        },
                      ),
              ),

              // Bottom Actions
              if (_selectedMode != ConversionType.pdfMerge)
                _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Build custom app bar
  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App Logo & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_fix_high_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I FIX PDF',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  Text(
                    'Convert • Resize • Compress',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Free Conversions Counter
          BlocBuilder<MonetizationBloc, MonetizationState>(
            builder: (context, state) {
              return _buildFreeConversionsCounter(state);
            },
          ),
        ],
      ),
    );
  }

  /// Build mode selector tabs
  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildModeTab(
            key: _photoPdfKey,
            mode: ConversionType.imageToPdf,
            icon: Icons.picture_as_pdf_rounded,
            label: 'Photo to PDF',
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          _buildModeTab(
            key: _photoPhotoKey,
            mode: ConversionType.imageToImage,
            icon: Icons.photo_size_select_large_rounded,
            label: 'Photo',
            color: AppColors.secondary,
          ),
          const SizedBox(width: 4),
          _buildModeTab(
            key: _pdfMergeKey,
            mode: ConversionType.pdfMerge,
            icon: Icons.merge_rounded,
            label: 'PDF Merge',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    Key? key,
    required ConversionType mode,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.7),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : AppColors.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build free conversions counter
  Widget _buildFreeConversionsCounter(MonetizationState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Unlimited',
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Build PDF merge content
  Widget _buildPdfMergeContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PDF Merge Icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.merge_rounded,
              size: 64,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Merge PDFs',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Combine multiple PDF files into one document.\nDrag to reorder, set target size, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 40),

          // Open PDF Merge Screen Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PdfMergeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Select PDFs to Merge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build image preview section
  Widget _buildImagePreview(BuildContext context, ImageSelectionState state) {
    return Column(
      children: [
        // Stats Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.image_rounded,
                label: 'Images',
                value: '${state.imageCount}',
              ),
              _buildStatItem(
                icon: Icons.storage_rounded,
                label: 'Total Size',
                value: state.formattedTotalSize,
              ),
              _buildStatItem(
                icon: _selectedMode == ConversionType.imageToPdf
                    ? Icons.description_rounded
                    : Icons.photo_library_rounded,
                label: _selectedMode == ConversionType.imageToPdf
                    ? 'PDF Pages'
                    : 'Output Files',
                value: '${state.imageCount}',
              ),
            ],
          ),
        ),

        // Image Grid
        Expanded(
          child: ImageGrid(images: state.images),
        ),
      ],
    );
  }

  /// Build stat item widget
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: _selectedMode == ConversionType.imageToPdf
              ? AppColors.primary
              : AppColors.secondary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }

  /// Build bottom action buttons
  Widget _buildBottomActions(BuildContext context) {
    final isPdfMode = _selectedMode == ConversionType.imageToPdf;
    final primaryColor = isPdfMode ? AppColors.primary : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BlocBuilder<ImageSelectionBloc, ImageSelectionState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add Images Row
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        icon: Icons.add_photo_alternate_rounded,
                        label: 'Add Images',
                        onTap: () => _pickImages(context),
                        isPrimary: !state.hasImages,
                        color: primaryColor,
                      ),
                    ),
                    if (state.hasImages) ...[
                      const SizedBox(width: 12),
                      _buildIconButton(
                        context: context,
                        icon: Icons.clear_all_rounded,
                        tooltip: 'Clear All',
                        onTap: () => _clearImages(context),
                      ),
                    ],
                  ],
                ),

                // Convert Button
                if (state.hasImages) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      context: context,
                      icon: isPdfMode
                          ? Icons.picture_as_pdf_rounded
                          : Icons.auto_fix_high_rounded,
                      label: isPdfMode ? 'Convert to PDF' : 'Convert Images',
                      onTap: () => _startConversion(context),
                      isPrimary: true,
                      isGradient: true,
                      color: primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build action button
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isGradient = false,
    Color color = AppColors.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isGradient
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                )
              : null,
          color: isPrimary && !isGradient ? color : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary || isGradient
                  ? Colors.white
                  : AppColors.textPrimaryDark,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary || isGradient
                    ? Colors.white
                    : AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build icon button
  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimaryDark,
            size: 22,
          ),
        ),
      ),
    );
  }

  /// Pick images from gallery — requests storage permission first.
  void _pickImages(BuildContext context) async {
    // ── Storage / Gallery permission check ────────────────────────
    // Permission is only requested when the user explicitly taps
    // "Add Images". A rationale dialog explains the purpose first.
    final granted =
        await PermissionHandlerUtils.requestStoragePermission(context);
    if (!granted || !context.mounted) return;
    // ─────────────────────────────────────────────────────
    context.read<ImageSelectionBloc>().add(const PickMultipleImages());
  }

  /// Clear all images
  void _clearImages(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Images?'),
        content:
            const Text('This will remove all selected images from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ImageSelectionBloc>().add(const ClearImages());
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Start conversion - navigate to appropriate settings screen
  void _startConversion(BuildContext context) {
    final Widget settingsScreen;

    if (_selectedMode == ConversionType.imageToPdf) {
      settingsScreen = const SettingsScreen();
    } else {
      settingsScreen = const PhotoSettingsScreen();
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
          child: settingsScreen,
        ),
      ),
    );
  }


}
