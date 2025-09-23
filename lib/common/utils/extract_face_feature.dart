// lib/common/utils/extract_face_feature.dart - Production Ready

import 'package:face_auth/model/user_model.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;

/// Main face feature extraction function for production use
Future<FaceFeatures?> extractFaceFeatures(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    print("🚀 Starting face detection...");
    print("⏰ Detection started at: ${DateTime.now().toIso8601String()}");
    
    // Strategy 1: Accurate detection (best for registration and authentication)
    FaceFeatures? features = await _attemptAccurateDetection(
      inputImage, 
      faceDetector, 
      "Accurate Detection"
    );
    
    if (features != null && _validateFeatureQuality(features, 0.6)) {
      print("✅ SUCCESS: Accurate detection completed");
      print("📊 Feature quality: ${_getFeatureQualityScore(features)}");
      print("🎯 Detection method: Accurate (best for production)");
      return _optimizeFeatures(features);
    }
    
    // Strategy 2: Reliable detection with lower threshold
    print("🔄 Trying reliable detection...");
    features = await _attemptReliableDetection(
      inputImage, 
      faceDetector, 
      "Reliable Detection"
    );
    
    if (features != null && _validateFeatureQuality(features, 0.5)) {
      print("✅ SUCCESS: Reliable detection completed");
      print("🎯 Detection method: Reliable");
      return _optimizeFeatures(features);
    }
    
    // Strategy 3: Fallback detection for difficult conditions
    print("🔄 Trying fallback detection...");
    features = await _attemptFallbackDetection(
      inputImage, 
      faceDetector, 
      "Fallback Detection"
    );
    
    if (features != null && _validateFeatureQuality(features, 0.4)) {
      print("✅ SUCCESS: Fallback detection completed");
      print("🎯 Detection method: Fallback");
      return _optimizeFeatures(features);
    }
    
    // Strategy 4: Lenient detection as last resort
    print("🔄 Final attempt: Lenient detection...");
    features = await _attemptLenientDetection(
      inputImage, 
      faceDetector, 
      "Lenient Detection"
    );
    
    if (features != null) {
      print("⚠️ FALLBACK: Basic face detected with lenient settings");
      print("🎯 Detection method: Lenient (last resort)");
      
      FaceFeatures optimizedFeatures = _optimizeFeatures(features);
      print("📊 Optimized features quality: ${_getFeatureQualityScore(optimizedFeatures)}");
      print("✅ Optimized features created successfully");
      return optimizedFeatures;
    }
    
    print("❌ FAILURE: No faces detected with any detection strategy");
    print("💡 Suggestions: Ensure good lighting, proper face positioning, clean camera");
    return null;
    
  } catch (e) {
    print('❌ CRITICAL ERROR in face detection: $e');
    print('❌ Stack trace: ${StackTrace.current}');
    return null;
  }
}

/// Strategy 1: Accurate detection for best quality
Future<FaceFeatures?> _attemptAccurateDetection(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  final accurateDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: false,
      enableContours: false,
    ),
  );
  
  try {
    FaceFeatures? features = await _performDetectionWithValidation(
      inputImage, accurateDetector, strategyName
    );
    
    accurateDetector.close();
    return features;
  } catch (e) {
    accurateDetector.close();
    print("❌ $strategyName error: $e");
    return null;
  }
}

/// Strategy 2: Reliable detection with balanced settings
Future<FaceFeatures?> _attemptReliableDetection(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  final reliableDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      enableContours: false,
    ),
  );
  
  try {
    FaceFeatures? features = await _performDetectionWithValidation(
      inputImage, reliableDetector, strategyName
    );
    
    reliableDetector.close();
    return features;
  } catch (e) {
    reliableDetector.close();
    print("❌ $strategyName error: $e");
    return null;
  }
}

/// Strategy 3: Fallback detection for difficult conditions
Future<FaceFeatures?> _attemptFallbackDetection(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  final fallbackDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.08,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      enableContours: false,
    ),
  );
  
  try {
    FaceFeatures? features = await _performDetectionWithValidation(
      inputImage, fallbackDetector, strategyName
    );
    
    fallbackDetector.close();
    return features;
  } catch (e) {
    fallbackDetector.close();
    print("❌ $strategyName error: $e");
    return null;
  }
}

