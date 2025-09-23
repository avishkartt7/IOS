// lib/main.dart - COMPLETE IMPLEMENTATION WITH GEOFENCE MONITORING AND ORIENTATION SUPPORT

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/onboarding/onboarding_screen.dart';
import 'package:face_auth_compatible/pin_entry/pin_entry_view.dart';
import 'package:face_auth_compatible/dashboard/dashboard_view.dart';
import 'package:face_auth_compatible/constants/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth_compatible/services/service_locator.dart';
import 'package:face_auth_compatible/services/simple_firebase_auth_service.dart';
import 'package:face_auth_compatible/model/enhanced_face_features.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import the services for offline functionality
import 'package:face_auth_compatible/services/sync_service.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/secure_face_storage_service.dart';
import 'package:face_auth_compatible/services/face_data_migration_service.dart';
import 'package:face_auth_compatible/services/geofence_exit_monitoring_service.dart'; // NEW
import 'package:connectivity_plus/connectivity_plus.dart';

// Add these imports for permissions
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:face_auth_compatible/repositories/polygon_location_repository.dart';
import 'package:face_auth_compatible/repositories/location_exemption_repository.dart';

import 'package:flutter/services.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    print("Handling a background message: ${message.messageId}");
  } catch (e) {
    print("Background message handler error: $e");
  }
}

void main() async {
  // Enhanced error handling wrapper - COMPATIBLE VERSION
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    print("🚀 Starting Android App with Geofence Exit Monitoring...");

    // ✅ NEW: Allow all orientations for tablet support
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Set clean white status bar from the start
    await _setSafeSystemUI();

    // Global Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print("Flutter Error: ${details.exception}");
      print("Stack trace: ${details.stack}");
    };

    // Initialize Firebase with proper error handling
    await _initializeFirebaseSafely();

    // Set the background messaging handler
    await _setupFirebaseMessagingSafely();

    // Initialize local notifications
    await _initializeLocalNotificationsSafely();

    // Initialize Firestore for offline persistence
    await _initializeFirestoreOfflineMode();

    // Request permissions early
    await requestAppPermissions();

    // Setup service locator FIRST
    await setupServiceLocator();
    listRegisteredServices();

    // ✅ NEW: Initialize geofence monitoring service after service locator
    await _initializeGeofenceMonitoringService();

    // Initialize location exemptions after service locator
    await _initializeLocationExemptions();

    // Check and migrate existing face data
    await _migrateFaceDataSafely();

    // Initialize sync service after service locator is setup
    await _initializeSyncServiceSafely();

    runApp(const MyApp());

  }, (error, stack) {
    // Catch uncaught errors
    print("Uncaught Error: $error");
    print("Stack trace: $stack");
  });
}

// ✅ NEW: Initialize geofence monitoring service
Future<void> _initializeGeofenceMonitoringService() async {
  try {
    print("🛡️ Initializing geofence exit monitoring service...");

    // Check if service is registered
    if (!getIt.isRegistered<GeofenceExitMonitoringService>()) {
      print("❌ GeofenceExitMonitoringService not registered in service locator");
      return;
    }

    // Get the service and initialize database
    final geofenceService = getIt<GeofenceExitMonitoringService>();
    await geofenceService.initializeDatabase();

    print("✅ Geofence exit monitoring service initialized successfully");

    // Test the service
    bool isActive = await geofenceService.isMonitoringActive();
    String? currentEmployee = await geofenceService.getCurrentMonitoredEmployee();

    print("📊 Geofence Monitoring Status:");
    print("  - Active: $isActive");
    print("  - Current Employee: ${currentEmployee ?? 'None'}");

  } catch (e) {
    print("❌ Error initializing geofence monitoring service: $e");
    print("Stack trace: ${StackTrace.current}");
    // Don't rethrow - allow app to continue without geofence monitoring
  }
}

// Enhanced - Safer system UI setup
Future<void> _setSafeSystemUI() async {
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  } catch (e) {
    print("Status bar setup failed: $e");
  }
}

