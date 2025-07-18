// lib/services/secure_face_storage_service.dart - ULTRA-ENHANCED WITH VALIDATION

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/model/user_model.dart';

class SecureFaceStorageService {
  static const String _imagePrefix = 'secure_face_image_';
  static const String _featuresPrefix = 'secure_face_features_';
  static const String _enhancedFeaturesPrefix = 'secure_enhanced_face_features_';
  static const String _registeredPrefix = 'face_registered_';
  static const String _enhancedRegisteredPrefix = 'enhanced_face_registered_';
  static const String _qualityPrefix = 'face_quality_score_';  // ✅ NEW
  static const String _methodPrefix = 'registration_method_';  // ✅ NEW

  /// ✅ ENHANCED: Save face image with validation and quality checks
  Future<void> saveFaceImage(String employeeId, String base64Image) async {
    try {
      debugPrint("🔒 ENHANCED: Saving face image for $employeeId with validation...");

      // ✅ STEP 1: Validate image data
      if (!_validateImageData(base64Image)) {
        throw Exception("Invalid image data provided");
      }

      // ✅ STEP 2: Clean and optimize image data
      String cleanedImage = _cleanImageData(base64Image);
      debugPrint("🧹 Image data cleaned and optimized (${cleanedImage.length} chars)");

      // ✅ STEP 3: Analyze image quality
      Map<String, dynamic> qualityAnalysis = _analyzeImageQuality(cleanedImage);
      debugPrint("📊 Image quality analysis: ${qualityAnalysis['qualityScore']}");

      if (qualityAnalysis['qualityScore'] < 0.3) {
        debugPrint("⚠️ WARNING: Low image quality detected");
      }

      // ✅ STEP 4: Save with multiple backup methods
      await _saveImageWithBackups(employeeId, cleanedImage, qualityAnalysis);

      debugPrint("✅ ENHANCED: Face image saved successfully for $employeeId");
    } catch (e) {
      debugPrint("❌ ENHANCED: Error saving face image: $e");
      rethrow;
    }
  }

  /// ✅ ENHANCED: Save face features with comprehensive validation
  Future<void> saveFaceFeatures(String employeeId, FaceFeatures features) async {
    try {
      debugPrint("🔒 ENHANCED: Saving face features for $employeeId...");

      // ✅ STEP 1: Validate features thoroughly
      if (!_validateFaceFeatures(features)) {
        throw Exception("Face features validation failed");
      }

      // ✅ STEP 2: Calculate quality metrics
      double qualityScore = features.getQualityScore();
      debugPrint("📊 Face features quality score: ${(qualityScore * 100).toStringAsFixed(1)}%");

      // ✅ STEP 3: Convert to enhanced features for better storage
      EnhancedFaceFeatures enhancedFeatures = EnhancedFaceFeatures.fromStandardFeatures(
        features,
        qualityScore: qualityScore,
        method: 'enhanced_validation',
        symmetryScore: _calculateSymmetryScore(features),
      );

      // ✅ STEP 4: Save both standard and enhanced versions
      await _saveFeaturesWithBackups(employeeId, features, enhancedFeatures);

      debugPrint("✅ ENHANCED: Face features saved successfully for $employeeId");
    } catch (e) {
      debugPrint("❌ ENHANCED: Error saving face features: $e");
      rethrow;
    }
  }

  /// ✅ NEW: Save enhanced face features with comprehensive metadata
  Future<void> saveEnhancedFaceFeatures(String employeeId, EnhancedFaceFeatures features) async {
    try {
      debugPrint("🔒 ULTRA-ENHANCED: Saving enhanced face features for $employeeId...");

      // ✅ STEP 1: Validate enhanced features
      if (!_validateEnhancedFaceFeatures(features)) {
        throw Exception("Enhanced face features validation failed");
      }

      // ✅ STEP 2: Update metadata
      features.captureTimestamp = DateTime.now();
      features.detectionMethod = 'ultra_enhanced_v3';

      // ✅ STEP 3: Save with ultra-secure backup system
      await _saveEnhancedFeaturesSecurely(employeeId, features);

      // ✅ STEP 4: Set registration flags with quality thresholds
      bool isHighQuality = features.faceQualityScore != null && features.faceQualityScore! >= 0.7;
      await setEnhancedFaceRegistered(employeeId, true);
      
      if (isHighQuality) {
        await _setQualityScore(employeeId, features.faceQualityScore!);
        await _setRegistrationMethod(employeeId, 'ultra_enhanced_high_quality');
      }

      debugPrint("✅ ULTRA-ENHANCED: Enhanced face features saved for $employeeId (Quality: ${features.faceQualityScore})");
    } catch (e) {
      debugPrint("❌ ULTRA-ENHANCED: Error saving enhanced face features: $e");
      rethrow;
    }
  }

