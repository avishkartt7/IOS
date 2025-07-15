import 'dart:io';
import 'dart:typed_data';

import 'package:face_auth/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String _statusMessage = "Tap to capture your face";

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // Camera preview or placeholder
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: accentColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Processing image...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Control buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildControlButtons(),
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
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "Tap to capture your face",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Make sure you have good lighting",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake button
        if (_image != null)
          _buildControlButton(
            icon: Icons.refresh,
            label: "Retake",
            onPressed: _retakeImage,
          ),

        // Capture button
        _buildControlButton(
          icon: _image == null ? Icons.camera_alt : Icons.check,
          label: _image == null ? "Capture" : "Use Photo",
          onPressed: _image == null ? _getImage : _processCurrentImage,
          isPrimary: true,
        ),

        // Gallery button
        _buildControlButton(
          icon: Icons.photo_library,
          label: "Gallery",
          onPressed: _getImageFromGallery,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isPrimary ? accentColor : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
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

  Future<void> _getImage() async {
    // Check camera permission
    if (!await _checkCameraPermission()) {
      _updateStatusMessage("Camera permission required");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Opening camera...";
    });

    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      } else {
        _updateStatusMessage("No image captured");
      }
    } catch (e) {
      debugPrint("Error capturing image: $e");
      _updateStatusMessage("Error capturing image");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _getImageFromGallery() async {
    // Check storage permission
    if (!await _checkStoragePermission()) {
      _updateStatusMessage("Storage permission required");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Opening gallery...";
    });

    try {
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _setPickedFile(pickedFile);
      } else {
        _updateStatusMessage("No image selected");
      }
    } catch (e) {
      debugPrint("Error selecting image: $e");
      _updateStatusMessage("Error selecting image");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _setPickedFile(XFile pickedFile) async {
    final path = pickedFile.path;
    
    setState(() {
      _image = File(path);
      _statusMessage = "Image captured successfully";
    });

    // Process the image
    await _processImage(path);
  }

  Future<void> _processImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Processing image...";
    });

    try {
      // Read image bytes
      Uint8List imageBytes = await File(imagePath).readAsBytes();
      
      // Create InputImage for ML Kit
      InputImage inputImage = InputImage.fromFilePath(imagePath);
      
      // Call the callbacks
      widget.onImage(imageBytes);
      widget.onInputImage(inputImage);
      
      _updateStatusMessage("Image processed successfully");
    } catch (e) {
      debugPrint("Error processing image: $e");
      _updateStatusMessage("Error processing image");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCurrentImage() async {
    if (_image == null) return;
    
    await _processImage(_image!.path);
  }

  void _retakeImage() {
    setState(() {
      _image = null;
      _statusMessage = "Tap to capture your face";
    });
  }

  Future<bool> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (status != PermissionStatus.granted) {
      status = await Permission.camera.request();
    }
    return status == PermissionStatus.granted;
  }

  Future<bool> _checkStoragePermission() async {
    var status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      status = await Permission.storage.request();
    }
    return status == PermissionStatus.granted;
  }

  void _updateStatusMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
    
    // Clear message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = _image == null 
              ? "Tap to capture your face" 
              : "Image ready for processing";
        });
      }
    });
  }
}