// Enhanced - Firebase initialization with retry logic
Future<void> _initializeFirebaseSafely() async {
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      await Firebase.initializeApp().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Firebase initialization timed out');
        },
      );
      print("✅ Firebase initialized successfully");
      return;
    } catch (e) {
      retryCount++;
      print("❌ Firebase initialization attempt $retryCount failed: $e");

      if (retryCount >= maxRetries) {
        print("❌ Firebase initialization failed after $maxRetries attempts");
        // Continue without Firebase for offline functionality
        break;
      }

      // Wait before retry
      await Future.delayed(Duration(seconds: 2));
    }
  }
}

// Enhanced - Safer Firebase messaging setup
Future<void> _setupFirebaseMessagingSafely() async {
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print("✅ Firebase messaging setup completed");
  } catch (e) {
    print("⚠️ Firebase messaging setup failed: $e");
  }
}

// Enhanced - Safer notification initialization
Future<void> _initializeLocalNotificationsSafely() async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print("✅ Local notifications initialized");
  } catch (e) {
    print("⚠️ Local notifications setup failed: $e");
  }
}

// Initialize location exemptions with enhanced error handling
Future<void> _initializeLocationExemptions() async {
  try {
    print("🔧 Setting up location exemptions...");

    // Check if we have connectivity with timeout
    var connectivityResult = await Connectivity()
        .checkConnectivity()
        .timeout(Duration(seconds: 5), onTimeout: () => ConnectivityResult.none);

    bool isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      print("📱 Offline mode - skipping exemption setup");
      return;
    }

    try {
      final exemptionRepository = getIt<LocationExemptionRepository>();
      bool success = await exemptionRepository
          .createTestExemptionForPIN1244()
          .timeout(Duration(seconds: 10));

      if (success) {
        print("✅ Location exemption setup completed for PIN 3576");
      } else {
        print("⚠️ Location exemption setup failed or already exists");
      }
    } catch (e) {
      print("⚠️ Location exemption service not available: $e");
    }
  } catch (e) {
    print("❌ Error setting up location exemptions: $e");
  }
}

// Enhanced - Safer face data migration
Future<void> _migrateFaceDataSafely() async {
  try {
    final storageService = getIt<SecureFaceStorageService>();
    final migrationService = FaceDataMigrationService(storageService);
    await migrationService.migrateExistingData();
    print("✅ Face data migration completed");
  } catch (e) {
    print("⚠️ Face data migration failed: $e");
  }
}

// Enhanced - Safer sync service initialization
Future<void> _initializeSyncServiceSafely() async {
  try {
    final syncService = getIt<SyncService>();
    print("✅ Sync service initialized");
  } catch (e) {
    print("⚠️ Sync service initialization failed: $e");
  }
}

// Request app permissions with better error handling
Future<void> requestAppPermissions() async {
  if (Platform.isAndroid) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      print("Requesting app permissions for Android SDK: ${androidInfo.version.sdkInt}");

      // Enhanced - Individual permission requests with error handling
      await _requestStoragePermissionsSafely(androidInfo.version.sdkInt);
      await _requestCameraPermissionSafely();
      await _requestLocationPermissionsSafely(); // Important for geofence monitoring
      await _requestNotificationPermissionSafely();

      // ✅ NEW: Request background location permission for geofence monitoring
      await _requestBackgroundLocationPermissionSafely(androidInfo.version.sdkInt);

      print("✅ Permissions requested successfully");

    } catch (e) {
      print("Error requesting app permissions: $e");
    }
  }
}

// Enhanced - Safer storage permission requests
Future<void> _requestStoragePermissionsSafely(int sdkVersion) async {
  try {
    if (sdkVersion >= 33) {
      // Android 13+
      await Permission.photos.request();
      await Permission.mediaLibrary.request();
    } else if (sdkVersion >= 30) {
      // Android 11-12
      await Permission.storage.request();
    } else {
      // Android 10 and below
      await Permission.storage.request();
    }
    print("✅ Storage permissions requested");
  } catch (e) {
    print("Storage permission error: $e");
  }
}

