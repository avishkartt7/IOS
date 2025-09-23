// lib/repositories/attendance_repository.dart - FIXED VERSION WITH PROPER LOCATION NAMES

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/model/local_attendance_model.dart';
import 'package:face_auth/model/attendance_model.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AttendanceRepository {
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivityService;

  AttendanceRepository({
    required DatabaseHelper dbHelper,
    FirebaseFirestore? firestore,
    required ConnectivityService connectivityService,
  }) : _dbHelper = dbHelper,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivityService = connectivityService;

  // ✅ FIXED: Helper method to convert Firestore Timestamps to ISO strings for local storage
  Map<String, dynamic> _convertTimestampsForLocal(Map<String, dynamic> data) {
    Map<String, dynamic> cleanData = Map<String, dynamic>.from(data);

    cleanData.forEach((key, value) {
      if (value is Timestamp) {
        cleanData[key] = value.toDate().toIso8601String();
        debugPrint("🔄 Converted $key from Timestamp to: ${cleanData[key]}");
      }
    });

    return cleanData;
  }

  // ✅ ENHANCED: Get location name from ID using Firebase lookup
  Future<String> _getLocationNameFromId(String locationId) async {
    try {
      debugPrint("🔍 Looking up location name for ID: $locationId");

      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        debugPrint("📵 Offline - cannot resolve location name");
        return "Offline Location ($locationId)";
      }

      // Check regular locations collection
      DocumentSnapshot locationDoc = await _firestore
          .collection('locations')
          .doc(locationId)
          .get();

      if (locationDoc.exists) {
        Map<String, dynamic> data = locationDoc.data() as Map<String, dynamic>;
        String locationName = data['name'] ?? data['locationName'] ?? 'Unknown Location';
        debugPrint("✅ Found location name: $locationName");
        return locationName;
      }

      // Check polygon locations collection
      DocumentSnapshot polygonDoc = await _firestore
          .collection('polygon_locations')
          .doc(locationId)
          .get();

      if (polygonDoc.exists) {
        Map<String, dynamic> data = polygonDoc.data() as Map<String, dynamic>;
        String locationName = data['name'] ?? 'Unknown Polygon Location';
        debugPrint("✅ Found polygon location name: $locationName");
        return locationName;
      }

      // ✅ ENHANCED: Try to search by partial ID match in polygon_locations
      try {
        QuerySnapshot polygonQuery = await _firestore
            .collection('polygon_locations')
            .where('isActive', isEqualTo: true)
            .get();

        for (var doc in polygonQuery.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String docId = doc.id;
          String name = data['name'] ?? '';

          // Check if the locationId contains the document ID or name
          if (docId.contains(locationId) || locationId.contains(docId) ||
              name.toLowerCase().contains(locationId.toLowerCase())) {
            debugPrint("✅ Found polygon location by partial match: $name");
            return name;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Error in polygon partial search: $e");
      }

      debugPrint("⚠️ Location not found for ID: $locationId");
      return "Unknown Location";

    } catch (e) {
      debugPrint("❌ Error getting location name for $locationId: $e");
      return "Unknown Location";
    }
  }

  // ✅ ENHANCED: Record check-in with proper location name resolution
  Future<bool> recordCheckIn({
    required String employeeId,
    required DateTime checkInTime,
    required String locationId,
    required String locationName,
    required double locationLat,
    required double locationLng,
    String? imageData,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      debugPrint("🔽 === RECORDING CHECK-IN ===");
      debugPrint("Employee: $employeeId");
      debugPrint("Date: $today");
      debugPrint("Location ID: $locationId");
      debugPrint("Location Name Provided: $locationName");

      // ✅ CRITICAL: Resolve proper location name if ID was passed as name
      String resolvedLocationName = locationName;
      String resolvedLocationId = locationId;

      // If location name looks like an ID (UUID format), resolve it
      if (locationName.length > 20 && locationName.contains('-')) {
        debugPrint("🔍 Location name looks like ID, resolving...");
        resolvedLocationName = await _getLocationNameFromId(locationName);
        resolvedLocationId = locationName; // Use the UUID as the ID
      } else if (locationId.length > 20 && locationId.contains('-')) {
        // If locationId is UUID but locationName is provided, use them as is
        resolvedLocationName = locationName.isNotEmpty ? locationName : await _getLocationNameFromId(locationId);
        resolvedLocationId = locationId;
      }

      debugPrint("📍 RESOLVED - ID: $resolvedLocationId");
      debugPrint("📍 RESOLVED - Name: $resolvedLocationName");

      // Check if there's already a record for today
      LocalAttendanceRecord? existingRecord = await _getLocalAttendanceRecord(employeeId, today);

      if (existingRecord != null) {
        debugPrint("📝 Updating existing record with check-in data");

        Map<String, dynamic> updatedData = Map<String, dynamic>.from(existingRecord.rawData);
        updatedData.addAll({
          'checkIn': checkInTime.toIso8601String(),
          'checkInLocation': resolvedLocationId,
          'checkInLocationName': resolvedLocationName,
          'checkInLat': locationLat,
          'checkInLng': locationLng,
          'workStatus': existingRecord.hasCheckOut ? 'Completed' : 'In Progress',
          'isWithinGeofence': true,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        if (additionalData != null) {
          updatedData.addAll(additionalData);
        }

        // Update with check-in data, preserving check-out location if exists
        LocalAttendanceRecord updatedRecord = existingRecord.updateWithCheckIn(
          checkIn: checkInTime.toIso8601String(),
          checkInLocationId: resolvedLocationId,
          checkInLocationName: resolvedLocationName,
          additionalData: updatedData,
        );

        // Update local database
        int updateResult = await _dbHelper.update(
          'attendance',
          updatedRecord.toMap(),
          where: 'id = ?',
          whereArgs: [existingRecord.id],
        );

        if (updateResult > 0) {
          debugPrint("✅ Local record updated successfully");
          debugPrint("📍 Check-in Location: $resolvedLocationName");
        }

        // Sync to cloud if online
        await _syncToFirestore(updatedRecord);
        return true;
      }

      // ✅ NEW RECORD: Create fresh check-in record
      debugPrint("🆕 Creating new check-in record");

      Map<String, dynamic> checkInData = {
        'employeeId': employeeId,
        'date': today,
        'checkIn': checkInTime.toIso8601String(),
        'checkInLocation': resolvedLocationId,
        'checkInLocationName': resolvedLocationName,
        'checkInLat': locationLat,
        'checkInLng': locationLng,
        // Legacy compatibility
        'location': resolvedLocationId,
        'locationName': resolvedLocationName,
        // Work status
        'workStatus': 'In Progress',
        'totalHours': 0,
        'isWithinGeofence': true,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (additionalData != null) {
        checkInData.addAll(additionalData);
      }

      // Create new local record with separate location support
      LocalAttendanceRecord localRecord = LocalAttendanceRecord(
        employeeId: employeeId,
        date: today,
        checkIn: checkInTime.toIso8601String(),
        checkInLocationId: resolvedLocationId,
        checkInLocationName: resolvedLocationName,
        isSynced: false,
        rawData: checkInData,
      );

      // Save to local database
      int localId = await _dbHelper.insert('attendance', localRecord.toMap());
      debugPrint("💾 Check-in saved locally with ID: $localId");

      // Update the record with the new ID
      localRecord = localRecord.copyWith(id: localId);

      // Sync to cloud if online
      await _syncToFirestore(localRecord);

      debugPrint("✅ CHECK-IN COMPLETED:");
      debugPrint("  📍 Location: $resolvedLocationName");
      debugPrint("  🕐 Time: ${DateFormat('HH:mm').format(checkInTime)}");
      return true;

    } catch (e) {
      debugPrint('❌ Error recording check-in: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Record check-out with proper location name resolution
  Future<bool> recordCheckOut({
    required String employeeId,
    required DateTime checkOutTime,
    required String locationId,
    required String locationName,
    required double locationLat,
    required double locationLng,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      debugPrint("🔼 === RECORDING CHECK-OUT ===");
      debugPrint("Employee: $employeeId");
      debugPrint("Date: $today");
      debugPrint("Location ID: $locationId");
      debugPrint("Location Name Provided: $locationName");

      // ✅ CRITICAL: Resolve proper location name if ID was passed as name
      String resolvedLocationName = locationName;
      String resolvedLocationId = locationId;

      // If location name looks like an ID (UUID format), resolve it
      if (locationName.length > 20 && locationName.contains('-')) {
        debugPrint("🔍 Location name looks like ID, resolving...");
        resolvedLocationName = await _getLocationNameFromId(locationName);
        resolvedLocationId = locationName;
      } else if (locationId.length > 20 && locationId.contains('-')) {
        resolvedLocationName = locationName.isNotEmpty ? locationName : await _getLocationNameFromId(locationId);
        resolvedLocationId = locationId;
      }

      debugPrint("📍 RESOLVED - ID: $resolvedLocationId");
      debugPrint("📍 RESOLVED - Name: $resolvedLocationName");

      // Get existing record to preserve check-in location
      LocalAttendanceRecord? existingRecord = await _getLocalAttendanceRecord(employeeId, today);

      if (existingRecord == null) {
        debugPrint("❌ No check-in record found for today - cannot check out without check-in");
        return false;
      }

      if (!existingRecord.hasCheckIn) {
        debugPrint("❌ No check-in time in existing record");
        return false;
      }

      // ✅ Calculate working hours
      DateTime checkInTime = DateTime.parse(existingRecord.checkIn!);
      double hoursWorked = checkOutTime.difference(checkInTime).inMinutes / 60.0;
      debugPrint("⏱️ Hours worked: ${hoursWorked.toStringAsFixed(2)}");

      // Calculate overtime (after 6:30 PM or on weekends)
      double overtimeHours = _calculateOvertimeHours(checkInTime, checkOutTime);

      // ✅ Create updated data preserving check-in location
      Map<String, dynamic> updatedData = Map<String, dynamic>.from(existingRecord.rawData);
      updatedData.addAll({
        'checkOut': checkOutTime.toIso8601String(),
        'checkOutLocation': resolvedLocationId,
        'checkOutLocationName': resolvedLocationName,
        'checkOutLat': locationLat,
        'checkOutLng': locationLng,
        'workStatus': 'Completed',
        'totalHours': hoursWorked,
        'overtimeHours': overtimeHours,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      if (additionalData != null) {
        updatedData.addAll(additionalData);
      }

      // ✅ PRESERVE CHECK-IN LOCATION: Update record with check-out data
      LocalAttendanceRecord updatedRecord = existingRecord.updateWithCheckOut(
        checkOut: checkOutTime.toIso8601String(),
        checkOutLocationId: resolvedLocationId,
        checkOutLocationName: resolvedLocationName,
        additionalData: updatedData,
      );

      // Update local database
      int updateResult = await _dbHelper.update(
        'attendance',
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [existingRecord.id],
      );

      if (updateResult > 0) {
        debugPrint("💾 Local record updated with check-out data");
        debugPrint("📍 Complete journey: ${existingRecord.checkInLocationName} → $resolvedLocationName");
      }

      // Sync to cloud if online
      await _syncToFirestore(updatedRecord);

      debugPrint("✅ CHECK-OUT COMPLETED:");
      debugPrint("  📍 Location: $resolvedLocationName");
      debugPrint("  🕐 Time: ${DateFormat('HH:mm').format(checkOutTime)}");
      debugPrint("  📊 Total hours: ${hoursWorked.toStringAsFixed(1)}h");
      debugPrint("  ⏰ Overtime: ${overtimeHours.toStringAsFixed(1)}h");
      return true;

    } catch (e) {
      debugPrint('❌ Error recording check-out: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Calculate overtime hours properly
  double _calculateOvertimeHours(DateTime checkIn, DateTime checkOut) {
    try {
      // If it's Saturday or Sunday, all hours are overtime
      if (checkOut.weekday == DateTime.saturday || checkOut.weekday == DateTime.sunday) {
        Duration workDuration = checkOut.difference(checkIn);
        double overtimeHours = workDuration.inMinutes / 60.0;
        return overtimeHours > 0 ? overtimeHours : 0.0;
      }

      // For weekdays: overtime after 6:30 PM
      DateTime overtimeStartTime = DateTime(
        checkOut.year,
        checkOut.month,
        checkOut.day,
        18, // 6:30 PM
        30,
      );

      // If checkout is before or at 6:30 PM, no overtime
      if (checkOut.isBefore(overtimeStartTime) || checkOut.isAtSameMomentAs(overtimeStartTime)) {
        return 0.0;
      }

      // Calculate overtime from 6:30 PM onwards
      Duration overtimeDuration = checkOut.difference(overtimeStartTime);
      double overtimeHours = overtimeDuration.inMinutes / 60.0;

      return overtimeHours > 0 ? overtimeHours : 0.0;
    } catch (e) {
      debugPrint("❌ Error calculating overtime hours: $e");
      return 0.0;
    }
  }

  // ✅ Helper method to get local attendance record
  Future<LocalAttendanceRecord?> _getLocalAttendanceRecord(String employeeId, String date) async {
    try {
      final results = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, date],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return LocalAttendanceRecord.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting local attendance record: $e');
      return null;
    }
  }

  // ✅ ENHANCED: Sync record to Firestore with proper location handling
  Future<void> _syncToFirestore(LocalAttendanceRecord record) async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      debugPrint("⚠️ Offline - record will sync when connection is restored");
      return;
    }

    try {
      debugPrint("☁️ Syncing to Firestore...");
      debugPrint("📍 Check-in: ${record.checkInLocationName}");
      debugPrint("📍 Check-out: ${record.checkOutLocationName}");

      // Convert to Firestore format (handles separate locations)
      Map<String, dynamic> firestoreData = record.toFirestore();

      // ✅ IMPORTANT: Convert ISO string dates to Timestamps for Firestore
      if (firestoreData['checkIn'] != null && firestoreData['checkIn'] is String) {
        firestoreData['checkIn'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkIn']));
      }
      if (firestoreData['checkOut'] != null && firestoreData['checkOut'] is String) {
        firestoreData['checkOut'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkOut']));
      }

      // Save to Firestore
      await _firestore
          .collection('Attendance_Records')
          .doc('PTSEmployees')
          .collection('Records')
          .doc('${record.employeeId}-${record.date}')
          .set(firestoreData, SetOptions(merge: true));

      // Mark as synced in local database
      await _markRecordAsSynced(record.employeeId, record.date);

      debugPrint("☁️ Successfully synced to Firestore with location names");

    } catch (e) {
      debugPrint("❌ Error syncing to Firestore: $e");
      await _markSyncError(record.employeeId, record.date, e.toString());
    }
  }

  // ✅ Helper method to mark record as synced
  Future<void> _markRecordAsSynced(String employeeId, String date) async {
    try {
      await _dbHelper.update(
        'attendance',
        {'is_synced': 1, 'sync_error': null},
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, date],
      );
    } catch (e) {
      debugPrint('❌ Error marking record as synced: $e');
    }
  }

  // ✅ Helper method to mark sync error
  Future<void> _markSyncError(String employeeId, String date, String error) async {
    try {
      await _dbHelper.update(
        'attendance',
        {'sync_error': error},
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, date],
      );
    } catch (e) {
      debugPrint('❌ Error marking sync error: $e');
    }
  }

  // ✅ ENHANCED: Get attendance for specific date with location name resolution
  Future<LocalAttendanceRecord?> getAttendanceForDate(String employeeId, String date) async {
    try {
      // Always check local database first
      LocalAttendanceRecord? localRecord = await _getLocalAttendanceRecord(employeeId, date);

      if (localRecord != null) {
        // ✅ ENHANCED: Resolve location names if they're stored as IDs
        localRecord = await _resolveLocationNamesInRecord(localRecord);
        return localRecord;
      }

      // If online and no local record, check Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final doc = await _firestore
            .collection('Attendance_Records')
            .doc('PTSEmployees')
            .collection('Records')
            .doc('$employeeId-$date')
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data()!;

          // ✅ Convert Timestamps to ISO strings BEFORE creating local record
          Map<String, dynamic> cleanData = _convertTimestampsForLocal(data);

          // ✅ Create record using cleaned data
          LocalAttendanceRecord record = LocalAttendanceRecord.fromFirestore(employeeId, cleanData);

          // ✅ Resolve location names
          record = await _resolveLocationNamesInRecord(record);

          // Save to local database for future offline use
          try {
            await _dbHelper.insert('attendance', record.toMap());
            debugPrint("💾 Saved Firestore data to local cache with resolved location names");
          } catch (localSaveError) {
            debugPrint("⚠️ Error saving to local cache: $localSaveError");
          }

          return record;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting attendance for date $date: $e');
      return null;
    }
  }

  // ✅ NEW: Resolve location names in existing records
  Future<LocalAttendanceRecord> _resolveLocationNamesInRecord(LocalAttendanceRecord record) async {
    try {
      bool needsUpdate = false;
      String? resolvedCheckInName = record.checkInLocationName;
      String? resolvedCheckOutName = record.checkOutLocationName;

      debugPrint("🔍 Resolving location names for record ${record.date}");
      debugPrint("  Current check-in: ID=${record.checkInLocationId}, Name=${record.checkInLocationName}");
      debugPrint("  Current check-out: ID=${record.checkOutLocationId}, Name=${record.checkOutLocationName}");

      // Resolve check-in location name if missing or looks like ID
      if (record.checkInLocationId != null && record.checkInLocationId!.isNotEmpty) {
        bool needsCheckInResolution = resolvedCheckInName == null ||
            resolvedCheckInName.isEmpty ||
            resolvedCheckInName == 'Unknown Location' ||
            resolvedCheckInName == 'Unknown location' ||
            (resolvedCheckInName.length > 20 && resolvedCheckInName.contains('-'));

        if (needsCheckInResolution) {
          debugPrint("🔧 Resolving check-in location name for ID: ${record.checkInLocationId}");
          resolvedCheckInName = await _getLocationNameFromId(record.checkInLocationId!);
          needsUpdate = true;
          debugPrint("✅ Resolved check-in name: $resolvedCheckInName");
        }
      }

      // Resolve check-out location name if missing or looks like ID
      if (record.checkOutLocationId != null && record.checkOutLocationId!.isNotEmpty) {
        bool needsCheckOutResolution = resolvedCheckOutName == null ||
            resolvedCheckOutName.isEmpty ||
            resolvedCheckOutName == 'Unknown Location' ||
            resolvedCheckOutName == 'Unknown location' ||
            (resolvedCheckOutName.length > 20 && resolvedCheckOutName.contains('-'));

        if (needsCheckOutResolution) {
          debugPrint("🔧 Resolving check-out location name for ID: ${record.checkOutLocationId}");
          resolvedCheckOutName = await _getLocationNameFromId(record.checkOutLocationId!);
          needsUpdate = true;
          debugPrint("✅ Resolved check-out name: $resolvedCheckOutName");
        }
      }

      // ✅ ENHANCED: Also check legacy location fields
      String? legacyLocationId = record.rawData['location']?.toString();
      String? legacyLocationName = record.rawData['locationName']?.toString();

      if (legacyLocationId != null && legacyLocationId.isNotEmpty &&
          (resolvedCheckInName == null || resolvedCheckInName == 'Unknown Location')) {
        debugPrint("🔧 Trying to resolve legacy location: $legacyLocationId");
        String resolvedName = await _getLocationNameFromId(legacyLocationId);
        if (resolvedName != 'Unknown Location') {
          resolvedCheckInName = resolvedName;
          needsUpdate = true;
          debugPrint("✅ Resolved from legacy location: $resolvedName");
        }
      }

      // Update record if names were resolved
      if (needsUpdate) {
        Map<String, dynamic> updatedRawData = Map<String, dynamic>.from(record.rawData);
        if (resolvedCheckInName != null && resolvedCheckInName != 'Unknown Location') {
          updatedRawData['checkInLocationName'] = resolvedCheckInName;
          updatedRawData['locationName'] = resolvedCheckInName; // Update legacy field too
        }
        if (resolvedCheckOutName != null && resolvedCheckOutName != 'Unknown Location') {
          updatedRawData['checkOutLocationName'] = resolvedCheckOutName;
        }

        LocalAttendanceRecord updatedRecord = record.copyWith(
          checkInLocationName: resolvedCheckInName,
          checkOutLocationName: resolvedCheckOutName,
          rawData: updatedRawData,
        );

        // Update local database
        if (record.id != null) {
          await _dbHelper.update(
            'attendance',
            updatedRecord.toMap(),
            where: 'id = ?',
            whereArgs: [record.id],
          );
          debugPrint("💾 Updated local database with resolved names");
        }

        debugPrint("🔄 Location names resolved: ${updatedRecord.locationSummary}");
        return updatedRecord;
      }

      return record;
    } catch (e) {
      debugPrint("❌ Error resolving location names: $e");
      return record;
    }
  }

  // ✅ Get today's attendance with proper location names
  Future<LocalAttendanceRecord?> getTodaysAttendance(String employeeId) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return getAttendanceForDate(employeeId, today);
  }

  // ✅ ENHANCED: Get attendance records for date range with location name resolution
  Future<List<LocalAttendanceRecord>> getAttendanceForDateRange({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefreshFromFirestore = false,
  }) async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      debugPrint("📅 Getting attendance for $employeeId from $startDateStr to $endDateStr (force: $forceRefreshFromFirestore)");

      Map<String, LocalAttendanceRecord> recordsMap = {};

      // If force refresh OR online, prioritize Firestore data
      if (forceRefreshFromFirestore || _connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          debugPrint("🌐 Fetching fresh data from Firestore...");

          QuerySnapshot snapshot = await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .where('employeeId', isEqualTo: employeeId)
              .where('date', isGreaterThanOrEqualTo: startDateStr)
              .where('date', isLessThanOrEqualTo: endDateStr)
              .get();

          debugPrint("🌐 Found ${snapshot.docs.length} records in Firestore");

          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String recordDate = data['date'] ?? '';

            if (recordDate.isEmpty) continue;

            // ✅ Convert Timestamps to ISO strings using helper method
            Map<String, dynamic> cleanData = _convertTimestampsForLocal(data);

            // ✅ Use new constructor that handles separate locations
            LocalAttendanceRecord record = LocalAttendanceRecord.fromFirestore(employeeId, cleanData);

            // ✅ Resolve location names
            record = await _resolveLocationNamesInRecord(record);

            recordsMap[recordDate] = record;

            // Update local cache with fresh data
            try {
              await _dbHelper.delete(
                'attendance',
                where: 'employee_id = ? AND date = ?',
                whereArgs: [employeeId, recordDate],
              );

              await _dbHelper.insert('attendance', record.toMap());
              debugPrint("🔄 Updated local cache for date: $recordDate with resolved names");

            } catch (e) {
              debugPrint("⚠️ Error updating local cache for $recordDate: $e");
            }
          }

        } catch (e) {
          debugPrint("❌ Error fetching from Firestore: $e");
        }
      }

      // Get local records as fallback/supplement
      if (!forceRefreshFromFirestore || recordsMap.isEmpty) {
        debugPrint("💾 Getting local records...");

        List<Map<String, dynamic>> localRecords = await _dbHelper.query(
          'attendance',
          where: 'employee_id = ? AND date >= ? AND date <= ?',
          whereArgs: [employeeId, startDateStr, endDateStr],
          orderBy: 'date DESC',
        );

        debugPrint("💾 Found ${localRecords.length} local records");

        for (var record in localRecords) {
          LocalAttendanceRecord localRecord = LocalAttendanceRecord.fromMap(record);

          // ✅ Resolve location names for local records too
          localRecord = await _resolveLocationNamesInRecord(localRecord);

          if (!recordsMap.containsKey(localRecord.date)) {
            recordsMap[localRecord.date] = localRecord;
          }
        }
      }

      // Convert to list and sort
      List<LocalAttendanceRecord> records = recordsMap.values.toList();
      records.sort((a, b) => b.date.compareTo(a.date));

      debugPrint("✅ Returning ${records.length} total records for date range");

      // ✅ DEBUG: Print location info for each record
      for (var record in records.take(5)) {
        debugPrint("📍 ${record.date}: ${record.locationSummary}");
      }

      return records;

    } catch (e) {
      debugPrint('❌ Error getting attendance for date range: $e');
      return [];
    }
  }

  // ✅ ENHANCED: Convert to AttendanceRecord with proper location handling
  AttendanceRecord convertToAttendanceRecord(LocalAttendanceRecord localRecord) {
    return AttendanceRecord(
      date: localRecord.date,
      checkIn: localRecord.checkIn != null ? DateTime.parse(localRecord.checkIn!) : null,
      checkOut: localRecord.checkOut != null ? DateTime.parse(localRecord.checkOut!) : null,
      checkInLocation: localRecord.checkInLocationId,
      checkOutLocation: localRecord.checkOutLocationId,
      checkInLocationName: localRecord.checkInLocationName,
      checkOutLocationName: localRecord.checkOutLocationName,
      workStatus: localRecord.rawData['workStatus'] ?? 'Unknown',
      totalHours: (localRecord.rawData['totalHours'] ?? 0.0).toDouble(),
      regularHours: _calculateRegularHours((localRecord.rawData['totalHours'] ?? 0.0).toDouble()),
      overtimeHours: (localRecord.rawData['overtimeHours'] ?? 0.0).toDouble(),
      isWithinGeofence: localRecord.rawData['isWithinGeofence'] ?? false,
      rawData: localRecord.rawData,
    );
  }

  // ✅ Get attendance records for a specific month with location resolution
  Future<List<LocalAttendanceRecord>> getAttendanceForMonth({
    required String employeeId,
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    DateTime startDate = DateTime(year, month, 1);
    DateTime endDate = DateTime(year, month + 1, 0);

    return getAttendanceForDateRange(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
      forceRefreshFromFirestore: forceRefresh,
    );
  }

  // ✅ ENHANCED: Force refresh today's data from Firestore with location resolution
  Future<LocalAttendanceRecord?> forceRefreshTodayFromFirestore(String employeeId) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    debugPrint("🔄 Force refreshing today's attendance from Firestore for $employeeId...");

    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final doc = await _firestore
            .collection('Attendance_Records')
            .doc('PTSEmployees')
            .collection('Records')
            .doc('$employeeId-$today')
            .get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data()!;
          debugPrint("🌐 Found fresh data in Firestore for today");

          // ✅ Convert Timestamps to ISO strings using helper method
          Map<String, dynamic> cleanData = _convertTimestampsForLocal(data);

          // ✅ Create record with cleaned data
          LocalAttendanceRecord record = LocalAttendanceRecord.fromFirestore(employeeId, cleanData);

          // ✅ Resolve location names
          record = await _resolveLocationNamesInRecord(record);

          // Update local cache
          try {
            await _dbHelper.delete(
              'attendance',
              where: 'employee_id = ? AND date = ?',
              whereArgs: [employeeId, today],
            );

            await _dbHelper.insert('attendance', record.toMap());
            debugPrint("🔄 Updated local cache with fresh data for today");
            debugPrint("📍 Today's locations: ${record.locationSummary}");

          } catch (e) {
            debugPrint("⚠️ Error updating local cache: $e");
          }

          return record;
        } else {
          debugPrint("📭 No record found in Firestore for today");
        }
      }
    } catch (e) {
      debugPrint("❌ Error force refreshing today's data: $e");
    }

    return null;
  }

  // ✅ ENHANCED: Get AttendanceRecord objects for month with proper location handling
  Future<List<AttendanceRecord>> getAttendanceRecordsForMonth({
    required String employeeId,
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint("📅 Getting attendance records for $employeeId, $year-$month");

      List<LocalAttendanceRecord> localRecords = await getAttendanceForMonth(
        employeeId: employeeId,
        year: year,
        month: month,
        forceRefresh: forceRefresh,
      );

      debugPrint("📱 Found ${localRecords.length} local records");

      // Convert to AttendanceRecord objects (now with proper location names)
      List<AttendanceRecord> existingRecords = localRecords
          .map((localRecord) => convertToAttendanceRecord(localRecord))
          .toList();

      // Generate complete month view
      List<AttendanceRecord> completeRecords = await _generateSimpleMonthView(
          employeeId, year, month, existingRecords);

      debugPrint("✅ Returning ${completeRecords.length} complete records with resolved location names");
      return completeRecords;

    } catch (e) {
      debugPrint("❌ Error getting attendance records for month: $e");
      return [];
    }
  }

  // Generate complete month view (unchanged, but now works with proper location names)
  Future<List<AttendanceRecord>> _generateSimpleMonthView(
      String employeeId,
      int year,
      int month,
      List<AttendanceRecord> existingRecords,
      ) async {
    try {
      debugPrint("🗓️ Generating simple month view...");

      Map<String, AttendanceRecord> existingRecordsMap = {};
      for (var record in existingRecords) {
        existingRecordsMap[record.date] = record;
      }

      List<AttendanceRecord> completeRecords = [];
      DateTime startOfMonth = DateTime(year, month, 1);
      DateTime endOfMonth = DateTime(year, month + 1, 0);
      DateTime currentDay = startOfMonth;

      while (currentDay.isBefore(endOfMonth) || currentDay.isAtSameMomentAs(endOfMonth)) {
        String currentDateStr = DateFormat('yyyy-MM-dd').format(currentDay);

        if (existingRecordsMap.containsKey(currentDateStr)) {
          completeRecords.add(existingRecordsMap[currentDateStr]!);
        } else {
          AttendanceRecord dayRecord = _createSimpleDayRecord(currentDay, currentDateStr);
          completeRecords.add(dayRecord);
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }

      completeRecords.sort((a, b) => b.date.compareTo(a.date));

      debugPrint("✅ Simple month view generated with ${completeRecords.length} days");
      return completeRecords;

    } catch (e) {
      debugPrint("❌ Error generating simple month view: $e");
      return [];
    }
  }

  // Create simple day record (unchanged)
  AttendanceRecord _createSimpleDayRecord(DateTime date, String dateStr) {
    if (date.weekday == DateTime.sunday) {
      return AttendanceRecord(
        date: dateStr,
        checkIn: null,
        checkOut: null,
        workStatus: 'Sunday Holiday',
        totalHours: 0.0,
        regularHours: 0.0,
        overtimeHours: 0.0,
        isWithinGeofence: false,
        rawData: {
          'hasRecord': false,
          'dayType': 'sunday',
          'isDayOff': true,
          'shouldCountAsPresent': true,
          'reason': 'Sunday Holiday',
        },
      );
    }

    if (date.weekday == DateTime.saturday) {
      return AttendanceRecord(
        date: dateStr,
        checkIn: null,
        checkOut: null,
        workStatus: 'Absent',
        totalHours: 0.0,
        regularHours: 0.0,
        overtimeHours: 0.0,
        isWithinGeofence: false,
        rawData: {
          'hasRecord': false,
          'dayType': 'working',
          'isDayOff': false,
          'shouldCountAsPresent': false,
          'reason': 'Absent on Saturday working day',
        },
      );
    }

    return AttendanceRecord(
      date: dateStr,
      checkIn: null,
      checkOut: null,
      workStatus: 'Absent',
      totalHours: 0.0,
      regularHours: 0.0,
      overtimeHours: 0.0,
      isWithinGeofence: false,
      rawData: {
        'hasRecord': false,
        'dayType': 'working',
        'isDayOff': false,
        'shouldCountAsPresent': false,
        'reason': 'Absent on working day',
      },
    );
  }

  // ✅ ENHANCED: Sync pending records with proper location names
  Future<bool> syncPendingRecords() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      debugPrint("📵 Cannot sync while offline");
      return false;
    }

    try {
      List<LocalAttendanceRecord> pendingRecords = await getPendingRecords();
      debugPrint("🔄 Syncing ${pendingRecords.length} pending records");

      int successCount = 0;
      int failureCount = 0;

      for (var record in pendingRecords) {
        try {
          debugPrint("📤 Syncing record ${record.id} for ${record.date}");
          debugPrint("📍 Locations: ${record.locationSummary}");

          // ✅ Resolve location names before syncing
          LocalAttendanceRecord resolvedRecord = await _resolveLocationNamesInRecord(record);

          await _syncToFirestore(resolvedRecord);
          successCount++;

          debugPrint("✅ Successfully synced record ${record.id} with location names");

        } catch (e) {
          failureCount++;
          await _markSyncError(record.employeeId, record.date, e.toString());
          debugPrint('❌ Error syncing record ${record.id}: $e');
        }
      }

      debugPrint("🎯 Sync completed. Success: $successCount, Failures: $failureCount");
      return failureCount == 0;

    } catch (e) {
      debugPrint('❌ Error in syncPendingRecords: $e');
      return false;
    }
  }

  // Get pending records that need syncing
  Future<List<LocalAttendanceRecord>> getPendingRecords() async {
    try {
      List<Map<String, dynamic>> maps = await _dbHelper.query(
        'attendance',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      return maps.map((map) => LocalAttendanceRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending records: $e');
      return [];
    }
  }

  // Helper: Calculate regular hours
  double _calculateRegularHours(double totalHours) {
    const double standardWorkHours = 8.0;
    return totalHours > standardWorkHours ? standardWorkHours : totalHours;
  }

  // Get recent attendance records
  Future<List<LocalAttendanceRecord>> getRecentAttendance(String employeeId, int limit) async {
    try {
      List<Map<String, dynamic>> localRecords = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'date DESC',
        limit: limit,
      );

      List<LocalAttendanceRecord> records = [];
      for (var record in localRecords) {
        LocalAttendanceRecord localRecord = LocalAttendanceRecord.fromMap(record);
        // ✅ Resolve location names
        localRecord = await _resolveLocationNamesInRecord(localRecord);
        records.add(localRecord);
      }

      return records;
    } catch (e) {
      debugPrint('❌ Error getting recent attendance: $e');
      return [];
    }
  }

  // ✅ ENHANCED: Get attendance statistics with location info
  Future<Map<String, dynamic>> getAttendanceStatistics({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      DateTime start = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      DateTime end = endDate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

      List<LocalAttendanceRecord> records = await getAttendanceForDateRange(
        employeeId: employeeId,
        startDate: start,
        endDate: end,
      );

      int totalDays = 0;
      int presentDays = 0;
      int absentDays = 0;
      double totalHours = 0;
      double totalOvertimeHours = 0;
      int lateCheckIns = 0;
      int multiLocationDays = 0;
      Set<String> uniqueLocations = {};

      for (var record in records) {
        totalDays++;

        if (record.checkIn != null) {
          presentDays++;

          // ✅ Track unique locations
          if (record.checkInLocationName != null) {
            uniqueLocations.add(record.checkInLocationName!);
          }
          if (record.checkOutLocationName != null) {
            uniqueLocations.add(record.checkOutLocationName!);
          }

          if (record.checkOut != null) {
            double hours = (record.rawData['totalHours'] ?? 0.0).toDouble();
            totalHours += hours;

            double overtime = (record.rawData['overtimeHours'] ?? 0.0).toDouble();
            totalOvertimeHours += overtime;
          }

          DateTime checkInTime = DateTime.parse(record.checkIn!);
          if (checkInTime.hour > 9 || (checkInTime.hour == 9 && checkInTime.minute > 0)) {
            lateCheckIns++;
          }

          // Count days with multiple locations
          if (record.hasMultipleLocations) {
            multiLocationDays++;
          }
        } else {
          absentDays++;
        }
      }

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'attendancePercentage': totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0,
        'totalHours': totalHours,
        'totalOvertimeHours': totalOvertimeHours,
        'averageHoursPerDay': presentDays > 0 ? totalHours / presentDays : 0.0,
        'lateCheckIns': lateCheckIns,
        'onTimePercentage': presentDays > 0 ? ((presentDays - lateCheckIns) / presentDays) * 100 : 0.0,
        'multiLocationDays': multiLocationDays,
        'mobilityPercentage': presentDays > 0 ? (multiLocationDays / presentDays) * 100 : 0.0,
        'uniqueLocationsCount': uniqueLocations.length,
        'uniqueLocations': uniqueLocations.toList(),
      };
    } catch (e) {
      debugPrint('❌ Error getting attendance statistics: $e');
      return {};
    }
  }

  // Clear attendance data for testing
  Future<bool> clearAttendanceData({String? employeeId}) async {
    try {
      if (employeeId != null) {
        await _dbHelper.delete(
          'attendance',
          where: 'employee_id = ?',
          whereArgs: [employeeId],
        );
        debugPrint("🧹 Cleared attendance data for employee $employeeId");
      } else {
        await _dbHelper.delete('attendance');
        debugPrint("🧹 Cleared all attendance data");
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing attendance data: $e');
      return false;
    }
  }

  // ✅ ENHANCED: Debug attendance locations with proper names
  Future<void> debugAttendanceLocations(String employeeId) async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      LocalAttendanceRecord? record = await getAttendanceForDate(employeeId, today);

      if (record != null) {
        debugPrint("🔍 DEBUG - Today's Attendance Locations:");
        debugPrint("  📅 Date: ${record.date}");
        debugPrint("  📍 Check-in ID: ${record.checkInLocationId ?? 'Not set'}");
        debugPrint("  📍 Check-in Name: ${record.checkInLocationName ?? 'Not set'}");
        debugPrint("  📍 Check-out ID: ${record.checkOutLocationId ?? 'Not set'}");
        debugPrint("  📍 Check-out Name: ${record.checkOutLocationName ?? 'Not set'}");
        debugPrint("  📊 Summary: ${record.locationSummary}");
        debugPrint("  🚗 Multiple locations: ${record.hasMultipleLocations}");
        debugPrint("  📋 Detailed Info: ${record.detailedLocationInfo}");
      } else {
        debugPrint("🔍 DEBUG - No attendance record found for today");
      }
    } catch (e) {
      debugPrint("❌ Error debugging attendance locations: $e");
    }
  }




