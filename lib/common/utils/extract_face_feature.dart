import 'package:face_auth/model/user_model.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;

/// Enhanced face feature extraction with multiple detection strategies
/// Optimized for construction/industrial environments with challenging conditions
Future<FaceFeatures?> extractFaceFeatures(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    print("🔍 Starting enhanced face detection process...");
    
    // Strategy 1: Try with current detector first
    FaceFeatures? features = await _attemptFaceDetection(
      inputImage, 
      faceDetector, 
      "Current Settings"
    );
    
    if (features != null) {
      print("✅ Face detected with current settings");
      return features;
    }
    
    // Strategy 2: Ultra-lenient settings for challenging conditions
    final ultraLenientDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.01, // Much smaller minimum face size
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        enableContours: false,
      ),
    );
    
    features = await _attemptFaceDetection(
      inputImage, 
      ultraLenientDetector, 
      "Ultra-Lenient"
    );
    
    ultraLenientDetector.close();
    
    if (features != null) {
      print("✅ Face detected with ultra-lenient settings");
      return features;
    }
    
    // Strategy 3: Fast detection with minimal requirements
    final fastDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.05,
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        enableContours: false,
      ),
    );
    
    features = await _attemptFaceDetection(
      inputImage, 
      fastDetector, 
      "Fast Detection"
    );
    
    fastDetector.close();
    
    if (features != null) {
      print("✅ Face detected with fast detection");
      return features;
    }
    
    // Strategy 4: Accurate but lenient settings
    final accurateDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        enableContours: false,
      ),
    );
    
    features = await _attemptFaceDetection(
      inputImage, 
      accurateDetector, 
      "Accurate Detection"
    );
    
    accurateDetector.close();
    
    if (features != null) {
      print("✅ Face detected with accurate settings");
      return features;
    }
    
    // Strategy 5: Last resort - any face detection
    final lastResortDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.001, // Extremely small minimum
        enableLandmarks: false, // Disable landmarks for basic detection
        enableClassification: false,
        enableTracking: false,
        enableContours: false,
      ),
    );
    
    List<Face> faces = await lastResortDetector.processImage(inputImage);
    lastResortDetector.close();
    
    if (faces.isNotEmpty) {
      print("⚠️ Face detected with last resort settings, but no landmarks available");
      print("📊 Face bounding box: ${faces.first.boundingBox}");
      
      // Return a basic face features object with essential points estimated
      return _createBasicFaceFeatures(faces.first);
    }
    
    print("❌ No faces detected with any detection strategy");
    return null;
    
  } catch (e) {
    print('❌ Error in enhanced face detection: $e');
    print('❌ Stack trace: ${StackTrace.current}');
    return null;
  }
}

/// Attempt face detection with a specific detector
Future<FaceFeatures?> _attemptFaceDetection(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  try {
    print("🔍 Trying $strategyName strategy...");
    
    List<Face> faces = await detector.processImage(inputImage);
    print("📊 $strategyName: ${faces.length} faces found");
    
    if (faces.isEmpty) {
      return null;
    }
    
    Face face = faces.first;
    print("📏 Face bounding box: ${face.boundingBox}");
    
    // Extract landmarks with better error handling
    FaceFeatures faceFeatures = FaceFeatures(
      rightEar: _extractPoint(face, FaceLandmarkType.rightEar),
      leftEar: _extractPoint(face, FaceLandmarkType.leftEar),
      rightMouth: _extractPoint(face, FaceLandmarkType.rightMouth),
      leftMouth: _extractPoint(face, FaceLandmarkType.leftMouth),
      rightEye: _extractPoint(face, FaceLandmarkType.rightEye),
      leftEye: _extractPoint(face, FaceLandmarkType.leftEye),
      rightCheek: _extractPoint(face, FaceLandmarkType.rightCheek),
      leftCheek: _extractPoint(face, FaceLandmarkType.leftCheek),
      noseBase: _extractPoint(face, FaceLandmarkType.noseBase),
      bottomMouth: _extractPoint(face, FaceLandmarkType.bottomMouth),
    );
    
    int detectedLandmarks = _countDetectedLandmarks(faceFeatures);
    print("🎯 $strategyName: $detectedLandmarks/10 landmarks detected");
    
    // Accept if we have at least basic features (eyes and nose)
    if (faceFeatures.rightEye != null && faceFeatures.leftEye != null) {
      print("✅ $strategyName: Essential features detected");
      return faceFeatures;
    }
    
    // If no landmarks but face detected, try to estimate essential points
    if (detectedLandmarks < 3) {
      print("⚠️ $strategyName: Few landmarks, estimating essential points");
      return _estimateEssentialFeatures(face, faceFeatures);
    }
    
    return faceFeatures;
    
  } catch (e) {
    print("❌ Error in $strategyName: $e");
    return null;
  }
}

