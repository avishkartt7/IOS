

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SimpleFirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static User? _currentUser;

  /// Get current authenticated user
  static User? get currentUser => _currentUser ?? _auth.currentUser;

  /// Check if user is currently authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Ensure user is authenticated (using anonymous authentication)
  static Future<bool> ensureAuthenticated() async {
    try {
      // Check if already authenticated
      if (isAuthenticated) {
        debugPrint("✅ User already authenticated: ${currentUser?.uid}");
        return true;
      }

      debugPrint("🔐 No authentication found, signing in anonymously...");

      // Sign in anonymously for file upload capabilities
      final UserCredential result = await _auth.signInAnonymously();
      _currentUser = result.user;

      if (_currentUser != null) {
        debugPrint("✅ Anonymous authentication successful");
        debugPrint("👤 User ID: ${_currentUser!.uid}");
        debugPrint("🔗 Provider: ${_currentUser!.providerData.isEmpty ? 'Anonymous' : _currentUser!.providerData.first.providerId}");
        return true;
      } else {
        debugPrint("❌ Anonymous authentication failed - no user returned");
        return false;
      }

    } catch (e) {
      debugPrint("❌ Authentication error: $e");
      debugPrint("🔍 Error type: ${e.runtimeType}");

      // Provide specific error handling
      if (e.toString().contains('network')) {
        debugPrint("💡 Network error detected - check internet connection");
      } else if (e.toString().contains('disabled')) {
        debugPrint("💡 Anonymous authentication may be disabled in Firebase Console");
      }

      return false;
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      debugPrint("✅ User signed out successfully");
    } catch (e) {
      debugPrint("❌ Error signing out: $e");
    }
  }

  /// Get authentication state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Initialize the service and listen to auth state changes
  static void initialize() {
    debugPrint("🚀 Initializing SimpleFirebaseAuthService");

    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      if (user != null) {
        debugPrint("👤 Auth state changed: User signed in (${user.uid})");
      } else {
        debugPrint("👤 Auth state changed: User signed out");
      }
    });

    // Check current authentication status
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      debugPrint("✅ Service initialized with existing user: ${_currentUser!.uid}");
    } else {
      debugPrint("ℹ️ Service initialized - no existing authentication");
    }
  }

  /// Refresh authentication token (useful for long-running sessions)
  static Future<bool> refreshToken() async {
    try {
      if (_currentUser != null) {
        debugPrint("🔄 Refreshing authentication token...");

        // Force token refresh
        final String? token = await _currentUser!.getIdToken(true);

        if (token != null && token.isNotEmpty) {
          debugPrint("✅ Token refreshed successfully");
          return true;
        } else {
          debugPrint("❌ Token refresh failed - empty token");
          return false;
        }
      } else {
        debugPrint("❌ Cannot refresh token - no authenticated user");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Error refreshing token: $e");
      return false;
    }
  }

  /// Get current user's ID token
  static Future<String?> getIdToken() async {
    try {
      if (_currentUser != null) {
        return await _currentUser!.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error getting ID token: $e");
      return null;
    }
  }

  /// Check Firebase Auth connection
  static Future<bool> checkConnection() async {
    try {
      debugPrint("🔍 Checking Firebase Auth connection...");

      // Try to get current user (this will fail if no connection)
      final User? user = _auth.currentUser;

      // If we have a user, try to refresh token to test connection
      if (user != null) {
        await user.getIdToken(false);
        debugPrint("✅ Firebase Auth connection is healthy");
        return true;
      } else {
        // Try anonymous sign-in to test connection
        await _auth.signInAnonymously();
        await _auth.signOut();
        debugPrint("✅ Firebase Auth connection test successful");
        return true;
      }
    } catch (e) {
      debugPrint("❌ Firebase Auth connection failed: $e");
      return false;
    }
  }

  /// Force re-authentication if needed
  static Future<bool> reAuthenticate() async {
    try {
      debugPrint("🔄 Re-authenticating user...");

      // Sign out first
      await signOut();

      // Sign in again
      return await ensureAuthenticated();
    } catch (e) {
      debugPrint("❌ Re-authentication failed: $e");
      return false;
    }
  }

  /// Get user authentication info
  static Map<String, dynamic> getUserInfo() {
    if (_currentUser == null) {
      return {
        'isAuthenticated': false,
        'uid': null,
        'provider': null,
        'email': null,
        'isAnonymous': false,
      };
    }

    return {
      'isAuthenticated': true,
      'uid': _currentUser!.uid,
      'provider': _currentUser!.providerData.isEmpty
          ? 'anonymous'
          : _currentUser!.providerData.first.providerId,
      'email': _currentUser!.email,
      'isAnonymous': _currentUser!.isAnonymous,
      'creationTime': _currentUser!.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': _currentUser!.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  /// Debug method to print current auth status
  static void printAuthStatus() {
    final info = getUserInfo();
    debugPrint("=== FIREBASE AUTH STATUS ===");
    debugPrint("Authenticated: ${info['isAuthenticated']}");
    debugPrint("User ID: ${info['uid']}");
    debugPrint("Provider: ${info['provider']}");
    debugPrint("Email: ${info['email']}");
    debugPrint("Anonymous: ${info['isAnonymous']}");
    debugPrint("Creation: ${info['creationTime']}");
    debugPrint("Last Sign In: ${info['lastSignInTime']}");
    debugPrint("===========================");
  }
} 