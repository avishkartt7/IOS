// lib/services/secure_face_storage_service.dart - Production Ready

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
  static const String _registeredPrefix = 'face_registered_';
  static const String _qualityPrefix = 'face_quality_score_';
  static const String _methodPrefix = 'registration_method_';

  /// Save face image with validation and quality checks
  Future<void> saveFaceImage(String employeeId, String base64Image) async {
    try {
      debugPrint("🔒 Saving face image for $employeeId...");

      // Validate image data
      if (!_validateImageData(base64Image)) {
        throw Exception("Invalid image data provided");
      }

      // Clean and optimize image data
      String cleanedImage = _cleanImageData(base64Image);
      debugPrint("🧹 Image data cleaned (${cleanedImage.length} chars)");

      // Analyze image quality
      Map<String, dynamic> qualityAnalysis = _analyzeImageQuality(cleanedImage);
      debugPrint("📊 Image quality score: ${qualityAnalysis['qualityScore']}");

      if (qualityAnalysis['qualityScore'] < 0.3) {
        debugPrint("⚠️ WARNING: Low image quality detected");
      }

      // Save with multiple backup methods
      await _saveImageWithBackups(employeeId, cleanedImage, qualityAnalysis);

      debugPrint("✅ Face image saved successfully for $employeeId");
    } catch (e) {
      debugPrint("❌ Error saving face image: $e");
      rethrow;
    }
  }

  /// Save face features with validation
  Future<void> saveFaceFeatures(String employeeId, FaceFeatures features) async {
    try {
      debugPrint("🔒 Saving face features for $employeeId...");

      // Validate features
      if (!_validateFaceFeatures(features)) {
        throw Exception("Face features validation failed");
      }

      // Calculate quality metrics
      double qualityScore = features.getQualityScore();
      debugPrint("📊 Face features quality: ${(qualityScore * 100).toStringAsFixed(1)}%");

      // Save with backup methods
      await _saveFeaturesWithBackups(employeeId, features);

      debugPrint("✅ Face features saved successfully for $employeeId");
    } catch (e) {
      debugPrint("❌ Error saving face features: $e");
      rethrow;
    }
  }

  /// Get face image with multiple fallback sources
  Future<String?> getFaceImage(String employeeId) async {
    try {
      debugPrint("🔍 Retrieving face image for $employeeId...");

      // Try external storage first
      String? image = await _getFromExternalStorage(employeeId, 'image');
      if (image != null && _validateImageData(image)) {
        debugPrint("✅ Retrieved image from external storage");
        return image;
      }

      // Try multiple SharedPreferences keys
      final prefs = await SharedPreferences.getInstance();
      List<String> imageKeys = [
        '$_imagePrefix$employeeId',
        'employee_image_$employeeId',
        'face_image_$employeeId',
      ];

      for (String key in imageKeys) {
        image = prefs.getString(key);
        if (image != null && _validateImageData(image)) {
          debugPrint("✅ Retrieved image from key: $key");
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

  /// Get face features with validation and fallbacks
  Future<FaceFeatures?> getFaceFeatures(String employeeId) async {
    try {
      debugPrint("🔍 Retrieving face features for $employeeId...");

      // Try direct feature storage
      final prefs = await SharedPreferences.getInstance();
      List<String> featureKeys = [
        '$_featuresPrefix$employeeId',
        'employee_face_features_$employeeId',
        'face_features_$employeeId',
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

  /// Smart cloud recovery with validation
  Future<bool> downloadFaceDataFromCloud(String employeeId) async {
    try {
      debugPrint("🌐 Downloading face data from cloud for: $employeeId");

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

      // Validate cloud data
      bool hasValidImage = data.containsKey('image') && 
                          data['image'] != null && 
                          _validateImageData(data['image']);
      
      bool hasValidFeatures = data.containsKey('faceFeatures') && 
                             data['faceFeatures'] != null;
      
      bool isFaceRegistered = data['faceRegistered'] ?? false;

      if (!hasValidImage || !isFaceRegistered) {
        debugPrint("❌ No valid face data found in cloud");
        return false;
      }

      debugPrint("✅ Valid face data found in cloud, downloading...");

      // Download and save with validation
      bool success = true;

      // Save face image
      try {
        await saveFaceImage(employeeId, data['image']);
        debugPrint("✅ Face image downloaded and saved");
      } catch (e) {
        debugPrint("❌ Error saving downloaded image: $e");
        success = false;
      }

      // Save features if available
      if (hasValidFeatures) {
        try {
          Map<String, dynamic> featuresMap = data['faceFeatures'];
          FaceFeatures features = FaceFeatures.fromJson(featuresMap);
          await saveFaceFeatures(employeeId, features);
          debugPrint("✅ Face features downloaded and saved");
        } catch (e) {
          debugPrint("❌ Error saving downloaded features: $e");
          success = false;
        }
      }

      // Set registration flags
      await setFaceRegistered(employeeId, true);

      // Save backup in standard SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_image_$employeeId', data['image']);
      await prefs.setBool('face_registered_$employeeId', true);

      debugPrint("🎉 Face data successfully downloaded for: $employeeId");
      return success;

    } catch (e) {
      debugPrint("❌ Error downloading face data from cloud: $e");
      return false;
    }
  }

  /// Comprehensive face data validation
  Future<bool> validateLocalFaceData(String employeeId) async {
    try {
      debugPrint("🔍 Validating local face data for: $employeeId");

      // Check image data
      String? image = await getFaceImage(employeeId);
      bool hasValidImage = image != null && _validateImageData(image);

      // Check features
      FaceFeatures? features = await getFaceFeatures(employeeId);
      bool hasValidFeatures = features != null && _validateFaceFeatures(features);

      // Check registration flags
      bool isRegistered = await isFaceRegistered(employeeId);

      debugPrint("📊 Validation results for $employeeId:");
      debugPrint("   - Valid image: $hasValidImage");
      debugPrint("   - Valid features: $hasValidFeatures");
      debugPrint("   - Is registered: $isRegistered");

      // Validation logic
      bool isValid = hasValidImage && hasValidFeatures && isRegistered;

      if (!isValid && isRegistered) {
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

  /// Set face registered flag
  Future<void> setFaceRegistered(String employeeId, bool isRegistered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_registeredPrefix$employeeId', isRegistered);
      
      if (isRegistered) {
        await prefs.setString('face_registration_date_$employeeId', DateTime.now().toIso8601String());
        await prefs.setString('face_registration_method_$employeeId', 'production');
      }
      
      debugPrint("🔒 Set face registered for $employeeId: $isRegistered");
    } catch (e) {
      debugPrint("❌ Error setting face registered flag: $e");
    }
  }

  /// Check if face is registered
  Future<bool> isFaceRegistered(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isRegistered = prefs.getBool('$_registeredPrefix$employeeId') ?? false;
      debugPrint("🔍 Face registered for $employeeId: $isRegistered");
      return isRegistered;
    } catch (e) {
      debugPrint("❌ Error checking face registered flag: $e");
      return false;
    }
  }

  /// Get face data information for debugging
  Future<Map<String, dynamic>> getFaceDataInfo(String employeeId) async {
    try {
      String? image = await getFaceImage(employeeId);
      FaceFeatures? features = await getFaceFeatures(employeeId);
      bool isRegistered = await isFaceRegistered(employeeId);
      double? qualityScore = await _getQualityScore(employeeId);
      String? method = await _getRegistrationMethod(employeeId);

      return {
        'employeeId': employeeId,
        'hasImage': image != null,
        'imageSize': image?.length ?? 0,
        'imageValid': image != null ? _validateImageData(image) : false,
        'hasFeatures': features != null,
        'featuresValid': features != null ? _validateFaceFeatures(features) : false,
        'isRegistered': isRegistered,
        'qualityScore': qualityScore,
        'registrationMethod': method,
        'faceQuality': features?.getQualityScore(),
        'landmarkCount': features?.countFeatures(),
        'validationStatus': await validateLocalFaceData(employeeId),
        'needsCloudRecovery': await needsCloudRecovery(employeeId),
      };
    } catch (e) {
      debugPrint("❌ Error getting face data info: $e");
      return {'error': e.toString()};
    }
  }

  /// Clear all face data
  Future<void> clearFaceData(String employeeId) async {
    try {
      debugPrint("🗑️ Clearing all face data for $employeeId");

      // Clear external storage
      await _deleteFromExternalStorage(employeeId, 'image');
      await _deleteFromExternalStorage(employeeId, 'features');

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> keysToRemove = [
        '$_imagePrefix$employeeId',
        '$_featuresPrefix$employeeId',
        '$_registeredPrefix$employeeId',
        '$_qualityPrefix$employeeId',
        '$_methodPrefix$employeeId',
        'employee_image_$employeeId',
        'employee_face_features_$employeeId',
        'face_image_$employeeId',
        'face_features_$employeeId',
        'face_registration_date_$employeeId',
        'face_registration_method_$employeeId',
      ];

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      debugPrint("✅ All face data cleared for $employeeId");
    } catch (e) {
      debugPrint("❌ Error clearing face data: $e");
    }
  }

  /// Check if needs cloud recovery
  Future<bool> needsCloudRecovery(String employeeId) async {
    try {
      bool isRegistered = await isFaceRegistered(employeeId);
      bool hasValidData = await validateLocalFaceData(employeeId);

      return isRegistered && !hasValidData;
    } catch (e) {
      debugPrint("❌ Error checking cloud recovery need: $e");
      return false;
    }
  }

  /// Ensure face data is available with smart recovery
  Future<bool> ensureFaceDataAvailable(String employeeId) async {
    try {
      debugPrint("🔄 Ensuring face data is available for: $employeeId");

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

  /// Save user data with face information
  Future<void> saveUserData(String employeeId, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Add metadata
      userData['lastUpdated'] = DateTime.now().toIso8601String();
      userData['platform'] = Platform.operatingSystem;
      userData['version'] = 'production_v1';
      
      await prefs.setString('user_data_$employeeId', jsonEncode(userData));
      debugPrint("✅ User data saved for $employeeId");
    } catch (e) {
      debugPrint("❌ Error saving user data: $e");
    }
  }

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user_data_$employeeId');
      
      if (userData != null && userData.isNotEmpty) {
        return jsonDecode(userData);
      }
      
      return null;
    } catch (e) {
      debugPrint("❌ Error getting user data: $e");
      return null;
    }
  }

  // ================ PRIVATE HELPER METHODS ================

  /// Validate image data quality and format
  bool _validateImageData(String imageData) {
    if (imageData.isEmpty) return false;
    
    // Check minimum size (should be at least 1KB when decoded)
    if (imageData.length < 1000) return false;
    
    // Check maximum size (should be less than 10MB)
    if (imageData.length > 10000000) return false;
    
    // Check if it's valid base64
    try {
      String testData = imageData.substring(0, math.min(100, imageData.length));
      base64Decode(testData);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean and optimize image data
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

  /// Analyze image quality
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

  /// Validate face features
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

  /// Save image with multiple backup methods
  Future<void> _saveImageWithBackups(String employeeId, String imageData, Map<String, dynamic> qualityAnalysis) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Primary storage
    await prefs.setString('$_imagePrefix$employeeId', imageData);
    
    // Legacy compatibility
    await prefs.setString('employee_image_$employeeId', imageData);
    
    // Alternative storage
    await prefs.setString('face_image_$employeeId', imageData);
    
    // External storage
    await _saveToExternalStorage(employeeId, imageData, 'image');
    
    // Save quality metadata
    await prefs.setDouble('$_qualityPrefix$employeeId', qualityAnalysis['qualityScore']);
  }

  /// Save features with backups
  Future<void> _saveFeaturesWithBackups(String employeeId, FaceFeatures features) async {
    final prefs = await SharedPreferences.getInstance();
    
    String featuresJson = jsonEncode(features.toJson());
    
    // Primary features storage
    await prefs.setString('$_featuresPrefix$employeeId', featuresJson);
    
    // Legacy compatibility
    await prefs.setString('employee_face_features_$employeeId', featuresJson);
    
    // Alternative storage
    await prefs.setString('face_features_$employeeId', featuresJson);
    
    // External storage
    await _saveToExternalStorage(employeeId, featuresJson, 'features');
  }

  /// Get quality score
  Future<double?> _getQualityScore(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_qualityPrefix$employeeId');
  }

  /// Get registration method
  Future<String?> _getRegistrationMethod(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_methodPrefix$employeeId');
  }

  // External storage helper methods
  Future<bool> _saveToExternalStorage(String employeeId, String data, String dataType) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        Directory? directory = await getExternalStorageDirectory();
        if (directory != null) {
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
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
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
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
          String filePath = '${directory.path}/face_data_${employeeId}_$dataType.dat';
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

  /// Sync pending face registrations when coming online
  Future<void> syncPendingRegistrations() async {
    try {
      debugPrint("🔄 Syncing pending face registrations...");
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      List<String> employeesWithPendingSync = [];
      
      for (String key in keys) {
        if (key.startsWith('pending_face_registration_')) {
          String employeeId = key.replaceFirst('pending_face_registration_', '');
          employeesWithPendingSync.add(employeeId);
        }
      }
      
      debugPrint("📊 Found ${employeesWithPendingSync.length} pending sync operations");
      
      for (String employeeId in employeesWithPendingSync) {
        await _syncSingleEmployeeData(employeeId);
      }
      
      debugPrint("✅ Pending sync operations completed");
    } catch (e) {
      debugPrint("❌ Error syncing pending registrations: $e");
    }
  }

  /// Sync single employee data to cloud
  Future<void> _syncSingleEmployeeData(String employeeId) async {
    try {
      debugPrint("🔄 Syncing data for employee: $employeeId");
      
      // Get local data
      String? image = await getFaceImage(employeeId);
      FaceFeatures? features = await getFaceFeatures(employeeId);
      Map<String, dynamic>? userData = await getUserData(employeeId);
      
      if (image == null || features == null) {
        debugPrint("❌ Missing local data for $employeeId");
        return;
      }
      
      // Prepare cloud data
      Map<String, dynamic> cloudData = {
        'image': image,
        'faceFeatures': features.toJson(),
        'faceRegistered': true,
        'registeredOn': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
        'registrationMethod': 'production_offline_sync',
        'faceQualityScore': features.getQualityScore(),
        'featuresCount': features.countFeatures(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'syncedAt': FieldValue.serverTimestamp(),
      };
      
      if (userData != null) {
        cloudData.addAll(userData);
      }
      
      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .update(cloudData);
      
      // Mark as synced
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_face_registration_$employeeId');
      await prefs.remove('pending_sync_data_$employeeId');
      
      debugPrint("✅ Successfully synced data for $employeeId");
      
    } catch (e) {
      debugPrint("❌ Error syncing data for $employeeId: $e");
    }
  }
}