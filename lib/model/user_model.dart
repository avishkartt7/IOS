// lib/model/user_model.dart - Production Ready

import 'dart:math' as math;

class UserModel {
  String? id;
  String? name;
  String? image;
  FaceFeatures? faceFeatures;
  int? registeredOn;
  double? faceQualityScore;
  String? registrationMethod;

  UserModel({
    this.id,
    this.name,
    this.image,
    this.faceFeatures,
    this.registeredOn,
    this.faceQualityScore,
    this.registrationMethod,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      faceFeatures: json["faceFeatures"] != null 
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      registeredOn: json['registeredOn'],
      faceQualityScore: json['faceQualityScore']?.toDouble(),
      registrationMethod: json['registrationMethod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'faceFeatures': faceFeatures?.toJson(),
      'registeredOn': registeredOn,
      'faceQualityScore': faceQualityScore,
      'registrationMethod': registrationMethod,
    };
  }
}

/// Production-ready FaceFeatures with validation
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

  /// Validate feature quality for authentication
  bool isValidForAuthentication() {
    // Must have essential features (eyes + nose)
    bool hasEssentials = leftEye != null && rightEye != null && noseBase != null;
    
    // Should have at least 5 total features
    int totalFeatures = countFeatures();
    bool hasMinimumFeatures = totalFeatures >= 5;
    
    return hasEssentials && hasMinimumFeatures;
  }

  /// Count detected features
  int countFeatures() {
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

  /// Get feature quality score
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

  /// Create summary for debugging
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

  /// Check if has good feature distribution
  bool hasGoodDistribution() {
    int upperFeatures = 0;  // Eyes, ears
    int middleFeatures = 0; // Nose, cheeks
    int lowerFeatures = 0;  // Mouth
    
    if (leftEye != null) upperFeatures++;
    if (rightEye != null) upperFeatures++;
    if (leftEar != null) upperFeatures++;
    if (rightEar != null) upperFeatures++;
    
    if (noseBase != null) middleFeatures++;
    if (leftCheek != null) middleFeatures++;
    if (rightCheek != null) middleFeatures++;
    
    if (leftMouth != null) lowerFeatures++;
    if (rightMouth != null) lowerFeatures++;
    if (bottomMouth != null) lowerFeatures++;
    
    // Good distribution means features in at least 2 of 3 regions
    int regionsWithFeatures = 0;
    if (upperFeatures > 0) regionsWithFeatures++;
    if (middleFeatures > 0) regionsWithFeatures++;
    if (lowerFeatures > 0) regionsWithFeatures++;
    
    return regionsWithFeatures >= 2;
  }

  /// Get essential feature ratio
  double getEssentialFeatureRatio() {
    int essentialCount = 0;
    int totalEssential = 3;  // Eyes + nose
    
    if (leftEye != null) essentialCount++;
    if (rightEye != null) essentialCount++;
    if (noseBase != null) essentialCount++;
    
    return essentialCount / totalEssential;
  }

  /// Calculate face symmetry score
  double getSymmetryScore() {
    if (leftEye == null || rightEye == null || noseBase == null) {
      return 0.0;
    }
    
    double eyeMidX = (leftEye!.x! + rightEye!.x!) / 2;
    double noseOffset = (noseBase!.x! - eyeMidX).abs();
    double eyeDistance = leftEye!.distanceTo(rightEye!);
    
    if (eyeDistance == 0) return 0.0;
    
    double symmetryRatio = 1.0 - (noseOffset / (eyeDistance / 2));
    return math.max(0.0, math.min(1.0, symmetryRatio));
  }

  /// Get comprehensive quality metrics
  Map<String, dynamic> getQualityMetrics() {
    return {
      'qualityScore': getQualityScore(),
      'landmarkCount': countFeatures(),
      'symmetryScore': getSymmetryScore(),
      'hasEssentials': leftEye != null && rightEye != null && noseBase != null,
      'isValidForAuth': isValidForAuthentication(),
      'hasGoodDistribution': hasGoodDistribution(),
      'essentialRatio': getEssentialFeatureRatio(),
    };
  }
}

/// Production-ready Points class with validation and utility methods
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

