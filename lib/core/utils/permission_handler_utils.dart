/// Permission Handler Utilities
/// Centralised, reusable functions for requesting runtime permissions.
///
/// Usage:
///   final granted = await PermissionHandlerUtils.requestCameraPermission(context);
///   if (!granted) return; // user denied or permanently denied
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionHandlerUtils {
  PermissionHandlerUtils._(); // prevent instantiation

  // ────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ────────────────────────────────────────────────────────────────

  /// Request camera permission.
  ///
  /// Shows a rationale dialog before the system prompt,
  /// and guides the user to Settings if permanently denied.
  ///
  /// Returns `true` if permission is granted, `false` otherwise.
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    // Already granted — no dialog needed
    if (status.isGranted) return true;

    // Permanently denied — go to settings
    if (status.isPermanentlyDenied) {
      await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Camera',
        reason:
            'Camera access has been permanently denied. '
            'Please enable it in App Settings to scan documents.',
      );
      return false;
    }

    // Show rationale dialog then request
    if (!context.mounted) return false;
    final proceed = await _showRationaleDialog(
      context,
      title: 'Camera Access Required',
      icon: Icons.camera_alt_rounded,
      iconColor: const Color(0xFF6366F1),
      reason:
          'This app needs Camera access to scan documents.\n\n'
          'The camera is only used when you tap "Scan Document" and '
          'is never accessed in the background.',
    );
    if (!proceed || !context.mounted) return false;

    final result = await Permission.camera.request();

    if (result.isGranted) return true;

    if (result.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Camera',
        reason:
            'Camera access was permanently denied. '
            'Please enable it in App Settings.',
      );
      return false;
    }

    // Denied (not permanently) — show a soft message
    if (context.mounted) {
      _showDeniedSnackBar(context, 'Camera permission denied. Cannot scan documents.');
    }
    return false;
  }

  /// Request storage / gallery permission.
  ///
  /// Handles Android 13+ (`READ_MEDIA_IMAGES`) and older
  /// (`READ_EXTERNAL_STORAGE`) automatically.
  ///
  /// Returns `true` if permission is granted, `false` otherwise.
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // On Android 13+ the system photo picker handles its own
    // access — we may not need a permission at all. But we still
    // guard with READ_MEDIA_IMAGES for apps that access file paths
    // directly (which this app does via image_picker path returns).

    final permission = await _storagePermission();
    final status = await permission.status;

    // Already granted
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Photos / Storage',
        reason:
            'Photo access has been permanently denied. '
            'Please enable it in App Settings to select or save files.',
      );
      return false;
    }

    // Show rationale dialog then request
    if (!context.mounted) return false;
    final proceed = await _showRationaleDialog(
      context,
      title: 'Photo Library Access',
      icon: Icons.photo_library_rounded,
      iconColor: const Color(0xFF10B981),
      reason:
          'This app needs access to your Photo Library to let you '
          'select images for conversion.\n\n'
          'Files are only read when you explicitly choose them and '
          'are never uploaded anywhere.',
    );
    if (!proceed || !context.mounted) return false;

    final result = await permission.request();

    if (result.isGranted || result.isLimited) return true;

    if (result.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showPermanentlyDeniedDialog(
        context,
        permissionName: 'Photos / Storage',
        reason:
            'Photo access was permanently denied. '
            'Please enable it in App Settings.',
      );
      return false;
    }

    if (context.mounted) {
      _showDeniedSnackBar(context, 'Storage permission denied. Cannot access photos.');
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────
  //  PRIVATE HELPERS
  // ────────────────────────────────────────────────────────────────

  /// Returns the correct storage permission based on platform / OS version.
  static Future<Permission> _storagePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return Permission.photos;
      }
      return Permission.storage;
    }
    return Permission.photos; // iOS
  }

  /// Shows a bottom-sheet-style rationale dialog.
  ///
  /// Returns `true` if the user pressed "Allow", `false` if dismissed/cancelled.
  static Future<bool> _showRationaleDialog(
    BuildContext context, {
    required String title,
    required String reason,
    required IconData icon,
    required Color iconColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B8D1),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F3D56)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Not Now',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Allow Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// Shows a dialog guiding the user to open App Settings.
  static Future<void> _showPermanentlyDeniedDialog(
    BuildContext context, {
    required String permissionName,
    required String reason,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFFBBF24),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                '$permissionName Permission Blocked',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B8D1),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3F3D56)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await openAppSettings();
                      },
                      icon: const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Open Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a non-intrusive snackbar when permission is denied (not permanent).
  static void _showDeniedSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF374151),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
