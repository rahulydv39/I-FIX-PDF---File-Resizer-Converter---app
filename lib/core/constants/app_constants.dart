/// Application-wide constants
/// Contains configuration values used throughout the app
library;

/// Core application constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'File Converter';
  static const String appVersion = '1.0.0';

  // Supported Image Formats
  static const List<String> supportedFormats = ['jpg', 'jpeg', 'png', 'webp', 'heic'];

  // Default DPI Presets
  static const List<int> dpiPresets = [72, 150, 300];
  static const int defaultDpi = 150;

  // Quality Settings
  static const int defaultQuality = 80;
  static const int minQuality = 10;
  static const int maxQuality = 100;

  // Page Sizes (in points, 72 points = 1 inch)
  static const double a4Width = 595.28; // 210mm
  static const double a4Height = 841.89; // 297mm

  // Size Optimization
  static const int maxOptimizationPasses = 3;
  static const double sizeTolerancePercent = 0.05; // ±5%

  // File paths
  static const String outputFolder = 'FileConverter';
  static const String convertedImagesFolder = 'FileConverter/Images';
}
