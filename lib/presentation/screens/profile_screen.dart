/// Profile Screen
/// Shows user profile, login/logout, and subscription details
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/di/injection_container.dart';
import '../../services/auth_service.dart';
import '../../data/services/usage_stats_service.dart';
import '../../data/services/conversion_history_service.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/walkthrough_service.dart';
import '../../data/services/support_service.dart';
import '../bloc/monetization/monetization_bloc.dart';
import '../bloc/monetization/monetization_state.dart';
import 'image_history_screen.dart';
import 'pdf_history_screen.dart';
import 'scanner/my_documents_screen.dart';

/// Profile screen with user info and subscription management
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.backgroundDark,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(context),
            const SizedBox(height: 24),

            // Subscription Section
            _buildSubscriptionSection(context),
            const SizedBox(height: 24),

            // Usage Stats
            _buildUsageStats(context),
            const SizedBox(height: 24),

            // Settings Section
            _buildSettingsSection(context),
            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(context),
            const SizedBox(height: 24),

            // Sign Out Button
            _buildSignOutButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Build profile header
  Widget _buildProfileHeader(BuildContext context) {
    final user = sl<AuthService>().currentUser;
    final email = user?.email ?? 'No Email';
    final name = user?.displayName ?? 'User';
    final photoUrl = user?.photoURL;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.secondary.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 3,
              ),
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // User Info
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Build free conversions section
  Widget _buildSubscriptionSection(BuildContext context) {
    return BlocBuilder<MonetizationBloc, MonetizationState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.confirmation_num_rounded,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Free Conversions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.backgroundLight, height: 24),

              _buildInfoRow(
                'Conversions',
                'Unlimited',
                AppColors.success,
              ),
              const SizedBox(height: 12),
              const Text(
                'Convert as many files as you want',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build usage stats
  Widget _buildUsageStats(BuildContext context) {
    final historyService = sl<ConversionHistoryService>();
    
    return ValueListenableBuilder<HistoryStats?>(
      valueListenable: historyService.statsNotifier,
      builder: (context, stats, _) {
        final pdf = stats?.pdfCount ?? 0;
        final photo = stats?.imageCount ?? 0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_rounded, color: AppColors.secondary),
                  SizedBox(width: 12),
                  Text(
                    'Usage Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const Divider(color: AppColors.backgroundLight, height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'PDFs Created',
                      '$pdf',
                      Icons.picture_as_pdf_rounded,
                      AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PdfHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Images Converted',
                      '$photo',
                      Icons.photo_library_rounded,
                      AppColors.secondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ImageHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Scanned Documents Card
              Container(
                width: double.infinity,
                child: _buildStatCard(
                  'Scanned Documents History',
                  'Search & View OCR texts',
                  Icons.document_scanner_rounded,
                  AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyDocumentsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build settings section
  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_rounded, color: AppColors.textSecondaryDark),
              SizedBox(width: 12),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.backgroundLight, height: 24),

          _buildSettingsTile(
            'Notifications',
            Icons.notifications_rounded,
            onTap: () => _showNotificationSettings(context),
          ),
          _buildSettingsTile(
            'Storage',
            Icons.storage_rounded,
            onTap: () => _showStorageInfo(context),
          ),
          _buildSettingsTile(
            'Show App Tour',
            Icons.tour_rounded,
            onTap: () => _replayWalkthrough(context),
          ),
          _buildSettingsTile(
            'Clear Cache',
            Icons.delete_sweep_rounded,
            onTap: () => _showClearCacheDialog(context),
          ),
        ],
      ),
    );
  }

  /// Build about section
  Widget _buildAboutSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_rounded, color: AppColors.textSecondaryDark),
              SizedBox(width: 12),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.backgroundLight, height: 24),

          _buildSettingsTile(
            'Privacy Policy',
            Icons.privacy_tip_rounded,
            onTap: () => _showPrivacyPolicy(context),
          ),
          _buildSettingsTile(
            'Terms of Service',
            Icons.description_rounded,
            onTap: () => _showTermsOfService(context),
          ),
          _buildSettingsTile(
            'Rate App',
            Icons.star_rounded,
            onTap: () => _rateApp(context),
          ),
          _buildSettingsTile(
            'Contact Support',
            Icons.support_agent_rounded,
            onTap: () => _contactSupport(context),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build sign out button
  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
            // Confirm logout
            final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out?'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );

            if (shouldLogout == true) {
              await sl<AuthService>().signOut();
            }
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  /// Build info row
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// Build stat card
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (onTap != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build settings tile
  Widget _buildSettingsTile(
    String title,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondaryDark),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimaryDark),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondaryDark,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }





  /// Show clear cache dialog
  void _showClearCacheDialog(BuildContext context) {
    final settingsService = AppSettingsService();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all temporary files. Your converted files will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await settingsService.clearCache();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully!')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Replay app walkthrough
  static void _replayWalkthrough(BuildContext context) {
    final walkthroughService = sl<WalkthroughService>();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.tour_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'App Tour',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will guide you through all the main features of the app.\\n\\nWould you like to start the tour?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryDark,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Reset walkthrough flag
              await walkthroughService.resetWalkthrough();
              
              // Show message to go to home tab
              if (!context.mounted) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please go to the Converter tab to start the tour'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Start Tour'),
          ),
        ],
      ),
    );
  }

  /// Show notification settings dialog
  void _showNotificationSettings(BuildContext context) {
    final settingsService = AppSettingsService();
    
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<bool>(
        future: settingsService.getNotificationsEnabled(),
        builder: (context, snapshot) {
          var notificationsEnabled = snapshot.data ?? true;
          
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Notification Settings'),
                content: SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive conversion completion updates'),
                  value: notificationsEnabled,
                  onChanged: (value) {
                    setState(() => notificationsEnabled = value);
                    settingsService.setNotificationsEnabled(value);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Show storage info dialog
  void _showStorageInfo(BuildContext context) {
    final settingsService = AppSettingsService();
    
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<int>(
        future: settingsService.getStorageUsage(),
        builder: (context, snapshot) {
          final bytes = snapshot.data ?? 0;
          final formattedSize = settingsService.formatBytes(bytes);
          
          return AlertDialog(
            title: const Text('Storage Usage'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Storage',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedSize,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This includes all converted files and app data.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show privacy policy — Google Play compliant
  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.backgroundMedium,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Updated: April 2026',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Camera Permission ──────────────────────────
                    _buildPolicyCard(
                      icon: Icons.camera_alt_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: '📷  Camera Access',
                      body:
                          'Camera is used ONLY when you tap "Scan Document" to capture '
                          'a physical document.\n\n'
                          '• Never accessed in the background\n'
                          '• No photos are stored without your action\n'
                          '• Scanned images are saved locally on your device only',
                    ),
                    const SizedBox(height: 12),

                    // ── Storage Permission ─────────────────────────
                    _buildPolicyCard(
                      icon: Icons.photo_library_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: '🗂️  Storage & Photos',
                      body:
                          'Storage access is used ONLY when you choose to select images '
                          'from your gallery or save a converted file.\n\n'
                          '• Files are read only when you explicitly select them\n'
                          '• Saved files go to your device storage only\n'
                          '• We never browse or scan your files automatically',
                    ),
                    const SizedBox(height: 12),

                    // ── Local Processing ───────────────────────────
                    _buildPolicyCard(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: '🔐  Your Data Stays on Your Device',
                      body:
                          'All conversions, scanning, and OCR processing happen '
                          'entirely on your device.\n\n'
                          '• No personal data is collected, stored, or shared\n'
                          '• Your images and documents are never uploaded to any server\n'
                          '• No account required to use core features',
                    ),
                    const SizedBox(height: 12),

                    // ── What we do collect ─────────────────────────
                    _buildPolicyCard(
                      icon: Icons.analytics_outlined,
                      iconColor: const Color(0xFF64748B),
                      title: '📊  What We Do Collect',
                      body:
                          'To improve the app we may collect anonymised crash reports '
                          'and usage analytics (e.g. which features are used most). '
                          'This data contains no files, images, or personal information.',
                    ),
                    const SizedBox(height: 12),

                    // ── Ads ────────────────────────────────────────
                    _buildPolicyCard(
                      icon: Icons.ad_units_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: '📢  Advertisements',
                      body:
                          'This app shows ads via Google AdMob. AdMob may use '
                          'device identifiers to show relevant ads as described in '
                          'Google\'s Privacy Policy. You can opt out via your device\'s '
                          'ad settings.',
                    ),
                    const SizedBox(height: 12),

                    // ── Contact ────────────────────────────────────
                    const _PolicySectionTitle('📬  Contact Us'),
                    const SizedBox(height: 6),
                    const Text(
                      'For privacy questions or data deletion requests:\n'
                      'rahulyadav969102@gmail.com',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Privacy Policy helper widgets ──────────────────────────────────

  Widget _buildPolicyCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Temporary getter for backgroundMedium fallback ─
  // (uses cardDark if backgroundMedium is not defined)

  // ignore: unused_element
  Color get _backgroundMedium =>
      AppColors.cardDark;

  /// Show privacy policy — Google Play compliant (original section kept below)
  void _unused_showPrivacyPolicyLegacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(title: Text(''))
    );
  }
  // This stub is intentionally empty — the new _showPrivacyPolicy above
  // replaces it fully. The legacy method reference is removed.

  // ─────────────────────────────────────────────────────────────────
  // Placeholder to keep the structure — the legacy privacy sections
  // that were here (4. Third-Party Services onwards) are now within
  // _showPrivacyPolicy via _buildPolicyCard widgets above.
  //
  // DO NOT add content below this comment — it is unreachable.
  // ─────────────────────────────────────────────────────────────────

  // ignore: unused_element
  void _legacyPrivacyText() {
    // Previously: sections 4–6 of the old dialog.
    // Now replaced by the card-based layout in _showPrivacyPolicy().
  }

  /// Section title helper used inside Privacy Policy dialog.

  /// Rate app
  void _rateApp(BuildContext context) {
    sl<SupportService>().rateApp();
  }

  /// Contact support
  void _contactSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like to contact us?',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 24),
            
            // Email Support
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.email_rounded, color: AppColors.primary),
              ),
              title: const Text(
                'Email Support',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              subtitle: const Text(
                'rahulyadav969102@gmail.com',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              ),
              onTap: () {
                Navigator.pop(ctx);
                sl<SupportService>().contactSupport();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Phone Support
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_rounded, color: AppColors.secondary),
              ),
              title: const Text(
                'Call Support',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              subtitle: const Text(
                '+91 9504356783',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              ),
              onTap: () {
                Navigator.pop(ctx);
                sl<SupportService>().callSupport();
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Show terms of service
  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Updated: February 2026\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '1. Acceptance of Terms\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'By using I FIX PDF, you agree to these terms. If you disagree with any part of these terms, you may not use our app.\n\n',
              ),
              Text(
                '2. License\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'We grant you a limited, non-exclusive, non-transferable license to use I FIX PDF for personal or commercial purposes.\n\n',
              ),
              Text(
                '3. Acceptable Use\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'You agree to:\n'
                '• Use the app lawfully\n'
                '• Not reverse engineer the app\n'
                '• Not distribute modified versions\n'
                '• Not use for illegal content conversion\n\n',
              ),
              Text(
                '4. Conversions\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'You acknowledge that:\n'
                '• Conversions are unlimited and free\n'
                '• Quality depends on source files\n'
                '• Large files may take longer to process\n'
                '• We are not responsible for conversion quality\n\n',
              ),
              Text(
                '5. Intellectual Property\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'You retain all rights to files you convert. We do not claim ownership of your content.\n\n',
              ),
              Text(
                '6. Disclaimer of Warranties\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'The app is provided "as is" without warranties of any kind. We do not guarantee uninterrupted or error-free service.\n\n',
              ),
              Text(
                '7. Limitation of Liability\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'We are not liable for any damages arising from app use, including data loss or corruption.\n\n',
              ),
              Text(
                '8. Changes to Terms\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'We reserve the right to modify these terms at any time. Continued use constitutes acceptance of new terms.\n\n',
              ),
              Text(
                '9. Contact\n\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'For questions about these terms:\n'
                'legal@fileconverter.app',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Section title widget used inside the Privacy Policy dialog.
class _PolicySectionTitle extends StatelessWidget {
  final String title;
  const _PolicySectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
