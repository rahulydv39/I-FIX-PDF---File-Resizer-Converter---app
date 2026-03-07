import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/di/injection_container.dart';
import '../data/services/usage_stats_service.dart';
import '../data/services/conversion_history_service.dart';

/// Service for handling authentication using Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of user authentication state
  Stream<User?> get user => _auth.authStateChanges();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // ── Sync data from Firestore after successful login ──
      await _syncDataFromFirestore();

      return userCredential;
    } catch (e) {
      // ignore: avoid_print
      print('Failed to sign in with Google: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Load stats and history from Firestore after login
  Future<void> _syncDataFromFirestore() async {
    try {
      print('🔄 Syncing data from Firestore...');

      // Load stats from Firestore
      final statsService = sl<UsageStatsService>();
      await statsService.loadFromFirestore();

      // Load history from Firestore
      final historyService = sl<ConversionHistoryService>();
      await historyService.loadFromFirestore();

      print('✅ Firestore sync complete');
    } catch (e) {
      print('⚠️ Firestore sync failed (non-fatal): $e');
    }
  }
}
