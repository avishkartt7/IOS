// COMPLETELY FIXED VerifyFaceView - ZERO OVERFLOW GUARANTEED

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';

import 'package:face_auth_compatible/services/registration_completion_service.dart';
import 'package:face_auth_compatible/dashboard/dashboard_view.dart';
import 'package:face_auth_compatible/services/secure_face_storage_service.dart';

// Enhanced utilities imports
import 'package:face_auth_compatible/model/enhanced_face_features.dart';
import 'package:face_auth_compatible/common/utils/enhanced_face_extractor.dart';
import 'package:face_auth_compatible/common/utils/extract_face_feature.dart';

// Existing imports
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth_compatible/common/views/camera_view.dart';
import 'package:face_auth_compatible/model/user_model.dart';
import 'package:face_auth_compatible/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/service_locator.dart';
import 'package:flutter_face_api/face_api.dart' as regula;

class VerifyFaceView extends StatefulWidget {
  final String employeeId;
  final String employeePin;

  const VerifyFaceView({
    Key? key,
    required this.employeeId,
    required this.employeePin,
  }) : super(key: key);

  @override
  State<VerifyFaceView> createState() => _VerifyFaceViewState();
}

class _VerifyFaceViewState extends State<VerifyFaceView>
    with TickerProviderStateMixin {

  // Face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  String? _image;
  EnhancedFaceFeatures? _enhancedFaceFeatures;
  FaceFeatures? _faceFeatures;
  bool _isVerifying = false;
  bool _isOfflineMode = false;
  bool _isCameraActive = false;
  late ConnectivityService _connectivityService;

  // Regula SDK images for comparison
  var storedImage = regula.MatchFacesImage();
  var capturedImage = regula.MatchFacesImage();

  // Live feedback variables
  String _realTimeFeedback = "Position your face in the camera";
  Color _feedbackColor = const Color(0xFF2196F3);
  bool _isProcessingRealTime = false;

  // Quality tracking
  double _currentQuality = 0.0;
  bool _isReadyForCapture = false;

  // Status tracking
  bool _isFaceDetected = false;
  bool _areEyesOpen = false;
  bool _isLookingStraight = false;
  bool _isFaceCentered = false;
  bool _isProperDistance = false;
  bool _hasGoodLighting = false;

  // Verification results
  String _similarity = "0.0";
  int _verificationAttempts = 0;
  static const int _maxVerificationAttempts = 3;

  @override
  void initState() {
    super.initState();
    print("🔍 VerifyFaceView initialized for employee: ${widget.employeeId}");
    _connectivityService = getIt<ConnectivityService>();
    _checkConnectivity();

    // Listen to connectivity changes
    _connectivityService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isOfflineMode = status == ConnectionStatus.offline;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      bool isOnline = await _connectivityService.checkConnectivity();
      setState(() {
        _isOfflineMode = !isOnline;
      });
    } catch (e) {
      setState(() {
        _isOfflineMode = false;
      });
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    EnhancedFaceExtractor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CustomSnackBar.context = context;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50), // Green for verification
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Verify Face",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => _showExitConfirmation(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOfflineMode ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isOfflineMode ? "Offline" : "Online",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    // ✅ HEADER SECTION - COMPACT
                    _buildHeader(),

                    // ✅ STATUS SECTION - ONLY WHEN ACTIVE
                    if (_isCameraActive) _buildStatusCard(),

                    // ✅ CAMERA SECTION - FLEXIBLE
                    _buildCameraSection(constraints),

                    // ✅ ACTION SECTION - FLEXIBLE
                    _buildActionSection(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user,
            color: Color(0xFF4CAF50),
            size: 24,
          ),
          const SizedBox(height: 4),
          const Text(
            "Face Verification",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Verify your registered face to complete setup",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: const Text(
              "Step 2 of 2 - Verification",
              style: TextStyle(
                fontSize: 9,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _feedbackColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getFeedbackIcon(),
              color: _feedbackColor,
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _realTimeFeedback,
                  style: TextStyle(
                    color: _feedbackColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_currentQuality > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        "Quality: ${(_currentQuality * 100).toInt()}%",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _currentQuality,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _currentQuality > 0.7 ? Colors.green :
                            _currentQuality > 0.4 ? Colors.orange : Colors.red,
                          ),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_isProcessingRealTime)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF4CAF50),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraSection(BoxConstraints constraints) {
    // Calculate available height for camera
    double maxCameraHeight = constraints.maxHeight * 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: maxCameraHeight.clamp(200.0, 400.0), // Min 200, Max 400
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCameraActive ? _feedbackColor.withOpacity(0.5) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isCameraActive
                ? _feedbackColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraView(
                onImage: (image) {
                  setState(() {
                    _image = base64Encode(image);
                  });
                  _testImageQuality(_image!);
                },
                onInputImage: (inputImage) async {
                  await _processRealTimeFeedback(
                      inputImage, constraints.maxWidth, constraints.maxHeight);
                },
              ),
            ),
            if (_isProcessingRealTime)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50),
                    strokeWidth: 3,
                  ),
                ),
              ),
            if (_isVerifying)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF4CAF50),
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Verifying your face...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
    );
  }

  Widget _buildActionSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isVerifying) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Color(0xFF4CAF50),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Verifying face...",
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isReadyForCapture && _enhancedFaceFeatures != null) ...[
            // Success indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "Ready to verify",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Verify button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => _verifyFace(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Verify My Face",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Default instruction state
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Position Your Face for Verification",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Look at the camera to verify your registered face",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_verificationAttempts > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Attempt ${_verificationAttempts + 1} of $_maxVerificationAttempts",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getFeedbackIcon() {
    if (_feedbackColor == Colors.green || _feedbackColor == const Color(0xFF4CAF50)) return Icons.check_circle;
    if (_feedbackColor == Colors.orange || _feedbackColor == const Color(0xFFFF9800)) return Icons.warning;
    if (_feedbackColor == const Color(0xFF2196F3)) return Icons.info;
    return Icons.error;
  }

  // Enhanced real-time feedback processing
  Future<void> _processRealTimeFeedback(InputImage inputImage, double screenWidth, double screenHeight) async {
    if (_isProcessingRealTime || _isVerifying) return;

    setState(() {
      _isProcessingRealTime = true;
    });

    try {
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      EnhancedFaceFeatures? features = await EnhancedFaceExtractor.extractForRealTime(
        inputImage,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      if (mounted) {
        setState(() {
          _enhancedFaceFeatures = features;

          // Update status flags
          _isFaceDetected = features != null;
          _areEyesOpen = features?.areEyesOpen ?? false;
          _isLookingStraight = features?.isLookingStraight ?? false;
          _isFaceCentered = features?.isFaceCentered ?? false;

          if (features != null) {
            double faceWidth = features.faceWidth ?? 0;
            double faceRatio = faceWidth / screenWidth;
            _isProperDistance = faceRatio >= 0.15 && faceRatio <= 0.8;
          } else {
            _isProperDistance = false;
          }

          _hasGoodLighting = features?.hasGoodLighting ?? false;
          _currentQuality = features?.faceQualityScore ?? 0.0;

          // Generate feedback
          _realTimeFeedback = _generateVerificationFeedbackMessage(features, screenWidth, screenHeight);
          _feedbackColor = _getFeedbackColorAdvanced(features);

          // Check readiness
          bool wasReady = _isReadyForCapture;
          _isReadyForCapture = _isReadyForVerification(features);

          if (_isReadyForCapture && !wasReady && features != null) {
            _captureHighQualityFeatures(features);
          }

          _isProcessingRealTime = false;
          _isCameraActive = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingRealTime = false;
          _realTimeFeedback = "Error - try again";
          _feedbackColor = Colors.red;
          _resetStatusFlags();
        });
      }
    }
  }

  void _resetStatusFlags() {
    _isFaceDetected = false;
    _areEyesOpen = false;
    _isLookingStraight = false;
    _isFaceCentered = false;
    _isProperDistance = false;
    _hasGoodLighting = false;
  }

  String _generateVerificationFeedbackMessage(EnhancedFaceFeatures? features, double screenWidth, double screenHeight) {
    if (features == null) {
      return "Position face in camera";
    }

    if (!features.areEyesOpen) {
      return "Keep eyes open";
    }

    if ((features.faceQualityScore ?? 0) < 0.3) {
      return "Move to better light";
    }

    double faceWidth = features.faceWidth ?? 0;
    double faceRatio = faceWidth / screenWidth;

    if (faceRatio < 0.15) {
      return "Move closer";
    } else if (faceRatio > 0.8) {
      return "Move farther away";
    }

    if (!features.isFaceCentered) {
      return "Center your face";
    }

    double headYaw = (features.headEulerAngleY ?? 0).abs();
    if (headYaw > 30) {
      return "Look straight ahead";
    }

    if ((features.faceQualityScore ?? 0) > 0.5) {
      return "Perfect! Ready to verify";
    }

    return "Hold position";
  }

  Color _getFeedbackColorAdvanced(EnhancedFaceFeatures? features) {
    if (features == null) return Colors.red;

    if (!features.areEyesOpen) return Colors.red;

    if (features.areEyesOpen && (features.faceQualityScore ?? 0) > 0.5) {
      return const Color(0xFF4CAF50);
    } else if ((features.faceQualityScore ?? 0) > 0.3 && features.areEyesOpen) {
      return const Color(0xFFFF9800);
    } else {
      return Colors.red;
    }
  }

  bool _isReadyForVerification(EnhancedFaceFeatures? features) {
    if (features == null) return false;

    bool eyesOpen = features.areEyesOpen;
    bool goodQuality = (features.faceQualityScore ?? 0) > 0.5;
    bool reasonablyPositioned = features.isFaceCentered ||
        features.isProperDistance ||
        features.hasGoodLighting;

    return eyesOpen && goodQuality && reasonablyPositioned;
  }

  void _captureHighQualityFeatures(EnhancedFaceFeatures features) {
    // Features captured for verification
    debugPrint("📸 High-quality features captured for verification");
  }

  void _testImageQuality(String base64Image) {
    // Image quality testing logic for verification
  }

  // ✅ VERIFY FACE AND NAVIGATE TO DASHBOARD
  void _verifyFace(BuildContext context) async {
    if (_image == null || _enhancedFaceFeatures == null || _faceFeatures == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Please capture your face with good quality first",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationAttempts++;
    });

    try {
      // Prepare captured image
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      capturedImage.bitmap = cleanedImage;
      capturedImage.imageType = regula.ImageType.PRINTED;

      // Get stored face image for comparison
      String? storedFaceImage = await _getStoredFaceImage();

      if (storedFaceImage == null) {
        setState(() {
          _isVerifying = false;
        });
        _showVerificationError("No registered face found. Please register your face first.");
        return;
      }

      storedImage.bitmap = storedFaceImage;
      storedImage.imageType = regula.ImageType.PRINTED;

      // Perform face verification
      bool verificationSuccess = false;
      double similarityScore = 0.0;

      await _checkConnectivity();

      if (!_isOfflineMode) {
        // Online verification using Regula SDK
        try {
          var request = regula.MatchFacesRequest();
          request.images = [storedImage, capturedImage];

          dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request))
              .timeout(const Duration(seconds: 8));

          var response = regula.MatchFacesResponse.fromJson(json.decode(value));

          if (response != null && response.results != null && response.results!.isNotEmpty) {
            double thresholdValue = 0.75;

            dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
                jsonEncode(response.results), thresholdValue);

            var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));

            if (split!.matchedFaces.isNotEmpty) {
              similarityScore = split.matchedFaces[0]!.similarity! * 100;
              _similarity = similarityScore.toStringAsFixed(2);

              // Lower threshold for verification (more lenient than authentication)
              verificationSuccess = similarityScore > 75.0;
            }
          }
        } catch (e) {
          debugPrint("⚠️ Online verification failed, falling back to offline: $e");
          // Fall back to offline verification
          verificationSuccess = await _performOfflineVerification();
        }
      } else {
        // Offline verification
        verificationSuccess = await _performOfflineVerification();
      }

      setState(() {
        _isVerifying = false;
      });

      if (verificationSuccess) {
        // ✅ VERIFICATION SUCCESSFUL
        await _handleSuccessfulVerification();
      } else {
        // ❌ VERIFICATION FAILED
        await _handleFailedVerification();
      }

    } catch (e) {
      setState(() {
        _isVerifying = false;
      });

      _showVerificationError("Error during verification: $e");
    }
  }

  // Get stored face image for comparison
  Future<String?> _getStoredFaceImage() async {
    try {
      final secureFaceStorage = getIt<SecureFaceStorageService>();

      // Try secure storage first
      String? storedImage = await secureFaceStorage.getFaceImage(widget.employeeId);

      if (storedImage != null && storedImage.isNotEmpty) {
        return storedImage;
      }

      // Try SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      storedImage = prefs.getString('employee_image_${widget.employeeId}');

      if (storedImage != null && storedImage.isNotEmpty) {
        if (storedImage.contains('data:image') && storedImage.contains(',')) {
          storedImage = storedImage.split(',')[1];
        }
        return storedImage;
      }

      // Try Firestore if online
      if (!_isOfflineMode) {
        try {
          DocumentSnapshot snapshot = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            if (data.containsKey('image') && data['image'] != null) {
              String cloudImage = data['image'];
              if (cloudImage.contains('data:image') && cloudImage.contains(',')) {
                cloudImage = cloudImage.split(',')[1];
              }
              return cloudImage;
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error fetching from Firestore: $e");
        }
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error getting stored face image: $e");
      return null;
    }
  }

  // Perform offline verification using enhanced features
  Future<bool> _performOfflineVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get stored enhanced face features
      String? storedFeaturesJson = prefs.getString('enhanced_face_features_${widget.employeeId}');

      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        debugPrint("❌ No stored enhanced features found for offline verification");
        return false;
      }

      Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
      EnhancedFaceFeatures storedFeatures = EnhancedFaceFeatures.fromJson(storedFeaturesMap);

      if (_enhancedFaceFeatures != null) {
        double similarity = _enhancedFaceFeatures!.calculateSimilarityTo(storedFeatures);
        double similarityPercentage = similarity * 100;

        _similarity = similarityPercentage.toStringAsFixed(2);

        // More lenient threshold for verification
        return similarityPercentage > 70.0;
      }

      return false;
    } catch (e) {
      debugPrint("❌ Error in offline verification: $e");
      return false;
    }
  }

  // Handle successful verification
  Future<void> _handleSuccessfulVerification() async {
    debugPrint("✅ Face verification successful with ${_similarity}% similarity");

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "✅ Face verified successfully! ($_similarity%)",
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // ✅ STEP 1: Mark registration as complete
    try {
      await RegistrationCompletionService.markRegistrationComplete(widget.employeeId);
      debugPrint("✅ Registration marked as complete");
    } catch (e) {
      debugPrint("⚠️ Error marking registration complete: $e");
    }

    // ✅ STEP 2: Set authentication status for PIN-based system
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('authenticated_user_id', widget.employeeId);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);
      debugPrint("✅ Authentication status set for dashboard access");
    } catch (e) {
      debugPrint("⚠️ Error setting authentication status: $e");
    }

    // ✅ STEP 3: Navigate to dashboard after a short delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      debugPrint("🎉 Navigating to dashboard after successful verification");
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardView(employeeId: widget.employeeId),
        ),
            (route) => false, // Remove all previous routes
      );
    }
  }

  // Handle failed verification
  Future<void> _handleFailedVerification() async {
    debugPrint("❌ Face verification failed with ${_similarity}% similarity");

    if (_verificationAttempts >= _maxVerificationAttempts) {
      // Max attempts reached
      _showMaxAttemptsDialog();
    } else {
      // Allow retry
      _showVerificationError(
          "Face verification failed. Please ensure good lighting and try again.\n"
              "Attempt $_verificationAttempts of $_maxVerificationAttempts"
      );
    }
  }

  // Show verification error dialog
  void _showVerificationError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Verification Failed",
                  style: TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          actions: [
            if (_verificationAttempts < _maxVerificationAttempts)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Reset for retry
                  setState(() {
                    _realTimeFeedback = "Position your face in the camera";
                    _feedbackColor = const Color(0xFF2196F3);
                    _isReadyForCapture = false;
                    _resetStatusFlags();
                  });
                },
                child: const Text(
                  "Try Again",
                  style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_verificationAttempts >= _maxVerificationAttempts) {
                  _showMaxAttemptsDialog();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show max attempts reached dialog
  void _showMaxAttemptsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Max Attempts Reached",
                  style: TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "You have reached the maximum number of verification attempts. "
                "You can try again later or contact support for assistance.",
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text(
                "Go Back",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset attempts and try again
                setState(() {
                  _verificationAttempts = 0;
                  _realTimeFeedback = "Position your face in the camera";
                  _feedbackColor = const Color(0xFF2196F3);
                  _isReadyForCapture = false;
                  _resetStatusFlags();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Try Again",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show exit confirmation dialog
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Exit Verification?",
                  style: TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "You need to complete face verification to access the app. "
                "Are you sure you want to exit?",
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Stay",
                style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit verification
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Exit",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}