/// Strategy 4: Lenient detection as last resort
Future<FaceFeatures?> _attemptLenientDetection(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  final lenientDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.05,
      enableLandmarks: true,
      enableClassification: false,
      enableTracking: false,
      enableContours: false,
    ),
  );
  
  try {
    List<Face> faces = await lenientDetector.processImage(inputImage);
    lenientDetector.close();
    
    if (faces.isNotEmpty) {
      print("⚠️ $strategyName: Basic face detected, creating optimized features...");
      Face face = faces.first;
      
      // Create features and optimize
      FaceFeatures basicFeatures = _extractBasicFeatures(face);
      return _optimizeFeatures(basicFeatures);
    }
    
    return null;
  } catch (e) {
    lenientDetector.close();
    print("❌ $strategyName error: $e");
    return null;
  }
}

/// Core detection with validation
Future<FaceFeatures?> _performDetectionWithValidation(
    InputImage inputImage, FaceDetector detector, String strategyName) async {
  try {
    print("🔍 Strategy: $strategyName");
    
    Stopwatch stopwatch = Stopwatch()..start();
    List<Face> faces = await detector.processImage(inputImage);
    stopwatch.stop();
    
    print("⏱️ $strategyName detection time: ${stopwatch.elapsedMilliseconds}ms");
    print("📊 $strategyName: ${faces.length} faces detected");
    
    if (faces.isEmpty) {
      print("❌ $strategyName: No faces found");
      return null;
    }
    
    // Process the best face
    Face face = _selectBestFace(faces);
    print("📏 $strategyName selected face bounds: ${face.boundingBox}");
    
    // Quality checks
    if (!_isQualityFace(face)) {
      print("⚠️ $strategyName: Face quality insufficient");
      return null;
    }
    
    // Extract features
    FaceFeatures faceFeatures = _extractFeatures(face, strategyName);
    
    // Validate extracted features
    int detectedLandmarks = _countDetectedLandmarks(faceFeatures);
    print("🎯 $strategyName: $detectedLandmarks/10 landmarks detected");
    
    // Feature validation
    bool hasEssentialFeatures = _hasEssentialFeatures(faceFeatures);
    double landmarkQuality = _calculateLandmarkQuality(faceFeatures);
    
    print("📊 $strategyName quality metrics:");
    print("   - Essential features: $hasEssentialFeatures");
    print("   - Landmark quality: ${(landmarkQuality * 100).toStringAsFixed(1)}%");
    print("   - Feature distribution: ${_analyzeFeatureDistribution(faceFeatures)}");
    
    if (hasEssentialFeatures && landmarkQuality >= 0.3) {
      print("🎉 $strategyName: SUCCESS - Quality features detected");
      return faceFeatures;
    } else {
      print("❌ $strategyName: Insufficient feature quality");
      return null;
    }
    
  } catch (e) {
    print("❌ Error in $strategyName: $e");
    return null;
  }
}

/// Select the best face from multiple detected faces
Face _selectBestFace(List<Face> faces) {
  if (faces.length == 1) return faces.first;
  
  // Score faces based on multiple criteria
  Face bestFace = faces.first;
  double bestScore = 0.0;
  
  for (Face face in faces) {
    double score = _calculateFaceScore(face);
    
    if (score > bestScore) {
      bestScore = score;
      bestFace = face;
    }
  }
  
  print("📊 Selected best face with score: ${bestScore.toStringAsFixed(2)}");
  return bestFace;
}

