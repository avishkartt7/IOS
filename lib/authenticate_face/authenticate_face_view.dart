// lib/authenticate_face/authenticate_face_view.dart - COMPLETE ENHANCED iOS IMPLEMENTATION

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

  // ================ ENHANCED DEBUG STATE ================
  List<String> _debugLogs = [];
  Map<String, dynamic> _authenticationDebugData = {};
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    print("🚀 ENHANCED iOS AuthenticateFaceView initialized for employee: ${widget.employeeId}");
    _addDebugLog("🚀 Authentication view initialized");
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

  // ================ DEBUG LOGGING ================
  void _addDebugLog(String message) {
    String timestampedMessage = "${DateTime.now().toIso8601String().substring(11, 19)} - $message";
    setState(() {
      _debugLogs.add(timestampedMessage);
      if (_debugLogs.length > 50) _debugLogs.removeAt(0); // Keep only last 50 logs
    });
    print("AUTH_DEBUG: $timestampedMessage");
  }

  // ================ CONNECTIVITY CHECK ================
  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      _addDebugLog("📶 Connectivity status: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
      _addDebugLog("⚠️ Connectivity check failed, assuming offline: $e");
    }
  }

  // ================ STORED FACE CHECK ================
  Future<void> _checkStoredImage() async {
    try {
      if (widget.employeeId == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Check multiple possible storage keys
      String? storedImage = prefs.getString('employee_image_${widget.employeeId}');
      String? secureImage = prefs.getString('secure_face_image_${widget.employeeId}');
      String? storedFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      String? secureFeatures = prefs.getString('secure_face_features_${widget.employeeId}');
      bool faceRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;
      bool enhancedRegistered = prefs.getBool('enhanced_face_registered_${widget.employeeId}') ?? false;

      setState(() {
        _hasStoredFace = (storedImage != null && storedImage.isNotEmpty) || 
                        (secureImage != null && secureImage.isNotEmpty) ||
                        (storedFeatures != null && storedFeatures.isNotEmpty) ||
                        (secureFeatures != null && secureFeatures.isNotEmpty) ||
                        faceRegistered || enhancedRegistered;
      });

      _addDebugLog("📱 Stored face check for ${widget.employeeId}:");
      _addDebugLog("   - Primary image: ${storedImage != null ? 'EXISTS (${storedImage.length} chars)' : 'NULL'}");
      _addDebugLog("   - Secure image: ${secureImage != null ? 'EXISTS (${secureImage.length} chars)' : 'NULL'}");
      _addDebugLog("   - Primary features: ${storedFeatures != null ? 'EXISTS (${storedFeatures.length} chars)' : 'NULL'}");
      _addDebugLog("   - Secure features: ${secureFeatures != null ? 'EXISTS (${secureFeatures.length} chars)' : 'NULL'}");
      _addDebugLog("   - Face registered: $faceRegistered");
      _addDebugLog("   - Enhanced registered: $enhancedRegistered");
      _addDebugLog("   - Overall has stored face: $_hasStoredFace");

      // Store debug data
      _authenticationDebugData['storedFaceCheck'] = {
        'primaryImage': storedImage != null,
        'secureImage': secureImage != null,
        'primaryFeatures': storedFeatures != null,
        'secureFeatures': secureFeatures != null,
        'faceRegistered': faceRegistered,
        'enhancedRegistered': enhancedRegistered,
        'hasStoredFace': _hasStoredFace,
      };

    } catch (e) {
      _addDebugLog("❌ Error checking stored image: $e");
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
            : "Enhanced Face Authentication"),
        elevation: 0,
        actions: [
          // Debug toggle
          IconButton(
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugInfo ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
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

                  // Debug panel (if enabled)
                  if (_showDebugInfo) _buildDebugPanel(),

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
                          : "🔐 Enhanced Authenticate",
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
          // Debug indicator
          if (_showDebugInfo)
            Icon(
              Icons.bug_report,
              color: Colors.yellow,
              size: 16,
            ),
        ],
      ),
    );
  }

  // ================ DEBUG PANEL ================
  Widget _buildDebugPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.yellow, size: 16),
              const SizedBox(width: 8),
              const Text(
                "Enhanced Debug Panel",
                style: TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _debugLogs.clear();
                    _authenticationDebugData.clear();
                  });
                },
                child: const Text("Clear", style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                return Text(
                  _debugLogs[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_hasAuthenticated) {
      return "✅ Authentication successful!";
    } else if (isMatching) {
      return "🔍 Enhanced verification in progress...";
    } else if (_canAuthenticate) {
      return "🚀 Ready for enhanced authentication";
    } else if (_isOfflineMode && !_hasStoredFace) {
      return "📱 Offline mode: No stored face data";
    } else {
      return "📸 Position your face in the camera";
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
    _addDebugLog("📸 Image captured and set for authentication");
  }

  Future<void> _processInputImage(InputImage inputImage) async {
    try {
      setState(() => isMatching = true);
      
      _addDebugLog("🔍 Processing input image for face detection...");
      
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (_faceFeatures != null) {
        bool isValid = validateFaceFeatures(_faceFeatures!);
        double qualityScore = getFaceFeatureQuality(_faceFeatures!);
        
        _addDebugLog("✅ Face detected with quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");
        _addDebugLog("📊 Face features are ${isValid ? 'valid' : 'needs improvement'} for authentication");
        
        // Store debug data
        _authenticationDebugData['lastFaceDetection'] = {
          'detected': true,
          'qualityScore': qualityScore,
          'isValid': isValid,
          'timestamp': DateTime.now().toIso8601String(),
          'featuresCount': _countDetectedLandmarks(_faceFeatures!),
        };
      } else {
        _addDebugLog("❌ No face detected during authentication");
        _authenticationDebugData['lastFaceDetection'] = {
          'detected': false,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
      
      setState(() => isMatching = false);
    } catch (e) {
      setState(() => isMatching = false);
      _addDebugLog("❌ Error processing input image: $e");
      debugPrint("Error processing input image: $e");
    }
  }

  // ================ EMPLOYEE DATA FETCHING ================
  Future<void> _fetchEmployeeData() async {
    if (widget.employeeId == null) return;

    _addDebugLog("📊 Fetching employee data for: ${widget.employeeId}");

    try {
      // Always try local storage first
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString('user_data_${widget.employeeId}');
      String? enhancedData = prefs.getString('enhanced_user_data_${widget.employeeId}');
      
      if (enhancedData != null) {
        Map<String, dynamic> data = jsonDecode(enhancedData);
        setState(() {
          employeeData = data;
        });
        _addDebugLog("✅ Enhanced employee data loaded from local storage");
      } else if (localData != null) {
        Map<String, dynamic> data = jsonDecode(localData);
        setState(() {
          employeeData = data;
        });
        _addDebugLog("✅ Standard employee data loaded from local storage");
      }

      // If online, try to get fresh data from Firestore
      if (!_isOfflineMode) {
        try {
          _addDebugLog("🌐 Attempting to fetch fresh data from Firestore...");
          
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
            _addDebugLog("✅ Employee data updated from Firestore");
          } else {
            _addDebugLog("⚠️ Employee document not found in Firestore");
          }
        } catch (e) {
          _addDebugLog("⚠️ Firestore fetch failed, using local data: $e");
        }
      } else {
        _addDebugLog("📱 Offline mode: Using local employee data only");
      }
    } catch (e) {
      _addDebugLog("❌ Error fetching employee data: $e");
    }
  }

  // ================ AUTHENTICATION LOGIC ================
  Future<void> _authenticate() async {
    if (!_canAuthenticate || isMatching) return;

    _addDebugLog("🔐 Starting ENHANCED iOS authentication process...");

    setState(() {
      isMatching = true;
      _hasAuthenticated = false;
    });

    _playScanningAudio;

    try {
      await _matchFaceWithStored();
    } catch (e) {
      _addDebugLog("❌ Authentication error: $e");
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

  // ================ ENHANCED CORE FACE MATCHING LOGIC ================
  Future<void> _matchFaceWithStored() async {
    try {
      _addDebugLog("🔍 Enhanced face matching started...");
      
      String? storedImage;

      // Try multiple storage sources with priority
      if (employeeData != null && employeeData!['image'] != null) {
        storedImage = employeeData!['image'];
        _addDebugLog("📱 Using face image from employee data");
      } else {
        // Try enhanced local storage first
        SharedPreferences prefs = await SharedPreferences.getInstance();
        storedImage = prefs.getString('secure_face_image_${widget.employeeId}') ??
                     prefs.getString('employee_image_${widget.employeeId}');
        _addDebugLog("📱 Using face image from local storage");
      }

      if (storedImage == null) {
        _addDebugLog("❌ No stored face image found - checking cloud recovery...");
        await _attemptCloudRecovery();
        return;
      }

      // Clean stored image
      if (storedImage.contains('data:image') && storedImage.contains(',')) {
        storedImage = storedImage.split(',')[1];
        _addDebugLog("🧹 Cleaned stored image data URL format");
      }

      // Perform face matching based on connectivity
      if (_isOfflineMode) {
        _addDebugLog("📱 iOS Enhanced Offline mode - using ML Kit matching");
        await _performEnhancedOfflineAuthentication(storedImage);
      } else {
        _addDebugLog("🌐 iOS Online mode - using Regula SDK matching");
        await _performOnlineAuthentication(storedImage);
      }

    } catch (e) {
      _addDebugLog("❌ Error in enhanced face matching: $e");
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
      _addDebugLog("🌐 Performing online authentication with Regula SDK...");
      
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

      _addDebugLog("📊 Online similarity: $_similarity%");

      if (_similarity != "0.0" && double.parse(_similarity) > 85.0) {
        _addDebugLog("✅ Online authentication SUCCESS!");
        _handleSuccessfulAuthentication();
      } else {
        _addDebugLog("❌ Online authentication FAILED - similarity too low");
        _handleFailedAuthentication("Face doesn't match. Please try again.");
      }
    } catch (e) {
      _addDebugLog("❌ Online authentication failed, falling back to offline: $e");
      await _performEnhancedOfflineAuthentication(storedImage);
    }
  }

  // ================ ENHANCED OFFLINE AUTHENTICATION ================
  Future<void> _performEnhancedOfflineAuthentication(String storedImage) async {
    try {
      _addDebugLog("📱 Performing ENHANCED offline authentication with ML Kit...");
      
      if (_faceFeatures == null) {
        _addDebugLog("❌ No current face features detected");
        _handleFailedAuthentication("No face detected. Please try again with better lighting.");
        return;
      }

      // ✅ STEP 1: Get stored features with multiple fallback methods
      FaceFeatures? storedFeatures = await _getStoredFaceFeatures();
      
      if (storedFeatures == null) {
        _addDebugLog("❌ No stored face features found - attempting cloud recovery");
        await _attemptCloudRecovery();
        return;
      }

      _addDebugLog("✅ Successfully retrieved stored face features");
      _addDebugLog("🔍 Stored features summary: ${_getFeaturesDebugInfo(storedFeatures)}");
      _addDebugLog("🔍 Current features summary: ${_getFeaturesDebugInfo(_faceFeatures!)}");

      // ✅ STEP 2: Enhanced face feature comparison with multiple algorithms
      double matchPercentage = await _enhancedFaceComparison(storedFeatures, _faceFeatures!);
      
      setState(() {
        _similarity = matchPercentage.toStringAsFixed(2);
      });

      _addDebugLog("📊 ENHANCED iOS Offline similarity: $_similarity%");
      _addDebugLog("🎯 Threshold: 65.0% (Adjusted for offline mode)");

      // Store authentication result in debug data
      _authenticationDebugData['lastAuthentication'] = {
        'method': 'enhanced_offline',
        'similarity': matchPercentage,
        'threshold': 65.0,
        'successful': matchPercentage >= 65.0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // ✅ STEP 3: More lenient threshold for offline mode
      if (matchPercentage >= 65.0) { // Lowered from 75.0 for better offline performance
        _addDebugLog("✅ ENHANCED OFFLINE AUTHENTICATION SUCCESSFUL!");
        _handleSuccessfulAuthentication();
      } else {
        _addDebugLog("❌ ENHANCED OFFLINE AUTHENTICATION FAILED - Match too low");
        _handleFailedAuthentication("Face doesn't match (${matchPercentage.toStringAsFixed(1)}%). Please try again with good lighting.");
      }
    } catch (e) {
      _addDebugLog("❌ Enhanced offline authentication error: $e");
      _handleFailedAuthentication("Error during face matching: $e");
    }
  }

  // ✅ ENHANCED: Get stored face features with multiple fallback methods
  Future<FaceFeatures?> _getStoredFaceFeatures() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Method 1: Try enhanced storage key
      String? storedFeaturesJson = prefs.getString('secure_enhanced_face_features_${widget.employeeId}');
      
      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        _addDebugLog("🔄 Fallback 1: Trying secure storage key...");
        storedFeaturesJson = prefs.getString('secure_face_features_${widget.employeeId}');
      }
      
      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        _addDebugLog("🔄 Fallback 2: Trying standard storage key...");
        storedFeaturesJson = prefs.getString('employee_face_features_${widget.employeeId}');
      }
      
      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        _addDebugLog("🔄 Fallback 3: Checking employee data...");
        if (employeeData != null && employeeData!.containsKey('faceFeatures')) {
          Map<String, dynamic> featuresMap = employeeData!['faceFeatures'];
          _addDebugLog("✅ Found features in employee data");
          return FaceFeatures.fromJson(featuresMap);
        }
      }
      
      if (storedFeaturesJson != null && storedFeaturesJson.isNotEmpty) {
        _addDebugLog("✅ Found stored features (${storedFeaturesJson.length} chars)");
        Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
        return FaceFeatures.fromJson(storedFeaturesMap);
      }
      
      _addDebugLog("❌ No stored face features found in any location");
      return null;
      
    } catch (e) {
      _addDebugLog("❌ Error retrieving stored face features: $e");
      return null;
    }
  }

  // ✅ ENHANCED: Multi-algorithm face comparison
  Future<double> _enhancedFaceComparison(FaceFeatures stored, FaceFeatures current) async {
    _addDebugLog("🔍 ENHANCED: Starting multi-algorithm face comparison...");
    
    // Algorithm 1: Landmark-based comparison (original)
    double landmarkScore = _compareFaceLandmarks(stored, current);
    _addDebugLog("📊 Landmark comparison score: ${landmarkScore.toStringAsFixed(1)}%");
    
    // Algorithm 2: Distance-based comparison  
    double distanceScore = _compareFeatureDistances(stored, current);
    _addDebugLog("📊 Distance comparison score: ${distanceScore.toStringAsFixed(1)}%");
    
    // Algorithm 3: Geometric relationship comparison
    double geometricScore = _compareGeometricRelationships(stored, current);
    _addDebugLog("📊 Geometric comparison score: ${geometricScore.toStringAsFixed(1)}%");
    
    // Weighted combination of all algorithms
    double finalScore = (landmarkScore * 0.4) + (distanceScore * 0.4) + (geometricScore * 0.2);
    
    _addDebugLog("🎯 FINAL ENHANCED SCORE: ${finalScore.toStringAsFixed(2)}%");
    _addDebugLog("   - Landmark: ${landmarkScore.toStringAsFixed(1)}% (40% weight)");
    _addDebugLog("   - Distance: ${distanceScore.toStringAsFixed(1)}% (40% weight)");
    _addDebugLog("   - Geometric: ${geometricScore.toStringAsFixed(1)}% (20% weight)");
    
    return finalScore;
  }

  // ✅ ENHANCED: Improved landmark comparison with adaptive tolerances
  double _compareFaceLandmarks(FaceFeatures stored, FaceFeatures current) {
    _addDebugLog("🔍 Enhanced landmark comparison...");
    
    int matchCount = 0;
    int totalTests = 0;
    List<String> matchedFeatures = [];
    List<String> failedFeatures = [];

    // Eye comparison with adaptive tolerance
    if (_comparePointsEnhanced(stored.leftEye, current.leftEye, 'leftEye', 50)) {
      matchCount++;
      matchedFeatures.add('leftEye');
    } else {
      failedFeatures.add('leftEye');
    }
    totalTests++;

    if (_comparePointsEnhanced(stored.rightEye, current.rightEye, 'rightEye', 50)) {
      matchCount++;
      matchedFeatures.add('rightEye');
    } else {
      failedFeatures.add('rightEye');
    }
    totalTests++;

    // Nose comparison
    if (_comparePointsEnhanced(stored.noseBase, current.noseBase, 'noseBase', 45)) {
      matchCount++;
      matchedFeatures.add('noseBase');
    } else {
      failedFeatures.add('noseBase');
    }
    totalTests++;

    // Mouth comparison (more lenient)
    if (_comparePointsEnhanced(stored.leftMouth, current.leftMouth, 'leftMouth', 55)) {
      matchCount++;
      matchedFeatures.add('leftMouth');
    } else {
      failedFeatures.add('leftMouth');
    }
    totalTests++;

    if (_comparePointsEnhanced(stored.rightMouth, current.rightMouth, 'rightMouth', 55)) {
      matchCount++;
      matchedFeatures.add('rightMouth');
    } else {
      failedFeatures.add('rightMouth');
    }
    totalTests++;

    // Additional features (if available)
    if (stored.leftCheek != null && current.leftCheek != null) {
      if (_comparePointsEnhanced(stored.leftCheek, current.leftCheek, 'leftCheek', 60)) {
        matchCount++;
        matchedFeatures.add('leftCheek');
      } else {
        failedFeatures.add('leftCheek');
      }
      totalTests++;
    }

    if (stored.rightCheek != null && current.rightCheek != null) {
      if (_comparePointsEnhanced(stored.rightCheek, current.rightCheek, 'rightCheek', 60)) {
        matchCount++;
        matchedFeatures.add('rightCheek');
      } else {
        failedFeatures.add('rightCheek');
      }
      totalTests++;
    }

    double percentage = totalTests > 0 ? (matchCount / totalTests) * 100 : 0.0;
    
    _addDebugLog("📊 Landmark comparison result: $matchCount/$totalTests matches = ${percentage.toStringAsFixed(1)}%");
    _addDebugLog("✅ Matched features: ${matchedFeatures.join(', ')}");
    _addDebugLog("❌ Failed features: ${failedFeatures.join(', ')}");
    
    return percentage;
  }

  // ✅ NEW: Enhanced point comparison with detailed logging
  bool _comparePointsEnhanced(Points? p1, Points? p2, String featureName, double tolerance) {
    if (p1 == null || p2 == null || p1.x == null || p2.x == null || p1.y == null || p2.y == null) {
      _addDebugLog("⚠️ $featureName: Missing coordinate data");
      return false;
    }

    double distance = sqrt(
        (p1.x! - p2.x!) * (p1.x! - p2.x!) +
            (p1.y! - p2.y!) * (p1.y! - p2.y!)
    );

    bool matches = distance <= tolerance;
    
    _addDebugLog("📍 $featureName: distance=${distance.toStringAsFixed(1)} (tolerance=$tolerance) -> ${matches ? 'MATCH' : 'FAIL'}");
    if (_showDebugInfo) {
      _addDebugLog("   Stored: (${p1.x!.toStringAsFixed(1)}, ${p1.y!.toStringAsFixed(1)})");
      _addDebugLog("   Current: (${p2.x!.toStringAsFixed(1)}, ${p2.y!.toStringAsFixed(1)})");
    }

    return matches;
  }

  // ✅ NEW: Distance-based comparison algorithm
  double _compareFeatureDistances(FaceFeatures stored, FaceFeatures current) {
    _addDebugLog("🔍 Distance-based comparison...");
    
    // Calculate inter-feature distances for both faces
    Map<String, double> storedDistances = _calculateFeatureDistances(stored);
    Map<String, double> currentDistances = _calculateFeatureDistances(current);
    
    int matchCount = 0;
    int totalDistances = 0;
    
    for (String distanceKey in storedDistances.keys) {
      if (currentDistances.containsKey(distanceKey)) {
        double storedDist = storedDistances[distanceKey]!;
        double currentDist = currentDistances[distanceKey]!;
        
        // Calculate percentage difference
        double percentDiff = ((storedDist - currentDist).abs() / storedDist) * 100;
        
        // Allow up to 20% difference in distances
        if (percentDiff <= 20.0) {
          matchCount++;
          _addDebugLog("✅ Distance $distanceKey: ${percentDiff.toStringAsFixed(1)}% diff (MATCH)");
        } else {
          _addDebugLog("❌ Distance $distanceKey: ${percentDiff.toStringAsFixed(1)}% diff (FAIL)");
        }
        totalDistances++;
      }
    }
    
    double percentage = totalDistances > 0 ? (matchCount / totalDistances) * 100 : 0.0;
    _addDebugLog("📊 Distance comparison: $matchCount/$totalDistances = ${percentage.toStringAsFixed(1)}%");
    
    return percentage;
  }

  // ✅ NEW: Calculate distances between facial features
  Map<String, double> _calculateFeatureDistances(FaceFeatures features) {
    Map<String, double> distances = {};
    
    // Eye-to-eye distance
    if (features.leftEye != null && features.rightEye != null) {
      distances['eye_to_eye'] = _pointDistance(features.leftEye!, features.rightEye!);
    }
    
    // Eye-to-nose distances
    if (features.leftEye != null && features.noseBase != null) {
      distances['left_eye_to_nose'] = _pointDistance(features.leftEye!, features.noseBase!);
    }
    if (features.rightEye != null && features.noseBase != null) {
      distances['right_eye_to_nose'] = _pointDistance(features.rightEye!, features.noseBase!);
    }
    
    // Nose-to-mouth distance
    if (features.noseBase != null && features.leftMouth != null) {
      distances['nose_to_mouth'] = _pointDistance(features.noseBase!, features.leftMouth!);
    }
    
    // Mouth width
    if (features.leftMouth != null && features.rightMouth != null) {
      distances['mouth_width'] = _pointDistance(features.leftMouth!, features.rightMouth!);
    }
    
    return distances;
  }

  // ✅ NEW: Geometric relationship comparison
  double _compareGeometricRelationships(FaceFeatures stored, FaceFeatures current) {
    _addDebugLog("🔍 Geometric relationship comparison...");
    
    int matchCount = 0;
    int totalTests = 0;
    
    // Test 1: Eye-nose triangle
    if (stored.leftEye != null && stored.rightEye != null && stored.noseBase != null &&
        current.leftEye != null && current.rightEye != null && current.noseBase != null) {
      
      double storedTriangleArea = _triangleArea(stored.leftEye!, stored.rightEye!, stored.noseBase!);
      double currentTriangleArea = _triangleArea(current.leftEye!, current.rightEye!, current.noseBase!);
      
      double areaDiff = ((storedTriangleArea - currentTriangleArea).abs() / storedTriangleArea) * 100;
      
      if (areaDiff <= 25.0) {
        matchCount++;
        _addDebugLog("✅ Eye-nose triangle: ${areaDiff.toStringAsFixed(1)}% diff (MATCH)");
      } else {
        _addDebugLog("❌ Eye-nose triangle: ${areaDiff.toStringAsFixed(1)}% diff (FAIL)");
      }
      totalTests++;
    }
    
    // Test 2: Face symmetry
    if (stored.leftEye != null && stored.rightEye != null && stored.noseBase != null &&
        current.leftEye != null && current.rightEye != null && current.noseBase != null) {
      
      double storedSymmetry = _calculateFaceSymmetry(stored);
      double currentSymmetry = _calculateFaceSymmetry(current);
      
      double symmetryDiff = (storedSymmetry - currentSymmetry).abs();
      
      if (symmetryDiff <= 15.0) {
        matchCount++;
        _addDebugLog("✅ Face symmetry: ${symmetryDiff.toStringAsFixed(1)} diff (MATCH)");
      } else {
        _addDebugLog("❌ Face symmetry: ${symmetryDiff.toStringAsFixed(1)} diff (FAIL)");
      }
      totalTests++;
    }
    
    double percentage = totalTests > 0 ? (matchCount / totalTests) * 100 : 0.0;
    _addDebugLog("📊 Geometric comparison: $matchCount/$totalTests = ${percentage.toStringAsFixed(1)}%");
    
    return percentage;
  }

  // ✅ Helper methods for geometric calculations
  double _pointDistance(Points p1, Points p2) {
    if (p1.x == null || p1.y == null || p2.x == null || p2.y == null) return 0.0;
    return sqrt((p1.x! - p2.x!) * (p1.x! - p2.x!) + (p1.y! - p2.y!) * (p1.y! - p2.y!));
  }

  double _triangleArea(Points p1, Points p2, Points p3) {
    if (p1.x == null || p1.y == null || p2.x == null || p2.y == null || p3.x == null || p3.y == null) return 0.0;
    return ((p1.x! * (p2.y! - p3.y!) + p2.x! * (p3.y! - p1.y!) + p3.x! * (p1.y! - p2.y!)) / 2).abs();
  }

  double _calculateFaceSymmetry(FaceFeatures features) {
    if (features.leftEye == null || features.rightEye == null || features.noseBase == null) return 0.0;
    
    // Calculate how centered the nose is between the eyes
    double eyeMidX = (features.leftEye!.x! + features.rightEye!.x!) / 2;
    double noseCenterOffset = (features.noseBase!.x! - eyeMidX).abs();
    
    return noseCenterOffset;
  }

  // ✅ NEW: Get debug info for face features
  String _getFeaturesDebugInfo(FaceFeatures features) {
    List<String> available = [];
    List<String> missing = [];
    
    if (features.leftEye != null) available.add('leftEye'); else missing.add('leftEye');
    if (features.rightEye != null) available.add('rightEye'); else missing.add('rightEye');
    if (features.noseBase != null) available.add('noseBase'); else missing.add('noseBase');
    if (features.leftMouth != null) available.add('leftMouth'); else missing.add('leftMouth');
    if (features.rightMouth != null) available.add('rightMouth'); else missing.add('rightMouth');
    
    return "Available: [${available.join(', ')}] Missing: [${missing.join(', ')}]";
  }

  // ================ CLOUD RECOVERY ================
  Future<void> _attemptCloudRecovery() async {
    if (_isOfflineMode) {
      _addDebugLog("❌ Cannot attempt cloud recovery in offline mode");
      _handleFailedAuthentication("No stored face data available and device is offline.");
      return;
    }

    _addDebugLog("🌐 Attempting cloud recovery for face data...");

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
          await prefs.setString('secure_face_image_${widget.employeeId}', data['image']);
          
          if (data.containsKey('faceFeatures') && data['faceFeatures'] != null) {
            await prefs.setString('employee_face_features_${widget.employeeId}', 
                jsonEncode(data['faceFeatures']));
            await prefs.setString('secure_face_features_${widget.employeeId}', 
                jsonEncode(data['faceFeatures']));
          }
          
          if (data.containsKey('enhancedFaceFeatures') && data['enhancedFaceFeatures'] != null) {
            await prefs.setString('secure_enhanced_face_features_${widget.employeeId}', 
                jsonEncode(data['enhancedFaceFeatures']));
          }
          
          await prefs.setBool('face_registered_${widget.employeeId}', true);
          await prefs.setBool('enhanced_face_registered_${widget.employeeId}', true);
          
          _addDebugLog("✅ Face data recovered from cloud and saved locally");
          
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
      
      _addDebugLog("❌ No face data found in cloud");
      _handleFailedAuthentication("No registered face found. Please register first.");
      
    } catch (e) {
      _addDebugLog("❌ Cloud recovery failed: $e");
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

    _addDebugLog("✅ ENHANCED iOS Authentication successful!");

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
    _addDebugLog("❌ Authentication failed: $message");
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
              "🎉 Enhanced Authentication Success!",
              style: TextStyle(color: Colors.white, fontSize: 16),
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
              "Mode: ${_isOfflineMode ? 'Enhanced Offline' : 'Online'}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (_showDebugInfo && _authenticationDebugData.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                "Debug Info:",
                style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                "Logs: ${_debugLogs.length} entries",
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: Colors.white),
            ),
            if (_showDebugInfo) ...[
              const SizedBox(height: 12),
              const Text(
                "Recent Debug Logs:",
                style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(
                height: 80,
                child: ListView.builder(
                  itemCount: min(_debugLogs.length, 5),
                  itemBuilder: (context, index) {
                    int logIndex = _debugLogs.length - 5 + index;
                    if (logIndex < 0) logIndex = index;
                    return Text(
                      _debugLogs[logIndex],
                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'monospace'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_showDebugInfo)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _debugLogs.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Debug logs copied to clipboard")),
                );
              },
              child: const Text("Copy Logs", style: TextStyle(color: Colors.orange)),
            ),
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

  // ================ HELPER FUNCTIONS ================
  int _countDetectedLandmarks(FaceFeatures features) {
    int count = 0;
    if (features.rightEar != null) count++;
    if (features.leftEar != null) count++;
    if (features.rightEye != null) count++;
    if (features.leftEye != null) count++;
    if (features.rightCheek != null) count++;
    if (features.leftCheek != null) count++;
    if (features.rightMouth != null) count++;
    if (features.leftMouth != null) count++;
    if (features.noseBase != null) count++;
    if (features.bottomMouth != null) count++;
    return count;
  }
}