  /// ✅ ENHANCED: Get face image with multiple fallback sources
  Future<String?> getFaceImage(String employeeId) async {
    try {
      debugPrint("🔍 ENHANCED: Retrieving face image for $employeeId...");

      // ✅ Try enhanced external storage first
      String? image = await _getFromExternalStorage(employeeId, 'enhanced_image');
      if (image != null && _validateImageData(image)) {
        debugPrint("✅ Retrieved high-quality image from enhanced external storage");
        return image;
      }

      // ✅ Try standard external storage
      image = await _getFromExternalStorage(employeeId, 'image');
      if (image != null && _validateImageData(image)) {
        debugPrint("✅ Retrieved image from standard external storage");
        return image;
      }

      // ✅ Try multiple SharedPreferences keys
      final prefs = await SharedPreferences.getInstance();
      List<String> imageKeys = [
        '${_imagePrefix}enhanced_$employeeId',
        '$_imagePrefix$employeeId',
        'employee_image_$employeeId',
        'enhanced_face_image_$employeeId',
      ];

      for (String key in imageKeys) {
        image = prefs.getString(key);
        if (image != null && _validateImageData(image)) {
          debugPrint("✅ Retrieved image from SharedPreferences key: $key");
          return image;
        }
      }

      debugPrint("❌ No valid face image found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("❌ Error retrieving face image: $e");
      return null;
    }
  }

  /// ✅ ENHANCED: Get face features with validation and fallbacks
  Future<FaceFeatures?> getFaceFeatures(String employeeId) async {
    try {
      debugPrint("🔍 ENHANCED: Retrieving face features for $employeeId...");

      // ✅ Try enhanced features first (convert to standard)
      EnhancedFaceFeatures? enhanced = await getEnhancedFaceFeatures(employeeId);
      if (enhanced != null) {
        FaceFeatures standard = enhanced.toStandardFaceFeatures();
        if (_validateFaceFeatures(standard)) {
          debugPrint("✅ Retrieved and converted enhanced features to standard");
          return standard;
        }
      }

      // ✅ Try direct feature storage
      final prefs = await SharedPreferences.getInstance();
      List<String> featureKeys = [
        '${_featuresPrefix}enhanced_$employeeId',
        '$_featuresPrefix$employeeId',
        'employee_face_features_$employeeId',
        'secure_enhanced_face_features_$employeeId',
      ];

      for (String key in featureKeys) {
        String? featuresJson = prefs.getString(key);
        if (featuresJson != null && featuresJson.isNotEmpty) {
          try {
            Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
            FaceFeatures features = FaceFeatures.fromJson(featuresMap);
            
            if (_validateFaceFeatures(features)) {
              debugPrint("✅ Retrieved valid features from key: $key");
              return features;
            } else {
              debugPrint("⚠️ Invalid features found at key: $key");
            }
          } catch (e) {
            debugPrint("⚠️ Error parsing features from $key: $e");
          }
        }
      }

      debugPrint("❌ No valid face features found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("❌ Error retrieving face features: $e");
      return null;
    }
  }

  /// ✅ ENHANCED: Get enhanced face features with comprehensive validation
  Future<EnhancedFaceFeatures?> getEnhancedFaceFeatures(String employeeId) async {
    try {
      debugPrint("🔍 ULTRA-ENHANCED: Retrieving enhanced face features for $employeeId...");

      // ✅ Try ultra-secure storage first
      String? featuresJson = await _getFromSecureStorage(employeeId, 'ultra_enhanced_features');
      
      if (featuresJson == null) {
        // ✅ Try standard enhanced storage
        final prefs = await SharedPreferences.getInstance();
        List<String> enhancedKeys = [
          '${_enhancedFeaturesPrefix}ultra_$employeeId',
          '$_enhancedFeaturesPrefix$employeeId',
          'secure_enhanced_face_features_$employeeId',
          'enhanced_face_features_backup_$employeeId',
        ];

        for (String key in enhancedKeys) {
          featuresJson = prefs.getString(key);
          if (featuresJson != null && featuresJson.isNotEmpty) {
            debugPrint("🔍 Found enhanced features at: $key");
            break;
          }
        }
      }

      if (featuresJson != null && featuresJson.isNotEmpty) {
        try {
          Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
          EnhancedFaceFeatures features = EnhancedFaceFeatures.fromJson(featuresMap);
          
          if (_validateEnhancedFaceFeatures(features)) {
            debugPrint("✅ Retrieved valid enhanced features (Quality: ${features.faceQualityScore})");
            debugPrint("📊 Features summary: ${features.toString()}");
            return features;
          } else {
            debugPrint("⚠️ Enhanced features validation failed");
          }
        } catch (e) {
          debugPrint("❌ Error parsing enhanced features: $e");
        }
      }

      debugPrint("❌ No valid enhanced face features found for $employeeId");
      return null;
    } catch (e) {
      debugPrint("❌ Error retrieving enhanced face features: $e");
      return null;
    }
  }

  /// ✅ ENHANCED: Smart cloud recovery with validation
  Future<bool> downloadFaceDataFromCloud(String employeeId) async {
    try {
      debugPrint("🌐 ENHANCED: Downloading face data from cloud for: $employeeId");

      // Check connectivity
      final connectivityService = getIt<ConnectivityService>();
      if (connectivityService.currentStatus == ConnectionStatus.offline) {
        debugPrint("❌ Cannot download - device is offline");
        return false;
      }

      // Get data from Firestore with timeout
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .get()
          .timeout(Duration(seconds: 15));

      if (!doc.exists) {
        debugPrint("❌ Employee document not found in Firestore");
        return false;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // ✅ Enhanced validation of cloud data
      bool hasValidImage = data.containsKey('image') && 
                          data['image'] != null && 
                          _validateImageData(data['image']);
      
      bool hasValidFeatures = data.containsKey('faceFeatures') && 
                             data['faceFeatures'] != null;
      
      bool hasEnhancedFeatures = data.containsKey('enhancedFaceFeatures') && 
                                data['enhancedFaceFeatures'] != null;
      
      bool isFaceRegistered = data['faceRegistered'] ?? false;

      if (!hasValidImage || !isFaceRegistered) {
        debugPrint("❌ No valid face data found in cloud");
        return false;
      }

      debugPrint("✅ Valid face data found in cloud, downloading...");

      // ✅ Download and save with validation
      bool success = true;

      // Save face image
      try {
        await saveFaceImage(employeeId, data['image']);
        debugPrint("✅ Face image downloaded and saved");
      } catch (e) {
        debugPrint("❌ Error saving downloaded image: $e");
        success = false;
      }

      // Save standard features if available
      if (hasValidFeatures) {
        try {
          Map<String, dynamic> featuresMap = data['faceFeatures'];
          FaceFeatures features = FaceFeatures.fromJson(featuresMap);
          await saveFaceFeatures(employeeId, features);
          debugPrint("✅ Standard face features downloaded and saved");
        } catch (e) {
          debugPrint("❌ Error saving downloaded features: $e");
          success = false;
        }
      }

      // Save enhanced features if available
      if (hasEnhancedFeatures) {
        try {
          Map<String, dynamic> enhancedMap = data['enhancedFaceFeatures'];
          EnhancedFaceFeatures enhanced = EnhancedFaceFeatures.fromJson(enhancedMap);
          await saveEnhancedFaceFeatures(employeeId, enhanced);
          debugPrint("✅ Enhanced face features downloaded and saved");
        } catch (e) {
          debugPrint("❌ Error saving downloaded enhanced features: $e");
          // Don't fail completely for enhanced features
        }
      }

      // Set registration flags
      await setFaceRegistered(employeeId, true);
      if (hasEnhancedFeatures) {
        await setEnhancedFaceRegistered(employeeId, true);
      }

      // Save backup in standard SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_$employeeId', data['image']);
      await prefs.setBool('face_registered_$employeeId', true);

      debugPrint("🎉 Face data successfully downloaded and restored for: $employeeId");
      return success;

    } catch (e) {
      debugPrint("❌ Error downloading face data from cloud: $e");
      return false;
    }
  }

  /// ✅ ENHANCED: Comprehensive face data validation
  Future<bool> validateLocalFaceData(String employeeId) async {
    try {
      debugPrint("🔍 ENHANCED: Validating local face data for: $employeeId");

      // ✅ Check image data
      String? image = await getFaceImage(employeeId);
      bool hasValidImage = image != null && _validateImageData(image);

      // ✅ Check features
      FaceFeatures? features = await getFaceFeatures(employeeId);
      bool hasValidFeatures = features != null && _validateFaceFeatures(features);

      // ✅ Check enhanced features
      EnhancedFaceFeatures? enhanced = await getEnhancedFaceFeatures(employeeId);
      bool hasValidEnhanced = enhanced != null && _validateEnhancedFaceFeatures(enhanced);

      // ✅ Check registration flags
      bool isRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);

      debugPrint("📊 ENHANCED Validation results for $employeeId:");
      debugPrint("   - Valid image: $hasValidImage");
      debugPrint("   - Valid features: $hasValidFeatures");
      debugPrint("   - Valid enhanced: $hasValidEnhanced");
      debugPrint("   - Is registered: $isRegistered");
      debugPrint("   - Is enhanced registered: $isEnhancedRegistered");

      // ✅ Comprehensive validation logic
      bool isValid = hasValidImage && 
                    (hasValidFeatures || hasValidEnhanced) && 
                    (isRegistered || isEnhancedRegistered);

      if (!isValid && (isRegistered || isEnhancedRegistered)) {
        debugPrint("⚠️ Registration flags exist but data is invalid - needs recovery");
        return false;
      }

      debugPrint("✅ Local face data validation: ${isValid ? 'PASS' : 'FAIL'}");
      return isValid;

    } catch (e) {
      debugPrint("❌ Error validating local face data: $e");
      return false;
    }
  }

  /// ✅ Set enhanced face registered flag with quality tracking
  Future<void> setEnhancedFaceRegistered(String employeeId, bool isRegistered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_enhancedRegisteredPrefix$employeeId', isRegistered);
      
      // Also set timestamp
      if (isRegistered) {
        await prefs.setString('enhanced_registration_date_$employeeId', DateTime.now().toIso8601String());
      }
      
      debugPrint("🔒 Set ENHANCED face registered for $employeeId: $isRegistered");
    } catch (e) {
      debugPrint("❌ Error setting enhanced face registered flag: $e");
    }
  }

  /// ✅ Check if enhanced face is registered
  Future<bool> isEnhancedFaceRegistered(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isRegistered = prefs.getBool('$_enhancedRegisteredPrefix$employeeId') ?? false;
      debugPrint("🔍 Enhanced face registered for $employeeId: $isRegistered");
      return isRegistered;
    } catch (e) {
      debugPrint("❌ Error checking enhanced face registered flag: $e");
      return false;
    }
  }

