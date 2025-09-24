// lib/register_face/register_face_view.dart - Clean Production Ready

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:face_auth/common/utils/extract_face_feature.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:face_auth/common/utils/extensions/size_extension.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class RegisterFaceView extends StatefulWidget {
  final String employeeId;
  final String employeePin;

  const RegisterFaceView({
    Key? key,
    required this.employeeId,
    required this.employeePin,
  }) : super(key: key);

  @override
  State<RegisterFaceView> createState() => _RegisterFaceViewState();
}

class _RegisterFaceViewState extends State<RegisterFaceView>
    with TickerProviderStateMixin {
  
  // Core Services
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
      enableContours: false,
    ),
  );

  // State Variables
  String? _image;
  FaceFeatures? _faceFeatures;
  bool _isRegistering = false;
  bool _isOfflineMode = false;
  File? _imageFile;
  bool _isProcessing = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;
  late Animation<Color?> _colorAnimation;

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

    _colorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.3),
      end: Colors.green.withOpacity(0.8),
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _faceDetector.close();
    _pulseController.dispose();
    _successController.dispose();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Face Registration",
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
    
    if (_isProcessing) {
      message = "Analyzing your face...";
      icon = Icons.face_retouching_natural;
      color = Colors.blue;
    } else if (_faceFeatures != null && _validateFaceQuality()) {
      message = "Perfect! Your face is ready for registration";
      icon = Icons.verified;
      color = Colors.green;
    } else if (_imageFile != null) {
      message = "Face not detected clearly. Please try again";
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      message = "Position your face in the circle below";
      icon = Icons.face;
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
      child: Row(
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
    );
  }

  Widget _buildCameraSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Camera Circle with Animation
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _successController,
              _colorAnimation,
            ]),
            builder: (context, child) {
              double scale = 1.0;
              Color borderColor = Colors.white.withOpacity(0.3);
              
              if (_faceFeatures != null && _validateFaceQuality()) {
                scale = _successAnimation.value;
                borderColor = Colors.green;
                if (!_successController.isAnimating && !_successController.isCompleted) {
                  _successController.forward();
                }
              } else if (_imageFile == null) {
                scale = _pulseAnimation.value;
                _pulseController.repeat(reverse: true);
              } else {
                _pulseController.stop();
              }
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: 4,
                    ),
                    boxShadow: [
                      if (_faceFeatures != null && _validateFaceQuality())
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 15,
                        ),
                    ],
                  ),
                  child: ClipOval(
                    child: _imageFile != null
                        ? Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.face,
                                size: 80,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Capture Button with Improved UI
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isProcessing ? null : _getImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: _isProcessing
                ? [Colors.grey, Colors.grey.withOpacity(0.5)]
                : [
                    const Color(0xFF4CAF50),
                    const Color(0xFF2E7D4B),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: _isProcessing
                  ? Colors.grey.withOpacity(0.3)
                  : const Color(0xFF4CAF50).withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isProcessing
            ? const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              )
            : const Center(
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 40,
                ),
              ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isRegistering) {
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
              "Registering your face...",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_faceFeatures != null && _validateFaceQuality()) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _registerFace,
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
                Icon(Icons.verified, size: 24),
                SizedBox(width: 12),
                Text(
                  "Register Face",
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

    if (_imageFile != null && _faceFeatures == null && !_isProcessing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _retakePhoto,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 24),
                SizedBox(width: 12),
                Text(
                  "Try Again",
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
      child: const Text(
        "Tap the camera button above to capture your face",
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Image Capture
  Future<void> _getImage() async {
    setState(() {
      _imageFile = null;
      _image = null;
      _faceFeatures = null;
      _isProcessing = true;
    });

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog("Error capturing image. Please try again.");
    }
  }

  Future<void> _setPickedFile(XFile pickedFile) async {
    try {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      // Read image bytes
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      setState(() {
        _image = base64Encode(imageBytes);
      });

      // Create InputImage for face detection
      InputImage inputImage = InputImage.fromFilePath(pickedFile.path);

      // Process face detection
      await _processFaceDetection(inputImage);

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog("Error processing image. Please try again.");
    }
  }

  Future<void> _processFaceDetection(InputImage inputImage) async {
    try {
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);

      setState(() {
        _isProcessing = false;
      });

      if (_faceFeatures != null && _validateFaceQuality()) {
        HapticFeedback.lightImpact();
        _successController.forward();
      }

    } catch (e) {
      setState(() {
        _faceFeatures = null;
        _isProcessing = false;
      });
    }
  }

  bool _validateFaceQuality() {
    if (_faceFeatures == null) return false;

    int essentialCount = 0;
    if (_faceFeatures!.leftEye != null) essentialCount++;
    if (_faceFeatures!.rightEye != null) essentialCount++;
    if (_faceFeatures!.noseBase != null) essentialCount++;

    double qualityScore = getFaceFeatureQuality(_faceFeatures!);
    return essentialCount >= 3 && qualityScore >= 0.4;
  }

  void _retakePhoto() {
    setState(() {
      _imageFile = null;
      _image = null;
      _faceFeatures = null;
    });
    _successController.reset();
  }

  // Face Registration
  Future<void> _registerFace() async {
    if (_image == null || _faceFeatures == null) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      // Clean the image data
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      // Save locally
      await _saveLocalData(cleanedImage);

      // Save to cloud if online
      if (!_isOfflineMode) {
        await _saveToCloud(cleanedImage);
      }

      setState(() {
        _isRegistering = false;
      });

      // Show success message
      _showSuccessDialog();

    } catch (e) {
      setState(() {
        _isRegistering = false;
      });
      _showErrorDialog("Registration failed. Please try again.");
    }
  }

  Future<void> _saveLocalData(String cleanedImage) async {
    final prefs = await SharedPreferences.getInstance();

    // Save image
    await prefs.setString('employee_image_${widget.employeeId}', cleanedImage);
    await prefs.setString('secure_face_image_${widget.employeeId}', cleanedImage);

    // Save face features
    String featuresJson = jsonEncode(_faceFeatures!.toJson());
    await prefs.setString('employee_face_features_${widget.employeeId}', featuresJson);
    await prefs.setString('secure_face_features_${widget.employeeId}', featuresJson);

    // Set registration flags
    DateTime now = DateTime.now();
    await prefs.setBool('face_registered_${widget.employeeId}', true);
    await prefs.setString('face_registration_date_${widget.employeeId}', now.toIso8601String());

    // Save complete user data
    Map<String, dynamic> employeeData = {
      'id': widget.employeeId,
      'pin': widget.employeePin,
      'faceRegistered': true,
      'registrationDate': now.toIso8601String(),
      'faceFeatures': _faceFeatures!.toJson(),
      'image': cleanedImage,
      'faceQualityScore': getFaceFeatureQuality(_faceFeatures!),
    };

    await prefs.setString('user_data_${widget.employeeId}', jsonEncode(employeeData));
  }

  Future<void> _saveToCloud(String cleanedImage) async {
    try {
      Map<String, dynamic> cloudData = {
        'image': cleanedImage,
        'faceFeatures': _faceFeatures!.toJson(),
        'faceRegistered': true,
        'registeredOn': FieldValue.serverTimestamp(),
        'faceQualityScore': getFaceFeatureQuality(_faceFeatures!),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .update(cloudData);

    } catch (e) {
      // Cloud save failed but local save succeeded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_face_registration_${widget.employeeId}', true);
    }
  }

  // Dialogs
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              "Face Registered Successfully!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isOfflineMode
                  ? "Your face has been registered locally and will sync when online."
                  : "You can now use face authentication to access the app.",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AuthenticateFaceView(
                        employeeId: widget.employeeId,
                        employeePin: widget.employeePin,
                        isRegistrationValidation: true,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Error",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}