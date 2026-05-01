import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/ads_service.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/document_model.dart';
import '../../../domain/entities/folder_model.dart';
import '../../bloc/scanner/scanner_bloc.dart';
import '../../bloc/scanner/scanner_event.dart';
import '../../bloc/scanner/scanner_state.dart';
import 'scan_capture_screen.dart';

/// Main "My Documents" screen – document list + folders + search + FAB
class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  late final ScannerBloc _bloc;
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  String? _activeFolderId;

  BannerAd? _bannerAd;
  Widget? _bannerWidget;

  @override
  void initState() {
    super.initState();
    _bloc = sl<ScannerBloc>()..add(const LoadDocumentsEvent());
    
    final adsService = sl<AdsService>();
    _bannerAd = adsService.createBannerAd();
    if (_bannerAd != null) {
      _bannerWidget = Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 16),
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        decoration: BoxDecoration(
          color: AppColors.backgroundMedium,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AdWidget(ad: _bannerAd!),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: BlocListener<ScannerBloc, ScannerState>(
          listener: (ctx, state) {
            if (state is ScannerError) {
              ScaffoldMessenger.of(ctx)
                  .showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: NestedScrollView(
            headerSliverBuilder: (ctx, _) => [_buildSliverAppBar(ctx)],
            body: BlocBuilder<ScannerBloc, ScannerState>(
              builder: (ctx, state) {
                if (state is ScannerLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is SearchResultState) {
                  return _buildSearchResults(ctx, state);
                }
                if (state is DocumentsLoadedState) {
                  return _buildDocumentList(ctx, state);
                }
                return const Center(
                  child: Text('Tap + to scan your first document',
                      style: TextStyle(color: AppColors.textSecondaryDark)),
                );
              },
            ),
          ),
        ),
        floatingActionButton: _buildFAB(context),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext ctx) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'My Documents',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1B4B), AppColors.backgroundDark],
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: _buildSearchBar(ctx),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          if (v.isEmpty) {
            setState(() => _isSearching = false);
            ctx.read<ScannerBloc>().add(const LoadDocumentsEvent());
          } else {
            setState(() => _isSearching = true);
            ctx.read<ScannerBloc>().add(SearchDocumentsEvent(v));
          }
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search docs (marks, name, aadhaar…)',
          hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryDark, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondaryDark, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _isSearching = false);
                    ctx.read<ScannerBloc>().add(const LoadDocumentsEvent());
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.backgroundMedium,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext ctx) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      onPressed: () => Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<ScannerBloc>(),
            child: const ScanCaptureScreen(),
          ),
        ),
      ).then((_) => _bloc.add(const LoadDocumentsEvent())),
      icon: const Icon(Icons.document_scanner, color: Colors.white),
      label: const Text('Scan Document',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ── Document list ────────────────────────────────────────────────

  Widget _buildDocumentList(BuildContext ctx, DocumentsLoadedState state) {
    final hasFolders = state.folders.isNotEmpty;
    // If filtering by folder, just show docs for that folder (list view)
    if (_activeFolderId != null) {
      return _buildFolderFilteredList(ctx, state);
    }
    return CustomScrollView(
      slivers: [
        // ── Folders Grid ─────────────────────────────────────────
        if (hasFolders) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.folder_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  const Text('Folders',
                      style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showCreateFolderDialog(ctx),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildFolderCard(ctx, state.folders[i]),
                childCount: state.folders.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],

        // ── Files Header ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded,
                    color: AppColors.secondary, size: 18),
                const SizedBox(width: 6),
                const Text('Files',
                    style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const Spacer(),
                if (!hasFolders)
                  TextButton.icon(
                    onPressed: () => _showCreateFolderDialog(ctx),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                    label: const Text('New Folder'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero),
                  ),
              ],
            ),
          ),
        ),

        // Empty state for documents
        if (state.documents.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text('No documents yet',
                      style: TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Tap Scan Document to get started',
                      style: TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 12)),
                ],
              ),
            ),
          ),

        // ── Document List ───────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildDocCard(ctx, state.documents[i], state.folders),
              childCount: state.documents.length,
            ),
          ),
        ),

        // ── Banner Ad (immediately after content) ───────────────
        if (_bannerWidget != null)
          SliverToBoxAdapter(child: _bannerWidget!),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildFolderFilteredList(
      BuildContext ctx, DocumentsLoadedState state) {
    final folder =
        state.folders.firstWhere((f) => f.id == _activeFolderId,
            orElse: () => state.folders.first);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _activeFolderId = null);
                    ctx.read<ScannerBloc>().add(const LoadDocumentsEvent());
                  },
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.folder_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(folder.folderName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const Spacer(),
                Text('${state.documents.length} files',
                    style: const TextStyle(
                        color: AppColors.textSecondaryDark, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (state.documents.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text('No files in this folder',
                      style:
                          TextStyle(color: AppColors.textSecondaryDark)),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) =>
                  _buildDocCard(ctx, state.documents[i], state.folders),
              childCount: state.documents.length,
            ),
          ),
        ),
        if (_bannerWidget != null)
          SliverToBoxAdapter(child: _bannerWidget!),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildFolderCard(BuildContext ctx, FolderModel folder) {
    final isActive = _activeFolderId == folder.id;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFolderId = folder.id);
        ctx.read<ScannerBloc>().add(LoadDocumentsEvent(folderId: folder.id));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.backgroundMedium,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.backgroundLight,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive ? Icons.folder_open_rounded : Icons.folder_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder.folderName,
                style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                ctx.read<ScannerBloc>().add(DeleteFolderEvent(folder.id));
                if (_activeFolderId == folder.id) {
                  setState(() => _activeFolderId = null);
                }
              },
              child: const Icon(Icons.more_vert,
                  size: 16, color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard(
      BuildContext ctx, DocumentModel doc, List<FolderModel> folders) {
    final folder =
        folders.where((f) => f.id == doc.folderId).firstOrNull;
    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(ctx),
      onDismissed: (_) =>
          ctx.read<ScannerBloc>().add(DeleteDocumentEvent(doc.id)),
      child: GestureDetector(
        onTap: () => OpenFilex.open(doc.filePath),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.backgroundMedium,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.backgroundLight.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: _buildThumbnail(doc),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy · hh:mm a')
                            .format(doc.createdAt),
                        style: const TextStyle(
                            color: AppColors.textSecondaryDark, fontSize: 11),
                      ),
                      if (folder != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.folder_outlined,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(folder.folderName,
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              _buildDocActions(ctx, doc, folders),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(DocumentModel doc) {
    if (doc.thumbnailPath != null &&
        File(doc.thumbnailPath!).existsSync()) {
      return Image.file(
        File(doc.thumbnailPath!),
        width: 70,
        height: 90,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: 70,
      height: 90,
      color: AppColors.primary.withValues(alpha: 0.15),
      child: const Icon(Icons.picture_as_pdf,
          color: AppColors.primary, size: 32),
    );
  }

  Widget _buildDocActions(
      BuildContext ctx, DocumentModel doc, List<FolderModel> folders) {
    return PopupMenuButton<String>(
      color: AppColors.backgroundMedium,
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondaryDark),
      onSelected: (value) {
        switch (value) {
          case 'open':
            OpenFilex.open(doc.filePath);
            break;
          case 'share':
            SharePlus.instance.share(
                ShareParams(files: [XFile(doc.filePath)]));
            break;
          case 'rename':
            _showRenameDialog(ctx, doc);
            break;
          case 'move':
            _showMoveFolderDialog(ctx, doc, folders);
            break;
          case 'delete':
            ctx.read<ScannerBloc>().add(DeleteDocumentEvent(doc.id));
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'open',
            child: _MenuItem(Icons.open_in_new, 'Open')),
        PopupMenuItem(
            value: 'share',
            child: _MenuItem(Icons.share_outlined, 'Share')),
        PopupMenuItem(
            value: 'rename',
            child: _MenuItem(Icons.drive_file_rename_outline, 'Rename')),
        PopupMenuItem(
            value: 'move',
            child: _MenuItem(Icons.drive_file_move_outlined, 'Move to Folder')),
        PopupMenuItem(
            value: 'delete',
            child: _MenuItem(Icons.delete_outline, 'Delete', isDestructive: true)),
      ],
    );
  }

  // ── Search results ───────────────────────────────────────────────

  Widget _buildSearchResults(BuildContext ctx, SearchResultState state) {
    return CustomScrollView(
      slivers: [
        // Smart results banner
        if (state.smartResults.isNotEmpty)
          SliverToBoxAdapter(child: _buildSmartBanner(state)),

        if (state.documents.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text('No matches for "${state.query}"',
                  style: const TextStyle(color: AppColors.textSecondaryDark)),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildSearchDocCard(ctx, state.documents[i], state.query),
              childCount: state.documents.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartBanner(SearchResultState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text('Smart results for "${state.query}"',
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ...state.smartResults.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text('${e.key}: ',
                      style: const TextStyle(
                          color: AppColors.textSecondaryDark, fontSize: 13)),
                  Text(e.value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDocCard(
      BuildContext ctx, DocumentModel doc, String query) {
    final snippet = _getSnippet(doc.extractedText, query);
    return GestureDetector(
      onTap: () => OpenFilex.open(doc.filePath),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundMedium,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.backgroundLight.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(doc.fileName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(snippet,
                  style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontStyle: FontStyle.italic,
                      fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────

  void _showCreateFolderDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title: const Text('New Folder',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondaryDark))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ctx
                    .read<ScannerBloc>()
                    .add(CreateFolderEvent(ctrl.text.trim()));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext ctx, DocumentModel doc) {
    final ctrl = TextEditingController(
        text: doc.fileName.replaceAll('.pdf', ''));
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title: const Text('Rename Document',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Document name',
            hintStyle: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondaryDark))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ctx.read<ScannerBloc>().add(
                    RenameDocumentEvent(doc.id, '${ctrl.text.trim()}.pdf'));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showMoveFolderDialog(
      BuildContext ctx, DocumentModel doc, List<FolderModel> folders) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        title: const Text('Move to Folder',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off_outlined,
                    color: AppColors.textSecondaryDark),
                title: const Text('No folder',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  ctx
                      .read<ScannerBloc>()
                      .add(MoveToFolderEvent(doc.id, null));
                  Navigator.pop(ctx);
                },
              ),
              ...folders.map(
                (f) => ListTile(
                  leading: const Icon(Icons.folder_outlined,
                      color: AppColors.primary),
                  title: Text(f.folderName,
                      style: const TextStyle(color: Colors.white)),
                  trailing: doc.folderId == f.id
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ctx
                        .read<ScannerBloc>()
                        .add(MoveToFolderEvent(doc.id, f.id));
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.backgroundMedium,
            title: const Text('Delete Document?',
                style: TextStyle(color: Colors.white)),
            content: const Text('This action cannot be undone.',
                style: TextStyle(color: AppColors.textSecondaryDark)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _getSnippet(String text, String query) {
    final lText = text.toLowerCase();
    final lQuery = query.toLowerCase();
    final idx = lText.indexOf(lQuery);
    if (idx == -1) return '';
    final s = (idx - 20).clamp(0, text.length);
    final e = (idx + query.length + 40).clamp(0, text.length);
    var snippet = text.substring(s, e);
    if (s > 0) snippet = '…$snippet';
    if (e < text.length) snippet = '$snippet…';
    return snippet;
  }
}

/// Reusable popup menu item
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _MenuItem(this.icon, this.label, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : Colors.white;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}
