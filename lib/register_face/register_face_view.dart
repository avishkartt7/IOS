import 'dart:convert';
import 'dart:typed_data';

import 'package:face_auth/common/utils/extract_face_feature.dart';
import 'package:face_auth/common/views/camera_view.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  String? _image;
  FaceFeatures? _faceFeatures;
  bool _isRegistering = false;
  bool _canRegister = false;
  String _feedback = "Take a clear photo of your face";
  Color _feedbackColor = Colors.blue;

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: const Text("Register Your Face"),
        elevation: 0,
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
                  // Feedback text
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _feedbackColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _feedbackColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getFeedbackIcon(),
                          color: _feedbackColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _feedback,
                            style: TextStyle(
                              color: _feedbackColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Camera view
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _canRegister 
                              ? Colors.green 
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CameraView(
                          onImage: (image) {
                            _setImage(image);
                          },
                          onInputImage: (inputImage) async {
                            await _processFaceDetection(inputImage);
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register button
                  if (_canRegister && !_isRegistering)
                    CustomButton(
                      text: "Register My Face",
                      onTap: _registerFace,
                    ),

                  if (_isRegistering)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: accentColor),
                          SizedBox(width: 16),
                          Text(
                            "Registering your face...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (!_canRegister && !_isRegistering)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        "Position your face clearly in the camera",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
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
    );
  }

  IconData _getFeedbackIcon() {
    if (_feedbackColor == Colors.green) return Icons.check_circle;
    if (_feedbackColor == Colors.orange) return Icons.warning;
    return Icons.info;
  }

  Future<void> _setImage(Uint8List imageToAuthenticate) async {
    _image = base64Encode(imageToAuthenticate);
    debugPrint("📸 Image captured and encoded");
  }

  Future<void> _processFaceDetection(InputImage inputImage) async {
    try {
      FaceFeatures? features = await extractFaceFeatures(inputImage, _faceDetector);
      
      if (features != null) {
        setState(() {
          _faceFeatures = features;
          _canRegister = true;
          _feedback = "Perfect! Face detected clearly";
          _feedbackColor = Colors.green;
        });
      } else {
        setState(() {
          _canRegister = false;
          _feedback = "No face detected. Position your face in the camera";
          _feedbackColor = Colors.orange;
        });
      }
    } catch (e) {
      debugPrint("❌ Error processing face detection: $e");
      setState(() {
        _canRegister = false;
        _feedback = "Error processing image. Please try again";
        _feedbackColor = Colors.red;
      });
    }
  }

  Future<void> _registerFace() async {
    if (_image == null || _faceFeatures == null) {
      CustomSnackBar.errorSnackBar("Please capture your face first");
      return;
    }

    setState(() {
      _isRegistering = true;
      _feedback = "Registering your face...";
      _feedbackColor = Colors.blue;
    });

    try {
      // Clean the image data
      String cleanedImage = _image!;
      if (cleanedImage.contains('data:image') && cleanedImage.contains(',')) {
        cleanedImage = cleanedImage.split(',')[1];
      }

      // Create user model
      UserModel user = UserModel(
        id: widget.employeeId,
        name: '', // Will be filled from profile
        image: cleanedImage,
        registeredOn: DateTime.now().millisecondsSinceEpoch,
        faceFeatures: _faceFeatures,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .update({
        'image': cleanedImage,
        'faceFeatures': _faceFeatures!.toJson(),
        'faceRegistered': true,
        'registeredOn': FieldValue.serverTimestamp(),
      });

      // Save to local storage
      await _saveToLocalStorage(user);

      // Mark registration as complete
      await _markRegistrationComplete();

      setState(() {
        _isRegistering = false;
        _feedback = "Face registered successfully!";
        _feedbackColor = Colors.green;
      });

      // Show success message
      CustomSnackBar.successSnackBar("Face registered successfully!");

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
        _feedback = "Registration failed. Please try again";
        _feedbackColor = Colors.red;
      });
      
      debugPrint("❌ Error registering face: $e");
      CustomSnackBar.errorSnackBar("Error registering face: $e");
    }
  }

  Future<void> _saveToLocalStorage(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save user data
      await prefs.setString('user_${widget.employeeId}', 
          jsonEncode(user.toJson()));
      
      // Save face image separately
      await prefs.setString('employee_image_${widget.employeeId}', 
          user.image!);
      
      // Save face features
      await prefs.setString('employee_face_features_${widget.employeeId}', 
          jsonEncode(user.faceFeatures!.toJson()));
      
      await prefs.setBool('face_registered_${widget.employeeId}', true);
      
      debugPrint("💾 Face data saved to local storage");
    } catch (e) {
      debugPrint("❌ Error saving to local storage: $e");
    }
  }

  Future<void> _markRegistrationComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('registration_complete_${widget.employeeId}', true);
      await prefs.setBool('is_authenticated', true);
      
      debugPrint("✅ Registration marked as complete");
    } catch (e) {
      debugPrint("❌ Error marking registration complete: $e");
    }
  }
}