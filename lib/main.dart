// lib/main.dart - iOS ENHANCED VERSION WITH OFFLINE SUPPORT

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:face_auth/dashboard/simple_dashboard_view.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/utils/screen_size_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print("🚀 Starting iOS Face Authentication App...");
  
  // Firebase initialization with error handling
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("⚠️ Firebase initialization failed: $e");
    print("📱 Continuing in offline mode...");
    // Continue with app - offline features will still work
  }
  
  runApp(const FaceAuthApp());
}

class FaceAuthApp extends StatefulWidget {
  const FaceAuthApp({super.key});

  @override
  State<FaceAuthApp> createState() => _FaceAuthAppState();
}

class _FaceAuthAppState extends State<FaceAuthApp> {
  String? _authenticatedUserId;
  bool _isLoading = true;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    print("📱 iOS FaceAuthApp initialized");
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check connectivity first
      await _checkConnectivity();
      
      // Check authentication status
      await _checkAuthenticationStatus();
      
    } catch (e) {
      print("❌ App initialization error: $e");
      setState(() {
        _isLoading = false;
        _authenticatedUserId = null;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      print("📶 iOS App connectivity: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      print("⚠️ Connectivity check failed: $e");
      setState(() {
        _isOfflineMode = true;
      });
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      print("🔍 Checking iOS authentication status...");
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if user is authenticated and registration is complete
      String? userId = prefs.getString('authenticated_user_id');
      bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      bool registrationComplete = prefs.getBool('registration_complete_$userId') ?? false;
      bool faceRegistered = prefs.getBool('face_registered_$userId') ?? false;
      
      print("📊 Authentication check results:");
      print("   - User ID: $userId");
      print("   - Is authenticated: $isAuthenticated");
      print("   - Registration complete: $registrationComplete");
      print("   - Face registered: $faceRegistered");
      
      if (isAuthenticated && userId != null && (registrationComplete || faceRegistered)) {
        // Check if authentication is still valid (not expired)
        int? authTimestamp = prefs.getInt('authentication_timestamp');
        if (authTimestamp != null) {
          DateTime authDate = DateTime.fromMillisecondsSinceEpoch(authTimestamp);
          DateTime now = DateTime.now();
          int daysSinceAuth = now.difference(authDate).inDays;
          
          print("📅 Days since authentication: $daysSinceAuth");
          
          if (daysSinceAuth < 30) { // Authentication valid for 30 days
            print("✅ Valid authentication found - proceeding to dashboard");
            setState(() {
              _authenticatedUserId = userId;
              _isLoading = false;
            });
            return;
          } else {
            print("⏰ Authentication expired");
          }
        } else {
          print("⚠️ No authentication timestamp found");
        }
      } else {
        print("❌ No valid authentication found");
      }
      
      // Clear expired or invalid authentication
      await _clearAuthenticationData();
      
      setState(() {
        _authenticatedUserId = null;
        _isLoading = false;
      });
      
      print("🔄 Proceeding to PIN entry");
      
    } catch (e) {
      print("❌ Error checking authentication: $e");
      setState(() {
        _isLoading = false;
        _authenticatedUserId = null;
      });
    }
  }

  Future<void> _clearAuthenticationData() async {
    try {
      print("🧹 Clearing authentication data...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('authenticated_user_id');
      await prefs.remove('authenticated_employee_pin');
      await prefs.setBool('is_authenticated', false);
      await prefs.remove('authentication_timestamp');
      print("✅ Authentication data cleared");
    } catch (e) {
      print("❌ Error clearing authentication data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iOS Face Authentication',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(accentColor: accentColor),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.all(20),
          filled: true,
          fillColor: primaryWhite,
          hintStyle: TextStyle(
            color: primaryBlack.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          errorStyle: const TextStyle(
            letterSpacing: 0.8,
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: _isLoading 
        ? iOSSplashScreen(isOfflineMode: _isOfflineMode)
        : _authenticatedUserId != null 
          ? SimpleDashboardView(employeeId: _authenticatedUserId!)
          : const PinEntryView(),
      builder: (context, child) {
        // Initialize screen size utility
        ScreenSizeUtil.context = context;
        CustomSnackBar.context = context;
        return child!;
      },
    );
  }
}

class iOSSplashScreen extends StatelessWidget {
  final bool isOfflineMode;
  
  const iOSSplashScreen({
    Key? key,
    required this.isOfflineMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Loading indicator
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                
                const SizedBox(height: 24),
                
                // App title
                const Text(
                  "📱 iOS Face Authentication",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Status text
                Text(
                  isOfflineMode ? "📱 Initializing (Offline Mode)..." : "🌐 Initializing...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Connection status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOfflineMode 
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOfflineMode ? Colors.orange : Colors.green,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOfflineMode ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOfflineMode ? "Offline Mode" : "Online Mode",
                        style: TextStyle(
                          color: isOfflineMode ? Colors.orange : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Feature indicators
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow("🔐", "Face Recognition", true),
                      _buildFeatureRow("📱", "Offline Support", true),
                      _buildFeatureRow("☁️", "Cloud Sync", !isOfflineMode),
                      _buildFeatureRow("🔄", "Auto Recovery", true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String icon, String feature, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                feature,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Icon(
            isEnabled ? Icons.check_circle : Icons.circle_outlined,
            color: isEnabled ? Colors.green : Colors.grey,
            size: 16,
          ),
        ],
      ),
    );
  }
}