// Enhanced - Safer camera permission request
Future<void> _requestCameraPermissionSafely() async {
  try {
    await Permission.camera.request();
    print("✅ Camera permission requested");
  } catch (e) {
    print("Camera permission error: $e");
  }
}

// Enhanced - Safer location permission requests
Future<void> _requestLocationPermissionsSafely() async {
  try {
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
    print("✅ Location permissions requested");
  } catch (e) {
    print("Location permission error: $e");
  }
}

// ✅ NEW: Request background location permission for geofence monitoring
Future<void> _requestBackgroundLocationPermissionSafely(int sdkVersion) async {
  try {
    if (sdkVersion >= 29) { // Android 10+
      // First request foreground location
      final foregroundStatus = await Permission.location.request();

      if (foregroundStatus.isGranted) {
        // Then request background location
        final backgroundStatus = await Permission.locationAlways.request();

        if (backgroundStatus.isGranted) {
          print("✅ Background location permission granted");
        } else {
          print("⚠️ Background location permission denied - geofence monitoring may be limited");
        }
      }
    } else {
      print("✅ Background location not required for this Android version");
    }
  } catch (e) {
    print("Background location permission error: $e");
  }
}

// Enhanced - Safer notification permission request
Future<void> _requestNotificationPermissionSafely() async {
  try {
    await Permission.notification.request();
    print("✅ Notification permission requested");
  } catch (e) {
    print("Notification permission error: $e");
  }
}