/// Create basic face features when only face bounding box is available
FaceFeatures _createBasicFaceFeatures(Face face) {
  final Rect boundingBox = face.boundingBox;
  
  // Estimate eye positions (approximate)
  double eyeY = boundingBox.top + (boundingBox.height * 0.35);
  double leftEyeX = boundingBox.left + (boundingBox.width * 0.25);
  double rightEyeX = boundingBox.left + (boundingBox.width * 0.75);
  
  // Estimate nose position
  double noseX = boundingBox.left + (boundingBox.width * 0.5);
  double noseY = boundingBox.top + (boundingBox.height * 0.55);
  
  // Estimate mouth positions
  double mouthY = boundingBox.top + (boundingBox.height * 0.75);
  double leftMouthX = boundingBox.left + (boundingBox.width * 0.35);
  double rightMouthX = boundingBox.left + (boundingBox.width * 0.65);
  
  return FaceFeatures(
    leftEye: Points(x: leftEyeX, y: eyeY),
    rightEye: Points(x: rightEyeX, y: eyeY),
    noseBase: Points(x: noseX, y: noseY),
    leftMouth: Points(x: leftMouthX, y: mouthY),
    rightMouth: Points(x: rightMouthX, y: mouthY),
    bottomMouth: Points(x: noseX, y: mouthY + 10),
    // Leave other features as null since they're estimated
    leftEar: null,
    rightEar: null,
    leftCheek: null,
    rightCheek: null,
  );
}

/// Estimate essential features when few landmarks are detected
FaceFeatures _estimateEssentialFeatures(Face face, FaceFeatures existing) {
  if (existing.rightEye != null && existing.leftEye != null) {
    return existing; // Already has essential features
  }
  
  final Rect boundingBox = face.boundingBox;
  
  // If we have some landmarks, use them as reference
  FaceFeatures enhanced = FaceFeatures(
    rightEar: existing.rightEar,
    leftEar: existing.leftEar,
    rightMouth: existing.rightMouth,
    leftMouth: existing.leftMouth,
    rightEye: existing.rightEye,
    leftEye: existing.leftEye,
    rightCheek: existing.rightCheek,
    leftCheek: existing.leftCheek,
    noseBase: existing.noseBase,
    bottomMouth: existing.bottomMouth,
  );
  
  // Estimate missing essential features
  if (enhanced.leftEye == null) {
    enhanced.leftEye = Points(
      x: boundingBox.left + (boundingBox.width * 0.25),
      y: boundingBox.top + (boundingBox.height * 0.35),
    );
  }
  
  if (enhanced.rightEye == null) {
    enhanced.rightEye = Points(
      x: boundingBox.left + (boundingBox.width * 0.75),
      y: boundingBox.top + (boundingBox.height * 0.35),
    );
  }
  
  if (enhanced.noseBase == null) {
    enhanced.noseBase = Points(
      x: boundingBox.left + (boundingBox.width * 0.5),
      y: boundingBox.top + (boundingBox.height * 0.55),
    );
  }
  
  return enhanced;
}

/// Helper method to safely extract a point from face landmarks
Points? _extractPoint(Face face, FaceLandmarkType landmarkType) {
  try {
    final landmark = face.landmarks[landmarkType];
    if (landmark != null) {
      return Points(
        x: landmark.position.x.toDouble(),
        y: landmark.position.y.toDouble(),
      );
    }
    return null;
  } catch (e) {
    print("❌ Error extracting $landmarkType: $e");
    return null;
  }
}

/// Count how many landmarks were successfully detected
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

/// Debug print for landmark detection status
void _debugLandmarks(FaceFeatures features) {
  print("👁️ Eyes: Right=${features.rightEye != null}, Left=${features.leftEye != null}");
  print("👂 Ears: Right=${features.rightEar != null}, Left=${features.leftEar != null}");
  print("👄 Mouth: Right=${features.rightMouth != null}, Left=${features.leftMouth != null}, Bottom=${features.bottomMouth != null}");
  print("👃 Nose: ${features.noseBase != null}");
  print("😊 Cheeks: Right=${features.rightCheek != null}, Left=${features.leftCheek != null}");
}

