// lib/register_face/register_face_view.dart - iOS OFFLINE FIXED VERSION

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

class _RegisterFaceViewState extends State<RegisterFaceView> {
  // ================ CORE SERVICES ================
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
  
  // ================ STATE VARIABLES ================
  String? _image;
  FaceFeatures? _faceFeatures;
  bool _isRegistering = false;
  bool _isOfflineMode = false;
  File? _imageFile;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print("🚀 iOS RegisterFaceView initialized for employee: ${widget.employeeId}");
    _checkConnectivity();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  // ================ CONNECTIVITY CHECK ================
  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      print("📶 iOS Registration connectivity: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
      print("⚠️ Connectivity check failed, assuming offline: $e");
    }
  }

  // ================ UI BUILD ================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: const Text("Register Your Face"),
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
              height: 0.82.sh,
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(0.05.sw, 0.025.sh, 0.05.sw, 0.04.sh),
              decoration: BoxDecoration(
                color: overlayContainerClr,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0.03.sh),
                  topRight: Radius.circular(0.03.sh),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Camera section
                  _buildCameraSection(),
                  
                  const Spacer(),
                  
                  // Status display
                  _buildStatusSection(),
                  
                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================ CAMERA SECTION ================
  Widget _buildCameraSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: primaryWhite,
              size: 0.038.sh,
            ),
          ],
        ),
        SizedBox(height: 0.025.sh),
        _imageFile != null
            ? CircleAvatar(
                radius: 0.15.sh,
                backgroundColor: const Color(0xffD9D9D9),
                backgroundImage: FileImage(_imageFile!),
              )
            : CircleAvatar(
                radius: 0.15.sh,
                backgroundColor: const Color(0xffD9D9D9),
                child: Icon(
                  Icons.camera_alt,
                  size: 0.09.sh,
                  color: const Color(0xff2E2E2E),
                ),
              ),
        GestureDetector(
          onTap: _getImage,
          child: Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(top: 44, bottom: 20),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                stops: [0.4, 0.65, 1],
                colors: [
                  Color(0xffD9D9D9),
                  primaryWhite,
                  Color(0xffD9D9D9),
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Text(
          "Click here to Capture",
          style: TextStyle(
            fontSize: 14,
            color: primaryWhite.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ================ STATUS SECTION ================
  Widget _buildStatusSection() {
    if (_image != null && _faceFeatures != null) {
      double qualityScore = getFaceFeatureQuality(_faceFeatures!);
      int featuresDetected = _countDetectedLandmarks(_faceFeatures!);
      
      Color statusColor = Colors.green;
      IconData statusIcon = Icons.check_circle;
      String statusText = "✅ Face detected successfully!";
      
      if (qualityScore < 0.5) {
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = "⚠️ Face detected but quality could be improved";
      } else if (qualityScore < 0.7) {
        statusColor = Colors.blue;
        statusIcon = Icons.info;
        statusText = "ℹ️ Good face detection quality";
      }
      
      return Container(
        margin: EdgeInsets.only(bottom: 0.02.sh),
        padding: EdgeInsets.all(0.015.sh),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "📊 Quality: ${(qualityScore * 100).toStringAsFixed(1)}% • Features: $featuresDetected/10",
              style: TextStyle(
                color: statusColor.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            if (validateFaceFeatures(_faceFeatures!)) ...[
              const SizedBox(height: 4),
              Text(
                "✅ Ready for registration (${_isOfflineMode ? 'Offline Mode' : 'Online Mode'})",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    } else if (_image != null && _faceFeatures == null) {
      return Container(
        margin: EdgeInsets.only(bottom: 0.02.sh),
        padding: EdgeInsets.all(0.015.sh),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "❌ No face detected",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Please retake with better lighting and ensure your face fills the frame",
              style: TextStyle(
                color: Colors.red.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _showFaceDetectionTips,
              child: Text(
                "💡 Tap here for iOS face detection tips",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: EdgeInsets.only(bottom: 0.02.sh),
        padding: EdgeInsets.all(0.015.sh),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "📸 Take a clear photo of your face to continue",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_isOfflineMode) ...[
              const SizedBox(height: 8),
              Text(
                "⚠️ iOS Offline Mode: Face will be saved locally and synced when online",
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  // ================ ACTION BUTTONS ================
  Widget _buildActionButtons() {
    if (_isRegistering) {
      return Container(
        padding: EdgeInsets.all(0.02.sh),
        child: Column(
          children: [
            const CircularProgressIndicator(color: accentColor),
            SizedBox(height: 0.015.sh),
            Text(
              _isOfflineMode 
                  ? "Registering face locally..." 
                  : "Registering your face...",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Test Face Detection Button (for debugging)
        if (_image != null) ...[
          CustomButton(
            text: "🧪 Test iOS Face Detection",
            onTap: _testFaceDetection,
          ),
          SizedBox(height: 0.02.sh),
        ],
        
        // Main Register Button
        if (_image != null && _faceFeatures != null)
          CustomButton(
            text: _isOfflineMode 
                ? "📱 Register Offline" 
                : "🌐 Register Face",
            onTap: _registerFace,
          ),
        
        // Retake Button
        if (_image != null && _faceFeatures == null)
          CustomButton(
            text: "🔄 Retake Photo",
            onTap: () {
              setState(() {
                _image = null;
                _imageFile = null;
                _faceFeatures = null;
              });
            },
          ),
      ],
    );
  }

  // ================ IMAGE CAPTURE ================
  Future<void> _getImage() async {
    print("📸 Starting iOS enhanced image capture...");
    
    setState(() {
      _imageFile = null;
      _image = null;
      _faceFeatures = null;
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
        print("❌ No image selected");
      }
    } catch (e) {
      print("❌ Error capturing image: $e");
      CustomSnackBar.errorSnackBar("Error capturing image: $e");
    }
  }

  Future<void> _setPickedFile(XFile pickedFile) async {
    final path = pickedFile.path;
    print("📸 Processing iOS image from: $path");
    
    setState(() {
      _imageFile = File(path);
    });

    try {
      // Read image bytes
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      
      setState(() {
        _image = base64Encode(imageBytes);
      });
      
      print("📸 iOS Image encoded to base64");

      // Create InputImage for face detection
      InputImage inputImage = InputImage.fromFilePath(path);
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: accentColor,
          ),
        ),
      );
      
      // Process face detection
      await _processFaceDetection(inputImage);
      
      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      print("❌ Error processing image: $e");
      CustomSnackBar.errorSnackBar("Error processing image: $e");
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ================ FACE DETECTION ================
  Future<void> _processFaceDetection(InputImage inputImage) async {
    print("🔍 Starting iOS enhanced face detection...");
    
    try {
      // Use enhanced face detection
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (_faceFeatures != null) {
        print("✅ iOS Face detected and features extracted successfully!");
        
        // Validate features quality
        if (validateFaceFeatures(_faceFeatures!)) {
          print("✅ Face features are sufficient for registration");
        } else {
          print("⚠️ Face features detected but may need improvement");
        }
        
        // Get quality score
        double qualityScore = getFaceFeatureQuality(_faceFeatures!);
        print("📊 iOS Face quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");
        
      } else {
        print("❌ No face detected with enhanced detection");
        _showFaceDetectionTips();
      }
      
      setState(() {});
      
    } catch (e) {
      print("❌ Error in enhanced face detection: $e");
      setState(() {
        _faceFeatures = null;
      });
    }
  }

  // ================ FACE DETECTION TESTING ================
  Future<void> _testFaceDetection() async {
    if (_imageFile == null) {
      CustomSnackBar.errorSnackBar("No image to test");
      return;
    }
    
    print("🧪 Testing iOS face detection with multiple settings...");
    
    try {
      InputImage inputImage = InputImage.fromFilePath(_imageFile!.path);
      
      // Test 1: Ultra-lenient settings
      final detector1 = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.01,
          enableLandmarks: false,
        ),
      );
      
      List<Face> faces1 = await detector1.processImage(inputImage);
      print("🧪 iOS Test 1 (ultra-lenient): ${faces1.length} faces");
      
      // Test 2: Default settings
      final detector2 = FaceDetector(
        options: FaceDetectorOptions(),
      );
      List<Face> faces2 = await detector2.processImage(inputImage);
      print("🧪 iOS Test 2 (default): ${faces2.length} faces");
      
      // Test 3: Current settings
      List<Face> faces3 = await _faceDetector.processImage(inputImage);
      print("🧪 iOS Test 3 (current): ${faces3.length} faces");
      
      // Show results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "📱 iOS Face Detection Test Results",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "Ultra-lenient: ${faces1.length} faces\n"
            "Default: ${faces2.length} faces\n"
            "Current: ${faces3.length} faces\n\n"
            "${faces1.isNotEmpty || faces2.isNotEmpty || faces3.isNotEmpty ? '✅ Face detection working on iOS!' : '❌ No faces detected with any setting'}",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      
      // Cleanup
      detector1.close();
      detector2.close();
      
    } catch (e) {
      print("❌ iOS Face detection test error: $e");
      CustomSnackBar.errorSnackBar("Test failed: $e");
    }
  }

  // ================ FACE DETECTION TIPS ================
  void _showFaceDetectionTips() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                "📱 iOS Face Detection Tips",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "For better iOS face detection:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                "• Use good lighting conditions",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "• Face camera directly",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "• Remove sunglasses if possible",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "• Fill frame with your face",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "• Clean camera lens",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "• Hold device steady",
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                "✅ iOS ML Kit works great for face recognition!",
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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

  // ================ FACE REGISTRATION ================
  Future<void> _registerFace() async {
    if (_image == null || _faceFeatures == null) {
      CustomSnackBar.errorSnackBar("Please capture your face first");
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      print("🚀 Starting iOS face registration process...");
      print("📶 Registration mode: ${_isOfflineMode ? 'Offline' : 'Online'}");
      
      // Clean the image data
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      // ✅ STEP 1: Always save to local storage first (iOS priority)
      await _saveToLocalStorage(cleanedImage);
      print("✅ iOS Face data saved to local storage");

      // ✅ STEP 2: Save to cloud if online
      if (!_isOfflineMode) {
        try {
          print("🌐 Saving to Firestore...");
          await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .update({
            'image': cleanedImage,
            'faceFeatures': _faceFeatures!.toJson(),
            'faceRegistered': true,
            'registeredOn': FieldValue.serverTimestamp(),
            'platform': 'iOS',
          });
          print("✅ Face data saved to Firestore");
        } catch (e) {
          print("⚠️ Firestore save failed (offline mode activated): $e");
          // Continue with local registration
        }
      } else {
        print("📱 Offline mode: Marking for cloud sync when online");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_face_registration_${widget.employeeId}', true);
      }

      // ✅ STEP 3: Mark registration as complete
      await _markRegistrationComplete();

      setState(() {
        _isRegistering = false;
      });

      print("✅ iOS Face registration completed successfully!");
      
      // Show success message
      CustomSnackBar.successSnackBar(
        _isOfflineMode 
          ? "Face registered locally! Will sync when online." 
          : "Face registered successfully!"
      );

      // Wait a moment then navigate
      await Future.delayed(const Duration(seconds: 1));

      // Navigate to verification
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AuthenticateFaceView(
              employeeId: widget.employeeId,
              employeePin: widget.employeePin,
              isRegistrationValidation: true,
            ),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isRegistering = false;
      });
      
      print("❌ Error registering face: $e");
      CustomSnackBar.errorSnackBar("Error registering face. Please try again.");
    }
  }

  // ================ LOCAL STORAGE ================
  Future<void> _saveToLocalStorage(String cleanedImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print("💾 Saving iOS face data to SharedPreferences...");
      
      // ✅ Save face image
      await prefs.setString('employee_image_${widget.employeeId}', cleanedImage);
      print("✅ Face image saved");
      
      // ✅ Save face features
      String featuresJson = jsonEncode(_faceFeatures!.toJson());
      await prefs.setString('employee_face_features_${widget.employeeId}', featuresJson);
      print("✅ Face features saved");
      
      // ✅ Save registration flags
      await prefs.setBool('face_registered_${widget.employeeId}', true);
      await prefs.setString('face_registration_date_${widget.employeeId}', DateTime.now().toIso8601String());
      await prefs.setString('face_registration_platform_${widget.employeeId}', 'iOS');
      
      // ✅ Save employee data if available
      if (widget.employeePin.isNotEmpty) {
        Map<String, dynamic> employeeData = {
          'id': widget.employeeId,
          'pin': widget.employeePin,
          'faceRegistered': true,
          'registrationDate': DateTime.now().toIso8601String(),
          'platform': 'iOS',
        };
        await prefs.setString('user_data_${widget.employeeId}', jsonEncode(employeeData));
      }
      
      print("💾 iOS Face data saved to local storage successfully");
      
      // ✅ Debug: Verify save was successful
      String? savedImage = prefs.getString('employee_image_${widget.employeeId}');
      String? savedFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      bool savedRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;
      
      print("🔍 iOS Verification:");
      print("   - Image saved: ${savedImage != null && savedImage.isNotEmpty}");
      print("   - Features saved: ${savedFeatures != null && savedFeatures.isNotEmpty}");
      print("   - Registration flag: $savedRegistered");
      
    } catch (e) {
      print("❌ Error saving to local storage: $e");
      throw e;
    }
  }

  Future<void> _markRegistrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('registration_complete_${widget.employeeId}', true);
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('authenticated_user_id', widget.employeeId);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print("✅ iOS Registration marked as complete");
    } catch (e) {
      print("❌ Error marking registration complete: $e");
    }
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