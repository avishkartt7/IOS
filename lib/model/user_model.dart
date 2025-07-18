// lib/model/user_model.dart - ENHANCED VERSION WITH QUALITY METADATA

import 'dart:math' as math;

class UserModel {
  String? id;
  String? name;
  String? image;
  FaceFeatures? faceFeatures;
  EnhancedFaceFeatures? enhancedFaceFeatures; // ✅ NEW
  int? registeredOn;
  double? faceQualityScore; // ✅ NEW
  String? registrationMethod; // ✅ NEW

  UserModel({
    this.id,
    this.name,
    this.image,
    this.faceFeatures,
    this.enhancedFaceFeatures, // ✅ NEW
    this.registeredOn,
    this.faceQualityScore, // ✅ NEW
    this.registrationMethod, // ✅ NEW
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      faceFeatures: json["faceFeatures"] != null 
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      enhancedFaceFeatures: json["enhancedFaceFeatures"] != null 
          ? EnhancedFaceFeatures.fromJson(json["enhancedFaceFeatures"])
          : null, // ✅ NEW
      registeredOn: json['registeredOn'],
      faceQualityScore: json['faceQualityScore']?.toDouble(), // ✅ NEW
      registrationMethod: json['registrationMethod'], // ✅ NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'faceFeatures': faceFeatures?.toJson(),
      'enhancedFaceFeatures': enhancedFaceFeatures?.toJson(), // ✅ NEW
      'registeredOn': registeredOn,
      'faceQualityScore': faceQualityScore, // ✅ NEW
      'registrationMethod': registrationMethod, // ✅ NEW
    };
  }
}

/// ✅ ENHANCED: Standard FaceFeatures with better validation
class FaceFeatures {
  Points? rightEar;
  Points? leftEar;
  Points? rightEye;
  Points? leftEye;
  Points? rightCheek;
  Points? leftCheek;
  Points? rightMouth;
  Points? leftMouth;
  Points? noseBase;
  Points? bottomMouth;

  FaceFeatures({
    this.rightMouth,
    this.leftMouth,
    this.leftCheek,
    this.rightCheek,
    this.leftEye,
    this.rightEar,
    this.leftEar,
    this.rightEye,
    this.noseBase,
    this.bottomMouth,
  });