// Configure Firestore for offline persistence
Future<void> _initializeFirestoreOfflineMode() async {
  try {
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    print("✅ Firestore offline mode configured");
  } catch (e) {
    print("❌ Error configuring Firestore offline mode: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _showOnboarding;
  String? _loggedInEmployeeId;
  bool _isLoading = true;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check connectivity first
      await _checkConnectivity();

      // Check authentication status (PIN-based like iOS)
      await _checkPinBasedAuthentication();

      // Initialize location data and admin account
      await _initializeLocationData();
      await _initializeAdminAccount();

      // Setup auth state listener
      _setupAuthStateListener();

    } catch (e) {
      print("❌ App initialization error: $e");
      setState(() {
        _isLoading = false;
        _loggedInEmployeeId = null;
        _showOnboarding = false;
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      print("📶 App connectivity: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      print("⚠️ Connectivity check failed: $e");
      setState(() {
        _isOfflineMode = true;
      });
    }
  }

  // PIN-based authentication (like iOS)
  Future<void> _checkPinBasedAuthentication() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

    if (!onboardingComplete) {
      setState(() {
        _showOnboarding = true;
        _isLoading = false;
      });
      return;
    }

    // Check for PIN-based authentication (like iOS)
    String? authenticatedUserId = prefs.getString('authenticated_user_id');
    bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    int? authTimestamp = prefs.getInt('authentication_timestamp');

    debugPrint("🔍 Checking PIN-based authentication status...");
    debugPrint("   - User ID: $authenticatedUserId");
    debugPrint("   - Is Authenticated: $isAuthenticated");
    debugPrint("   - Auth Timestamp: $authTimestamp");

    if (isAuthenticated && authenticatedUserId != null) {
      // Check if authentication is recent (within 30 days)
      if (authTimestamp != null) {
        DateTime authDate = DateTime.fromMillisecondsSinceEpoch(authTimestamp);
        DateTime now = DateTime.now();
        int daysSinceAuth = now.difference(authDate).inDays;

        debugPrint("   - Days since auth: $daysSinceAuth");

        if (daysSinceAuth > 30) {
          debugPrint("⚠️ Authentication expired (30+ days), requiring re-login");
          await _clearAuthenticationData();
          setState(() {
            _showOnboarding = false;
            _loggedInEmployeeId = null;
            _isLoading = false;
          });
          return;
        }
      }

      // Check if user has COMPLETE registration (including face)
      bool hasCompleteRegistration = await _checkCompleteRegistration(authenticatedUserId);

      if (hasCompleteRegistration) {
        debugPrint("✅ Complete registration found, auto-login to dashboard");
        setState(() {
          _loggedInEmployeeId = authenticatedUserId;
          _showOnboarding = false;
          _isLoading = false;
        });
        return;
      } else {
        debugPrint("❌ Incomplete registration, requiring PIN entry");
        setState(() {
          _showOnboarding = false;
          _loggedInEmployeeId = null;
          _isLoading = false;
        });
        return;
      }
    }

    // No valid authentication found
    debugPrint("❌ No valid authentication found, showing PIN entry");
    setState(() {
      _showOnboarding = false;
      _loggedInEmployeeId = null;
      _isLoading = false;
    });
  }

  Future<bool> _checkCompleteRegistration(String employeeId) async {
    try {
      debugPrint("🔍 Checking complete registration for: $employeeId");

      // Check local storage first
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check local registration flags
      bool localFaceRegistered = prefs.getBool('face_registered_$employeeId') ?? false;
      String? storedImage = prefs.getString('employee_image_$employeeId');
      bool hasLocalImage = storedImage != null && storedImage.isNotEmpty;

      // Check if we have complete local registration data
      String? userData = prefs.getString('user_data_$employeeId');
      bool hasLocalData = userData != null;

      if (localFaceRegistered && hasLocalImage && hasLocalData) {
        try {
          Map<String, dynamic> data = jsonDecode(userData);
          bool profileCompleted = data['profileCompleted'] ?? false;
          bool registrationCompleted = data['registrationCompleted'] ?? false;
          bool faceRegistered = data['faceRegistered'] ?? false;
          bool enhancedRegistration = data['enhancedRegistration'] ?? false;

          bool isCompletelyRegistered = profileCompleted &&
              registrationCompleted &&
              (faceRegistered || enhancedRegistration || localFaceRegistered);

          if (isCompletelyRegistered) {
            debugPrint("✅ Complete registration confirmed locally");
            return true;
          }
        } catch (e) {
          debugPrint("⚠️ Error parsing local user data: $e");
        }
      }

      // Check online if we're connected
      if (!_isOfflineMode) {
        try {
          debugPrint("🌐 Checking complete registration online...");

          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(employeeId)
              .get()
              .timeout(Duration(seconds: 10));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            bool profileCompleted = data['profileCompleted'] ?? false;
            bool registrationCompleted = data['registrationCompleted'] ?? false;
            bool faceRegistered = data['faceRegistered'] ?? false;
            bool enhancedRegistration = data['enhancedRegistration'] ?? false;
            bool hasImage = data.containsKey('image') && data['image'] != null;

            debugPrint("📋 Online Registration Status:");
            debugPrint("   - profileCompleted: $profileCompleted");
            debugPrint("   - registrationCompleted: $registrationCompleted");
            debugPrint("   - faceRegistered: $faceRegistered");
            debugPrint("   - enhancedRegistration: $enhancedRegistration");
            debugPrint("   - hasImage: $hasImage");

            bool isCompletelyRegistered = profileCompleted &&
                registrationCompleted &&
                (faceRegistered || enhancedRegistration) &&
                hasImage;

            if (isCompletelyRegistered) {
              debugPrint("✅ Complete registration confirmed online");

              // Update local storage
              await prefs.setBool('face_registered_$employeeId', true);
              await prefs.setString('user_data_$employeeId', jsonEncode(data));

              if (data['image'] != null) {
                await prefs.setString('employee_image_$employeeId', data['image']);
              }

              return true;
            } else {
              debugPrint("❌ Registration incomplete online");
              return false;
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error checking online registration: $e");
        }
      }

      debugPrint("❌ Complete registration not found");
      return false;

    } catch (e) {
      debugPrint("❌ Error checking complete registration: $e");
      return false;
    }
  }

  // Setup authentication state listener
  void _setupAuthStateListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          print("🔐 User authenticated: ${user.uid}");
        } else {
          print("🔓 User signed out");
        }
      });
    } catch (e) {
      print("⚠️ Auth state listener setup failed: $e");
    }
  }

  // Clear authentication data
  Future<void> _clearAuthenticationData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Clear all authentication-related data
      await prefs.remove('authenticated_user_id');
      await prefs.remove('authenticated_employee_pin');
      await prefs.setBool('is_authenticated', false);
      await prefs.remove('authentication_timestamp');
      await prefs.remove('firebase_uid');

      debugPrint("🧹 Authentication data cleared");
    } catch (e) {
      debugPrint("❌ Error clearing authentication data: $e");
    }
  }

  Future<void> _initializeLocationData() async {
    if (_isOfflineMode) {
      return;
    }

    try {
      QuerySnapshot locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .limit(1)
          .get();

      if (locationsSnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('locations').add({

        });

        print('Default location created');
      }
    } catch (e) {
      print('Error initializing location data: $e');
    }
  }

  Future<void> _initializeAdminAccount() async {
    if (_isOfflineMode) {
      return;
    }

    try {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: "admin@pts",
          password: "pts123",
        ).then((userCredential) async {
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(userCredential.user!.uid)
              .set({
            'email': "admin@pts",
            'isAdmin': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          print('Default admin account created');
        });
      }
    } catch (e) {
      print('Error creating admin account: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PHOENICIAN',
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
      home: _getInitialScreen(),
      routes: {},
    );
  }

  Widget _getInitialScreen() {
    if (_isLoading) {
      return CleanSplashScreen(isOfflineMode: _isOfflineMode);
    }

    if (_showOnboarding == true) {
      return const OnboardingScreen();
    }

    if (_loggedInEmployeeId != null) {
      return DashboardView(employeeId: _loggedInEmployeeId!);
    }

    // Go to PIN entry (like iOS) instead of app password entry
    return const PinEntryView();
  }
}

