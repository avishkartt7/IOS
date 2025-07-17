// lib/common/views/camera_view.dart - iOS ENHANCED VERSION

import 'dart:io';
import 'dart:typed_data';

import 'package:face_auth/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage,
    required this.onInputImage,
  }) : super(key: key);

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  File? _image;
  ImagePicker? _imagePicker;
  bool _isProcessing = false;
  String _statusMessage = "Tap camera icon to capture";
  bool _isIOS = Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    print("📷 iOS CameraView initialized");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _image != null ? Colors.green : Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Main content area
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                _image!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            _buildCameraPlaceholder(),

          // Processing overlay
          if (_isProcessing)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Processing image...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Camera control button
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildCameraControls(),
          ),

          // Status message
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  if (_isIOS)
                    const Text(
                      "📱 ",
                      style: TextStyle(fontSize: 16),
                    ),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 20),
          Text(
            _isIOS ? "📱 Take a Photo (iOS)" : "Take a Photo",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isIOS 
                ? "Position your face clearly in good lighting\nOptimized for iOS face detection"
                : "Position your face clearly in good lighting",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery button
        _buildControlButton(
          icon: Icons.photo_library_rounded,
          label: "Gallery",
          onPressed: _getImageFromGallery,
          isSecondary: true,
        ),

        // Main camera button
        _buildControlButton(
          icon: _image == null ? Icons.camera_alt_rounded : Icons.refresh_rounded,
          label: _image == null ? "Camera" : "Retake",
          onPressed: _getImageFromCamera,
          isPrimary: true,
        ),

        // Process button (if image exists)
        if (_image != null)
          _buildControlButton(
            icon: Icons.check_rounded,
            label: "Use Photo",
            onPressed: _processCurrentImage,
            isSuccess: true,
          )
        else
          Container(width: 60), // Placeholder for spacing
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isSecondary = false,
    bool isSuccess = false,
  }) {
    Color buttonColor;
    if (isPrimary) {
      buttonColor = accentColor;
    } else if (isSuccess) {
      buttonColor = Colors.green;
    } else {
      buttonColor = Colors.white.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: _isProcessing ? null : onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: buttonColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImageFromCamera() async {
    print("📷 iOS: Opening camera...");
    
    setState(() {
      _isProcessing = true;
      _statusMessage = _isIOS ? "📱 Opening iOS camera..." : "Opening camera...";
    });

    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,  // Higher resolution for iOS
        maxHeight: 1024,
        imageQuality: 95, // Higher quality for better face detection
        preferredCameraDevice: CameraDevice.front, // Front camera for selfies
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      } else {
        _updateStatusMessage(_isIOS ? "📱 No photo taken" : "No photo taken");
      }
    } catch (e) {
      print("❌ iOS Camera error: $e");
      _updateStatusMessage(_isIOS ? "📱 iOS camera error: $e" : "Camera error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _getImageFromGallery() async {
    print("📷 iOS: Opening gallery...");
    
    setState(() {
      _isProcessing = true;
      _statusMessage = _isIOS ? "📱 Opening iOS gallery..." : "Opening gallery...";
    });

    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      } else {
        _updateStatusMessage(_isIOS ? "📱 No photo selected" : "No photo selected");
      }
    } catch (e) {
      print("❌ iOS Gallery error: $e");
      _updateStatusMessage(_isIOS ? "📱 iOS gallery error: $e" : "Gallery error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _setPickedFile(XFile pickedFile) async {
    final path = pickedFile.path;
    print("📷 iOS: Processing image from: $path");
    
    setState(() {
      _image = File(path);
      _statusMessage = _isIOS ? "📱 iOS photo captured successfully" : "Photo captured successfully";
    });

    try {
      // Read image bytes
      Uint8List imageBytes = await _image!.readAsBytes();
      
      // Create InputImage for ML Kit
      InputImage inputImage = InputImage.fromFilePath(path);
      
      print("📊 iOS Image info:");
      print("   - Path: $path");
      print("   - Size: ${imageBytes.length} bytes");
      print("   - InputImage created successfully");
      
      // Call the callbacks
      widget.onImage(imageBytes);
      widget.onInputImage(inputImage);
      
      _updateStatusMessage(_isIOS ? "📱 iOS photo ready for processing" : "Photo ready for processing");
      
    } catch (e) {
      print("❌ iOS Error processing image: $e");
      _updateStatusMessage(_isIOS ? "📱 iOS error processing photo" : "Error processing photo");
    }
  }

  Future<void> _processCurrentImage() async {
    if (_image == null) {
      print("❌ iOS: No image to process");
      return;
    }
    
    print("🔄 iOS: Reprocessing current image...");
    
    setState(() {
      _isProcessing = true;
      _statusMessage = _isIOS ? "📱 iOS reprocessing photo..." : "Reprocessing photo...";
    });

    try {
      // Read image bytes again
      Uint8List imageBytes = await _image!.readAsBytes();
      
      // Create InputImage for ML Kit
      InputImage inputImage = InputImage.fromFilePath(_image!.path);
      
      // Call the callbacks
      widget.onImage(imageBytes);
      widget.onInputImage(inputImage);
      
      _updateStatusMessage(_isIOS ? "📱 iOS photo reprocessed" : "Photo reprocessed");
      
    } catch (e) {
      print("❌ iOS Error reprocessing image: $e");
      _updateStatusMessage(_isIOS ? "📱 iOS error reprocessing photo" : "Error reprocessing photo");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _updateStatusMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
    
    // Clear message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (_image == null) {
            _statusMessage = _isIOS 
                ? "📱 Tap camera icon to capture (iOS)" 
                : "Tap camera icon to capture";
          } else {
            _statusMessage = _isIOS ? "📱 iOS photo ready" : "Photo ready";
          }
        });
      }
    });
  }
}