import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/di/injection_container.dart';
import 'app.dart';
import 'presentation/screens/splash_screen.dart';

/// Application entry point
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // Note: Ensure you have run 'flutterfire configure' to generate firebase_options.dart
  // Or remove DefaultFirebaseOptions.currentPlatform if manually managing config
  await Firebase.initializeApp();

  // Initialize MediaStorePlus for Android Gallery saving
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = "FileConverter";
  }

  // Set preferred orientations (portrait only for better UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  // Initialize dependencies
  await initDependencies();

  // Run the app with SplashScreen as home
  runApp(const FileConverterApp(home: SplashScreen()));
}

// Extracted helper for initialization if firebase_options.dart is missing during initial setup step
extension FirebaseInit on Firebase {
  static Future<void> initializeAppForLogin() async {
    try {
        // Try to load options if available, catch if not generated yet.
        // Assuming user acts on 'Firebase Setup' instructions.
        // For robustness, we just call initializeApp() and let it auto-detect google-services.json
        await Firebase.initializeApp();
    } catch (e) {
      print("Firebase initialization error: $e");
    }
  }
}