// CLEAN WHITE SPLASH SCREEN WITH GEOFENCE STATUS
class CleanSplashScreen extends StatefulWidget {
  final bool isOfflineMode;

  const CleanSplashScreen({
    Key? key,
    required this.isOfflineMode,
  }) : super(key: key);

  @override
  State<CleanSplashScreen> createState() => _CleanSplashScreenState();
}

class _CleanSplashScreenState extends State<CleanSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Set clean white status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Company Logo (Clean letter P)
                      Container(
                        width: isTablet ? 120 : 100,
                        height: isTablet ? 120 : 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D4B),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D4B).withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "P",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 48 : 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 32 : 24),

                      // Company Name
                      Text(
                        "PHOENICIAN TECHNICAL SERVICES",
                        style: TextStyle(
                          color: const Color(0xFF2E7D4B),
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      Text(
                        "Phoenician Technical Services LLC",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isTablet ? 48 : 36),

                      // Loading indicator
                      SizedBox(
                        width: isTablet ? 32 : 28,
                        height: isTablet ? 32 : 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF2E7D4B).withOpacity(0.8),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 24 : 16),

                      // Status text with geofence monitoring info
                      Text(
                        widget.isOfflineMode
                            ? "Initializing Offline Mode..."
                            : "Setting up Geofence Monitoring...",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: isTablet ? 12 : 8),

                      // Feature indicators
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D4B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "PIN-Only Authentication",
                              style: TextStyle(
                                color: const Color(0xFF2E7D4B),
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(height: 8),

                          // NEW: Geofence monitoring indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Work Area Monitoring System",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(height: 8),

                          // Location exemption indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Location Exemption System Active",
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (widget.isOfflineMode) ...[
                        SizedBox(height: isTablet ? 16 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF8C00),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 6),
                            Text(
                              "Offline Mode Active",
                              style: TextStyle(
                                color: const Color(0xFFFF8C00),
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}