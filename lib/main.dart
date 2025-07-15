import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:face_auth/dashboard/dashboard_view.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/utils/screen_size_util.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
    // Continue with app - some features may not work
  }

  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _authenticatedUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if user is authenticated and registration is complete
      String? userId = prefs.getString('authenticated_user_id');
      bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      bool registrationComplete = prefs.getBool('registration_complete_$userId') ?? false;
      
      if (isAuthenticated && userId != null && registrationComplete) {
        // Check if authentication is still valid (not expired)
        int? authTimestamp = prefs.getInt('authentication_timestamp');
        if (authTimestamp != null) {
          DateTime authDate = DateTime.fromMillisecondsSinceEpoch(authTimestamp);
          DateTime now = DateTime.now();
          int daysSinceAuth = now.difference(authDate).inDays;
          
          if (daysSinceAuth < 30) { // Authentication valid for 30 days
            setState(() {
              _authenticatedUserId = userId;
              _isLoading = false;
            });
            return;
          }
        }
      }
      
      // Clear expired or invalid authentication
      await _clearAuthenticationData();
      
      setState(() {
        _authenticatedUserId = null;
        _isLoading = false;
      });
    } catch (e) {
      print("Error checking authentication: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAuthenticationData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('authenticated_user_id');
    await prefs.remove('authenticated_employee_pin');
    await prefs.setBool('is_authenticated', false);
    await prefs.remove('authentication_timestamp');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Authentication App',
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
        ? const SplashScreen() 
        : _authenticatedUserId != null 
          ? DashboardView(employeeId: _authenticatedUserId!)
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

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldTopGradientClr,
              scaffoldBottomGradientClr,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Face Authentication",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Initializing...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}