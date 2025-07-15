import 'package:face_auth/model/user_model.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui'; 

/// Extract face features from input image using ML Kit
Future<FaceFeatures?> extractFaceFeatures(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    // Process the image to detect faces
    List<Face> faceList = await faceDetector.processImage(inputImage);
    
    // Return null if no faces detected
    if (faceList.isEmpty) {
      return null;
    }
    
    // Use the first detected face
    Face face = faceList.first;
    
    // Extract facial landmarks
    FaceFeatures faceFeatures = FaceFeatures(
      // Right ear landmark
      rightEar: face.landmarks[FaceLandmarkType.rightEar] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightEar]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightEar]!.position.y.toDouble(),
            )
          : null,
      
      // Left ear landmark
      leftEar: face.landmarks[FaceLandmarkType.leftEar] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftEar]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftEar]!.position.y.toDouble(),
            )
          : null,
      
      // Right mouth landmark
      rightMouth: face.landmarks[FaceLandmarkType.rightMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightMouth]!.position.y.toDouble(),
            )
          : null,
      
      // Left mouth landmark
      leftMouth: face.landmarks[FaceLandmarkType.leftMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftMouth]!.position.y.toDouble(),
            )
          : null,
      
      // Right eye landmark
      rightEye: face.landmarks[FaceLandmarkType.rightEye] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightEye]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightEye]!.position.y.toDouble(),
            )
          : null,
      
      // Left eye landmark
      leftEye: face.landmarks[FaceLandmarkType.leftEye] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftEye]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftEye]!.position.y.toDouble(),
            )
          : null,
      
      // Right cheek landmark
      rightCheek: face.landmarks[FaceLandmarkType.rightCheek] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.rightCheek]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.rightCheek]!.position.y.toDouble(),
            )
          : null,
      
      // Left cheek landmark
      leftCheek: face.landmarks[FaceLandmarkType.leftCheek] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.leftCheek]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.leftCheek]!.position.y.toDouble(),
            )
          : null,
      
      // Nose base landmark
      noseBase: face.landmarks[FaceLandmarkType.noseBase] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.noseBase]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.noseBase]!.position.y.toDouble(),
            )
          : null,
      
      // Bottom mouth landmark
      bottomMouth: face.landmarks[FaceLandmarkType.bottomMouth] != null
          ? Points(
              x: face.landmarks[FaceLandmarkType.bottomMouth]!.position.x.toDouble(),
              y: face.landmarks[FaceLandmarkType.bottomMouth]!.position.y.toDouble(),
            )
          : null,
    );

    return faceFeatures;
  } catch (e) {
    print('Error extracting face features: $e');
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
  int detectedFeatures = 0;

  // Count detected features
  if (features.rightEar != null) detectedFeatures++;
  if (features.leftEar != null) detectedFeatures++;
  if (features.rightEye != null) detectedFeatures++;
  if (features.leftEye != null) detectedFeatures++;
  if (features.rightCheek != null) detectedFeatures++;
  if (features.leftCheek != null) detectedFeatures++;
  if (features.rightMouth != null) detectedFeatures++;
  if (features.leftMouth != null) detectedFeatures++;
  if (features.noseBase != null) detectedFeatures++;
  if (features.bottomMouth != null) detectedFeatures++;

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

/// Check if face angle is appropriate for registration
bool isFaceAngleGood(Face face) {
  // Get face rotation angles
  double? headEulerAngleX = face.headEulerAngleX; // Pitch (up/down)
  double? headEulerAngleY = face.headEulerAngleY; // Yaw (left/right)
  double? headEulerAngleZ = face.headEulerAngleZ; // Roll (tilt)
  
  // Define acceptable angle ranges (in degrees)
  const double maxPitch = 15.0;
  const double maxYaw = 15.0;
  const double maxRoll = 15.0;
  
  // Check if all angles are within acceptable range
  bool pitchOk = headEulerAngleX == null || headEulerAngleX.abs() <= maxPitch;
  bool yawOk = headEulerAngleY == null || headEulerAngleY.abs() <= maxYaw;
  bool rollOk = headEulerAngleZ == null || headEulerAngleZ.abs() <= maxRoll;
  
  return pitchOk && yawOk && rollOk;
}

/// Check if eyes are open and visible
bool areEyesOpen(Face face) {
  // Get eye open probabilities
  double? leftEyeOpenProbability = face.leftEyeOpenProbability;
  double? rightEyeOpenProbability = face.rightEyeOpenProbability;
  
  // Define minimum probability for eyes to be considered open
  const double minEyeOpenProbability = 0.5;
  
  // Check if both eyes are open
  bool leftEyeOpen = leftEyeOpenProbability == null || 
                     leftEyeOpenProbability >= minEyeOpenProbability;
  bool rightEyeOpen = rightEyeOpenProbability == null || 
                      rightEyeOpenProbability >= minEyeOpenProbability;
  
  return leftEyeOpen && rightEyeOpen;
}

/// Check if person is smiling (optional for registration)
bool isSmiling(Face face) {
  double? smilingProbability = face.smilingProbability;
  
  // Define minimum probability for smiling
  const double minSmilingProbability = 0.7;
  
  return smilingProbability != null && smilingProbability >= minSmilingProbability;
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
    'isAngleGood': isFaceAngleGood(face),
    'areEyesOpen': areEyesOpen(face),
    'isSmiling': isSmiling(face),
    'headEulerAngleX': face.headEulerAngleX,
    'headEulerAngleY': face.headEulerAngleY,
    'headEulerAngleZ': face.headEulerAngleZ,
    'leftEyeOpenProbability': face.leftEyeOpenProbability,
    'rightEyeOpenProbability': face.rightEyeOpenProbability,
    'smilingProbability': face.smilingProbability,
    'trackingId': face.trackingId,
  };
}

