import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class AuthenticateFaceView extends StatefulWidget {
  final String? employeeId;
  final String? employeePin;
  final bool isRegistrationValidation;

  const AuthenticateFaceView({
    Key? key,
    this.employeeId,
    this.employeePin,
    this.isRegistrationValidation = false,
  }) : super(key: key);

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  FaceFeatures? _faceFeatures;
  var image1 = regula.MatchFacesImage();
  var image2 = regula.MatchFacesImage();

  String _similarity = "";
  bool _canAuthenticate = false;
  Map<String, dynamic>? employeeData;
  bool isMatching = false;
  int trialNumber = 1;
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeData();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: Text(widget.isRegistrationValidation 
            ? "Verify Your Face" 
            : "Face Authentication"),
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
                  // Status indicator
                  Container(
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
                      ],
                    ),
                  ),

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

  String _getStatusText() {
    if (_hasAuthenticated) {
      return "Authentication successful!";
    } else if (isMatching) {
      return "Verifying your face...";
    } else if (_canAuthenticate) {
      return "Ready to authenticate";
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
    } else {
      return Icons.face;
    }
  }

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
      setState(() => isMatching = false);
    } catch (e) {
      setState(() => isMatching = false);
      debugPrint("Error processing input image: $e");
    }
  }

  Future<void> _fetchEmployeeData() async {
    if (widget.employeeId == null) return;

    try {
      // Try to get from Firestore first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (doc.exists) {
        setState(() {
          employeeData = doc.data() as Map<String, dynamic>;
        });
      }

      // Also try to get from local storage
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString('user_data_${widget.employeeId}');
      if (localData != null) {
        Map<String, dynamic> data = jsonDecode(localData);
        setState(() {
          employeeData = data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching employee data: $e");
    }
  }

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

  Future<void> _matchFaceWithStored() async {
    try {
      String? storedImage;

      // Try to get stored image from multiple sources
      if (employeeData != null && employeeData!['image'] != null) {
        storedImage = employeeData!['image'];
      } else {
        // Try local storage
        SharedPreferences prefs = await SharedPreferences.getInstance();
        storedImage = prefs.getString('employee_image_${widget.employeeId}');
      }

      if (storedImage == null) {
        setState(() {
          isMatching = false;
        });
        _playFailedAudio;
        _showFailureDialog(
          title: "Authentication Failed",
          description: "No registered face found. Please register first.",
        );
        return;
      }

      // Clean stored image
      if (storedImage.contains('data:image') && storedImage.contains(',')) {
        storedImage = storedImage.split(',')[1];
      }

      // Perform face matching
      await _performFaceMatching(storedImage);

    } catch (e) {
      debugPrint("Error in face matching: $e");
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

  Future<void> _performFaceMatching(String storedImage) async {
    try {
      image1.bitmap = storedImage;
      image1.imageType = regula.ImageType.PRINTED;

      var request = regula.MatchFacesRequest();
      request.images = [image1, image2];

      dynamic value = await regula.FaceSDK.matchFaces(jsonEncode(request));
      var response = regula.MatchFacesResponse.fromJson(json.decode(value));

      dynamic str = await regula.FaceSDK.matchFacesSimilarityThresholdSplit(
          jsonEncode(response!.results), 0.75);

      var split = regula.MatchFacesSimilarityThresholdSplit.fromJson(json.decode(str));
      
      setState(() {
        _similarity = split!.matchedFaces.isNotEmpty
            ? (split.matchedFaces[0]!.similarity! * 100).toStringAsFixed(2)
            : "0.0";
      });

      debugPrint("Face matching similarity: $_similarity%");

      if (_similarity != "0.0" && double.parse(_similarity) > 85.0) {
        // Authentication successful
        _handleSuccessfulAuthentication();
      } else {
        // Authentication failed
        setState(() {
          isMatching = false;
        });
        _playFailedAudio;
        _showFailureDialog(
          title: "Authentication Failed",
          description: "Face doesn't match. Please try again.",
        );
      }
    } catch (e) {
      debugPrint("Error in face matching: $e");
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

  void _handleSuccessfulAuthentication() {
    _playSuccessAudio;

    setState(() {
      isMatching = false;
      _hasAuthenticated = true;
    });

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
  }

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