/// Calculate comprehensive face score
double _calculateFaceScore(Face face) {
  double score = 0.0;
  
  // Size score (larger faces generally better)
  double faceArea = face.boundingBox.width * face.boundingBox.height;
  double sizeScore = math.min(faceArea / 50000, 1.0);
  score += sizeScore * 0.3;
  
  // Position score (centered faces better)
  double centerX = face.boundingBox.left + face.boundingBox.width / 2;
  double centerY = face.boundingBox.top + face.boundingBox.height / 2;
  double distanceFromCenter = math.sqrt(math.pow(centerX - 500, 2) + math.pow(centerY - 500, 2));
  double positionScore = math.max(0.0, 1.0 - distanceFromCenter / 700);
  score += positionScore * 0.2;
  
  // Orientation score (straight faces better)
  double orientationScore = 1.0;
  if (face.headEulerAngleX != null && face.headEulerAngleY != null && face.headEulerAngleZ != null) {
    double totalRotation = (face.headEulerAngleX!.abs() + face.headEulerAngleY!.abs() + face.headEulerAngleZ!.abs()) / 3;
    orientationScore = math.max(0.0, 1.0 - totalRotation / 30);
  }
  score += orientationScore * 0.3;
  
  // Eye open score
  double eyeScore = 1.0;
  if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
    eyeScore = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2;
  }
  score += eyeScore * 0.2;
  
  return score;
}

/// Face quality check
bool _isQualityFace(Face face) {
  // Size check
  double faceArea = face.boundingBox.width * face.boundingBox.height;
  if (faceArea < 8000) {
    print("⚠️ Face too small: ${faceArea.toStringAsFixed(0)} pixels²");
    return false;
  }
  
  // Orientation check
  if (face.headEulerAngleX != null && face.headEulerAngleY != null && face.headEulerAngleZ != null) {
    double maxRotation = math.max(
      face.headEulerAngleX!.abs(),
      math.max(face.headEulerAngleY!.abs(), face.headEulerAngleZ!.abs())
    );
    
    if (maxRotation > 30) {
      print("⚠️ Face too rotated: ${maxRotation.toStringAsFixed(1)}°");
      return false;
    }
  }
  
  // Eye open check
  if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
    if (face.leftEyeOpenProbability! < 0.2 || face.rightEyeOpenProbability! < 0.2) {
      print("⚠️ Eyes not sufficiently open");
      return false;
    }
  }
  
  return true;
}

/// Extract features with validation
FaceFeatures _extractFeatures(Face face, String strategyName) {
  print("📍 Starting feature extraction for $strategyName...");
  
  FaceFeatures features = FaceFeatures(
    rightEar: _extractLandmarkSafe(face, FaceLandmarkType.rightEar, 'rightEar'),
    leftEar: _extractLandmarkSafe(face, FaceLandmarkType.leftEar, 'leftEar'),
    rightMouth: _extractLandmarkSafe(face, FaceLandmarkType.rightMouth, 'rightMouth'),
    leftMouth: _extractLandmarkSafe(face, FaceLandmarkType.leftMouth, 'leftMouth'),
    rightEye: _extractLandmarkSafe(face, FaceLandmarkType.rightEye, 'rightEye'),
    leftEye: _extractLandmarkSafe(face, FaceLandmarkType.leftEye, 'leftEye'),
    rightCheek: _extractLandmarkSafe(face, FaceLandmarkType.rightCheek, 'rightCheek'),
    leftCheek: _extractLandmarkSafe(face, FaceLandmarkType.leftCheek, 'leftCheek'),
    noseBase: _extractLandmarkSafe(face, FaceLandmarkType.noseBase, 'noseBase'),
    bottomMouth: _extractLandmarkSafe(face, FaceLandmarkType.bottomMouth, 'bottomMouth'),
  );
  
  print("📊 Feature extraction completed for $strategyName");
  return features;
}

/// Safe landmark extraction with validation
Points? _extractLandmarkSafe(Face face, FaceLandmarkType landmarkType, String landmarkName) {
  try {
    final landmark = face.landmarks[landmarkType];
    if (landmark != null) {
      double x = landmark.position.x.toDouble();
      double y = landmark.position.y.toDouble();
      
      // Validate coordinates are reasonable
      if (x >= 0 && y >= 0 && x < 10000 && y < 10000) {
        Points point = Points(x: x, y: y);
        
        // Check if point is within face bounds
        if (_isPointWithinFaceBounds(point, face.boundingBox)) {
          print("📍 $landmarkName: (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}) ✅");
          return point;
        } else {
          print("⚠️ $landmarkName: Point outside face bounds");
          return null;
        }
      } else {
        print("⚠️ $landmarkName: Invalid coordinates (${x}, ${y})");
        return null;
      }
    } else {
      print("❌ $landmarkName: Landmark not detected");
      return null;
    }
  } catch (e) {
    print("❌ Error extracting $landmarkName: $e");
    return null;
  }
}

