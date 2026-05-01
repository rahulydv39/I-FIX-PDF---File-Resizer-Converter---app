import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/permission_handler_utils.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/entities/folder_model.dart';
import '../../../domain/entities/document_model.dart';
import '../../bloc/scanner/scanner_bloc.dart';
import '../../bloc/scanner/scanner_event.dart';
import '../../bloc/scanner/scanner_state.dart';
import '../../../data/services/document_image_processor.dart';
import '../../../services/ads_service.dart';
import '../../widgets/info_sheet.dart';
/// Camera capture → preview → name → save screen
class ScanCaptureScreen extends StatefulWidget {
  const ScanCaptureScreen({super.key});

  @override
  State<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends State<ScanCaptureScreen> {
  final _nameCtrl = TextEditingController();
  List<FolderModel> _folders = [];
  String? _selectedFolderId;
  bool _scanStarted = false;

  @override
  void initState() {
    super.initState();
    // Load folders then trigger scan
    context.read<ScannerBloc>().add(LoadFoldersEvent());
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
        title: const Text('Scan Document'),
        backgroundColor: AppColors.backgroundDark,
        actions: [
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
                  title: 'Scanner',
                  description: 'Scan physical documents using your device camera.',
                  steps: [
                    'Point the camera at your document and capture',
                    'Scan one or multiple pages',
                    'Apply filters (Original, B&W, etc.)',
                    'Name the document and tap Save Document',
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (ctx, state) async {
          if (state is FoldersLoadedState) {
            setState(() => _folders = state.folders);
            if (!_scanStarted) {
              // ── Camera permission check ──────────────────────────
              // Request camera ONLY when the user is about to scan.
              // Rationale dialog explains why before the system prompt.
              if (!ctx.mounted) return;
              final granted = await PermissionHandlerUtils.requestCameraPermission(ctx);
              if (!granted) {
                // Permission denied — pop back gracefully
                if (ctx.mounted) Navigator.pop(ctx);
                return;
              }
              // ─────────────────────────────────────────────────────
              _scanStarted = true;
              if (ctx.mounted) ctx.read<ScannerBloc>().add(StartScanEvent());
            }
          }
          if (state is ScannerError) {
            ScaffoldMessenger.of(ctx)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is ScannerSuccessState) {
            _showResultDialog(ctx, state.savedDocument);
            // Show video ad after successfully saving the scan
            sl<AdsService>().showInterstitialAd();
          }
          if (state is ScannerInitial) {
            // User cancelled scanning
            Navigator.pop(ctx);
          }
        },
        builder: (ctx, state) {
          if (state is ScannerPreviewState) {
            // Set suggested name once
            if (_nameCtrl.text.isEmpty) {
              _nameCtrl.text = state.suggestedName;
            }
            return _buildPreview(ctx, state);
          }
          return _buildLoading();
        },
      ),
    );
  }

  // ── Loading ──────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text('Opening scanner…',
              style: TextStyle(color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────

  Widget _buildPreview(BuildContext ctx, ScannerPreviewState state) {
    return Column(
      children: [
        // Image preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: state.filteredImagesBytes != null && state.filteredImagesBytes!.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: state.filteredImagesBytes!.length,
                          itemBuilder: (context, index) {
                            return Image.memory(
                              state.filteredImagesBytes![index], 
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                        if (state.filteredImagesBytes!.length > 1)
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${state.filteredImagesBytes!.length} Pages Swipe \u2194',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),

        // Filters
        _buildFilterRow(ctx, state),

        // Name field + folder + actions
        _buildBottomPanel(ctx, state),
      ],
    );
  }

  Widget _buildFilterRow(BuildContext ctx, ScannerPreviewState state) {
    final filters = [
      (DocumentFilter.original, 'Original'),
      (DocumentFilter.grayscale, 'Grayscale'),
      (DocumentFilter.blackAndWhite, 'B & W'),
      (DocumentFilter.enhanced, 'Enhanced'),
    ];
    return Container(
      height: 56,
      color: AppColors.backgroundMedium,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: filters
            .map((f) => _filterChip(ctx, f.$1, f.$2, state.activeFilter))
            .toList(),
      ),
    );
  }

  Widget _filterChip(BuildContext ctx, DocumentFilter filter, String label,
      DocumentFilter active) {
    final isActive = filter == active;
    return GestureDetector(
      onTap: () => ctx.read<ScannerBloc>().add(ApplyFilterEvent(filter)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondaryDark,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext ctx, ScannerPreviewState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundMedium,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name field
          const Text('Document Name',
              style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Aadhaar_Card',
              hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
              filled: true,
              fillColor: AppColors.backgroundDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear,
                    size: 18, color: AppColors.textSecondaryDark),
                onPressed: () => _nameCtrl.clear(),
              ),
            ),
          ),

          // Folder selector
          if (_folders.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Save in Folder (optional)',
                style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: _selectedFolderId,
              dropdownColor: AppColors.backgroundMedium,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.backgroundDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None',
                      style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ..._folders.map(
                  (f) => DropdownMenuItem(
                    value: f.id,
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(f.folderName),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedFolderId = v),
            ),
          ],

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.backgroundLight),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    _nameCtrl.clear();
                    _scanStarted = false;
                    // Re-check camera permission on retake
                    if (!ctx.mounted) return;
                    final granted =
                        await PermissionHandlerUtils.requestCameraPermission(ctx);
                    if (granted && ctx.mounted) {
                      _scanStarted = true;
                      ctx.read<ScannerBloc>().add(StartScanEvent());
                    }
                  },
                  icon: const Icon(Icons.refresh,
                      color: AppColors.textSecondaryDark),
                  label: const Text('Retake',
                      style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: state.isSaving
                      ? null
                      : () {
                          ctx.read<ScannerBloc>().add(SaveDocumentEvent(
                                customName: _nameCtrl.text.trim(),
                                folderId: _selectedFolderId,
                              ));
                        },
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_alt, color: Colors.white),
                  label: Text(state.isSaving ? 'Saving…' : 'Save Document',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result Action ────────────────────────────────────────────────

  void _showResultDialog(BuildContext ctx, DocumentModel doc) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
            SizedBox(height: 12),
            Text('Saved Successfully!',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'File saved to your device. You can open, share, or organize it now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        ),
        actions: [
          _resultButton(
            icon: Icons.open_in_new,
            label: 'Open',
            onTap: () => OpenFilex.open(doc.filePath),
          ),
          _resultButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () => SharePlus.instance
                .share(ShareParams(files: [XFile(doc.filePath)])),
          ),
          _resultButton(
            icon: Icons.folder_outlined,
            label: 'Move to Folder',
            onTap: () {
              Navigator.pop(ctx); // Close result dialog
              _showMoveFolderDialog(ctx, doc);
            },
          ),
          const Divider(color: AppColors.backgroundLight),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close result dialog
                Navigator.pop(ctx); // Go back to documents list
              },
              child: const Text('Back to Documents',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title:
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: onTap,
    );
  }

  void _showMoveFolderDialog(BuildContext ctx, DocumentModel doc) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title:
            const Text('Move to Folder', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._folders.map((f) => ListTile(
                    leading: const Icon(Icons.folder_outlined,
                        color: AppColors.primary),
                    title: Text(f.folderName,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      ctx
                          .read<ScannerBloc>()
                          .add(MoveToFolderEvent(doc.id, f.id));
                      Navigator.pop(ctx); // Close move dialog
                      Navigator.pop(ctx); // Go back to documents list
                    },
                  )),
              if (_folders.isEmpty)
                const Text('No folders created yet.',
                    style: TextStyle(color: AppColors.textSecondaryDark)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }
}
