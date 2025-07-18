// lib/register_face/register_face_view.dart - COMPLETE ENHANCED iOS IMPLEMENTATION

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

  // ================ ENHANCED DEBUG STATE ================
  List<String> _debugLogs = [];
  Map<String, dynamic> _registrationDebugData = {};
  bool _showDebugInfo = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    print("🚀 ENHANCED iOS RegisterFaceView initialized for employee: ${widget.employeeId}");
    _addDebugLog("🚀 Registration view initialized");
    _checkConnectivity();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  // ================ DEBUG LOGGING ================
  void _addDebugLog(String message) {
    String timestampedMessage = "${DateTime.now().toIso8601String().substring(11, 19)} - $message";
    setState(() {
      _debugLogs.add(timestampedMessage);
      if (_debugLogs.length > 50) _debugLogs.removeAt(0); // Keep only last 50 logs
    });
    print("REG_DEBUG: $timestampedMessage");
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

  // ================ UI BUILD ================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: const Text("🚀 Enhanced Face Registration"),
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
          // Advanced options toggle
          IconButton(
            icon: Icon(
              _showAdvancedOptions ? Icons.settings : Icons.settings_outlined,
              color: _showAdvancedOptions ? Colors.blue : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showAdvancedOptions = !_showAdvancedOptions;
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
                  // Debug panel (if enabled)
                  if (_showDebugInfo) _buildDebugPanel(),
                  
                  // Advanced options panel (if enabled)
                  if (_showAdvancedOptions) _buildAdvancedOptionsPanel(),

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
                "Enhanced Registration Debug",
                style: TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _debugLogs.clear();
                    _registrationDebugData.clear();
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

  // ================ ADVANCED OPTIONS PANEL ================
  Widget _buildAdvancedOptionsPanel() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Text(
                "Advanced Options",
                style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testMultipleFaceDetection,
                  icon: const Icon(Icons.face_retouching_natural, size: 16),
                  label: const Text("Test Detection", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportDebugData,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text("Export Debug", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
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
        Stack(
          children: [
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
            // Quality indicator overlay
            if (_imageFile != null && _faceFeatures != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getQualityColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    _getQualityIcon(),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
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
          _isRegistering ? "Processing..." : "🚀 Click here to Capture (Enhanced)",
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
      String statusText = "✅ Enhanced face detection successful!";
      
      if (qualityScore < 0.4) {
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = "❌ Face quality too low - please retake";
      } else if (qualityScore < 0.6) {
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = "⚠️ Face detected but quality could be improved";
      } else if (qualityScore < 0.8) {
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
              "📊 Enhanced Quality: ${(qualityScore * 100).toStringAsFixed(1)}% • Features: $featuresDetected/10",
              style: TextStyle(
                color: statusColor.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            if (validateFaceFeatures(_faceFeatures!)) ...[
              const SizedBox(height: 4),
              Text(
                "✅ Ready for enhanced registration (${_isOfflineMode ? 'Offline Mode' : 'Online Mode'})",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            // Show feature breakdown in debug mode
            if (_showDebugInfo) ...[
              const SizedBox(height: 8),
              Text(
                _getFeaturesBreakdown(_faceFeatures!),
                style: TextStyle(
                  color: statusColor.withOpacity(0.7),
                  fontSize: 10,
                  fontFamily: 'monospace',
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
                    "❌ Enhanced face detection failed",
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
              "Please retake with better lighting and ensure your face fills the frame properly",
              style: TextStyle(
                color: Colors.red.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _showEnhancedFaceDetectionTips,
              child: Text(
                "💡 Tap here for enhanced iOS face detection tips",
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
                    "📸 Take an enhanced photo of your face to continue",
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
                "⚠️ Enhanced iOS Offline Mode: Face will be saved locally and synced when online",
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
                  ? "🚀 Enhanced offline registration..." 
                  : "🚀 Enhanced face registration...",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_showDebugInfo && _debugLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Latest: ${_debugLogs.last}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Advanced test buttons (if advanced options enabled)
        if (_showAdvancedOptions && _image != null) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testFaceQuality,
                  icon: const Icon(Icons.science, size: 16),
                  label: const Text("Test Quality", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _analyzeImageDetails,
                  icon: const Icon(Icons.analytics, size: 16),
                  label: const Text("Analyze", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.02.sh),
        ],

        // Main Register Button
        if (_image != null && _faceFeatures != null)
          CustomButton(
            text: _isOfflineMode 
                ? "🚀 Enhanced Offline Register" 
                : "🚀 Enhanced Face Register",
            onTap: _registerFace,
          ),
        
        // Retake Button
        if (_image != null && _faceFeatures == null)
          CustomButton(
            text: "🔄 Retake Photo (Enhanced)",
            onTap: () {
              setState(() {
                _image = null;
                _imageFile = null;
                _faceFeatures = null;
              });
              _addDebugLog("🔄 Photo reset for retake");
            },
          ),
      ],
    );
  }

  // ================ HELPER METHODS FOR UI ================
  Color _getQualityColor() {
    if (_faceFeatures == null) return Colors.red;
    double quality = getFaceFeatureQuality(_faceFeatures!);
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.blue;
    if (quality >= 0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getQualityIcon() {
    if (_faceFeatures == null) return Icons.error;
    double quality = getFaceFeatureQuality(_faceFeatures!);
    if (quality >= 0.8) return Icons.verified;
    if (quality >= 0.6) return Icons.check_circle;
    if (quality >= 0.4) return Icons.warning;
    return Icons.error;
  }

  String _getFeaturesBreakdown(FaceFeatures features) {
    List<String> detected = [];
    List<String> missing = [];
    
    if (features.leftEye != null) detected.add('LE'); else missing.add('LE');
    if (features.rightEye != null) detected.add('RE'); else missing.add('RE');
    if (features.noseBase != null) detected.add('N'); else missing.add('N');
    if (features.leftMouth != null) detected.add('LM'); else missing.add('LM');
    if (features.rightMouth != null) detected.add('RM'); else missing.add('RM');
    
    return "Detected: [${detected.join(',')}] Missing: [${missing.join(',')}]";
  }

  // ================ IMAGE CAPTURE ================
  Future<void> _getImage() async {
    _addDebugLog("📸 Starting enhanced iOS image capture...");
    
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
        _addDebugLog("❌ No image selected");
      }
    } catch (e) {
      _addDebugLog("❌ Error capturing image: $e");
      CustomSnackBar.errorSnackBar("Error capturing image: $e");
    }
  }

  Future<void> _setPickedFile(XFile pickedFile) async {
    final path = pickedFile.path;
    _addDebugLog("📸 Processing enhanced iOS image from: $path");
    
    setState(() {
      _imageFile = File(path);
    });

    try {
      // Read image bytes
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      
      setState(() {
        _image = base64Encode(imageBytes);
      });
      
      _addDebugLog("📸 Image encoded to base64 (${_image!.length} chars)");

      // Create InputImage for face detection
      InputImage inputImage = InputImage.fromFilePath(path);
      
      // Show loading dialog with enhanced info
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              const Text(
                "🚀 Enhanced Face Detection",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Processing with advanced iOS algorithms...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      
      // Process face detection
      await _processFaceDetection(inputImage);
      
      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      _addDebugLog("❌ Error processing image: $e");
      CustomSnackBar.errorSnackBar("Error processing image: $e");
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ================ ENHANCED FACE DETECTION ================
  Future<void> _processFaceDetection(InputImage inputImage) async {
    _addDebugLog("🔍 Starting enhanced iOS face detection...");
    
    try {
      // Use enhanced face detection
      _faceFeatures = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (_faceFeatures != null) {
        _addDebugLog("✅ Enhanced iOS Face detected and features extracted successfully!");
        
        // Validate features quality
        if (validateFaceFeatures(_faceFeatures!)) {
          _addDebugLog("✅ Face features are sufficient for enhanced registration");
        } else {
          _addDebugLog("⚠️ Face features detected but may need improvement");
        }
        
        // Get quality score
        double qualityScore = getFaceFeatureQuality(_faceFeatures!);
        _addDebugLog("📊 Enhanced iOS Face quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");
        
        // Store debug data
        _registrationDebugData['lastFaceDetection'] = {
          'successful': true,
          'qualityScore': qualityScore,
          'featuresCount': _countDetectedLandmarks(_faceFeatures!),
          'isValid': validateFaceFeatures(_faceFeatures!),
          'timestamp': DateTime.now().toIso8601String(),
          'method': 'enhanced_ios',
        };
        
      } else {
        _addDebugLog("❌ No face detected with enhanced detection");
        _registrationDebugData['lastFaceDetection'] = {
          'successful': false,
          'timestamp': DateTime.now().toIso8601String(),
          'method': 'enhanced_ios',
        };
        _showEnhancedFaceDetectionTips();
      }
      
      setState(() {});
      
    } catch (e) {
      _addDebugLog("❌ Error in enhanced face detection: $e");
      setState(() {
        _faceFeatures = null;
      });
    }
  }

  // ================ ENHANCED FACE REGISTRATION ================
  Future<void> _registerFace() async {
    if (_image == null || _faceFeatures == null) {
      CustomSnackBar.errorSnackBar("Please capture your face first");
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      _addDebugLog("🚀 Starting ENHANCED iOS face registration process...");
      _addDebugLog("📶 Registration mode: ${_isOfflineMode ? 'Enhanced Offline' : 'Enhanced Online'}");
      
      // ✅ STEP 1: Validate face quality before registration
      if (!_validateFaceQuality()) {
        setState(() {
          _isRegistering = false;
        });
        return;
      }
      
      // Clean the image data
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      // ✅ STEP 2: Enhanced local storage with multiple backup methods
      await _enhancedLocalStorage(cleanedImage);
      _addDebugLog("✅ Enhanced local storage completed");

      // ✅ STEP 3: Save to cloud if online with retry mechanism
      if (!_isOfflineMode) {
        bool cloudSuccess = await _saveToCloudWithRetry(cleanedImage);
        if (!cloudSuccess) {
          _addDebugLog("⚠️ Cloud save failed, but local save succeeded");
        }
      } else {
        _addDebugLog("📱 Enhanced offline mode: Marking for cloud sync when online");
        await _markForCloudSync();
      }

      // ✅ STEP 4: Validate the saved data
      bool validationPassed = await _validateSavedData();
      if (!validationPassed) {
        throw Exception("Enhanced data validation failed after registration");
      }

      // ✅ STEP 5: Mark registration as complete
      await _markRegistrationComplete();

      setState(() {
        _isRegistering = false;
      });

      _addDebugLog("✅ ENHANCED iOS Face registration completed successfully!");
      
      // Show enhanced success message
      CustomSnackBar.successSnackBar(
        _isOfflineMode 
          ? "🚀 Enhanced face registered locally! Will sync when online." 
          : "🚀 Enhanced face registered successfully!"
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
      
      _addDebugLog("❌ Error in enhanced registration: $e");
      CustomSnackBar.errorSnackBar("Enhanced registration failed. Please try again.");
    }
  }

  // ✅ ENHANCED: Validate face quality before registration
  bool _validateFaceQuality() {
    if (_faceFeatures == null) {
      CustomSnackBar.errorSnackBar("No face features detected");
      _addDebugLog("❌ Validation failed: No face features");
      return false;
    }

    // Count essential features
    int essentialCount = 0;
    if (_faceFeatures!.leftEye != null) essentialCount++;
    if (_faceFeatures!.rightEye != null) essentialCount++;
    if (_faceFeatures!.noseBase != null) essentialCount++;

    if (essentialCount < 3) {
      CustomSnackBar.errorSnackBar("Face quality too low. Please retake with better lighting.");
      _addDebugLog("❌ Validation failed: Only $essentialCount/3 essential features");
      return false;
    }

    double qualityScore = getFaceFeatureQuality(_faceFeatures!);
    _addDebugLog("📊 Face quality validation score: ${(qualityScore * 100).toStringAsFixed(1)}%");

    if (qualityScore < 0.4) {
      CustomSnackBar.errorSnackBar("Face quality too low (${(qualityScore * 100).toStringAsFixed(1)}%). Please retake.");
      _addDebugLog("❌ Validation failed: Quality score too low");
      return false;
    }

    _addDebugLog("✅ Face quality validation passed");
    return true;
  }

  // ✅ ENHANCED: Local storage with multiple backup methods
  Future<void> _enhancedLocalStorage(String cleanedImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _addDebugLog("💾 ENHANCED: Saving iOS face data with multiple backup methods...");
      
      // ✅ Primary storage locations with enhanced keys
      await prefs.setString('employee_image_${widget.employeeId}', cleanedImage);
      await prefs.setString('secure_face_image_${widget.employeeId}', cleanedImage);
      await prefs.setString('enhanced_face_image_${widget.employeeId}', cleanedImage);
      
      // ✅ Face features with enhanced storage
      String featuresJson = jsonEncode(_faceFeatures!.toJson());
      await prefs.setString('employee_face_features_${widget.employeeId}', featuresJson);
      await prefs.setString('secure_face_features_${widget.employeeId}', featuresJson);
      await prefs.setString('secure_enhanced_face_features_${widget.employeeId}', featuresJson);
      await prefs.setString('enhanced_face_features_backup_${widget.employeeId}', featuresJson);
      
      // ✅ Registration flags with enhanced timestamps
      DateTime now = DateTime.now();
      await prefs.setBool('face_registered_${widget.employeeId}', true);
      await prefs.setBool('enhanced_face_registered_${widget.employeeId}', true);
      await prefs.setBool('face_registration_complete_${widget.employeeId}', true);
      await prefs.setString('face_registration_date_${widget.employeeId}', now.toIso8601String());
      await prefs.setString('face_registration_platform_${widget.employeeId}', 'iOS_Enhanced');
      await prefs.setInt('face_registration_timestamp_${widget.employeeId}', now.millisecondsSinceEpoch);
      
      // ✅ Enhanced employee data with comprehensive face info
      Map<String, dynamic> enhancedEmployeeData = {
        'id': widget.employeeId,
        'pin': widget.employeePin,
        'faceRegistered': true,
        'enhancedFaceRegistered': true,
        'registrationDate': now.toIso8601String(),
        'platform': 'iOS_Enhanced',
        'faceFeatures': _faceFeatures!.toJson(),
        'image': cleanedImage,
        'faceQualityScore': getFaceFeatureQuality(_faceFeatures!),
        'registrationMethod': 'enhanced_ios_v2',
        'featuresCount': _countDetectedLandmarks(_faceFeatures!),
        'debugLogs': _debugLogs,
        'registrationDebugData': _registrationDebugData,
      };
      
      await prefs.setString('user_data_${widget.employeeId}', jsonEncode(enhancedEmployeeData));
      await prefs.setString('enhanced_user_data_${widget.employeeId}', jsonEncode(enhancedEmployeeData));
      await prefs.setString('secure_user_data_${widget.employeeId}', jsonEncode(enhancedEmployeeData));
      
      _addDebugLog("💾 Enhanced local storage completed successfully");
      
      // ✅ Debug: Verify all saves
      await _debugVerifyLocalStorage();
      
    } catch (e) {
      _addDebugLog("❌ Error in enhanced local storage: $e");
      throw e;
    }
  }

  // ✅ ENHANCED: Save to cloud with retry mechanism
  Future<bool> _saveToCloudWithRetry(String cleanedImage) async {
    _addDebugLog("🌐 Attempting enhanced cloud save with retry...");
    
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        _addDebugLog("🌐 Enhanced cloud save attempt $attempt/3...");
        
        Map<String, dynamic> enhancedCloudData = {
          'image': cleanedImage,
          'faceFeatures': _faceFeatures!.toJson(),
          'enhancedFaceFeatures': _faceFeatures!.toJson(),
          'faceRegistered': true,
          'enhancedFaceRegistered': true,
          'registeredOn': FieldValue.serverTimestamp(),
          'platform': 'iOS_Enhanced',
          'registrationMethod': 'enhanced_ios_v2',
          'faceQualityScore': getFaceFeatureQuality(_faceFeatures!),
          'featuresCount': _countDetectedLandmarks(_faceFeatures!),
          'devicePlatform': 'iOS',
          'lastUpdated': FieldValue.serverTimestamp(),
          'enhancedVersion': '2.0',
        };
        
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(widget.employeeId)
            .update(enhancedCloudData);
        
        _addDebugLog("✅ Enhanced cloud save successful on attempt $attempt");
        return true;
        
      } catch (e) {
        _addDebugLog("❌ Enhanced cloud save attempt $attempt failed: $e");
        
        if (attempt < 3) {
          _addDebugLog("🔄 Retrying in ${attempt * 2} seconds...");
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    
    _addDebugLog("❌ All enhanced cloud save attempts failed");
    return false;
  }

  // ✅ ENHANCED: Mark for cloud sync when in offline mode
  Future<void> _markForCloudSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_face_registration_${widget.employeeId}', true);
      await prefs.setBool('pending_enhanced_face_registration_${widget.employeeId}', true);
      await prefs.setBool('pending_enhanced_v2_registration_${widget.employeeId}', true);
      await prefs.setString('pending_sync_timestamp_${widget.employeeId}', DateTime.now().toIso8601String());
      
      // Store enhanced sync data
      Map<String, dynamic> enhancedSyncData = {
        'employeeId': widget.employeeId,
        'image': _image,
        'faceFeatures': _faceFeatures!.toJson(),
        'platform': 'iOS_Enhanced',
        'registrationMethod': 'enhanced_ios_v2_offline',
        'pendingSince': DateTime.now().toIso8601String(),
        'qualityScore': getFaceFeatureQuality(_faceFeatures!),
        'featuresCount': _countDetectedLandmarks(_faceFeatures!),
        'debugLogs': _debugLogs,
      };
      
      await prefs.setString('pending_sync_data_${widget.employeeId}', jsonEncode(enhancedSyncData));
      await prefs.setString('pending_enhanced_sync_data_${widget.employeeId}', jsonEncode(enhancedSyncData));
      
      _addDebugLog("📱 Enhanced data marked for cloud sync when online");
      
    } catch (e) {
      _addDebugLog("❌ Error marking for enhanced cloud sync: $e");
    }
  }

  // ✅ ENHANCED: Validate saved data
  Future<bool> _validateSavedData() async {
    try {
      _addDebugLog("🔍 Validating enhanced saved registration data...");
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check enhanced image data
      String? primaryImage = prefs.getString('employee_image_${widget.employeeId}');
      String? secureImage = prefs.getString('secure_face_image_${widget.employeeId}');
      String? enhancedImage = prefs.getString('enhanced_face_image_${widget.employeeId}');
      
      if (primaryImage == null && secureImage == null && enhancedImage == null) {
        _addDebugLog("❌ Validation failed: No saved images found");
        return false;
      }
      
      // Check enhanced face features
      String? primaryFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      String? secureFeatures = prefs.getString('secure_face_features_${widget.employeeId}');
      String? enhancedFeatures = prefs.getString('secure_enhanced_face_features_${widget.employeeId}');
      
      if (primaryFeatures == null && secureFeatures == null && enhancedFeatures == null) {
        _addDebugLog("❌ Validation failed: No saved features found");
        return false;
      }
      
      // Try to parse features
      String? featuresJson = enhancedFeatures ?? secureFeatures ?? primaryFeatures;
      if (featuresJson != null) {
        try {
          Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
          FaceFeatures parsedFeatures = FaceFeatures.fromJson(featuresMap);
          
          // Validate essential features
          if (parsedFeatures.leftEye == null || parsedFeatures.rightEye == null || parsedFeatures.noseBase == null) {
            _addDebugLog("❌ Validation failed: Missing essential features in parsed data");
            return false;
          }
          
          _addDebugLog("✅ Successfully parsed and validated face features");
          
        } catch (e) {
          _addDebugLog("❌ Validation failed: Cannot parse features - $e");
          return false;
        }
      }
      
      // Check enhanced registration flags
      bool isRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;
      bool isEnhancedRegistered = prefs.getBool('enhanced_face_registered_${widget.employeeId}') ?? false;
      
      if (!isRegistered && !isEnhancedRegistered) {
        _addDebugLog("❌ Validation failed: No registration flags set");
        return false;
      }
      
      _addDebugLog("✅ Enhanced data validation passed");
      _addDebugLog("   - Images available: ${[primaryImage != null, secureImage != null, enhancedImage != null].where((x) => x).length}/3");
      _addDebugLog("   - Features available: ${[primaryFeatures != null, secureFeatures != null, enhancedFeatures != null].where((x) => x).length}/3");
      _addDebugLog("   - Registration flags: Standard=$isRegistered, Enhanced=$isEnhancedRegistered");
      
      return true;
      
    } catch (e) {
      _addDebugLog("❌ Error during enhanced validation: $e");
      return false;
    }
  }

  // ✅ ENHANCED: Debug verification of local storage
  Future<void> _debugVerifyLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _addDebugLog("🔍 Enhanced DEBUG: Verifying local storage...");
      
      // Check all enhanced storage locations
      Map<String, bool> enhancedStorageCheck = {
        'employee_image': prefs.getString('employee_image_${widget.employeeId}') != null,
        'secure_face_image': prefs.getString('secure_face_image_${widget.employeeId}') != null,
        'enhanced_face_image': prefs.getString('enhanced_face_image_${widget.employeeId}') != null,
        'employee_face_features': prefs.getString('employee_face_features_${widget.employeeId}') != null,
        'secure_face_features': prefs.getString('secure_face_features_${widget.employeeId}') != null,
        'secure_enhanced_face_features': prefs.getString('secure_enhanced_face_features_${widget.employeeId}') != null,
        'enhanced_face_features_backup': prefs.getString('enhanced_face_features_backup_${widget.employeeId}') != null,
        'face_registered': prefs.getBool('face_registered_${widget.employeeId}') ?? false,
        'enhanced_face_registered': prefs.getBool('enhanced_face_registered_${widget.employeeId}') ?? false,
        'face_registration_complete': prefs.getBool('face_registration_complete_${widget.employeeId}') ?? false,
        'user_data': prefs.getString('user_data_${widget.employeeId}') != null,
        'enhanced_user_data': prefs.getString('enhanced_user_data_${widget.employeeId}') != null,
        'secure_user_data': prefs.getString('secure_user_data_${widget.employeeId}') != null,
      };
      
      _addDebugLog("📊 Enhanced storage verification results:");
      enhancedStorageCheck.forEach((key, value) {
        _addDebugLog("   ${value ? '✅' : '❌'} $key");
      });
      
      // Count successful saves
      int successCount = enhancedStorageCheck.values.where((v) => v).length;
      _addDebugLog("📈 Enhanced storage success rate: $successCount/${enhancedStorageCheck.length}");
      
      if (successCount < 8) {
        _addDebugLog("⚠️ WARNING: Some enhanced storage operations may have failed");
      } else {
        _addDebugLog("🎉 Enhanced storage verification successful!");
      }
      
    } catch (e) {
      _addDebugLog("❌ Error in enhanced debug verification: $e");
    }
  }

  Future<void> _markRegistrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('registration_complete_${widget.employeeId}', true);
      await prefs.setBool('enhanced_registration_complete_${widget.employeeId}', true);
      await prefs.setBool('is_authenticated', true);
      await prefs.setString('authenticated_user_id', widget.employeeId);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      _addDebugLog("✅ Enhanced iOS Registration marked as complete");
    } catch (e) {
      _addDebugLog("❌ Error marking enhanced registration complete: $e");
    }
  }

  // ================ ADVANCED TEST METHODS ================
  Future<void> _testMultipleFaceDetection() async {
    if (_imageFile == null) {
      CustomSnackBar.errorSnackBar("No image to test");
      return;
    }
    
    _addDebugLog("🧪 Testing multiple iOS face detection methods...");
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 16),
            const Text(
              "🧪 Testing Detection Methods",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Running comprehensive iOS tests...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );

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
      _addDebugLog("🧪 Test 1 (ultra-lenient): ${faces1.length} faces");
      
      // Test 2: Default settings
      final detector2 = FaceDetector(options: FaceDetectorOptions());
      List<Face> faces2 = await detector2.processImage(inputImage);
      _addDebugLog("🧪 Test 2 (default): ${faces2.length} faces");
      
      // Test 3: Enhanced settings
      final detector3 = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableClassification: true,
        ),
      );
      List<Face> faces3 = await detector3.processImage(inputImage);
      _addDebugLog("🧪 Test 3 (enhanced): ${faces3.length} faces");
      
      // Cleanup
      detector1.close();
      detector2.close();
      detector3.close();
      
      Navigator.pop(context);
      
      // Show results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          title: const Text("🧪 Detection Test Results", style: TextStyle(color: Colors.white)),
          content: Text(
            "Ultra-lenient: ${faces1.length} faces\n"
            "Default: ${faces2.length} faces\n"
            "Enhanced: ${faces3.length} faces\n\n"
            "${faces1.isNotEmpty || faces2.isNotEmpty || faces3.isNotEmpty ? '✅ Face detection working on iOS!' : '❌ No faces detected with any method'}",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
    } catch (e) {
      Navigator.pop(context);
      _addDebugLog("❌ Test failed: $e");
      CustomSnackBar.errorSnackBar("Test failed: $e");
    }
  }

  Future<void> _testFaceQuality() async {
    if (_faceFeatures == null) {
      CustomSnackBar.errorSnackBar("No face features to test");
      return;
    }
    
    _addDebugLog("🧪 Testing face quality metrics...");
    
    double qualityScore = getFaceFeatureQuality(_faceFeatures!);
    int featuresCount = _countDetectedLandmarks(_faceFeatures!);
    bool isValid = validateFaceFeatures(_faceFeatures!);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        title: const Text("🧪 Face Quality Report", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Quality Score: ${(qualityScore * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white)),
            Text("Features Count: $featuresCount/10", style: const TextStyle(color: Colors.white)),
            Text("Valid for Registration: ${isValid ? 'Yes' : 'No'}", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            Text("Feature Breakdown:", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
            Text(_getFeaturesBreakdown(_faceFeatures!), style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeImageDetails() async {
    if (_imageFile == null) {
      CustomSnackBar.errorSnackBar("No image to analyze");
      return;
    }
    
    _addDebugLog("🧪 Analyzing image details...");
    
    try {
      Uint8List imageBytes = await _imageFile!.readAsBytes();
      double imageSizeKB = imageBytes.length / 1024;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          title: const Text("🧪 Image Analysis", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("File Size: ${imageSizeKB.toStringAsFixed(1)} KB", style: const TextStyle(color: Colors.white)),
              Text("Image Bytes: ${imageBytes.length}", style: const TextStyle(color: Colors.white)),
              Text("Base64 Size: ${_image?.length ?? 0} chars", style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                imageSizeKB < 10 ? "⚠️ Image might be too small" :
                imageSizeKB > 5000 ? "⚠️ Image might be too large" :
                "✅ Good image size",
                style: TextStyle(color: imageSizeKB < 10 || imageSizeKB > 5000 ? Colors.orange : Colors.green),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      _addDebugLog("❌ Analysis failed: $e");
      CustomSnackBar.errorSnackBar("Analysis failed: $e");
    }
  }

  void _exportDebugData() {
    Map<String, dynamic> exportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'employeeId': widget.employeeId,
      'debugLogs': _debugLogs,
      'registrationDebugData': _registrationDebugData,
      'isOfflineMode': _isOfflineMode,
      'hasImage': _image != null,
      'hasFaceFeatures': _faceFeatures != null,
      'imageSize': _image?.length ?? 0,
      'qualityScore': _faceFeatures != null ? getFaceFeatureQuality(_faceFeatures!) : null,
      'featuresCount': _faceFeatures != null ? _countDetectedLandmarks(_faceFeatures!) : null,
    };
    
    String exportJson = jsonEncode(exportData);
    Clipboard.setData(ClipboardData(text: exportJson));
    _addDebugLog("📋 Debug data exported to clipboard");
    CustomSnackBar.successSnackBar("Debug data copied to clipboard");
  }

  // ================ ENHANCED FACE DETECTION TIPS ================
  void _showEnhancedFaceDetectionTips() {
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
                "🚀 Enhanced iOS Face Detection Tips",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "For optimal enhanced iOS face detection:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text("• Use excellent lighting conditions", style: TextStyle(color: Colors.white)),
              Text("• Face camera directly (avoid angles)", style: TextStyle(color: Colors.white)),
              Text("• Remove sunglasses, masks, hats", style: TextStyle(color: Colors.white)),
              Text("• Fill 60-80% of frame with your face", style: TextStyle(color: Colors.white)),
              Text("• Clean camera lens thoroughly", style: TextStyle(color: Colors.white)),
              Text("• Hold device steady during capture", style: TextStyle(color: Colors.white)),
              Text("• Ensure good contrast with background", style: TextStyle(color: Colors.white)),
              Text("• Avoid shadows on face", style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text(
                "✅ Enhanced iOS ML Kit provides superior face recognition!",
                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
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