  factory FaceFeatures.fromJson(Map<String, dynamic> json) => FaceFeatures(
        rightMouth: json["rightMouth"] != null 
            ? Points.fromJson(json["rightMouth"])
            : null,
        leftMouth: json["leftMouth"] != null 
            ? Points.fromJson(json["leftMouth"])
            : null,
        leftCheek: json["leftCheek"] != null 
            ? Points.fromJson(json["leftCheek"])
            : null,
        rightCheek: json["rightCheek"] != null 
            ? Points.fromJson(json["rightCheek"])
            : null,
        leftEye: json["leftEye"] != null 
            ? Points.fromJson(json["leftEye"])
            : null,
        rightEar: json["rightEar"] != null 
            ? Points.fromJson(json["rightEar"])
            : null,
        leftEar: json["leftEar"] != null 
            ? Points.fromJson(json["leftEar"])
            : null,
        rightEye: json["rightEye"] != null 
            ? Points.fromJson(json["rightEye"])
            : null,
        noseBase: json["noseBase"] != null 
            ? Points.fromJson(json["noseBase"])
            : null,
        bottomMouth: json["bottomMouth"] != null 
            ? Points.fromJson(json["bottomMouth"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "rightMouth": rightMouth?.toJson(),
        "leftMouth": leftMouth?.toJson(),
        "leftCheek": leftCheek?.toJson(),
        "rightCheek": rightCheek?.toJson(),
        "leftEye": leftEye?.toJson(),
        "rightEar": rightEar?.toJson(),
        "leftEar": leftEar?.toJson(),
        "rightEye": rightEye?.toJson(),
        "noseBase": noseBase?.toJson(),
        "bottomMouth": bottomMouth?.toJson(),
      };

  /// ✅ NEW: Validate feature quality
  bool isValidForAuthentication() {
    // Must have essential features (eyes + nose)
    bool hasEssentials = leftEye != null && rightEye != null && noseBase != null;
    
    // Should have at least 5 total features
    int totalFeatures = countFeatures();
    bool hasMinimumFeatures = totalFeatures >= 5;
    
    return hasEssentials && hasMinimumFeatures;
  }

  /// ✅ NEW: Count detected features (public method)
  int countFeatures() {
    return _countFeatures();
  }

  /// ✅ NEW: Count detected features
  int _countFeatures() {
    int count = 0;
    if (rightEar != null) count++;
    if (leftEar != null) count++;
    if (rightEye != null) count++;
    if (leftEye != null) count++;
    if (rightCheek != null) count++;
    if (leftCheek != null) count++;
    if (rightMouth != null) count++;
    if (leftMouth != null) count++;
    if (noseBase != null) count++;
    if (bottomMouth != null) count++;
    return count;
  }

  /// ✅ NEW: Get feature quality score
  double getQualityScore() {
    int totalPossible = 10;
    int detected = countFeatures();
    double baseScore = detected / totalPossible;
    
    // Bonus for essential features
    double essentialBonus = 0.0;
    if (leftEye != null && rightEye != null) essentialBonus += 0.3;
    if (noseBase != null) essentialBonus += 0.2;
    if (leftMouth != null && rightMouth != null) essentialBonus += 0.1;
    
    return (baseScore * 0.7) + (essentialBonus * 0.3);
  }

  /// ✅ NEW: Create summary for debugging
  String getSummary() {
    List<String> available = [];
    List<String> missing = [];
    
    if (leftEye != null) available.add('LE'); else missing.add('LE');
    if (rightEye != null) available.add('RE'); else missing.add('RE');
    if (noseBase != null) available.add('N'); else missing.add('N');
    if (leftMouth != null) available.add('LM'); else missing.add('LM');
    if (rightMouth != null) available.add('RM'); else missing.add('RM');
    if (leftCheek != null) available.add('LC'); else missing.add('LC');
    if (rightCheek != null) available.add('RC'); else missing.add('RC');
    if (leftEar != null) available.add('LEar'); else missing.add('LEar');
    if (rightEar != null) available.add('REar'); else missing.add('REar');
    if (bottomMouth != null) available.add('BM'); else missing.add('BM');
    
    return "Available: [${available.join(',')}] Missing: [${missing.join(',')}] Quality: ${(getQualityScore() * 100).toStringAsFixed(1)}%";
  }
}

/// ✅ NEW: Enhanced FaceFeatures with additional metadata for better accuracy
class EnhancedFaceFeatures {
  // Core facial landmarks (same as FaceFeatures)
  Points? rightEar;
  Points? leftEar;
  Points? rightEye;
  Points? leftEye;
  Points? rightCheek;
  Points? leftCheek;
  Points? rightMouth;
  Points? leftMouth;
  Points? noseBase;
  Points? bottomMouth;

  // ✅ NEW: Enhanced metadata for better accuracy
  double? faceQualityScore;
  int? landmarkCount;
  double? faceSymmetryScore;
  Map<String, double>? featureConfidences;
  Map<String, double>? featureDistances;
  Map<String, double>? facialProportions;
  DateTime? captureTimestamp;
  String? detectionMethod;
  double? faceSize;
  Map<String, double>? orientationAngles;

  EnhancedFaceFeatures({
    // Core landmarks
    this.rightEar,
    this.leftEar,
    this.rightEye,
    this.leftEye,
    this.rightCheek,
    this.leftCheek,
    this.rightMouth,
    this.leftMouth,
    this.noseBase,
    this.bottomMouth,
    
    // Enhanced metadata
    this.faceQualityScore,
    this.landmarkCount,
    this.faceSymmetryScore,
    this.featureConfidences,
    this.featureDistances,
    this.facialProportions,
    this.captureTimestamp,
    this.detectionMethod,
    this.faceSize,
    this.orientationAngles,
  });

  factory EnhancedFaceFeatures.fromJson(Map<String, dynamic> json) {
    return EnhancedFaceFeatures(
      // Core landmarks
      rightEar: json["rightEar"] != null ? Points.fromJson(json["rightEar"]) : null,
      leftEar: json["leftEar"] != null ? Points.fromJson(json["leftEar"]) : null,
      rightEye: json["rightEye"] != null ? Points.fromJson(json["rightEye"]) : null,
      leftEye: json["leftEye"] != null ? Points.fromJson(json["leftEye"]) : null,
      rightCheek: json["rightCheek"] != null ? Points.fromJson(json["rightCheek"]) : null,
      leftCheek: json["leftCheek"] != null ? Points.fromJson(json["leftCheek"]) : null,
      rightMouth: json["rightMouth"] != null ? Points.fromJson(json["rightMouth"]) : null,
      leftMouth: json["leftMouth"] != null ? Points.fromJson(json["leftMouth"]) : null,
      noseBase: json["noseBase"] != null ? Points.fromJson(json["noseBase"]) : null,
      bottomMouth: json["bottomMouth"] != null ? Points.fromJson(json["bottomMouth"]) : null,
      
      // Enhanced metadata
      faceQualityScore: json["faceQualityScore"]?.toDouble(),
      landmarkCount: json["landmarkCount"],
      faceSymmetryScore: json["faceSymmetryScore"]?.toDouble(),
      featureConfidences: json["featureConfidences"] != null 
          ? Map<String, double>.from(json["featureConfidences"].map((k, v) => MapEntry(k, v?.toDouble() ?? 0.0)))
          : null,
      featureDistances: json["featureDistances"] != null 
          ? Map<String, double>.from(json["featureDistances"].map((k, v) => MapEntry(k, v?.toDouble() ?? 0.0)))
          : null,
      facialProportions: json["facialProportions"] != null 
          ? Map<String, double>.from(json["facialProportions"].map((k, v) => MapEntry(k, v?.toDouble() ?? 0.0)))
          : null,
      captureTimestamp: json["captureTimestamp"] != null 
          ? DateTime.parse(json["captureTimestamp"])
          : null,
      detectionMethod: json["detectionMethod"],
      faceSize: json["faceSize"]?.toDouble(),
      orientationAngles: json["orientationAngles"] != null 
          ? Map<String, double>.from(json["orientationAngles"].map((k, v) => MapEntry(k, v?.toDouble() ?? 0.0)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Core landmarks
      "rightEar": rightEar?.toJson(),
      "leftEar": leftEar?.toJson(),
      "rightEye": rightEye?.toJson(),
      "leftEye": leftEye?.toJson(),
      "rightCheek": rightCheek?.toJson(),
      "leftCheek": leftCheek?.toJson(),
      "rightMouth": rightMouth?.toJson(),
      "leftMouth": leftMouth?.toJson(),
      "noseBase": noseBase?.toJson(),
      "bottomMouth": bottomMouth?.toJson(),
      
      // Enhanced metadata
      "faceQualityScore": faceQualityScore,
      "landmarkCount": landmarkCount,
      "faceSymmetryScore": faceSymmetryScore,
      "featureConfidences": featureConfidences,
      "featureDistances": featureDistances,
      "facialProportions": facialProportions,
      "captureTimestamp": captureTimestamp?.toIso8601String(),
      "detectionMethod": detectionMethod,
      "faceSize": faceSize,
      "orientationAngles": orientationAngles,
    };
  }

  /// ✅ Convert to standard FaceFeatures for backward compatibility
  FaceFeatures toStandardFaceFeatures() {
    return FaceFeatures(
      rightEar: rightEar,
      leftEar: leftEar,
      rightEye: rightEye,
      leftEye: leftEye,
      rightCheek: rightCheek,
      leftCheek: leftCheek,
      rightMouth: rightMouth,
      leftMouth: leftMouth,
      noseBase: noseBase,
      bottomMouth: bottomMouth,
    );
  }

  /// ✅ Create enhanced features from standard features
  static EnhancedFaceFeatures fromStandardFeatures(
    FaceFeatures features, {
    double? qualityScore,
    String? method,
    double? symmetryScore,
  }) {
    return EnhancedFaceFeatures(
      // Copy core landmarks
      rightEar: features.rightEar,
      leftEar: features.leftEar,
      rightEye: features.rightEye,
      leftEye: features.leftEye,
      rightCheek: features.rightCheek,
      leftCheek: features.leftCheek,
      rightMouth: features.rightMouth,
      leftMouth: features.leftMouth,
      noseBase: features.noseBase,
      bottomMouth: features.bottomMouth,
      
      // Add metadata
      faceQualityScore: qualityScore ?? features.getQualityScore(),
      landmarkCount: features.countFeatures(),
      faceSymmetryScore: symmetryScore,
      captureTimestamp: DateTime.now(),
      detectionMethod: method ?? 'standard',
    );
  }

  /// ✅ Validate enhanced features for high-accuracy authentication
  bool isValidForHighAccuracyAuth() {
    // Must have excellent quality score
    bool hasHighQuality = faceQualityScore != null && faceQualityScore! >= 0.7;
    
    // Must have essential landmarks
    bool hasEssentials = leftEye != null && rightEye != null && noseBase != null;
    
    // Should have good landmark count
    bool hasGoodLandmarkCount = landmarkCount != null && landmarkCount! >= 6;
    
    // Should have reasonable symmetry
    bool hasGoodSymmetry = faceSymmetryScore == null || faceSymmetryScore! >= 0.6;
    
    return hasHighQuality && hasEssentials && hasGoodLandmarkCount && hasGoodSymmetry;
  }

  /// ✅ Get comprehensive quality metrics
  Map<String, dynamic> getQualityMetrics() {
    return {
      'qualityScore': faceQualityScore ?? 0.0,
      'landmarkCount': landmarkCount ?? 0,
      'symmetryScore': faceSymmetryScore ?? 0.0,
      'hasEssentials': leftEye != null && rightEye != null && noseBase != null,
      'isHighQuality': isValidForHighAccuracyAuth(),
      'detectionMethod': detectionMethod ?? 'unknown',
      'captureAge': captureTimestamp != null 
          ? DateTime.now().difference(captureTimestamp!).inMinutes
          : null,
    };
  }

  /// ✅ Create detailed summary for debugging
  String getDetailedSummary() {
    StringBuffer summary = StringBuffer();
    
    // Basic info
    summary.writeln("📊 Enhanced Face Features Summary:");
    summary.writeln("   Quality Score: ${faceQualityScore?.toStringAsFixed(3) ?? 'N/A'}");
    summary.writeln("   Landmark Count: ${landmarkCount ?? 'N/A'}/10");
    summary.writeln("   Symmetry Score: ${faceSymmetryScore?.toStringAsFixed(3) ?? 'N/A'}");
    summary.writeln("   Detection Method: ${detectionMethod ?? 'N/A'}");
    summary.writeln("   Face Size: ${faceSize?.toStringAsFixed(1) ?? 'N/A'}");
    
    // Landmarks status
    List<String> available = [];
    List<String> missing = [];
    
    if (leftEye != null) available.add('LE'); else missing.add('LE');
    if (rightEye != null) available.add('RE'); else missing.add('RE');
    if (noseBase != null) available.add('N'); else missing.add('N');
    if (leftMouth != null) available.add('LM'); else missing.add('LM');
    if (rightMouth != null) available.add('RM'); else missing.add('RM');
    if (leftCheek != null) available.add('LC'); else missing.add('LC');
    if (rightCheek != null) available.add('RC'); else missing.add('RC');
    if (leftEar != null) available.add('LEar'); else missing.add('LEar');
    if (rightEar != null) available.add('REar'); else missing.add('REar');
    if (bottomMouth != null) available.add('BM'); else missing.add('BM');
    
    summary.writeln("   Available: [${available.join(', ')}]");
    summary.writeln("   Missing: [${missing.join(', ')}]");
    
    // Quality assessment
    bool isValid = isValidForHighAccuracyAuth();
    summary.writeln("   ✅ Validation: ${isValid ? 'PASS (High Accuracy Ready)' : 'NEEDS IMPROVEMENT'}");
    
    return summary.toString();
  }

  @override
  String toString() {
    return "EnhancedFaceFeatures(quality: ${faceQualityScore?.toStringAsFixed(2)}, landmarks: $landmarkCount, method: $detectionMethod)";
  }
}

/// ✅ ENHANCED: Points class with validation and utility methods
class Points {
  double? x;
  double? y;

  Points({
    required this.x,
    required this.y,
  });

  factory Points.fromJson(Map<String, dynamic> json) => Points(
        x: json['x'] != null ? (json['x'] as num).toDouble() : null,
        y: json['y'] != null ? (json['y'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'x': x, 
        'y': y
      };

  /// ✅ NEW: Validate point coordinates
  bool isValid() {
    return x != null && y != null && 
           x! >= 0 && y! >= 0 && 
           x! < 10000 && y! < 10000;  // Reasonable coordinate bounds
  }

  /// ✅ NEW: Calculate distance to another point
  double distanceTo(Points other) {
    if (!isValid() || !other.isValid()) return double.infinity;
    
    double dx = x! - other.x!;
    double dy = y! - other.y!;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// ✅ NEW: Get midpoint between this and another point
  Points? midpointTo(Points other) {
    if (!isValid() || !other.isValid()) return null;
    
    return Points(
      x: (x! + other.x!) / 2,
      y: (y! + other.y!) / 2,
    );
  }

  /// ✅ NEW: Apply smoothing filter
  Points smoothed() {
    if (!isValid()) return this;
    
    // Round to half-pixel precision to reduce noise
    return Points(
      x: (x! * 2).round() / 2,
      y: (y! * 2).round() / 2,
    );
  }

  @override
  String toString() => 'Points(x: $x, y: $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Points &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// ✅ NEW: Utility class for face feature analysis
class FaceFeatureAnalyzer {
  /// Calculate similarity between two feature sets
  static double calculateSimilarity(FaceFeatures features1, FaceFeatures features2) {
    if (!features1.isValidForAuthentication() || !features2.isValidForAuthentication()) {
      return 0.0;
    }
    
    int matches = 0;
    int total = 0;
    
    // Compare each landmark with tolerance
    matches += _compareFeature(features1.leftEye, features2.leftEye, 35.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.rightEye, features2.rightEye, 35.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.noseBase, features2.noseBase, 40.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.leftMouth, features2.leftMouth, 50.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.rightMouth, features2.rightMouth, 50.0) ? 1 : 0; total++;
    
    return total > 0 ? (matches / total) * 100 : 0.0;
  }
  
  static bool _compareFeature(Points? p1, Points? p2, double tolerance) {
    if (p1 == null || p2 == null) return false;
    return p1.distanceTo(p2) <= tolerance;
  }
  
  /// Get feature quality recommendations
  static List<String> getQualityRecommendations(FaceFeatures features) {
    List<String> recommendations = [];
    
    double quality = features.getQualityScore();
    
    if (quality < 0.3) {
      recommendations.add("Very poor quality - retake photo with better lighting");
    } else if (quality < 0.5) {
      recommendations.add("Poor quality - improve lighting and face position");
    } else if (quality < 0.7) {
      recommendations.add("Moderate quality - can be improved");
    } else {
      recommendations.add("Good quality for authentication");
    }
    
    if (features.leftEye == null || features.rightEye == null) {
      recommendations.add("❌ Eyes not detected - ensure eyes are visible and open");
    }
    
    if (features.noseBase == null) {
      recommendations.add("❌ Nose not detected - face camera directly");
    }
    
    if (features.leftMouth == null && features.rightMouth == null) {
      recommendations.add("⚠️ Mouth not detected - remove any obstructions");
    }
    
    return recommendations;
  }
}