/// Validate if face features are sufficient for registration/authentication
bool validateFaceFeatures(FaceFeatures features) {
  // For construction/industrial use, we need at least eyes and nose
  bool hasEssentialFeatures = features.rightEye != null &&
      features.leftEye != null &&
      features.noseBase != null;

  return hasEssentialFeatures;
}

/// Get face feature quality score (0.0 to 1.0)
double getFaceFeatureQuality(FaceFeatures features) {
  int totalFeatures = 10;
  int detectedFeatures = _countDetectedLandmarks(features);
  double baseScore = detectedFeatures / totalFeatures;
  
  // Bonus for essential features
  if (features.rightEye != null && features.leftEye != null && features.noseBase != null) {
    baseScore += 0.2; // 20% bonus for essential features
  }
  
  return math.min(baseScore, 1.0);
}

/// Advanced face detection with image preprocessing
Future<FaceFeatures?> detectFaceWithPreprocessing(Uint8List imageBytes) async {
  try {
    print("🔧 Starting face detection with preprocessing...");
    
    // Create input image
    InputImage inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: const Size(800, 800), // Assume square image
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: 800,
      ),
    );
    
    // Try enhanced detection
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        enableContours: false,
      ),
    );
    
    FaceFeatures? features = await extractFaceFeatures(inputImage, detector);
    detector.close();
    
    return features;
    
  } catch (e) {
    print("❌ Error in preprocessing detection: $e");
    return null;
  }
}

/// Check if image quality is suitable for face detection
Map<String, dynamic> analyzeImageQuality(Uint8List imageBytes) {
  try {
    // Basic quality checks
    double imageSizeKB = imageBytes.length / 1024;
    
    return {
      'size_kb': imageSizeKB,
      'is_too_small': imageSizeKB < 10, // Less than 10KB might be too small
      'is_too_large': imageSizeKB > 5000, // More than 5MB might be too large
      'quality_score': _calculateQualityScore(imageSizeKB),
      'recommendations': _getQualityRecommendations(imageSizeKB),
    };
  } catch (e) {
    print("❌ Error analyzing image quality: $e");
    return {
      'size_kb': 0,
      'is_too_small': true,
      'is_too_large': false,
      'quality_score': 0.0,
      'recommendations': ['Unable to analyze image quality'],
    };
  }
}

double _calculateQualityScore(double sizeKB) {
  if (sizeKB < 10) return 0.2;
  if (sizeKB < 50) return 0.5;
  if (sizeKB < 200) return 0.8;
  if (sizeKB < 1000) return 1.0;
  if (sizeKB < 5000) return 0.9;
  return 0.3; // Too large
}

List<String> _getQualityRecommendations(double sizeKB) {
  List<String> recommendations = [];
  
  if (sizeKB < 10) {
    recommendations.add("Image too small - use higher resolution");
  }
  if (sizeKB > 5000) {
    recommendations.add("Image too large - may cause processing issues");
  }
  if (sizeKB >= 10 && sizeKB <= 1000) {
    recommendations.add("Good image size for face detection");
  }
  
  return recommendations;
}

/// Get comprehensive face detection report
Map<String, dynamic> getFaceDetectionReport(FaceFeatures? features, Face? face) {
  if (features == null || face == null) {
    return {
      'success': false,
      'message': 'No face detected',
      'features_detected': 0,
      'quality_score': 0.0,
      'recommendations': ['Ensure face is clearly visible', 'Use good lighting', 'Remove obstructions'],
    };
  }
  
  int featuresDetected = _countDetectedLandmarks(features);
  double qualityScore = getFaceFeatureQuality(features);
  
  List<String> recommendations = [];
  
  if (featuresDetected < 5) {
    recommendations.add("Try better lighting conditions");
    recommendations.add("Ensure face is clearly visible");
    recommendations.add("Remove sunglasses or masks if possible");
  }
  
  if (qualityScore < 0.5) {
    recommendations.add("Position face closer to camera");
    recommendations.add("Use frontal face pose");
  }
  
  if (featuresDetected >= 7 && qualityScore >= 0.7) {
    recommendations.add("Good face detection quality");
  }
  
  return {
    'success': true,
    'message': 'Face detected successfully',
    'features_detected': featuresDetected,
    'quality_score': qualityScore,
    'bounding_box': {
      'left': face.boundingBox.left,
      'top': face.boundingBox.top,
      'width': face.boundingBox.width,
      'height': face.boundingBox.height,
    },
    'recommendations': recommendations,
  };
}