/// Validate point is within face bounds (with tolerance)
bool _isPointWithinFaceBounds(Points point, Rect faceBounds) {
  if (point.x == null || point.y == null) return false;
  
  // Add 20% tolerance around face bounds
  double tolerance = 0.2;
  double expandedLeft = faceBounds.left - (faceBounds.width * tolerance);
  double expandedTop = faceBounds.top - (faceBounds.height * tolerance);
  double expandedRight = faceBounds.right + (faceBounds.width * tolerance);
  double expandedBottom = faceBounds.bottom + (faceBounds.height * tolerance);
  
  return point.x! >= expandedLeft && 
         point.x! <= expandedRight && 
         point.y! >= expandedTop && 
         point.y! <= expandedBottom;
}

/// Optimize features for better accuracy
FaceFeatures _optimizeFeatures(FaceFeatures features) {
  print("🎯 Applying feature optimization...");
  
  // Apply coordinate smoothing
  FaceFeatures smoothedFeatures = _applySmoothingFilter(features);
  
  // Validate and fix symmetry
  FaceFeatures symmetryOptimized = _optimizeFeatureSymmetry(smoothedFeatures);
  
  // Apply proportional corrections
  FaceFeatures proportionOptimized = _applyProportionalCorrections(symmetryOptimized);
  
  print("✅ Feature optimization completed");
  return proportionOptimized;
}

/// Apply smoothing filter to reduce noise
FaceFeatures _applySmoothingFilter(FaceFeatures features) {
  return FaceFeatures(
    rightEar: _smoothPoint(features.rightEar),
    leftEar: _smoothPoint(features.leftEar),
    rightMouth: _smoothPoint(features.rightMouth),
    leftMouth: _smoothPoint(features.leftMouth),
    rightEye: _smoothPoint(features.rightEye),
    leftEye: _smoothPoint(features.leftEye),
    rightCheek: _smoothPoint(features.rightCheek),
    leftCheek: _smoothPoint(features.leftCheek),
    noseBase: _smoothPoint(features.noseBase),
    bottomMouth: _smoothPoint(features.bottomMouth),
  );
}

/// Smooth individual point coordinates
Points? _smoothPoint(Points? point) {
  if (point == null || point.x == null || point.y == null) return point;
  
  // Round to half-pixel precision to reduce noise
  double smoothedX = (point.x! * 2).round() / 2;
  double smoothedY = (point.y! * 2).round() / 2;
  
  return Points(x: smoothedX, y: smoothedY);
}

/// Optimize feature symmetry
FaceFeatures _optimizeFeatureSymmetry(FaceFeatures features) {
  if (features.leftEye == null || features.rightEye == null) return features;
  
  // Calculate center line
  double centerX = (features.leftEye!.x! + features.rightEye!.x!) / 2;
  
  // Adjust nose to be more centered if it's slightly off
  if (features.noseBase != null) {
    double noseOffset = (features.noseBase!.x! - centerX).abs();
    if (noseOffset > 5 && noseOffset < 20) {
      features.noseBase = Points(
        x: centerX, 
        y: features.noseBase!.y!
      );
      print("🔧 Applied nose centering correction");
    }
  }
  
  return features;
}

/// Apply proportional corrections
FaceFeatures _applyProportionalCorrections(FaceFeatures features) {
  // Check and correct eye level if needed
  if (features.leftEye != null && features.rightEye != null) {
    double eyeLevelDiff = (features.leftEye!.y! - features.rightEye!.y!).abs();
    
    if (eyeLevelDiff > 10 && eyeLevelDiff < 25) {
      double avgY = (features.leftEye!.y! + features.rightEye!.y!) / 2;
      
      features.leftEye = Points(x: features.leftEye!.x!, y: avgY);
      features.rightEye = Points(x: features.rightEye!.x!, y: avgY);
      
      print("🔧 Applied eye level correction");
    }
  }
  
  return features;
}