  /// Validate point coordinates
  bool isValid() {
    return x != null && y != null && 
           x! >= 0 && y! >= 0 && 
           x! < 10000 && y! < 10000;
  }

  /// Calculate distance to another point
  double distanceTo(Points other) {
    if (!isValid() || !other.isValid()) return double.infinity;
    
    double dx = x! - other.x!;
    double dy = y! - other.y!;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Get midpoint between this and another point
  Points? midpointTo(Points other) {
    if (!isValid() || !other.isValid()) return null;
    
    return Points(
      x: (x! + other.x!) / 2,
      y: (y! + other.y!) / 2,
    );
  }

  /// Apply smoothing filter
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

/// Utility class for face feature analysis
class FaceFeatureAnalyzer {
  /// Calculate similarity between two feature sets
  static double calculateSimilarity(FaceFeatures features1, FaceFeatures features2) {
    if (!features1.isValidForAuthentication() || !features2.isValidForAuthentication()) {
      return 0.0;
    }
    
    int matches = 0;
    int total = 0;
    
    // Compare each landmark with tolerance
    matches += _compareFeature(features1.leftEye, features2.leftEye, 40.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.rightEye, features2.rightEye, 40.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.noseBase, features2.noseBase, 45.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.leftMouth, features2.leftMouth, 55.0) ? 1 : 0; total++;
    matches += _compareFeature(features1.rightMouth, features2.rightMouth, 55.0) ? 1 : 0; total++;
    
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

  /// Compare features with detailed analysis
  static Map<String, dynamic> compareFeatures(FaceFeatures stored, FaceFeatures current) {
    double similarity = calculateSimilarity(stored, current);
    
    Map<String, bool> featureMatches = {
      'leftEye': _compareFeature(stored.leftEye, current.leftEye, 40.0),
      'rightEye': _compareFeature(stored.rightEye, current.rightEye, 40.0),
      'noseBase': _compareFeature(stored.noseBase, current.noseBase, 45.0),
      'leftMouth': _compareFeature(stored.leftMouth, current.leftMouth, 55.0),
      'rightMouth': _compareFeature(stored.rightMouth, current.rightMouth, 55.0),
    };
    
    int matchCount = featureMatches.values.where((match) => match).length;
    int totalCount = featureMatches.length;
    
    return {
      'similarity': similarity,
      'matchCount': matchCount,
      'totalCount': totalCount,
      'featureMatches': featureMatches,
      'isAcceptable': similarity >= 60.0,
      'qualityStored': stored.getQualityScore(),
      'qualityCurrent': current.getQualityScore(),
    };
  }

  /// Validate features for production use
  static bool validateForProduction(FaceFeatures features) {
    // Must have essential features
    if (!features.isValidForAuthentication()) {
      return false;
    }
    
    // Quality must be reasonable
    if (features.getQualityScore() < 0.4) {
      return false;
    }
    
    // Must have good distribution
    if (!features.hasGoodDistribution()) {
      return false;
    }
    
    return true;
  }

  /// Get detailed analysis for debugging
  static Map<String, dynamic> getDetailedAnalysis(FaceFeatures features) {
    return {
      'summary': features.getSummary(),
      'qualityMetrics': features.getQualityMetrics(),
      'recommendations': getQualityRecommendations(features),
      'isProductionReady': validateForProduction(features),
      'validationChecks': {
        'hasEssentials': features.isValidForAuthentication(),
        'qualityThreshold': features.getQualityScore() >= 0.4,
        'goodDistribution': features.hasGoodDistribution(),
        'symmetryScore': features.getSymmetryScore(),
      }
    };
  }
}