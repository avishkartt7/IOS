// lib/authenticate_face/authenticate_face_view.dart - iOS OFFLINE FIXED VERSION

import 'dart:convert';
import 'dart:developer';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/authenticate_face/scanning_animation/animated_view.dart';
import 'package:face_auth/authenticate_face/user_password_setup_view.dart';
import 'package:face_auth/authenticate_face/authentication_success_screen.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/utils/extract_face_feature.dart';
import 'package:face_auth/common/views/camera_view.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/dashboard/dashboard_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AuthenticateFaceView extends StatefulWidget {
  final String? employeeId;
  final String? employeePin;
  final bool isRegistrationValidation;
  final Function(bool success)? onAuthenticationComplete;
  final String? actionType;

  const AuthenticateFaceView({
    Key? key,
    this.employeeId,
    this.employeePin,
    this.isRegistrationValidation = false,
    this.onAuthenticationComplete,
    this.actionType,
  }) : super(key: key);

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
  // ================ CORE SERVICES ================
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // ================ AUTHENTICATION STATE ================
  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();
  final TextEditingController _pinController = TextEditingController();

  String _similarity = "";
  bool _canAuthenticate = false;
  Map<String, dynamic>? employeeData;
  bool isMatching = false;
  int trialNumber = 1;
  bool _hasAuthenticated = false;
  bool _isOfflineMode = false;
  bool _hasStoredFace = false;

  @override
  void initState() {
    super.initState();
    print("🚀 iOS AuthenticateFaceView initialized for employee: ${widget.employeeId}");
    _checkConnectivity();
    _fetchEmployeeData();
    _checkStoredImage();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _audioPlayer.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ================ CONNECTIVITY CHECK ================
  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      print("📶 iOS Connectivity status: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
      print("⚠️ Connectivity check failed, assuming offline: $e");
    }
  }

  // ================ STORED FACE CHECK ================
  Future<void> _checkStoredImage() async {
    try {
      if (widget.employeeId == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Check multiple possible storage keys
      String? storedImage = prefs.getString('employee_image_${widget.employeeId}');
      String? storedFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      bool faceRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;

      setState(() {
        _hasStoredFace = (storedImage != null && storedImage.isNotEmpty) || 
                        (storedFeatures != null && storedFeatures.isNotEmpty) ||
                        faceRegistered;
      });

      print("📱 iOS Stored face check for ${widget.employeeId}:");
      print("   - Has stored image: ${storedImage != null}");
      print("   - Has stored features: ${storedFeatures != null}");
      print("   - Face registered: $faceRegistered");
      print("   - Overall has stored face: $_hasStoredFace");

    } catch (e) {
      print("❌ Error checking stored image: $e");
      setState(() {
        _hasStoredFace = false;
      });
    }
  }

  // ================ AUDIO FEEDBACK ================
  AudioPlayer get _playScanningAudio => _audioPlayer
    ..setReleaseMode(ReleaseMode.loop)
    ..play(AssetSource("scan_beep.wav"));

  AudioPlayer get _playSuccessAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("success.mp3"));

  AudioPlayer get _playFailedAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("failed.mp3"));

  // ================ UI BUILD ================
  @override
  Widget build(BuildContext context) {
    CustomSnackBar.context = context;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: Text(widget.isRegistrationValidation 
            ? "Verify Your Face" 
            : "Face Authentication"),
        elevation: 0,
        actions: [
          // Connectivity indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOfflineMode ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isOfflineMode ? "Offline" : "Online",
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.82,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
              decoration: BoxDecoration(
                color: overlayContainerClr,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Status indicator
                  _buildStatusIndicator(),

                  // Camera view
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _canAuthenticate 
                              ? Colors.green 
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            CameraView(
                              onImage: (image) {
                                _setImage(image);
                              },
                              onInputImage: (inputImage) async {
                                await _processInputImage(inputImage);
                              },
                            ),
                            if (isMatching)
                              Container(
                                color: Colors.black.withOpacity(0.7),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: accentColor,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "Verifying your face...",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Authentication button
                  if (_canAuthenticate && !isMatching)
                    CustomButton(
                      text: widget.isRegistrationValidation 
                          ? "Verify Face" 
                          : "Authenticate",
                      onTap: _authenticate,
                    ),

                  if (!_canAuthenticate && !isMatching)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            "Position your face clearly in the camera",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_isOfflineMode && !_hasStoredFace)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "⚠️ Offline mode: No stored face data found",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================ STATUS INDICATOR ================
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(),
            color: _getStatusColor(),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(),
              style: TextStyle(
                color: _getStatusColor(),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Storage indicator
          if (_hasStoredFace)
            Icon(
              Icons.storage,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_hasAuthenticated) {
      return "Authentication successful!";
    } else if (isMatching) {
      return "Verifying your face...";
    } else if (_canAuthenticate) {
      return "Ready to authenticate";
    } else if (_isOfflineMode && !_hasStoredFace) {
      return "Offline mode: No stored face data";
    } else {
      return "Position your face in the camera";
    }
  }

  Color _getStatusColor() {
    if (_hasAuthenticated) {
      return Colors.green;
    } else if (isMatching) {
      return Colors.blue;
    } else if (_canAuthenticate) {
      return Colors.green;
    } else if (_isOfflineMode && !_hasStoredFace) {
      return Colors.orange;
    } else {
      return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    if (_hasAuthenticated) {
      return Icons.check_circle;
    } else if (isMatching) {
      return Icons.hourglass_empty;
    } else if (_canAuthenticate) {
      return Icons.verified;
    } else if (_isOfflineMode && !_hasStoredFace) {
      return Icons.warning;
    } else {
      return Icons.face;
    }
  }

  // ================ IMAGE PROCESSING ================
  Future<void> _setImage(Uint8List imageToAuthenticate) async {
    image2.bitmap = base64Encode(imageToAuthenticate);
    image2.imageType = regula.ImageType.PRINTED;

    setState(() {
      _canAuthenticate = true;
    });
    print("📸 iOS Image captured and set for authentication");
  }

  Future<void> _processInputImage(InputImage inputImage) async {
    try {
      setState(() => isMatching = true);
      
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (_faceFeatures != null) {
        bool isValid = validateFaceFeatures(_faceFeatures!);
        double qualityScore = getFaceFeatureQuality(_faceFeatures!);
        
        print("🔍 iOS Face detected with quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");
        print("✅ Face features are ${isValid ? 'valid' : 'needs improvement'} for authentication");
      } else {
        print("❌ No face detected during authentication");
      }
      
      setState(() => isMatching = false);
    } catch (e) {
      setState(() => isMatching = false);
      debugPrint("Error processing input image: $e");
    }
  }

  // ================ EMPLOYEE DATA FETCHING ================
  Future<void> _fetchEmployeeData() async {
    if (widget.employeeId == null) return;

    print("📊 Fetching employee data for: ${widget.employeeId}");

    try {
      // Always try local storage first
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString('user_data_${widget.employeeId}');
      
      if (localData != null) {
        Map<String, dynamic> data = jsonDecode(localData);
        setState(() {
          employeeData = data;
        });
        print("✅ iOS Employee data loaded from local storage");
      }

      // If online, try to get fresh data from Firestore
      if (!_isOfflineMode) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            // Save to local storage
            await prefs.setString('user_data_${widget.employeeId}', jsonEncode(data));
            
            setState(() {
              employeeData = data;
            });
            print("✅ iOS Employee data updated from Firestore");
          }
        } catch (e) {
          print("⚠️ Firestore fetch failed, using local data: $e");
        }
      }
    } catch (e) {
      print("❌ Error fetching employee data: $e");
    }
  }

  // ================ AUTHENTICATION LOGIC ================
  Future<void> _authenticate() async {
    if (!_canAuthenticate || isMatching) return;

    print("🔐 Starting iOS authentication process...");

    setState(() {
      isMatching = true;
      _hasAuthenticated = false;
    });

    _playScanningAudio;

    try {
      await _matchFaceWithStored();
    } catch (e) {
      debugPrint("Authentication error: $e");
      setState(() {
        isMatching = false;
      });
      _playFailedAudio;
      _showFailureDialog(
        title: "Authentication Error",
        description: "An error occurred during authentication. Please try again.",
      );
    }
  }

  // ================ CORE FACE MATCHING LOGIC ================
  Future<void> _matchFaceWithStored() async {
    try {
      print("🔍 iOS Face matching started...");
      
      String? storedImage;

      // Try multiple storage sources
      if (employeeData != null && employeeData!['image'] != null) {
        storedImage = employeeData!['image'];
        print("📱 Using face image from employee data");
      } else {
        // Try local storage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        storedImage = prefs.getString('employee_image_${widget.employeeId}');
        print("📱 Using face image from SharedPreferences");
      }

      if (storedImage == null) {
        print("❌ No stored face image found - checking cloud recovery...");
        await _attemptCloudRecovery();
        return;
      }

      // Clean stored image
      if (storedImage.contains('data:image') && storedImage.contains(',')) {
        storedImage = storedImage.split(',')[1];
      }

      // Perform face matching based on connectivity
      if (_isOfflineMode) {
        print("📱 iOS Offline mode - using ML Kit matching");
        await _performOfflineAuthentication(storedImage);
      } else {
        print("🌐 iOS Online mode - using Regula SDK matching");
        await _performOnlineAuthentication(storedImage);
      }

    } catch (e) {
      print("❌ Error in face matching: $e");
      setState(() {
        isMatching = false;
      });
      _playFailedAudio;
      _showFailureDialog(
        title: "Authentication Error",
        description: "Error during face matching: $e",
      );
    }
  }

  // ================ ONLINE AUTHENTICATION ================
  Future<void> _performOnlineAuthentication(String storedImage) async {
    try {
      print("🌐 Performing online authentication with Regula SDK...");
      
      image1.bitmap = storedImage;
      image1.imageType = regula.ImageType.PRINTED;

      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];

      dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request))
          .timeout(const Duration(seconds: 10));
      
      var response = regula.MatchFacesResponse.fromJson(json.decode(value));

      dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response!.results), 0.75);

      var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));
      
      setState(() {
        _similarity = split!.matchedFaces.isNotEmpty
            ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
            : "0.0";
      });

      print("📊 iOS Online similarity: $_similarity%");

      if (_similarity != "0.0" && double.parse(_similarity) > 85.0) {
        _handleSuccessfulAuthentication();
      } else {
        _handleFailedAuthentication("Face doesn't match. Please try again.");
      }
    } catch (e) {
      print("❌ Online authentication failed, falling back to offline: $e");
      await _performOfflineAuthentication(storedImage);
    }
  }

  // ================ OFFLINE AUTHENTICATION ================
  Future<void> _performOfflineAuthentication(String storedImage) async {
    try {
      print("📱 Performing offline authentication with ML Kit...");
      
      if (_faceFeatures == null) {
        _handleFailedAuthentication("No face detected. Please try again with better lighting.");
        return;
      }

      // Get stored features
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? storedFeaturesJson = prefs.getString('employee_face_features_${widget.employeeId}');
      
      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        print("❌ No stored face features found for offline authentication");
        _handleFailedAuthentication("No stored face data found for offline authentication.");
        return;
      }

      Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
      FaceFeatures storedFeatures = FaceFeatures.fromJson(storedFeaturesMap);

      // Compare face features
      double matchPercentage = _compareFaceFeatures(storedFeatures, _faceFeatures!);
      
      setState(() {
        _similarity = matchPercentage.toStringAsFixed(2);
      });

      print("📊 iOS Offline similarity: $_similarity%");

      if (matchPercentage >= 75.0) {
        _handleSuccessfulAuthentication();
      } else {
        _handleFailedAuthentication("Face doesn't match. Please try again with good lighting.");
      }
    } catch (e) {
      print("❌ Offline authentication error: $e");
      _handleFailedAuthentication("Error during face matching: $e");
    }
  }

  // ================ FACE FEATURES COMPARISON ================
  double _compareFaceFeatures(FaceFeatures stored, FaceFeatures current) {
    print("🔍 Comparing face features for offline authentication...");
    
    int matchCount = 0;
    int totalTests = 0;

    // Compare key facial landmarks
    if (_comparePoints(stored.leftEye, current.leftEye, 40)) {
      matchCount++;
      print("✅ Left eye matches");
    }
    totalTests++;

    if (_comparePoints(stored.rightEye, current.rightEye, 40)) {
      matchCount++;
      print("✅ Right eye matches");
    }
    totalTests++;

    if (_comparePoints(stored.noseBase, current.noseBase, 35)) {
      matchCount++;
      print("✅ Nose matches");
    }
    totalTests++;

    if (_comparePoints(stored.leftMouth, current.leftMouth, 45) &&
        _comparePoints(stored.rightMouth, current.rightMouth, 45)) {
      matchCount++;
      print("✅ Mouth matches");
    }
    totalTests++;

    double percentage = (matchCount / totalTests) * 100;
    print("📊 Feature comparison result: $matchCount/$totalTests matches = ${percentage.toStringAsFixed(1)}%");
    
    return percentage;
  }

  bool _comparePoints(Points? p1, Points? p2, double tolerance) {
    if (p1 == null || p2 == null || p1.x == null || p2.x == null) return false;

    double distance = sqrt(
        (p1.x! - p2.x!) * (p1.x! - p2.x!) +
            (p1.y! - p2.y!) * (p1.y! - p2.y!)
    );

    return distance <= tolerance;
  }

  // ================ CLOUD RECOVERY ================
  Future<void> _attemptCloudRecovery() async {
    if (_isOfflineMode) {
      print("❌ Cannot attempt cloud recovery in offline mode");
      _handleFailedAuthentication("No stored face data available and device is offline.");
      return;
    }

    print("🌐 Attempting cloud recovery for face data...");

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('image') && data['image'] != null) {
          // Save recovered data locally
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('employee_image_${widget.employeeId}', data['image']);
          
          if (data.containsKey('faceFeatures') && data['faceFeatures'] != null) {
            await prefs.setString('employee_face_features_${widget.employeeId}', 
                jsonEncode(data['faceFeatures']));
          }
          
          await prefs.setBool('face_registered_${widget.employeeId}', true);
          
          print("✅ Face data recovered from cloud and saved locally");
          
          // Update state and retry authentication
          setState(() {
            employeeData = data;
            _hasStoredFace = true;
          });
          
          // Retry authentication with recovered data
          await _matchFaceWithStored();
          return;
        }
      }
      
      print("❌ No face data found in cloud");
      _handleFailedAuthentication("No registered face found. Please register first.");
      
    } catch (e) {
      print("❌ Cloud recovery failed: $e");
      _handleFailedAuthentication("No stored face data available.");
    }
  }

  // ================ SUCCESS/FAILURE HANDLERS ================
  void _handleSuccessfulAuthentication() {
    _playSuccessAudio;

    setState(() {
      isMatching = false;
      _hasAuthenticated = true;
    });

    print("✅ iOS Authentication successful!");

    if (widget.isRegistrationValidation) {
      // Registration validation successful, go to dashboard
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardView(
                employeeId: widget.employeeId!,
              ),
            ),
          );
        }
      });
    } else {
      // Regular authentication successful
      _showSuccessDialog();
    }

    // Call completion callback
    if (widget.onAuthenticationComplete != null) {
      widget.onAuthenticationComplete!(true);
    }
  }

  void _handleFailedAuthentication(String message) {
    setState(() {
      isMatching = false;
    });
    _playFailedAudio;
    _showFailureDialog(
      title: "Authentication Failed",
      description: message,
    );

    // Call completion callback
    if (widget.onAuthenticationComplete != null) {
      widget.onAuthenticationComplete!(false);
    }
  }

  // ================ DIALOGS ================
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text(
              "Authentication Successful!",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome ${employeeData?['name'] ?? 'User'}!",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Match: $_similarity%",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              "Mode: ${_isOfflineMode ? 'Offline' : 'Online'}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DashboardView(
                    employeeId: widget.employeeId!,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Continue",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog({
    required String title,
    required String description,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          description,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Try Again",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}