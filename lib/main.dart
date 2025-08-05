// lib/main.dart - UPDATED WITH CLEAN WHITE SPLASH SCREEN

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/onboarding/onboarding_screen.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:face_auth/dashboard/dashboard_view.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/services/simple_firebase_auth_service.dart';
import 'package:face_auth/model/enhanced_face_features.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import the services for offline functionality
import 'package:face_auth/services/sync_service.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/services/secure_face_storage_service.dart';
import 'package:face_auth/services/face_data_migration_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Add these imports for permissions
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:face_auth/repositories/polygon_location_repository.dart';
import 'package:face_auth/admin/polygon_map_view.dart';
import 'package:face_auth/admin/geojson_importer_view.dart';
import 'package:flutter/services.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Starting Android App with iOS-style PIN Authentication...");

  // Set clean white status bar from the start
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ✅ Initialize Firebase with proper error handling
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
    // Continue without Firebase for offline functionality
  }

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
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

  // Initialize Firestore for offline persistence
  await _initializeFirestoreOfflineMode();
  await requestAppPermissions();

  // Setup service locator
  setupServiceLocator();
  listRegisteredServices();

  // Check and migrate existing face data
  final storageService = getIt<SecureFaceStorageService>();
  final migrationService = FaceDataMigrationService(storageService);
  await migrationService.migrateExistingData();

  // Initialize sync service after service locator is setup
  final syncService = getIt<SyncService>();
  print("Main: Sync service initialized");

  runApp(const MyApp());
}

// ✅ Request app permissions with better error handling
Future<void> requestAppPermissions() async {
  if (Platform.isAndroid) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      print("Requesting app permissions for Android SDK: ${androidInfo.version.sdkInt}");

      // Request different permissions based on Android version
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        await Permission.photos.request();
        await Permission.mediaLibrary.request();
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12
        await Permission.storage.request();
      } else {
        // Android 10 and below
        await Permission.storage.request();
      }

      // ✅ Request notification permissions for real-time updates
      await Permission.notification.request();

      print("✅ Permissions requested successfully");

    } catch (e) {
      print("Error requesting app permissions: $e");
    }
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

  // GeoJSON data for default locations
  final String santoriniGeoJson = '''
{
    "type": "FeatureCollection", 
    "features": [
        {
            "type": "Feature", 
            "geometry": {
                "type": "Polygon", 
                "coordinates": [
                    [
                        [55.2318760, 25.0134952, 0], 
                        [55.2353092, 25.0080894, 0], 
                        [55.2368435, 25.0083714, 0], 
                        [55.2370969, 25.0090520, 0], 
                        [55.2378332, 25.0101409, 0], 
                        [55.2383441, 25.0110403, 0], 
                        [55.2389409, 25.0118910, 0], 
                        [55.2391769, 25.0128535, 0], 
                        [55.2392647, 25.0134477, 0], 
                        [55.2392921, 25.0136687, 0], 
                        [55.2393135, 25.0137949, 0], 
                        [55.2393294, 25.0140339, 0], 
                        [55.2393613, 25.0143344, 0], 
                        [55.2394062, 25.0150764, 0], 
                        [55.2395175, 25.0152234, 0], 
                        [55.2396060, 25.0153182, 0], 
                        [55.2396731, 25.0154373, 0], 
                        [55.2396700, 25.0155436, 0], 
                        [55.2396240, 25.0156620, 0], 
                        [55.2395212, 25.0158844, 0], 
                        [55.2395800, 25.0159326, 0], 
                        [55.2396005, 25.0159852, 0], 
                        [55.2395947, 25.0160282, 0], 
                        [55.2395860, 25.0160808, 0], 
                        [55.2395525, 25.0161160, 0], 
                        [55.2394955, 25.0161552, 0], 
                        [55.2394438, 25.0161670, 0], 
                        [55.2393580, 25.0161564, 0], 
                        [55.2393419, 25.0161482, 0], 
                        [55.2389771, 25.0166726, 0], 
                        [55.2387022, 25.0172347, 0], 
                        [55.2364036, 25.0159842, 0], 
                        [55.2318760, 25.0134952, 0]  
                    ]
                ]
            }, 
            "properties": {
                "name": "SANTORINI", 
                "description": "DAMAC LAGOONS SANTORINI (PHOENICIAN TECHNICAL SERVICES)DUBAI,UAE", 
                "styleUrl": "#poly-C2185B-1200-77", 
                "fill-opacity": 0.30196078431372547, 
                "fill": "#c2185b", 
                "stroke-opacity": 1, 
                "stroke": "#c2185b", 
                "stroke-width": 1.2
            }
        }
    ]
}
''';

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
      await _loadDefaultGeoJsonData();

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

  // ✅ NEW: PIN-based authentication (like iOS)
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

    // ✅ Check for PIN-based authentication (like iOS)
    String? authenticatedUserId = prefs.getString('authenticated_user_id');
    bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    int? authTimestamp = prefs.getInt('authentication_timestamp');

    debugPrint("🔍 Checking PIN-based authentication status...");
    debugPrint("   - User ID: $authenticatedUserId");
    debugPrint("   - Is Authenticated: $isAuthenticated");
    debugPrint("   - Auth Timestamp: $authTimestamp");

    if (isAuthenticated && authenticatedUserId != null) {
      // ✅ Check if authentication is recent (within 30 days)
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

      // ✅ Check if user has COMPLETE registration (including face)
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

  // ✅ Setup authentication state listener
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

  Future<void> _loadDefaultGeoJsonData() async {
    try {
      final polygonRepository = getIt<PolygonLocationRepository>();
      final existingLocations = await polygonRepository.getActivePolygonLocations();

      if (existingLocations.isEmpty) {
        print("No polygon locations found. Importing default SANTORINI project boundaries...");

        final locations = await polygonRepository.loadFromGeoJson(santoriniGeoJson);

        if (locations.isNotEmpty) {
          await polygonRepository.savePolygonLocations(locations);
          print("Successfully imported ${locations.length} polygon locations");

          for (var location in locations) {
            print("Imported: ${location.name} with ${location.coordinates.length} boundary points");
          }
        }
      } else {
        print("Found ${existingLocations.length} existing polygon locations, skipping import");
      }
    } catch (e) {
      print("Error importing default GeoJSON data: $e");
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

  ConnectivityService get _connectivityService {
    try {
      return getIt<ConnectivityService>();
    } catch (e) {
      debugPrint("⚠️ ConnectivityService not available, assuming offline");
      // Create a temporary service instance
      return ConnectivityService();
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
          'name': 'Central Plaza',
          'address': 'DIP 1, Street 72, Dubai',
          'latitude': 24.985454,
          'longitude': 55.175509,
          'radius': 200.0,
          'isActive': true,
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
      routes: {
        '/polygon_map_view': (context) => const PolygonMapView(),
        '/geojson_importer_view': (context) => const GeoJsonImporterView(),
      },
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

    // ✅ Go to PIN entry (like iOS) instead of app password entry
    return const PinEntryView();
  }
}

// ✅ NEW CLEAN WHITE SPLASH SCREEN (No more purple/blue gradients or rockets)
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

                      // Status text
                      Text(
                        widget.isOfflineMode
                            ? "Initializing Offline Mode..."
                            : "Initializing PIN Authentication...",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: isTablet ? 12 : 8),

                      // Feature indicator
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