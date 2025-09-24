// lib/verify_face/verify_face_view.dart - Clean Production Ready

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

import 'package:face_auth/services/registration_completion_service.dart';
import 'package:face_auth/dashboard/dashboard_view.dart';
import 'package:face_auth/services/secure_face_storage_service.dart';
import 'package:face_auth/model/enhanced_face_features.dart';
import 'package:face_auth/common/utils/enhanced_face_extractor.dart';
import 'package:face_auth/common/utils/extract_face_feature.dart';
import 'package:face_auth/common/views/camera_view.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:flutter_face_api/face_api.dart' as regula;
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Core Services
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // State Variables
  String? _image;
  EnhancedFaceFeatures? _enhancedFaceFeatures;
  FaceFeatures? _faceFeatures;
  bool _isVerifying = false;
  bool _isOfflineMode = false;
  bool _isProcessing = false;
  bool _isCameraActive = false;
  int _verificationAttempts = 0;
  static const int _maxVerificationAttempts = 3;

  // Regula SDK images
  var storedImage = regula.MatchFacesImage();
  var capturedImage = regula.MatchFacesImage();

  // Quality tracking
  double _currentQuality = 0.0;
  bool _isReadyForVerification = false;
  String _similarity = "0.0";

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkConnectivity();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _successAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _faceDetector.close();
    _pulseController.dispose();
    _successController.dispose();
    EnhancedFaceExtractor.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: _showExitConfirmation,
        ),
        title: const Text(
          "Verify Face",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 20),
              
              // Status Message
              _buildStatusMessage(),
              
              const SizedBox(height: 30),
              
              // Camera Section
              Expanded(
                child: _buildCameraSection(),
              ),
              
              const SizedBox(height: 30),
              
              // Action Button
              _buildActionButton(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message;
    IconData icon;
    Color color;
    
    if (_isVerifying) {
      message = "Verifying your face against registered data...";
      icon = Icons.verified_user;
      color = Colors.blue;
    } else if (_isProcessing) {
      message = "Analyzing your face for verification...";
      icon = Icons.face_retouching_natural;
      color = Colors.blue;
    } else if (_isReadyForVerification && _enhancedFaceFeatures != null) {
      message = "Perfect! Ready to verify your identity";
      icon = Icons.verified;
      color = Colors.green;
    } else if (_isCameraActive && _currentQuality > 0.3) {
      message = "Hold steady - analyzing face quality";
      icon = Icons.face;
      color = Colors.orange;
    } else {
      message = "Look at the camera to verify your registered face";
      icon = Icons.face_recognition;
      color = Colors.white70;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (_verificationAttempts > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Attempt $_verificationAttempts of $_maxVerificationAttempts",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Camera View with Animation
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _successController,
            ]),
            builder: (context, child) {
              double scale = 1.0;
              Color borderColor = Colors.white.withOpacity(0.3);
              
              if (_isReadyForVerification && _enhancedFaceFeatures != null) {
                scale = _successAnimation.value;
                borderColor = Colors.green;
                if (!_successController.isAnimating && !_successController.isCompleted) {
                  _successController.forward();
                }
              } else if (!_isCameraActive || _currentQuality == 0.0) {
                scale = _pulseAnimation.value;
                _pulseController.repeat(reverse: true);
              } else {
                _pulseController.stop();
                if (_currentQuality > 0.5) {
                  borderColor = Colors.green.withOpacity(0.8);
                } else if (_currentQuality > 0.3) {
                  borderColor = Colors.orange.withOpacity(0.8);
                } else {
                  borderColor = Colors.red.withOpacity(0.8);
                }
              }
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: 4,
                    ),
                    boxShadow: [
                      if (_isReadyForVerification && _enhancedFaceFeatures != null)
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 15,
                        ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: CameraView(
                            onImage: (image) {
                              setState(() {
                                _image = base64Encode(image);
                                _isCameraActive = true;
                              });
                            },
                            onInputImage: (inputImage) async {
                              await _processRealTimeFeedback(inputImage);
                            },
                          ),
                        ),
                        
                        // Processing overlay
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Analyzing...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Verification overlay
                        if (_isVerifying)
                          Container(
                            color: Colors.black.withOpacity(0.8),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.blue,
                                    strokeWidth: 4,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Verifying face...",
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
                        
                        // Quality indicator
                        if (_isCameraActive && _currentQuality > 0 && !_isProcessing && !_isVerifying)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${(_currentQuality * 100).toInt()}%",
                                style: TextStyle(
                                  color: _currentQuality > 0.5 ? Colors.green : 
                                         _currentQuality > 0.3 ? Colors.orange : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isVerifying) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              "Verifying your identity...",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Please wait while we match your face",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    if (_isReadyForVerification && _enhancedFaceFeatures != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _verifyFace,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, size: 24),
                SizedBox(width: 12),
                Text(
                  "Verify My Face",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
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
            Icons.face_recognition,
            size: 32,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          const Text(
            "Position Your Face for Verification",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Look directly at the camera and hold steady",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Real-time face processing
  Future<void> _processRealTimeFeedback(InputImage inputImage) async {
    if (_isProcessing || _isVerifying) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Extract face features
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      // Extract enhanced features for better verification
      _enhancedFaceFeatures = await EnhancedFaceExtractor.extractForRealTime(
        inputImage,
        screenWidth: 300,
        screenHeight: 300,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCameraActive = true;
          
          if (_enhancedFaceFeatures != null) {
            _currentQuality = _enhancedFaceFeatures!.faceQualityScore ?? 0.0;
            _isReadyForVerification = _validateForVerification(_enhancedFaceFeatures!);
            
            if (_isReadyForVerification) {
              HapticFeedback.lightImpact();
              _successController.forward();
            }
          } else {
            _currentQuality = 0.0;
            _isReadyForVerification = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentQuality = 0.0;
          _isReadyForVerification = false;
        });
      }
    }
  }

  bool _validateForVerification(EnhancedFaceFeatures features) {
    bool eyesOpen = features.areEyesOpen;
    bool goodQuality = (features.faceQualityScore ?? 0) > 0.5;
    bool reasonablyPositioned = features.isFaceCentered && features.hasGoodLighting;

    return eyesOpen && goodQuality && reasonablyPositioned;
  }

  // Face Verification
  Future<void> _verifyFace() async {
    if (_image == null || _enhancedFaceFeatures == null) return;

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

      // Get stored face image
      String? storedFaceImage = await _getStoredFaceImage();

      if (storedFaceImage == null) {
        setState(() {
          _isVerifying = false;
        });
        _showErrorDialog("No registered face found. Please register your face first.");
        return;
      }

      storedImage.bitmap = storedFaceImage;
      storedImage.imageType = regula.ImageType.PRINTED;

      // Perform verification
      bool verificationSuccess = false;

      if (!_isOfflineMode) {
        // Online verification using Regula SDK
        try {
          var request = regula.MatchFacesRequest();
          request.images = [storedImage, capturedImage];

          dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request))
              .timeout(const Duration(seconds: 8));

          var response = regula.MatchFacesResponse.fromJson(json.decode(value));

          if (response != null && response.results != null && response.results!.isNotEmpty) {
            dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
                jsonEncode(response.results), 0.75);

            var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));

            if (split!.matchedFaces.isNotEmpty) {
              double similarityScore = split.matchedFaces[0]!.similarity! * 100;
              _similarity = similarityScore.toStringAsFixed(2);
              verificationSuccess = similarityScore > 75.0;
            }
          }
        } catch (e) {
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
        await _handleSuccessfulVerification();
      } else {
        await _handleFailedVerification();
      }

    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      _showErrorDialog("Error during verification. Please try again.");
    }
  }

  Future<String?> _getStoredFaceImage() async {
    try {
      // Try secure storage first
      if (getIt.isRegistered<SecureFaceStorageService>()) {
        final secureFaceStorage = getIt<SecureFaceStorageService>();
        String? storedImage = await secureFaceStorage.getFaceImage(widget.employeeId);
        if (storedImage != null && storedImage.isNotEmpty) {
          return storedImage;
        }
      }

      // Try SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? storedImage = prefs.getString('employee_image_${widget.employeeId}') ??
          prefs.getString('secure_face_image_${widget.employeeId}');

      if (storedImage != null && storedImage.isNotEmpty) {
        if (storedImage.contains('data:image') && storedImage.contains(',')) {
          storedImage = storedImage.split(',')[1];
        }
        return storedImage;
      }

      // Try Firestore if online
      if (!_isOfflineMode) {
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
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _performOfflineVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedFeaturesJson = prefs.getString('enhanced_face_features_${widget.employeeId}');

      if (storedFeaturesJson == null || storedFeaturesJson.isEmpty) {
        return false;
      }

      Map<String, dynamic> storedFeaturesMap = json.decode(storedFeaturesJson);
      EnhancedFaceFeatures storedFeatures = EnhancedFaceFeatures.fromJson(storedFeaturesMap);

      if (_enhancedFaceFeatures != null) {
        double similarity = _enhancedFaceFeatures!.calculateSimilarityTo(storedFeatures);
        double similarityPercentage = similarity * 100;

        _similarity = similarityPercentage.toStringAsFixed(2);
        return similarityPercentage > 70.0;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Success/Failure Handlers
  Future<void> _handleSuccessfulVerification() async {
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
                  "Face verified successfully! ($_similarity%)",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Mark registration as complete
    try {
      await RegistrationCompletionService.markRegistrationComplete(widget.employeeId);
    } catch (e) {
      // Handle error silently
    }

    // Set authentication status
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('authenticated_user_id', widget.employeeId);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Handle error silently
    }

    // Navigate to dashboard
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => DashboardView(employeeId: widget.employeeId),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _handleFailedVerification() async {
    if (_verificationAttempts >= _maxVerificationAttempts) {
      _showMaxAttemptsDialog();
    } else {
      _showErrorDialog(
        "Face verification failed ($_similarity%). Please ensure good lighting and try again.\n"
        "Attempt $_verificationAttempts of $_maxVerificationAttempts"
      );
    }
  }

  // Dialogs
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Verification Failed",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_verificationAttempts < _maxVerificationAttempts)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isReadyForVerification = false;
                  _currentQuality = 0.0;
                });
                _successController.reset();
              },
              child: const Text(
                "Try Again",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaxAttemptsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Max Attempts Reached",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You have reached the maximum number of verification attempts. "
          "You can try again later or contact support for assistance.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              "Go Back",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _verificationAttempts = 0;
                _isReadyForVerification = false;
                _currentQuality = 0.0;
              });
              _successController.reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Exit Verification?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You need to complete face verification to access the app. "
          "Are you sure you want to exit?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Stay",
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Exit",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}