/// Get face quality assessment
Map<String, dynamic> getFaceQualityAssessment(Face face, FaceFeatures features, 
    double imageWidth, double imageHeight) {
  
  double featureQuality = getFaceFeatureQuality(features);
  bool isPositioned = isFaceProperlyPositioned(face, imageWidth, imageHeight);
  bool isAngleGood = isFaceAngleGood(face);
  bool eyesOpen = areEyesOpen(face);
  
  // Calculate overall quality score
  double qualityScore = 0.0;
  
  if (featureQuality > 0.7) qualityScore += 0.3;
  if (isPositioned) qualityScore += 0.3;
  if (isAngleGood) qualityScore += 0.2;
  if (eyesOpen) qualityScore += 0.2;
  
  String qualityLevel = 'Poor';
  if (qualityScore >= 0.8) {
    qualityLevel = 'Excellent';
  } else if (qualityScore >= 0.6) {
    qualityLevel = 'Good';
  } else if (qualityScore >= 0.4) {
    qualityLevel = 'Fair';
  }
  
  return {
    'qualityScore': qualityScore,
    'qualityLevel': qualityLevel,
    'featureQuality': featureQuality,
    'isProperlyPositioned': isPositioned,
    'isAngleGood': isAngleGood,
    'areEyesOpen': eyesOpen,
    'recommendations': _getQualityRecommendations(
      featureQuality, isPositioned, isAngleGood, eyesOpen
    ),
  };
}

/// Get recommendations for improving face quality
List<String> _getQualityRecommendations(
    double featureQuality, bool isPositioned, bool isAngleGood, bool eyesOpen) {
  
  List<String> recommendations = [];
  
  if (featureQuality < 0.7) {
    recommendations.add('Improve lighting conditions');
    recommendations.add('Move closer to the camera');
  }
  
  if (!isPositioned) {
    recommendations.add('Center your face in the frame');
    recommendations.add('Adjust distance from camera');
  }
  
  if (!isAngleGood) {
    recommendations.add('Look straight at the camera');
    recommendations.add('Keep your head level');
  }
  
  if (!eyesOpen) {
    recommendations.add('Keep your eyes open');
    recommendations.add('Look directly at the camera');
  }
  
  if (recommendations.isEmpty) {
    recommendations.add('Face quality is good!');
  }
  
  return recommendations;
}