/// Extract basic features from face
FaceFeatures _extractBasicFeatures(Face face) {
  return FaceFeatures(
    rightEar: _extractLandmarkSafe(face, FaceLandmarkType.rightEar, 'rightEar'),
    leftEar: _extractLandmarkSafe(face, FaceLandmarkType.leftEar, 'leftEar'),
    rightMouth: _extractLandmarkSafe(face, FaceLandmarkType.rightMouth, 'rightMouth'),
    leftMouth: _extractLandmarkSafe(face, FaceLandmarkType.leftMouth, 'leftMouth'),
    rightEye: _extractLandmarkSafe(face, FaceLandmarkType.rightEye, 'rightEye'),
    leftEye: _extractLandmarkSafe(face, FaceLandmarkType.leftEye, 'leftEye'),
    rightCheek: _extractLandmarkSafe(face, FaceLandmarkType.rightCheek, 'rightCheek'),
    leftCheek: _extractLandmarkSafe(face, FaceLandmarkType.leftCheek, 'leftCheek'),
    noseBase: _extractLandmarkSafe(face, FaceLandmarkType.noseBase, 'noseBase'),
    bottomMouth: _extractLandmarkSafe(face, FaceLandmarkType.bottomMouth, 'bottomMouth'),
  );
}

/// Validate feature quality
bool _validateFeatureQuality(FaceFeatures features, double threshold) {
  double quality = _getFeatureQualityScore(features);
  bool isValid = quality >= threshold;
  
  print("📊 Feature quality validation:");
  print("   - Quality score: ${(quality * 100).toStringAsFixed(1)}%");
  print("   - Threshold: ${(threshold * 100).toStringAsFixed(1)}%");
  print("   - Result: ${isValid ? 'PASS' : 'FAIL'}");
  
  return isValid;
}

/// Get feature quality score
double _getFeatureQualityScore(FaceFeatures features) {
  int totalFeatures = 10;
  int detectedFeatures = _countDetectedLandmarks(features);
  double baseScore = detectedFeatures / totalFeatures;
  
  // Bonus scoring
  double bonusScore = 0.0;
  
  // Essential features (eyes + nose) - critical for authentication
  if (features.rightEye != null && features.leftEye != null) bonusScore += 0.3;
  if (features.noseBase != null) bonusScore += 0.2;
  
  // Important features (mouth)
  if (features.leftMouth != null && features.rightMouth != null) bonusScore += 0.15;
  
  // Symmetry bonus
  if (features.leftEye != null && features.rightEye != null &&
      features.leftMouth != null && features.rightMouth != null) {
    bonusScore += 0.1;
  }
  
  // Completeness bonus
  if (detectedFeatures >= 7) bonusScore += 0.1;
  if (detectedFeatures >= 5) bonusScore += 0.05;
  
  // Quality consistency bonus
  if (_hasGoodFeatureDistribution(features)) bonusScore += 0.1;
  
  double finalScore = (baseScore * 0.6) + (bonusScore * 0.4);
  return math.min(finalScore, 1.0);
}

/// Check if features have good distribution across face
bool _hasGoodFeatureDistribution(FaceFeatures features) {
  int upperFeatures = 0;  // Eyes, ears
  int middleFeatures = 0; // Nose, cheeks
  int lowerFeatures = 0;  // Mouth
  
  if (features.leftEye != null) upperFeatures++;
  if (features.rightEye != null) upperFeatures++;
  if (features.leftEar != null) upperFeatures++;
  if (features.rightEar != null) upperFeatures++;
  
  if (features.noseBase != null) middleFeatures++;
  if (features.leftCheek != null) middleFeatures++;
  if (features.rightCheek != null) middleFeatures++;
  
  if (features.leftMouth != null) lowerFeatures++;
  if (features.rightMouth != null) lowerFeatures++;
  if (features.bottomMouth != null) lowerFeatures++;
  
  // Good distribution means features in at least 2 of 3 regions
  int regionsWithFeatures = 0;
  if (upperFeatures > 0) regionsWithFeatures++;
  if (middleFeatures > 0) regionsWithFeatures++;
  if (lowerFeatures > 0) regionsWithFeatures++;
  
  return regionsWithFeatures >= 2;
}

