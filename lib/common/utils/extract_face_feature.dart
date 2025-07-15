import 'package:face_auth/model/user_model.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui'; 

/// Extract face features from input image using ML Kit
/// Enhanced version with better debugging and error handling
Future<FaceFeatures?> extractFaceFeatures(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    print("🔍 Starting face detection process...");
    
    // Process the image to detect faces
    List<Face> faceList = await faceDetector.processImage(inputImage);
    
    print("🔍 Face detection results: ${faceList.length} faces found");
    
    // Return null if no faces detected
    if (faceList.isEmpty) {
      print("❌ No faces detected in image");
      
      // Try with more lenient detector as fallback
      final lenientDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.01,
          enableLandmarks: false,
        ),
      );
      
      List<Face> lenientFaceList = await lenientDetector.processImage(inputImage);
      print("🔍 Lenient detection results: ${lenientFaceList.length} faces found");
      
      lenientDetector.close();
      
      if (lenientFaceList.isEmpty) {
        return null;
      }
      
      // Use the lenient result if available
      faceList = lenientFaceList;
    }
    
    // Use the first detected face
    Face face = faceList.first;
    print("✅ Processing first detected face");
    print("📏 Face bounding box: ${face.boundingBox}");
    
    // Extract facial landmarks with null safety
    FaceFeatures faceFeatures = FaceFeatures(
      // Right ear landmark
      rightEar: _extractPoint(face, FaceLandmarkType.rightEar),
      
      // Left ear landmark
      leftEar: _extractPoint(face, FaceLandmarkType.leftEar),
      
      // Right mouth landmark
      rightMouth: _extractPoint(face, FaceLandmarkType.rightMouth),
      
      // Left mouth landmark
      leftMouth: _extractPoint(face, FaceLandmarkType.leftMouth),
      
      // Right eye landmark
      rightEye: _extractPoint(face, FaceLandmarkType.rightEye),
      
      // Left eye landmark
      leftEye: _extractPoint(face, FaceLandmarkType.leftEye),
      
      // Right cheek landmark
      rightCheek: _extractPoint(face, FaceLandmarkType.rightCheek),
      
      // Left cheek landmark
      leftCheek: _extractPoint(face, FaceLandmarkType.leftCheek),
      
      // Nose base landmark
      noseBase: _extractPoint(face, FaceLandmarkType.noseBase),
      
      // Bottom mouth landmark
      bottomMouth: _extractPoint(face, FaceLandmarkType.bottomMouth),
    );

    // Debug: Print which landmarks were detected
    int detectedLandmarks = _countDetectedLandmarks(faceFeatures);
    print("🎯 Detected $detectedLandmarks/10 facial landmarks");
    
    // Print specific landmark availability
    _debugLandmarks(faceFeatures);
    
    // Check if we have essential features (eyes, nose)
    bool hasEssentialFeatures = faceFeatures.rightEye != null &&
        faceFeatures.leftEye != null &&
        faceFeatures.noseBase != null;
    
    if (!hasEssentialFeatures) {
      print("⚠️ Missing essential features (eyes/nose)");
      // Still return the features, but log the warning
    } else {
      print("✅ Essential features detected successfully");
    }

    return faceFeatures;
  } catch (e) {
    print('❌ Error extracting face features: $e');
    print('❌ Stack trace: ${StackTrace.current}');
    return null;
  }
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

/// Validate if face features are sufficient for registration/authentication
bool validateFaceFeatures(FaceFeatures features) {
  // Check if essential features are present
  bool hasEssentialFeatures = features.rightEye != null &&
      features.leftEye != null &&
      features.noseBase != null &&
      features.rightMouth != null &&
      features.leftMouth != null;

  return hasEssentialFeatures;
}

/// Get face feature quality score (0.0 to 1.0)
double getFaceFeatureQuality(FaceFeatures features) {
  int totalFeatures = 10; // Total possible features
  int detectedFeatures = _countDetectedLandmarks(features);
  return detectedFeatures / totalFeatures;
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