// ADD THESE METHODS TO YOUR attendance_repository.dart file
// Add them inside the AttendanceRepository class

// ✅ FIXED: Enhanced sync method that prioritizes local unsynced data
  Future<bool> syncPendingRecordsWithPriority() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      debugPrint("📵 Cannot sync while offline");
      return false;
    }

    try {
      List<LocalAttendanceRecord> pendingRecords = await getPendingRecords();
      debugPrint("🔄 Syncing ${pendingRecords.length} pending records with priority logic");

      int successCount = 0;
      int failureCount = 0;

      for (var record in pendingRecords) {
        try {
          debugPrint("📤 Syncing record ${record.id} for ${record.date}");
          debugPrint("📍 Locations: ${record.locationSummary}");

          // ✅ CRITICAL: Before syncing, check if Firestore has conflicting data
          String firestoreDocId = '${record.employeeId}-${record.date}';

          try {
            DocumentSnapshot firestoreDoc = await _firestore
                .collection('Attendance_Records')
                .doc('PTSEmployees')
                .collection('Records')
                .doc(firestoreDocId)
                .get();

            if (firestoreDoc.exists) {
              Map<String, dynamic> firestoreData = firestoreDoc.data() as Map<String, dynamic>;

              // Compare states
              bool firestoreHasCheckIn = firestoreData['checkIn'] != null;
              bool firestoreHasCheckOut = firestoreData['checkOut'] != null;
              bool localHasCheckIn = record.hasCheckIn;
              bool localHasCheckOut = record.hasCheckOut;

              debugPrint("🔍 Sync conflict check for ${record.date}:");
              debugPrint("  Firestore: checkIn=$firestoreHasCheckIn, checkOut=$firestoreHasCheckOut");
              debugPrint("  Local: checkIn=$localHasCheckIn, checkOut=$localHasCheckOut");

              // ✅ FIXED: Local unsynced data always wins
              if (localHasCheckIn && !firestoreHasCheckIn) {
                debugPrint("💪 Local has check-in that Firestore doesn't - uploading local data");
              } else if (!localHasCheckOut && firestoreHasCheckOut) {
                debugPrint("💪 Local is checked in, Firestore shows checked out - uploading local data");
              } else if (localHasCheckOut && !firestoreHasCheckOut) {
                debugPrint("💪 Local has check-out that Firestore doesn't - uploading local data");
              }
            }
          } catch (firestoreCheckError) {
            debugPrint("⚠️ Error checking Firestore before sync: $firestoreCheckError");
            // Continue with sync anyway
          }

          // ✅ Resolve location names before syncing
          LocalAttendanceRecord resolvedRecord = await _resolveLocationNamesInRecord(record);

          // ✅ Sync with MERGE option to preserve existing data while updating with local changes
          Map<String, dynamic> firestoreData = resolvedRecord.toFirestore();

          // ✅ IMPORTANT: Convert ISO string dates to Timestamps for Firestore
          if (firestoreData['checkIn'] != null && firestoreData['checkIn'] is String) {
            firestoreData['checkIn'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkIn']));
          }
          if (firestoreData['checkOut'] != null && firestoreData['checkOut'] is String) {
            firestoreData['checkOut'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkOut']));
          }

          // ✅ Add sync metadata
          firestoreData['lastSyncedAt'] = Timestamp.now();
          firestoreData['syncSource'] = 'local_priority';

          // Save to Firestore with MERGE to preserve existing data while updating with local changes
          await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${record.employeeId}-${record.date}')
              .set(firestoreData, SetOptions(merge: true));

          // Mark as synced in local database
          await _markRecordAsSynced(record.employeeId, record.date);
          successCount++;

          debugPrint("✅ Successfully synced record ${record.id} with priority logic");

        } catch (e) {
          failureCount++;
          await _markSyncError(record.employeeId, record.date, e.toString());
          debugPrint('❌ Error syncing record ${record.id}: $e');
        }
      }

      debugPrint("🎯 Priority sync completed. Success: $successCount, Failures: $failureCount");
      return failureCount == 0;

    } catch (e) {
      debugPrint('❌ Error in syncPendingRecordsWithPriority: $e');
      return false;
    }
  }

// ✅ ALSO ADD: Method to force sync a specific date's attendance
  Future<bool> forceSyncAttendanceForDate(String employeeId, String date) async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      debugPrint("📵 Cannot sync while offline");
      return false;
    }

    try {
      debugPrint("🔄 Force syncing attendance for $employeeId on $date");

      LocalAttendanceRecord? localRecord = await getAttendanceForDate(employeeId, date);

      if (localRecord == null) {
        debugPrint("❌ No local record found for $employeeId on $date");
        return false;
      }

      // Resolve location names
      LocalAttendanceRecord resolvedRecord = await _resolveLocationNamesInRecord(localRecord);

      // Convert to Firestore format
      Map<String, dynamic> firestoreData = resolvedRecord.toFirestore();

      // Convert timestamps
      if (firestoreData['checkIn'] != null && firestoreData['checkIn'] is String) {
        firestoreData['checkIn'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkIn']));
      }
      if (firestoreData['checkOut'] != null && firestoreData['checkOut'] is String) {
        firestoreData['checkOut'] = Timestamp.fromDate(DateTime.parse(firestoreData['checkOut']));
      }

      // Add force sync metadata
      firestoreData['lastSyncedAt'] = Timestamp.now();
      firestoreData['syncSource'] = 'force_sync';
      firestoreData['forceSyncedAt'] = Timestamp.now();

      // Force update Firestore (SET instead of MERGE to completely overwrite)
      await _firestore
          .collection('Attendance_Records')
          .doc('PTSEmployees')
          .collection('Records')
          .doc('$employeeId-$date')
          .set(firestoreData);

      // Mark as synced locally
      await _markRecordAsSynced(employeeId, date);

      debugPrint("✅ Force sync completed for $employeeId on $date");
      debugPrint("📍 Synced locations: ${resolvedRecord.locationSummary}");

      return true;

    } catch (e) {
      debugPrint("❌ Error in force sync: $e");
      return false;
    }
  }


  // ✅ NEW: Bulk resolve location names for existing records
  Future<void> bulkResolveLocationNames(String employeeId) async {
    try {
      debugPrint("🔄 Starting bulk location name resolution for $employeeId...");

      List<Map<String, dynamic>> allRecords = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
      );

      debugPrint("📊 Found ${allRecords.length} records to process");

      int resolvedCount = 0;
      for (var recordMap in allRecords) {
        try {
          LocalAttendanceRecord record = LocalAttendanceRecord.fromMap(recordMap);
          LocalAttendanceRecord resolvedRecord = await _resolveLocationNamesInRecord(record);

          // Only update if names were actually resolved
          if (resolvedRecord.checkInLocationName != record.checkInLocationName ||
              resolvedRecord.checkOutLocationName != record.checkOutLocationName) {

            await _dbHelper.update(
              'attendance',
              resolvedRecord.toMap(),
              where: 'id = ?',
              whereArgs: [record.id],
            );

            resolvedCount++;
            debugPrint("✅ Resolved locations for ${record.date}: ${resolvedRecord.locationSummary}");
          }
        } catch (e) {
          debugPrint("❌ Error resolving record: $e");
        }
      }

      debugPrint("🎯 Bulk resolution completed: $resolvedCount/$allRecords.length} records updated");

    } catch (e) {
      debugPrint("❌ Error in bulk location name resolution: $e");
    }
  }
}