/// Analyze feature distribution for debugging
String _analyzeFeatureDistribution(FaceFeatures features) {
  int upperFeatures = 0;
  int middleFeatures = 0;
  int lowerFeatures = 0;
  
  if (features.leftEye != null) upperFeatures++;
  if (features.rightEye != null) upperFeatures++;
  if (features.leftEar != null) upperFeatures++;
  if (features.rightEar != null) upperFeatures++;
  
  if (features.noseBase != null) middleFeatures++;
  if (features.leftCheek != null) middleFeatures++;
  if (features.rightCheek != null) middleFeatures++;
  
  if (features.leftMouth != null) lowerFeatures++;
  if (features.rightMouth != null) lowerFeatures++;
  if (features.bottomMouth != null) lowerFeatures++;
  
  return "Upper:$upperFeatures Middle:$middleFeatures Lower:$lowerFeatures";
}

/// Calculate landmark quality
double _calculateLandmarkQuality(FaceFeatures features) {
  int totalPossible = 10;
  int detected = _countDetectedLandmarks(features);
  
  // Quality calculation
  double detectionRatio = detected / totalPossible;
  double essentialRatio = _getEssentialFeatureRatio(features);
  double distributionScore = _hasGoodFeatureDistribution(features) ? 1.0 : 0.5;
  
  double finalQuality = (detectionRatio * 0.4) + (essentialRatio * 0.4) + (distributionScore * 0.2);
  
  return math.min(finalQuality, 1.0);
}

/// Get ratio of essential features detected
double _getEssentialFeatureRatio(FaceFeatures features) {
  int essentialCount = 0;
  int totalEssential = 3;  // Eyes + nose
  
  if (features.leftEye != null) essentialCount++;
  if (features.rightEye != null) essentialCount++;
  if (features.noseBase != null) essentialCount++;
  
  return essentialCount / totalEssential;
}

/// Check if has essential features for authentication
bool _hasEssentialFeatures(FaceFeatures features) {
  return features.rightEye != null && 
         features.leftEye != null && 
         features.noseBase != null;
}

/// Production validation for face features
bool validateFaceFeatures(FaceFeatures features) {
  bool hasEssential = _hasEssentialFeatures(features);
  bool qualityPass = _getFeatureQualityScore(features) >= 0.35;
  bool hasSymmetricEyes = features.leftEye != null && features.rightEye != null;
  bool hasMouthFeatures = features.leftMouth != null || features.rightMouth != null;
  bool goodDistribution = _hasGoodFeatureDistribution(features);
  
  bool isValid = hasEssential && qualityPass && hasSymmetricEyes && goodDistribution;
  
  print("🎯 Production Face validation result: ${isValid ? 'PASS' : 'FAIL'}");
  print("   - Essential features (eyes + nose): ${hasEssential ? '✅' : '❌'}");
  print("   - Quality score ≥35%: ${qualityPass ? '✅' : '❌'}");
  print("   - Symmetric eyes: ${hasSymmetricEyes ? '✅' : '❌'}");
  print("   - Mouth features: ${hasMouthFeatures ? '✅' : '❌'}");
  print("   - Good distribution: ${goodDistribution ? '✅' : '❌'}");
  
  return isValid;
}

/// Get quality score for face features
double getFaceFeatureQuality(FaceFeatures features) {
  return _getFeatureQualityScore(features);
}

/// Count detected landmarks
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

/// Simple version for backward compatibility  
Future<FaceFeatures?> extractFaceFeaturesSimple(
    InputImage inputImage, FaceDetector faceDetector) async {
  try {
    print("🔄 Using simple face extraction (backward compatibility)...");
    
    List<Face> faceList = await faceDetector.processImage(inputImage);
    
    if (faceList.isEmpty) {
      print("❌ No faces detected in simple extraction");
      return null;
    }
    
    Face face = faceList.first;
    print("✅ Face detected in simple extraction");

    FaceFeatures faceFeatures = _extractBasicFeatures(face);
    
    print("✅ Simple extraction completed with ${_countDetectedLandmarks(faceFeatures)} landmarks");
    return faceFeatures;
  } catch (e) {
    print('❌ Error in simple face extraction: $e');
    return null;
  }
}