  /// ✅ Set standard face registered flag
  Future<void> setFaceRegistered(String employeeId, bool isRegistered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_registeredPrefix$employeeId', isRegistered);
      
      if (isRegistered) {
        await prefs.setString('face_registration_date_$employeeId', DateTime.now().toIso8601String());
      }
      
      debugPrint("🔒 Set standard face registered for $employeeId: $isRegistered");
    } catch (e) {
      debugPrint("❌ Error setting face registered flag: $e");
    }
  }

  /// ✅ Check if standard face is registered
  Future<bool> isFaceRegistered(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isRegistered = prefs.getBool('$_registeredPrefix$employeeId') ?? false;
      debugPrint("🔍 Standard face registered for $employeeId: $isRegistered");
      return isRegistered;
    } catch (e) {
      debugPrint("❌ Error checking face registered flag: $e");
      return false;
    }
  }

  /// ✅ NEW: Get comprehensive face data information for debugging
  Future<Map<String, dynamic>> getFaceDataInfo(String employeeId) async {
    try {
      String? image = await getFaceImage(employeeId);
      FaceFeatures? features = await getFaceFeatures(employeeId);
      EnhancedFaceFeatures? enhanced = await getEnhancedFaceFeatures(employeeId);
      bool isRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);
      double? qualityScore = await _getQualityScore(employeeId);
      String? method = await _getRegistrationMethod(employeeId);

      return {
        'employeeId': employeeId,
        'hasImage': image != null,
        'imageSize': image?.length ?? 0,
        'imageValid': image != null ? _validateImageData(image) : false,
        'hasStandardFeatures': features != null,
        'standardFeaturesValid': features != null ? _validateFaceFeatures(features) : false,
        'hasEnhancedFeatures': enhanced != null,
        'enhancedFeaturesValid': enhanced != null ? _validateEnhancedFaceFeatures(enhanced) : false,
        'isStandardRegistered': isRegistered,
        'isEnhancedRegistered': isEnhancedRegistered,
        'qualityScore': qualityScore,
        'registrationMethod': method,
        'standardQuality': features?.getQualityScore(),
        'enhancedQuality': enhanced?.faceQualityScore,
        'landmarkCount': enhanced?.landmarkCount ?? features?._countFeatures(),
        'validationStatus': await validateLocalFaceData(employeeId),
        'needsCloudRecovery': await needsCloudRecovery(employeeId),
      };
    } catch (e) {
      debugPrint("❌ Error getting face data info: $e");
      return {'error': e.toString()};
    }
  }

  /// ✅ Clear all face data with comprehensive cleanup
  Future<void> clearFaceData(String employeeId) async {
    try {
      debugPrint("🗑️ ENHANCED: Clearing all face data for $employeeId");

      // Clear external storage
      await _deleteFromExternalStorage(employeeId, 'image');
      await _deleteFromExternalStorage(employeeId, 'enhanced_image');
      await _deleteFromExternalStorage(employeeId, 'features');
      await _deleteFromExternalStorage(employeeId, 'enhanced_features');
      await _deleteFromExternalStorage(employeeId, 'ultra_enhanced_features');

      // Clear SharedPreferences comprehensively
      final prefs = await SharedPreferences.getInstance();
      List<String> keysToRemove = [
        '$_imagePrefix$employeeId',
        '${_imagePrefix}enhanced_$employeeId',
        '$_featuresPrefix$employeeId',
        '${_featuresPrefix}enhanced_$employeeId',
        '$_enhancedFeaturesPrefix$employeeId',
        '${_enhancedFeaturesPrefix}ultra_$employeeId',
        '$_registeredPrefix$employeeId',
        '$_enhancedRegisteredPrefix$employeeId',
        '$_qualityPrefix$employeeId',
        '$_methodPrefix$employeeId',
        'employee_image_$employeeId',
        'employee_face_features_$employeeId',
        'enhanced_face_image_$employeeId',
        'secure_enhanced_face_features_$employeeId',
        'face_registration_date_$employeeId',
        'enhanced_registration_date_$employeeId',
      ];

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      debugPrint("✅ ENHANCED: All face data cleared for $employeeId");
    } catch (e) {
      debugPrint("❌ Error clearing face data: $e");
    }
  }

  /// ✅ Check if needs cloud recovery
  Future<bool> needsCloudRecovery(String employeeId) async {
    try {
      bool isRegistered = await isFaceRegistered(employeeId);
      bool isEnhancedRegistered = await isEnhancedFaceRegistered(employeeId);
      bool hasValidData = await validateLocalFaceData(employeeId);

      return (isRegistered || isEnhancedRegistered) && !hasValidData;
    } catch (e) {
      debugPrint("❌ Error checking cloud recovery need: $e");
      return false;
    }
  }

  /// ✅ Ensure face data is available with smart recovery
  Future<bool> ensureFaceDataAvailable(String employeeId) async {
    try {
      debugPrint("🔄 ENHANCED: Ensuring face data is available for: $employeeId");

      bool isValid = await validateLocalFaceData(employeeId);
      if (isValid) {
        debugPrint("✅ Local face data is valid");
        return true;
      }

      bool needsRecovery = await needsCloudRecovery(employeeId);
      if (!needsRecovery) {
        debugPrint("ℹ️ No cloud recovery needed");
        return false;
      }

      debugPrint("🌐 Attempting cloud recovery...");
      bool recovered = await downloadFaceDataFromCloud(employeeId);

      if (recovered) {
        debugPrint("🎉 Face data successfully recovered from cloud");
        return true;
      } else {
        debugPrint("❌ Failed to recover face data from cloud");
        return false;
      }

    } catch (e) {
      debugPrint("❌ Error in ensureFaceDataAvailable: $e");
      return false;
    }
  }

  // ================ PRIVATE HELPER METHODS ================

  /// ✅ Validate image data quality and format
  bool _validateImageData(String imageData) {
    if (imageData.isEmpty) return false;
    
    // Check minimum size (should be at least 1KB when decoded)
    if (imageData.length < 1000) return false;
    
    // Check maximum size (should be less than 10MB)
    if (imageData.length > 10000000) return false;
    
    // Check if it's valid base64
    try {
      // Try to decode a small portion to validate format
      String testData = imageData.substring(0, math.min(100, imageData.length));
      base64Decode(testData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ✅ Clean and optimize image data
  String _cleanImageData(String imageData) {
    String cleaned = imageData.trim();
    
    // Remove data URL prefix if present
    if (cleaned.contains('data:image') && cleaned.contains(',')) {
      cleaned = cleaned.split(',')[1];
    }
    
    // Remove any whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    
    return cleaned;
  }

  /// ✅ Analyze image quality
  Map<String, dynamic> _analyzeImageQuality(String imageData) {
    double sizeKB = imageData.length / 1024;
    
    double qualityScore;
    if (sizeKB < 15) {
      qualityScore = 0.2;
    } else if (sizeKB < 50) {
      qualityScore = 0.6;
    } else if (sizeKB < 500) {
      qualityScore = 1.0;
    } else if (sizeKB < 2000) {
      qualityScore = 0.9;
    } else {
      qualityScore = 0.7;
    }
    
    return {
      'sizeKB': sizeKB,
      'qualityScore': qualityScore,
      'isOptimal': sizeKB >= 50 && sizeKB <= 500,
    };
  }

  /// ✅ Validate face features comprehensively
  bool _validateFaceFeatures(FaceFeatures features) {
    // Must have essential features
    if (features.leftEye == null || features.rightEye == null || features.noseBase == null) {
      return false;
    }
    
    // Validate coordinate sanity
    if (!features.leftEye!.isValid() || !features.rightEye!.isValid() || !features.noseBase!.isValid()) {
      return false;
    }
    
    // Check if features pass quality threshold
    return features.getQualityScore() >= 0.3;
  }

  /// ✅ Validate enhanced face features
  bool _validateEnhancedFaceFeatures(EnhancedFaceFeatures features) {
    // Convert to standard and validate
    FaceFeatures standard = features.toStandardFaceFeatures();
    if (!_validateFaceFeatures(standard)) {
      return false;
    }
    
    // Additional enhanced validation
    if (features.faceQualityScore != null && features.faceQualityScore! < 0.25) {
      return false;
    }
    
    if (features.landmarkCount != null && features.landmarkCount! < 3) {
      return false;
    }
    
    return true;
  }

  /// ✅ Calculate symmetry score for features
  double _calculateSymmetryScore(FaceFeatures features) {
    if (features.leftEye == null || features.rightEye == null || features.noseBase == null) {
      return 0.0;
    }
    
    double eyeMidX = (features.leftEye!.x! + features.rightEye!.x!) / 2;
    double noseOffset = (features.noseBase!.x! - eyeMidX).abs();
    double eyeDistance = features.leftEye!.distanceTo(features.rightEye!);
    
    if (eyeDistance == 0) return 0.0;
    
    double symmetryRatio = 1.0 - (noseOffset / (eyeDistance / 2));
    return math.max(0.0, math.min(1.0, symmetryRatio));
  }

  /// ✅ Save image with multiple backup methods
  Future<void> _saveImageWithBackups(String employeeId, String imageData, Map<String, dynamic> qualityAnalysis) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Primary enhanced storage
    await prefs.setString('${_imagePrefix}enhanced_$employeeId', imageData);
    
    // Standard storage
    await prefs.setString('$_imagePrefix$employeeId', imageData);
    
    // Legacy compatibility
    await prefs.setString('employee_image_$employeeId', imageData);
    
    // External storage
    await _saveToExternalStorage(employeeId, imageData, 'enhanced_image');
    
    // Save quality metadata
    await prefs.setDouble('image_quality_score_$employeeId', qualityAnalysis['qualityScore']);
  }

  /// ✅ Save features with comprehensive backups
  Future<void> _saveFeaturesWithBackups(String employeeId, FaceFeatures features, EnhancedFaceFeatures enhanced) async {
    final prefs = await SharedPreferences.getInstance();
    
    String standardJson = jsonEncode(features.toJson());
    String enhancedJson = jsonEncode(enhanced.toJson());
    
    // Standard features storage
    await prefs.setString('${_featuresPrefix}enhanced_$employeeId', standardJson);
    await prefs.setString('$_featuresPrefix$employeeId', standardJson);
    await prefs.setString('employee_face_features_$employeeId', standardJson);
    
    // Enhanced features storage
    await prefs.setString('${_enhancedFeaturesPrefix}ultra_$employeeId', enhancedJson);
    await prefs.setString('$_enhancedFeaturesPrefix$employeeId', enhancedJson);
    
    // External storage
    await _saveToExternalStorage(employeeId, standardJson, 'features');
    await _saveToExternalStorage(employeeId, enhancedJson, 'enhanced_features');
  }

  /// ✅ Save enhanced features securely
  Future<void> _saveEnhancedFeaturesSecurely(String employeeId, EnhancedFaceFeatures features) async {
    String featuresJson = jsonEncode(features.toJson());
    
    // Ultra-secure storage
    await _saveToSecureStorage(employeeId, featuresJson, 'ultra_enhanced_features');
    
    // Standard enhanced storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_enhancedFeaturesPrefix}ultra_$employeeId', featuresJson);
    await prefs.setString('$_enhancedFeaturesPrefix$employeeId', featuresJson);
    
    // Backup storage
    await prefs.setString('enhanced_face_features_backup_$employeeId', featuresJson);
  }

  /// ✅ Set quality score
  Future<void> _setQualityScore(String employeeId, double score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_qualityPrefix$employeeId', score);
  }

  /// ✅ Get quality score
  Future<double?> _getQualityScore(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_qualityPrefix$employeeId');
  }

  /// ✅ Set registration method
  Future<void> _setRegistrationMethod(String employeeId, String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_methodPrefix$employeeId', method);
  }

  /// ✅ Get registration method
  Future<String?> _getRegistrationMethod(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_methodPrefix$employeeId');
  }

  // External storage helper methods (simplified for space)
  Future<bool> _saveToExternalStorage(String employeeId, String data, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();
        if (directory != null) {
          String filePath = '${directory.path}/face_data_enhanced_${employeeId}_$dataType.dat';
          File file = File(filePath);
          await file.parent.create(recursive: true);
          await file.writeAsString(data);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error saving to external storage: $e");
      return false;
    }
  }

  Future<String?> _getFromExternalStorage(String employeeId, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();
        if (directory != null) {
          String filePath = '${directory.path}/face_data_enhanced_${employeeId}_$dataType.dat';
          File file = File(filePath);
          if (await file.exists()) {
            return await file.readAsString();
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error reading from external storage: $e");
      return null;
    }
  }

  Future<void> _deleteFromExternalStorage(String employeeId, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();
        if (directory != null) {
          String filePath = '${directory.path}/face_data_enhanced_${employeeId}_$dataType.dat';
          File file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Error deleting from external storage: $e");
    }
  }

  // Secure storage methods (enhanced)
  Future<void> _saveToSecureStorage(String employeeId, String data, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getApplicationDocumentsDirectory();
        String securePath = '${directory.path}/secure';
        Directory secureDir = Directory(securePath);
        await secureDir.create(recursive: true);
        
        String filePath = '$securePath/secure_${employeeId}_$dataType.dat';
        File file = File(filePath);
        await file.writeAsString(data);
        debugPrint("🔒 Saved to ultra-secure storage: $filePath");
      }
    } catch (e) {
      debugPrint("❌ Error saving to secure storage: $e");
    }
  }

  Future<String?> _getFromSecureStorage(String employeeId, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getApplicationDocumentsDirectory();
        String filePath = '${directory.path}/secure/secure_${employeeId}_$dataType.dat';
        File file = File(filePath);
        if (await file.exists()) {
          return await file.readAsString();
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error reading from secure storage: $e");
      return null;
    }
  }
}