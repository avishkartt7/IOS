// phoenician_hr/lib/common/views/camera_view.dart - FIXED VERSION

import 'dart:io';
import 'dart:typed_data';

import 'package:face_auth_compatible/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage,
    required this.onInputImage
  }) : super(key: key);

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  File? _image;
  ImagePicker? _imagePicker;
  bool _isCapturing = false;
  String _captureStatus = "Ready to capture";

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    debugPrint("CAMERA: CameraView initialized");
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Responsive sizing
        final double avatarRadius = (availableHeight * 0.25).clamp(60.0, 120.0);
        final double iconSize = (availableHeight * 0.06).clamp(16.0, 24.0);
        final double captureButtonSize = (availableHeight * 0.12).clamp(40.0, 60.0);
        final double topSpacing = (availableHeight * 0.03).clamp(8.0, 20.0);
        final double buttonSpacing = (availableHeight * 0.05).clamp(12.0, 30.0);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ✅ FIXED: Top camera icon - smaller and flexible
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: topSpacing * 0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: primaryWhite,
                        size: iconSize,
                      ),
                    ],
                  ),
                ),

                // ✅ FIXED: Main avatar section - flexible size
                _image != null
                    ? Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: const Color(0xffD9D9D9),
                      backgroundImage: FileImage(_image!),
                    ),
                    // Add retake button
                    GestureDetector(
                      onTap: _resetImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: (iconSize * 0.8).clamp(12.0, 18.0),
                        ),
                      ),
                    ),
                  ],
                )
                    : CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: const Color(0xffD9D9D9),
                  child: Icon(
                    Icons.camera_alt,
                    size: avatarRadius * 0.6,
                    color: const Color(0xff2E2E2E),
                  ),
                ),

                // ✅ FIXED: Capture button - flexible spacing and size
                GestureDetector(
                  onTap: _isCapturing ? null : _getImage,
                  child: Container(
                    width: captureButtonSize,
                    height: captureButtonSize,
                    margin: EdgeInsets.symmetric(vertical: buttonSpacing),
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        stops: [0.4, 0.65, 1],
                        colors: [
                          Color(0xffD9D9D9),
                          primaryWhite,
                          Color(0xffD9D9D9),
                        ],
                      ),
                      shape: BoxShape.circle,
                      // Add subtle animation when capturing
                      boxShadow: _isCapturing
                          ? [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                          : null,
                    ),
                    child: _isCapturing
                        ? CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: (captureButtonSize * 0.05).clamp(2.0, 3.0),
                    )
                        : null,
                  ),
                ),

                // ✅ FIXED: Text sections - flexible and compact
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isCapturing ? "Capturing..." : "Click here to Capture",
                      style: TextStyle(
                        fontSize: (availableHeight * 0.035).clamp(10.0, 14.0),
                        color: primaryWhite.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Show capture status
                    if (_captureStatus != "Ready to capture")
                      Padding(
                        padding: EdgeInsets.only(top: topSpacing * 0.4),
                        child: Text(
                          _captureStatus,
                          style: TextStyle(
                            fontSize: (availableHeight * 0.03).clamp(8.0, 12.0),
                            color: _captureStatus.contains("Error")
                                ? Colors.red.withOpacity(0.8)
                                : Colors.green.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),

                // ✅ ADDED: Bottom spacing to prevent overflow
                SizedBox(height: topSpacing * 0.5),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetImage() async {
    setState(() {
      _image = null;
      _captureStatus = "Ready to capture";
    });
  }

  Future<void> _getImage() async {
    try {
      setState(() {
        _image = null;
        _isCapturing = true;
        _captureStatus = "Opening camera...";
      });

      // Use improved image settings for better quality
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,     // Increased from 400 for better quality
        maxHeight: 600,    // Increased from 400 for better quality
        imageQuality: 85,  // Explicitly set quality (0-100)
        preferredCameraDevice: CameraDevice.front, // Prefer front camera for face
      );

      if (pickedFile != null) {
        debugPrint("CAMERA: Image captured, processing...");
        setState(() {
          _captureStatus = "Processing image...";
        });
        await _setPickedFile(pickedFile);
        setState(() {
          _captureStatus = "Image captured successfully!";
        });
      } else {
        debugPrint("CAMERA: Image capture cancelled");
        setState(() {
          _captureStatus = "Capture cancelled";
        });
      }
    } catch (e) {
      debugPrint("CAMERA: Error capturing image: $e");
      setState(() {
        _captureStatus = "Error: $e";
      });
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _setPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      debugPrint("CAMERA: No image path returned");
      return;
    }

    setState(() {
      _image = File(path);
    });

    try {
      // Read image bytes and validate
      Uint8List imageBytes = await _image!.readAsBytes();

      // Check image size for quality validation
      if (imageBytes.length < 20000) {
        debugPrint("CAMERA: Warning - image size is small (${imageBytes.length} bytes), may cause authentication issues");
        setState(() {
          _captureStatus = "Warning: Low image quality, may affect recognition";
        });
      } else {
        debugPrint("CAMERA: Good image quality (${imageBytes.length} bytes)");
      }

      // Convert to base64 and pass to parent
      widget.onImage(imageBytes);

      // Create input image and process
      InputImage inputImage = InputImage.fromFilePath(path);
      widget.onInputImage(inputImage);

    } catch (e) {
      debugPrint("CAMERA: Error processing captured image: $e");
      setState(() {
        _captureStatus = "Error processing image: $e";
      });
    }
  }
}



