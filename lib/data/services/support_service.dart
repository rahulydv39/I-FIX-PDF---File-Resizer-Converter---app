import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';

/// Service for handling support, rating, and external links
class SupportService {
  final InAppReview _inAppReview = InAppReview.instance;

  /// Support contact details
  static const String supportEmail = 'rahulyadav969102@gmail.com';
  static const String supportPhone = '+919504356783'; // Normalized for tel: scheme

  /// Request app review or open store listing
  Future<void> rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing();
      }
    } catch (e) {
      debugPrint('Error rating app: $e');
      // Fallback to opening store listing if requestReview fails
      try {
         await _inAppReview.openStoreListing();
      } catch (e) {
         debugPrint('Error opening store listing: $e');
      }
    }
  }

  /// Open email client for support
  Future<void> contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQueryParameters({
        'subject': 'Support Request - File Converter App',
        'body': 'Describe your issue here...',
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        debugPrint('Could not launch email client');
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  /// Call support number
  Future<void> callSupport() async {
    final Uri telLaunchUri = Uri(
      scheme: 'tel',
      path: supportPhone,
    );

    try {
      if (await canLaunchUrl(telLaunchUri)) {
        await launchUrl(telLaunchUri);
      } else {
        debugPrint('Could not launch dialer');
      }
    } catch (e) {
      debugPrint('Error launching dialer: $e');
    }
  }

  // Helper to encode query parameters properly
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