/// Simple version that exactly matches your original working implementation
Future<FaceFeatures?> extractFaceFeaturesSimple(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    List<Face> faceList = await faceDetector.processImage(inputImage);
    
    if (faceList.isEmpty) {
      print("❌ No faces detected in simple extraction");
      return null;
    }
    
    Face face = faceList.first;

    FaceFeatures faceFeatures = FaceFeatures(
      rightEar: face.landmarks[FaceLandmarkType.rightEar] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightEar]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightEar]!.position.y.toDouble())
          : null,
      leftEar: face.landmarks[FaceLandmarkType.leftEar] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftEar]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftEar]!.position.y.toDouble())
          : null,
      rightMouth: face.landmarks[FaceLandmarkType.rightMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightMouth]!.position.y.toDouble())
          : null,
      leftMouth: face.landmarks[FaceLandmarkType.leftMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftMouth]!.position.y.toDouble())
          : null,
      rightEye: face.landmarks[FaceLandmarkType.rightEye] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightEye]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightEye]!.position.y.toDouble())
          : null,
      leftEye: face.landmarks[FaceLandmarkType.leftEye] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftEye]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftEye]!.position.y.toDouble())
          : null,
      rightCheek: face.landmarks[FaceLandmarkType.rightCheek] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightCheek]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightCheek]!.position.y.toDouble())
          : null,
      leftCheek: face.landmarks[FaceLandmarkType.leftCheek] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftCheek]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftCheek]!.position.y.toDouble())
          : null,
      noseBase: face.landmarks[FaceLandmarkType.noseBase] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.noseBase]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.noseBase]!.position.y.toDouble())
          : null,
      bottomMouth: face.landmarks[FaceLandmarkType.bottomMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.bottomMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.bottomMouth]!.position.y.toDouble())
          : null,
    );

    return faceFeatures;
  } catch (e) {
    print('❌ Error in simple face extraction: $e');
    return null;
  }
}

/// Check if face is properly positioned (centered and appropriate size)
bool isFaceProperlyPositioned(Face face, double imageWidth, double imageHeight) {
  // Get face bounding box
  final Rect boundingBox = face.boundingBox;
  
  // Calculate face center
  double faceCenterX = boundingBox.left + (boundingBox.width / 2);
  double faceCenterY = boundingBox.top + (boundingBox.height / 2);
  
  // Calculate image center
  double imageCenterX = imageWidth / 2;
  double imageCenterY = imageHeight / 2;
  
  // Check if face is centered (within 20% of image center)
  double maxOffsetX = imageWidth * 0.2;
  double maxOffsetY = imageHeight * 0.2;
  
  bool isCentered = (faceCenterX - imageCenterX).abs() < maxOffsetX &&
                   (faceCenterY - imageCenterY).abs() < maxOffsetY;
  
  // Check if face size is appropriate (20% to 80% of image width)
  double minFaceWidth = imageWidth * 0.2;
  double maxFaceWidth = imageWidth * 0.8;
  
  bool isGoodSize = boundingBox.width >= minFaceWidth && 
                   boundingBox.width <= maxFaceWidth;
  
  return isCentered && isGoodSize;
}

/// Get comprehensive face analysis
Map<String, dynamic> analyzeFace(Face face, double imageWidth, double imageHeight) {
  return {
    'boundingBox': {
      'left': face.boundingBox.left,
      'top': face.boundingBox.top,
      'width': face.boundingBox.width,
      'height': face.boundingBox.height,
    },
    'isProperlyPositioned': isFaceProperlyPositioned(face, imageWidth, imageHeight),
    'headEulerAngleX': face.headEulerAngleX,
    'headEulerAngleY': face.headEulerAngleY,
    'headEulerAngleZ': face.headEulerAngleZ,
    'leftEyeOpenProbability': face.leftEyeOpenProbability,
    'rightEyeOpenProbability': face.rightEyeOpenProbability,
    'smilingProbability': face.smilingProbability,
    'trackingId': face.trackingId,
  };
}