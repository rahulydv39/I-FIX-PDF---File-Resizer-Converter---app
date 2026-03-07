/// Walkthrough Service
/// Manages first-time app walkthrough and onboarding experience
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/theme/app_colors.dart';

/// Service for managing app walkthrough and onboarding
class WalkthroughService {
  static const String _keyFirstLaunch = 'is_first_launch';
  
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    
    print('🎯 Walkthrough Service Initialized');
  }
  
  /// Check if this is the first app launch
  Future<bool> isFirstLaunch() async {
    await _ensureInitialized();
    
    // Default to true for first launch
    final isFirst = _prefs!.getBool(_keyFirstLaunch) ?? true;
    print('🎯 Is first launch: $isFirst');
    return isFirst;
  }
  
  /// Mark walkthrough as completed
  Future<void> markWalkthroughComplete() async {
    await _ensureInitialized();
    
    await _prefs!.setBool(_keyFirstLaunch, false);
    print('✅ Walkthrough marked complete');
  }
  
  /// Reset walkthrough (for manual replay)
  Future<void> resetWalkthrough() async {
    await _ensureInitialized();
    
    await _prefs!.setBool(_keyFirstLaunch, true);
    print('🔄 Walkthrough reset - will show on next launch');
  }
  
  /// Start the app walkthrough
  Future<void> startWalkthrough(
    BuildContext context, {
    required GlobalKey photoPdfKey,
    required GlobalKey photoPhotoKey,
    required GlobalKey pdfMergeKey,
    required GlobalKey profileKey,
  }) async {
    await _ensureInitialized();
    
    print('🎯 Starting walkthrough...');
    
    // Create tutorial targets
    List<TargetFocus> targets = [];
    
    // 1. Photo → PDF
    if (photoPdfKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "photoPdf",
          keyTarget: photoPdfKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildContent(
                  title: 'Photo to PDF',
                  description: 'Convert your images into a single PDF in seconds.',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                );
              },
            ),
          ],
        ),
      );
    }
    
    // 2. Photo → Photo
    if (photoPhotoKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "photoPhoto",
          keyTarget: photoPhotoKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildContent(
                  title: 'Photo Conversion',
                  description: 'Compress, resize and change image formats here.',
                  icon: Icons.photo_size_select_large_rounded,
                  color: AppColors.secondary,
                );
              },
            ),
          ],
        ),
      );
    }
    
    // 3. PDF Merge
    if (pdfMergeKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "pdfMerge",
          keyTarget: pdfMergeKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildContent(
                  title: 'PDF Merge',
                  description: 'Merge multiple PDFs into one document.',
                  icon: Icons.merge_rounded,
                  color: AppColors.accent,
                );
              },
            ),
          ],
        ),
      );
    }
    
    // 4. Profile
    if (profileKey.currentContext != null) {
      targets.add(
        TargetFocus(
          identify: "profile",
          keyTarget: profileKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          radius: 25,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildContent(
                  title: 'Your Profile',
                  description: 'Track your usage and manage your account here.',
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                );
              },
            ),
          ],
        ),
      );
    }
    
    if (targets.isEmpty) {
      print('⚠️ No targets available for walkthrough');
      return;
    }
    
    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      paddingFocus: 10,
      alignSkip: Alignment.topRight,
      textSkip: "SKIP",
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      onFinish: () {
        print('✅ Walkthrough finished');
        markWalkthroughComplete();
      },
      onSkip: () {
        print('⏭️ Walkthrough skipped');
        markWalkthroughComplete();
        return true;
      },
    );
    
    // Show intro dialog first
    final shouldContinue = await _showWelcomeDialog(context);
    
    if (shouldContinue) {
      tutorial.show(context: context);
    } else {
      markWalkthroughComplete();
    }
  }
  
  /// Build content widget for tooltip
  Widget _buildContent({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show welcome dialog
  Future<bool> _showWelcomeDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                Icons.auto_fix_high_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to File Converter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryDark,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Convert, compress and manage your files easily.\n\nWould you like a quick tour of the main features?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Skip',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
    
    return result ?? false;
  }
  
  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
