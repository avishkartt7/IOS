// lib/repositories/location_exemption_repository.dart - UPDATED FOR UUID SUPPORT

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/model/location_exemption_model.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class LocationExemptionRepository {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivityService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LocationExemptionRepository({
    required DatabaseHelper dbHelper,
    required ConnectivityService connectivityService,
  }) : _dbHelper = dbHelper, _connectivityService = connectivityService;

  /// Enhanced method to check exemption using both UUID and PIN matching
  Future<bool> hasLocationExemption(String employeeId) async {
    try {
      debugPrint("🔍 Checking location exemption for employee: $employeeId");

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Get employee PIN from employees collection first
        String? employeePin = await _getEmployeePin(employeeId);
        debugPrint("📋 Employee PIN retrieved: $employeePin");

        // Check Firestore for exemptions using multiple search criteria
        final exemption = await getActiveExemption(employeeId, employeePin);
        if (exemption != null) {
          // Cache the result locally
          await _cacheExemption(exemption);
          debugPrint("✅ Found active exemption in Firestore for $employeeId");
          return true;
        }
      }

      // Check local cache
      final localExemption = await _getLocalExemption(employeeId);
      if (localExemption != null && localExemption.isCurrentlyActive) {
        debugPrint("✅ Found active exemption in local cache for $employeeId");
        return true;
      }

      debugPrint("❌ No active exemption found for $employeeId");
      return false;
    } catch (e) {
      debugPrint("❌ Error checking location exemption: $e");
      return false;
    }
  }

  /// Get employee PIN from employees collection using UUID
  Future<String?> _getEmployeePin(String employeeId) async {
    try {
      final employeeDoc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (employeeDoc.exists) {
        final data = employeeDoc.data() as Map<String, dynamic>;
        return data['pin']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error getting employee PIN: $e");
      return null;
    }
  }

  /// Enhanced method to get active exemption using UUID and PIN matching
  Future<LocationExemptionModel?> getActiveExemption(String employeeId, [String? employeePin]) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Search by multiple criteria
        List<String> searchIds = [employeeId];

        if (employeePin != null && employeePin.isNotEmpty) {
          searchIds.addAll([
            employeePin,           // 3576
            'EMP$employeePin',     // EMP3576
          ]);
        }

        debugPrint("🔍 Searching exemptions with IDs: $searchIds");

        // Search for exemptions matching any of the possible IDs
        for (String searchId in searchIds) {
          final snapshot = await _firestore
              .collection('location_exemptions')
              .where('employeeId', isEqualTo: searchId)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            data['id'] = snapshot.docs.first.id;
            final exemption = LocationExemptionModel.fromJson(data);

            if (exemption.isCurrentlyActive) {
              debugPrint("✅ Found exemption for searchId: $searchId");
              return exemption;
            }
          }
        }

        // Also try searching by employeePin field
        if (employeePin != null && employeePin.isNotEmpty) {
          final pinSnapshot = await _firestore
              .collection('location_exemptions')
              .where('employeePin', isEqualTo: employeePin)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

          if (pinSnapshot.docs.isNotEmpty) {
            final data = pinSnapshot.docs.first.data();
            data['id'] = pinSnapshot.docs.first.id;
            final exemption = LocationExemptionModel.fromJson(data);

            if (exemption.isCurrentlyActive) {
              debugPrint("✅ Found exemption by PIN: $employeePin");
              return exemption;
            }
          }
        }
      }

      return await _getLocalExemption(employeeId);
    } catch (e) {
      debugPrint("❌ Error getting active exemption: $e");
      return null;
    }
  }

  /// Create test exemption automatically for PIN 3576
  Future<bool> createTestExemptionForPIN1244() async {
    try {
      debugPrint("🧪 Creating test exemption for PIN 3576...");

      // First find the employee UUID for PIN 3576
      String? employeeUuid = await _findEmployeeUuidByPin('1244');

      if (employeeUuid == null) {
        debugPrint("❌ Could not find employee UUID for PIN 3576");
        return false;
      }

      debugPrint("📋 Found employee UUID: $employeeUuid for PIN 3576");

      // Get employee name from the document
      String employeeName = "Test Driver Employee";
      try {
        final employeeDoc = await _firestore.collection('employees').doc(employeeUuid).get();
        if (employeeDoc.exists) {
          final data = employeeDoc.data() as Map<String, dynamic>;
          employeeName = data['name'] ?? employeeName;
        }
      } catch (e) {
        debugPrint("Could not get employee name: $e");
      }

      // Check if exemption already exists
      bool alreadyExists = await hasLocationExemption(employeeUuid);
      if (alreadyExists) {
        debugPrint("✅ Exemption already exists for PIN 3576");
        return true;
      }

      // Create the exemption
      final exemptionData = {
        'employeeId': employeeUuid,        // Use UUID for employeeId
        'employeeName': employeeName,
        'employeePin': '1244',
        'reason': 'Driver - Mobile duty requires location flexibility',
        'grantedAt': DateTime.now().toIso8601String(),
        'grantedBy': 'System Auto-Setup',
        'isActive': true,
        'expiryDate': null,
        'notes': 'Auto-created test exemption for development and testing purposes',
      };

      await _firestore.collection('location_exemptions').add(exemptionData);

      debugPrint("✅ Test exemption created successfully for PIN 3576 (UUID: $employeeUuid)");
      return true;
    } catch (e) {
      debugPrint("❌ Error creating test exemption: $e");
      return false;
    }
  }

  /// Find employee UUID by PIN from employees collection
  Future<String?> _findEmployeeUuidByPin(String pin) async {
    try {
      final snapshot = await _firestore
          .collection('employees')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error finding employee by PIN: $e");
      return null;
    }
  }

  // Add new exemption
  Future<bool> addExemption(LocationExemptionModel exemption) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _firestore.collection('location_exemptions').add(exemption.toJson());
      }

      // Cache locally
      await _cacheExemption(exemption);
      return true;
    } catch (e) {
      debugPrint("❌ Error adding exemption: $e");
      return false;
    }
  }

  // Remove exemption
  Future<bool> removeExemption(String employeeId) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Get employee PIN for comprehensive search
        String? employeePin = await _getEmployeePin(employeeId);
        List<String> searchIds = [employeeId];

        if (employeePin != null) {
          searchIds.addAll([employeePin, 'EMP$employeePin']);
        }

        // Remove exemptions found by any matching criteria
        for (String searchId in searchIds) {
          final snapshot = await _firestore
              .collection('location_exemptions')
              .where('employeeId', isEqualTo: searchId)
              .where('isActive', isEqualTo: true)
              .get();

          for (var doc in snapshot.docs) {
            await doc.reference.update({'isActive': false});
          }
        }
      }

      // Remove from local cache
      await _dbHelper.delete(
        'location_exemptions',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
      );

      return true;
    } catch (e) {
      debugPrint("❌ Error removing exemption: $e");
      return false;
    }
  }

  // Get all exemptions for management
  Future<List<LocationExemptionModel>> getAllExemptions() async {
    try {
      List<LocationExemptionModel> exemptions = [];

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final snapshot = await _firestore
            .collection('location_exemptions')
            .orderBy('grantedAt', descending: true)
            .get();

        exemptions = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return LocationExemptionModel.fromJson(data);
        }).toList();

        // Cache all exemptions locally
        for (var exemption in exemptions) {
          await _cacheExemption(exemption);
        }
      } else {
        exemptions = await _getLocalExemptions();
      }

      return exemptions;
    } catch (e) {
      debugPrint("❌ Error getting all exemptions: $e");
      return [];
    }
  }

  // Private methods for caching
  Future<void> _cacheExemption(LocationExemptionModel exemption) async {
    try {
      await _dbHelper.insert('location_exemptions', {
        'employee_id': exemption.employeeId,
        'employee_name': exemption.employeeName,
        'employee_pin': exemption.employeePin,
        'reason': exemption.reason,
        'granted_at': exemption.grantedAt.toIso8601String(),
        'granted_by': exemption.grantedBy,
        'is_active': exemption.isActive ? 1 : 0,
        'expiry_date': exemption.expiryDate?.toIso8601String(),
        'notes': exemption.notes,
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("❌ Error caching exemption: $e");
    }
  }

  Future<LocationExemptionModel?> _getLocalExemption(String employeeId) async {
    try {
      final results = await _dbHelper.query(
        'location_exemptions',
        where: 'employee_id = ? AND is_active = 1',
        whereArgs: [employeeId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final data = results.first;
        return LocationExemptionModel(
          id: data['employee_id'].toString(),
          employeeId: data['employee_id'].toString(),
          employeeName: data['employee_name'].toString(),
          employeePin: data['employee_pin'].toString(),
          reason: data['reason'].toString(),
          grantedAt: DateTime.parse(data['granted_at'].toString()),
          grantedBy: data['granted_by'].toString(),
          isActive: data['is_active'] == 1,
          expiryDate: data['expiry_date'] != null
              ? DateTime.parse(data['expiry_date'].toString())
              : null,
          notes: data['notes']?.toString(),
        );
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error getting local exemption: $e");
      return null;
    }
  }

  Future<List<LocationExemptionModel>> _getLocalExemptions() async {
    try {
      final results = await _dbHelper.query(
        'location_exemptions',
        orderBy: 'granted_at DESC',
      );

      return results.map((data) {
        return LocationExemptionModel(
          id: data['employee_id'].toString(),
          employeeId: data['employee_id'].toString(),
          employeeName: data['employee_name'].toString(),
          employeePin: data['employee_pin'].toString(),
          reason: data['reason'].toString(),
          grantedAt: DateTime.parse(data['granted_at'].toString()),
          grantedBy: data['granted_by'].toString(),
          isActive: data['is_active'] == 1,
          expiryDate: data['expiry_date'] != null
              ? DateTime.parse(data['expiry_date'].toString())
              : null,
          notes: data['notes']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint("❌ Error getting local exemptions: $e");
      return [];
    }
  }
}



