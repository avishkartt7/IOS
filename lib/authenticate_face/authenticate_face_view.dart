// lib/authenticate_face/authenticate_face_view.dart - Full Screen Fixed Version

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
  // Core Services
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // Authentication State
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
    print("Authentication view initialized for employee: ${widget.employeeId}");
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

  // Connectivity Check
  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
    }
  }

  // Stored Face Check
  Future<void> _checkStoredImage() async {
    try {
      if (widget.employeeId == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      String? storedImage = prefs.getString('employee_image_${widget.employeeId}');
      String? secureImage = prefs.getString('secure_face_image_${widget.employeeId}');
      String? storedFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      String? secureFeatures = prefs.getString('secure_face_features_${widget.employeeId}');
      bool faceRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;

      setState(() {
        _hasStoredFace = (storedImage != null && storedImage.isNotEmpty) || 
                        (secureImage != null && secureImage.isNotEmpty) ||
                        (storedFeatures != null && storedFeatures.isNotEmpty) ||
                        (secureFeatures != null && secureFeatures.isNotEmpty) ||
                        faceRegistered;
      });
    } catch (e) {
      setState(() {
        _hasStoredFace = false;
      });
    }
  }

  // Audio Feedback
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

  @override
  Widget build(BuildContext context) {
    CustomSnackBar.context = context;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
    appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () {
      if (widget.onAuthenticationComplete != null) {
        widget.onAuthenticationComplete!(false);
      }
      Navigator.of(context).pop(false); // Return false when manually closed
    },
  ),
  title: Text(
    widget.isRegistrationValidation 
        ? "Verify Your Face" 
        : "Face Authentication",
    style: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  centerTitle: true,
  actions: [
    Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isOfflineMode ? Colors.orange : Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _isOfflineMode ? "Offline" : "Online",
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    ),
  ],
),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Status Indicator
              _buildStatusIndicator(),
              
              const SizedBox(height: 20),
              
              // Camera View
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _canAuthenticate 
                          ? Colors.green 
                          : Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
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
                            color: Colors.black.withOpacity(0.8),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 4,
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    "Verifying face...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
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
              
              const SizedBox(height: 30),
              
              // Action Button or Status Message
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: _canAuthenticate && !isMatching
                    ? SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.face, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                widget.isRegistrationValidation 
                                    ? "Verify Face" 
                                    : "Authenticate",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: _getStatusColor(),
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Authentication Status",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_hasStoredFace)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "Ready",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (_hasAuthenticated) {
      return "Authentication successful!";
    } else if (isMatching) {
      return "Verification in progress...";
    } else if (_canAuthenticate) {
      return "Ready for authentication";
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

  // Image Processing
  Future<void> _setImage(Uint8List imageToAuthenticate) async {
    image2.bitmap = base64Encode(imageToAuthenticate);
    image2.imageType = regula.ImageType.PRINTED;

    setState(() {
      _canAuthenticate = true;
    });
  }

  Future<void> _processInputImage(InputImage inputImage) async {
    try {
      setState(() => isMatching = true);
      
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (_faceFeatures != null) {
        bool isValid = validateFaceFeatures(_faceFeatures!);
        double qualityScore = getFaceFeatureQuality(_faceFeatures!);
        
        print("Face detected with quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");
      }
      
      setState(() => isMatching = false);
    } catch (e) {
      setState(() => isMatching = false);
      debugPrint("Error processing input image: $e");
    }
  }

  // Employee Data Fetching
  Future<void> _fetchEmployeeData() async {
    if (widget.employeeId == null) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString('user_data_${widget.employeeId}');
      
      if (localData != null) {
        Map<String, dynamic> data = jsonDecode(localData);
        setState(() {
          employeeData = data;
        });
      }

      if (!_isOfflineMode) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            await prefs.setString('user_data_${widget.employeeId}', jsonEncode(data));
            
            setState(() {
              employeeData = data;
            });
          }
        } catch (e) {
          print("Firestore fetch failed, using local data: $e");
        }
      }
    } catch (e) {
      print("Error fetching employee data: $e");
    }
  }

  // Authentication Logic
  Future<void> _authenticate() async {
    if (!_canAuthenticate || isMatching) return;

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

  // Core Face Matching Logic
  Future<void> _matchFaceWithStored() async {
    try {
      String? storedImage;

      if (employeeData != null && employeeData!['image'] != null) {
        storedImage = employeeData!['image'];
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        storedImage = prefs.getString('secure_face_image_${widget.employeeId}') ??
                     prefs.getString('employee_image_${widget.employeeId}');
      }

      if (storedImage == null) {
        await _attemptCloudRecovery();
        return;
      }

      if (storedImage.contains('data:image') && storedImage.contains(',')) {
        storedImage = storedImage.split(',')[1];
      }

      if (_isOfflineMode) {
        await _performOfflineAuthentication(storedImage);
      } else {
        await _performOnlineAuthentication(storedImage);
      }

    } catch (e) {
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

  // Online Authentication
  Future<void> _performOnlineAuthentication(String storedImage) async {
    try {
      image1.bitmap = storedImage;
      image1.imageType = regula.ImageType.PRINTED;

      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];

      dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request))
          .timeout(const Duration(seconds: 10));
      
      var response = regula.MatchFacesResponse.fromJson(json.decode(value));

      dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response!.results), 0.8);

      var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));
      
      setState(() {
        _similarity = split!.matchedFaces.isNotEmpty
            ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
            : "0.0";
      });

      if (_similarity != "0.0" && double.parse(_similarity) > 80.0) {
        _handleSuccessfulAuthentication();
      } else {
        _handleFailedAuthentication("Face doesn't match. Please try again.");
      }
    } catch (e) {
      await _performOfflineAuthentication(storedImage);
    }
  }

  // Offline Authentication
  Future<void> _performOfflineAuthentication(String storedImage) async {
    try {
      if (_faceFeatures == null) {
        _handleFailedAuthentication("No face detected. Please try again with better lighting.");
        return;
      }

      FaceFeatures? storedFeatures = await _getStoredFaceFeatures();
      
      if (storedFeatures == null) {
        await _attemptCloudRecovery();
        return;
      }

      double matchPercentage = await _compareFaceFeatures(storedFeatures, _faceFeatures!);
      
      setState(() {
        _similarity = matchPercentage.toStringAsFixed(2);
      });

      double threshold = 60.0;

      if (matchPercentage >= threshold) {
        _handleSuccessfulAuthentication();
      } else {
        _handleFailedAuthentication("Face match too low (${matchPercentage.toStringAsFixed(1)}% vs ${threshold.toStringAsFixed(1)}%).");
      }
    } catch (e) {
      _handleFailedAuthentication("Error during face matching: $e");
    }
  }

  // Face Comparison
  Future<double> _compareFaceFeatures(FaceFeatures stored, FaceFeatures current) async {
    double landmarkScore = _compareLandmarks(stored, current);
    double distanceScore = _compareDistances(stored, current);
    
    double finalScore = max(landmarkScore, distanceScore);
    
    if (finalScore > 30.0 && finalScore < 60.0) {
      finalScore = finalScore * 1.15;
    }
    
    finalScore = min(finalScore, 100.0);
    
    return finalScore;
  }

  double _compareLandmarks(FaceFeatures stored, FaceFeatures current) {
    int matchCount = 0;
    int totalTests = 0;

    Map<String, double> tolerances = {
      'leftEye': 50.0,
      'rightEye': 50.0,
      'noseBase': 60.0,
      'leftMouth': 70.0,
      'rightMouth': 70.0,
      'leftCheek': 80.0,
      'rightCheek': 80.0,
    };

    if (_comparePoints(stored.leftEye, current.leftEye, 'leftEye', tolerances['leftEye']!)) {
      matchCount++;
    }
    totalTests++;

    if (_comparePoints(stored.rightEye, current.rightEye, 'rightEye', tolerances['rightEye']!)) {
      matchCount++;
    }
    totalTests++;

    if (_comparePoints(stored.noseBase, current.noseBase, 'noseBase', tolerances['noseBase']!)) {
      matchCount++;
    }
    totalTests++;

    if (_comparePoints(stored.leftMouth, current.leftMouth, 'leftMouth', tolerances['leftMouth']!)) {
      matchCount++;
    }
    totalTests++;

    if (_comparePoints(stored.rightMouth, current.rightMouth, 'rightMouth', tolerances['rightMouth']!)) {
      matchCount++;
    }
    totalTests++;

    if (stored.leftCheek != null && current.leftCheek != null) {
      if (_comparePoints(stored.leftCheek, current.leftCheek, 'leftCheek', tolerances['leftCheek']!)) {
        matchCount++;
      }
      totalTests++;
    }

    if (stored.rightCheek != null && current.rightCheek != null) {
      if (_comparePoints(stored.rightCheek, current.rightCheek, 'rightCheek', tolerances['rightCheek']!)) {
        matchCount++;
      }
      totalTests++;
    }

    double percentage = totalTests > 0 ? (matchCount / totalTests) * 100 : 0.0;
    return percentage;
  }

  bool _comparePoints(Points? p1, Points? p2, String featureName, double tolerance) {
    if (p1 == null || p2 == null || p1.x == null || p2.x == null || p1.y == null || p2.y == null) {
      return false;
    }

    double distance = sqrt(
        (p1.x! - p2.x!) * (p1.x! - p2.x!) +
            (p1.y! - p2.y!) * (p1.y! - p2.y!)
    );

    return distance <= tolerance;
  }

  double _compareDistances(FaceFeatures stored, FaceFeatures current) {
    Map<String, double> storedDistances = _calculateFeatureDistances(stored);
    Map<String, double> currentDistances = _calculateFeatureDistances(current);
    
    int matchCount = 0;
    int totalDistances = 0;
    double tolerance = 30.0;
    
    for (String distanceKey in storedDistances.keys) {
      if (currentDistances.containsKey(distanceKey)) {
        double storedDist = storedDistances[distanceKey]!;
        double currentDist = currentDistances[distanceKey]!;
        
        if (storedDist > 0 && currentDist > 0) {
          double percentDiff = ((storedDist - currentDist).abs() / storedDist) * 100;
          
          if (percentDiff <= tolerance) {
            matchCount++;
          }
          totalDistances++;
        }
      }
    }
    
    double percentage = totalDistances > 0 ? (matchCount / totalDistances) * 100 : 0.0;
    return percentage;
  }

  Future<FaceFeatures?> _getStoredFaceFeatures() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      List<String> storageKeys = [
        'secure_face_features_${widget.employeeId}',
        'employee_face_features_${widget.employeeId}',
      ];
      
      for (String key in storageKeys) {
        String? storedFeaturesJson = prefs.getString(key);
        
        if (storedFeaturesJson != null && storedFeaturesJson.isNotEmpty) {
          try {
            Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
            FaceFeatures features = FaceFeatures.fromJson(storedFeaturesMap);
            
            if (features.leftEye != null || features.rightEye != null || features.noseBase != null) {
              return features;
            }
          } catch (e) {
            continue;
          }
        }
      }
      
      if (employeeData != null && employeeData!.containsKey('faceFeatures')) {
        try {
          Map<String, dynamic> featuresMap = employeeData!['faceFeatures'];
          FaceFeatures features = FaceFeatures.fromJson(featuresMap);
          
          if (features.leftEye != null || features.rightEye != null || features.noseBase != null) {
            return features;
          }
        } catch (e) {
          print("Error parsing features from employee data: $e");
        }
      }
      
      return null;
      
    } catch (e) {
      return null;
    }
  }

  // Cloud Recovery
  Future<void> _attemptCloudRecovery() async {
    if (_isOfflineMode) {
      _handleFailedAuthentication("No stored face data available and device is offline.");
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('image') && data['image'] != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('employee_image_${widget.employeeId}', data['image']);
          await prefs.setString('secure_face_image_${widget.employeeId}', data['image']);
          
          if (data.containsKey('faceFeatures') && data['faceFeatures'] != null) {
            await prefs.setString('employee_face_features_${widget.employeeId}', 
                jsonEncode(data['faceFeatures']));
            await prefs.setString('secure_face_features_${widget.employeeId}', 
                jsonEncode(data['faceFeatures']));
          }
          
          await prefs.setBool('face_registered_${widget.employeeId}', true);
          
          setState(() {
            employeeData = data;
            _hasStoredFace = true;
          });
          
          await _matchFaceWithStored();
          return;
        }
      }
      
      _handleFailedAuthentication("No registered face found. Please register first.");
      
    } catch (e) {
      _handleFailedAuthentication("No stored face data available.");
    }
  }

  // Success/Failure Handlers
  void _handleSuccessfulAuthentication() {
  _playSuccessAudio;

  setState(() {
    isMatching = false;
    _hasAuthenticated = true;
  });

  if (widget.isRegistrationValidation) {
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
    // Call the callback first
    if (widget.onAuthenticationComplete != null) {
      widget.onAuthenticationComplete!(true);
    }
    
    // Then close the screen and return success result
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop(true); // Return true for success
      }
    });
  }
}

  void _handleFailedAuthentication(String message) {
  setState(() {
    isMatching = false;
  });
  _playFailedAudio;
  
  // Call the callback first
  if (widget.onAuthenticationComplete != null) {
    widget.onAuthenticationComplete!(false);
  }
  
  _showFailureDialog(
    title: "Authentication Failed",
    description: message,
  );
}

  // Dialogs
  void _showSuccessDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text(
            "Authentication Success!",
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
            "Mode: ${_isOfflineMode ? 'Offline' : 'Online'}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(true); // Close authentication screen with success
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
      backgroundColor: const Color(0xFF1E293B),
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
            Navigator.of(context).pop(); // Close dialog
            // Don't close the authentication screen - let user try again
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            "Try Again",
            style: TextStyle(color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(false); // Close authentication screen with failure
          },
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    ),
  );
}

  // Helper Functions
  Map<String, double> _calculateFeatureDistances(FaceFeatures features) {
    Map<String, double> distances = {};
    
    if (features.leftEye != null && features.rightEye != null) {
      distances['eye_to_eye'] = _pointDistance(features.leftEye!, features.rightEye!);
    }
    
    if (features.leftEye != null && features.noseBase != null) {
      distances['left_eye_to_nose'] = _pointDistance(features.leftEye!, features.noseBase!);
    }
    if (features.rightEye != null && features.noseBase != null) {
      distances['right_eye_to_nose'] = _pointDistance(features.rightEye!, features.noseBase!);
    }
    
    if (features.noseBase != null && features.leftMouth != null) {
      distances['nose_to_mouth'] = _pointDistance(features.noseBase!, features.leftMouth!);
    }
    
    if (features.leftMouth != null && features.rightMouth != null) {
      distances['mouth_width'] = _pointDistance(features.leftMouth!, features.rightMouth!);
    }
    
    return distances;
  }

  double _pointDistance(Points p1, Points p2) {
    if (p1.x == null || p1.y == null || p2.x == null || p2.y == null) return 0.0;
    return sqrt((p1.x! - p2.x!) * (p1.x! - p2.x!) + (p1.y! - p2.y!) * (p1.y! - p2.y!));
  }

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