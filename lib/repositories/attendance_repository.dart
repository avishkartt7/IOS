// lib/repositories/attendance_repository.dart - FIXED CROSS-DEVICE SYNC VERSION

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/model/local_attendance_model.dart';
import 'package:face_auth/model/attendance_model.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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

  // Record check-in that works both online and offline
  Future<bool> recordCheckIn({
    required String employeeId,
    required DateTime checkInTime,
    required String locationId,
    required String locationName,
    required double locationLat,
    required double locationLng,
    String? imageData,
  }) async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      print("AttendanceRepository: Recording check-in for $employeeId on $today");

      // First, clear any existing records for today (to handle duplicates)
      try {
        await _dbHelper.delete(
          'attendance',
          where: 'employee_id = ? AND date = ?',
          whereArgs: [employeeId, today],
        );
        print("AttendanceRepository: Cleared any existing records for today");
      } catch (deleteError) {
        print("AttendanceRepository: Error clearing existing records: $deleteError");
      }

      // Prepare check-in data
      Map<String, dynamic> checkInData = {
        'employeeId': employeeId,
        'date': today,
        'checkIn': checkInTime.toIso8601String(),
        'checkOut': null,
        'workStatus': 'In Progress',
        'totalHours': 0,
        'location': locationName,
        'locationId': locationId,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'isWithinGeofence': true,
      };

      // Create local record
      LocalAttendanceRecord localRecord = LocalAttendanceRecord(
        employeeId: employeeId,
        date: today,
        checkIn: checkInTime.toIso8601String(),
        locationId: locationId,
        isSynced: false,
        rawData: checkInData,
      );

      // Save to local database
      int localId = await _dbHelper.insert('attendance', localRecord.toMap());
      print("AttendanceRepository: Check-in saved locally with ID: $localId");

      // If online, try to save to Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('$employeeId-$today')
              .set({
            ...checkInData,
            'checkIn': Timestamp.fromDate(checkInTime),
          }, SetOptions(merge: true));

          // Mark as synced
          await _dbHelper.update(
            'attendance',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [localId],
          );

          print("AttendanceRepository: Check-in saved to Firestore and marked as synced");
        } catch (e) {
          print("AttendanceRepository: Error saving to Firestore: $e");
        }
      }

      return true;
    } catch (e) {
      print('AttendanceRepository: Error recording check-in: $e');
      return false;
    }
  }

  // Record check-out that works both online and offline
  Future<bool> recordCheckOut({
    required String employeeId,
    required DateTime checkOutTime,
  }) async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      print("AttendanceRepository: Recording check-out for $employeeId on $today");

      // First, check if we have a local record
      List<Map<String, dynamic>> localRecords = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, today],
      );

      if (localRecords.isEmpty) {
        print("AttendanceRepository: No check-in record found for today");
        return false;
      }

      // Get the local record and update it
      LocalAttendanceRecord record = LocalAttendanceRecord.fromMap(localRecords.first);

      // Ensure there's a check-in time
      if (record.checkIn == null) {
        print("AttendanceRepository: No check-in time in record");
        return false;
      }

      DateTime checkInTime = DateTime.parse(record.checkIn!);

      // Calculate working hours
      double hoursWorked = checkOutTime.difference(checkInTime).inMinutes / 60;
      print("AttendanceRepository: Hours worked: ${hoursWorked.toStringAsFixed(2)}");

      // Update the raw data
      Map<String, dynamic> updatedData = Map<String, dynamic>.from(record.rawData);
      updatedData['checkOut'] = checkOutTime.toIso8601String();
      updatedData['workStatus'] = 'Completed';
      updatedData['totalHours'] = hoursWorked;

      // Calculate overtime hours (standard work day is 8 hours)
      const double standardWorkHours = 8.0;
      double overtimeHours = hoursWorked > standardWorkHours ? hoursWorked - standardWorkHours : 0.0;
      updatedData['overtimeHours'] = overtimeHours;

      // Prepare the updated local record
      LocalAttendanceRecord updatedRecord = LocalAttendanceRecord(
        id: record.id,
        employeeId: employeeId,
        date: today,
        checkIn: record.checkIn,
        checkOut: checkOutTime.toIso8601String(),
        locationId: record.locationId,
        isSynced: false,
        rawData: updatedData,
      );

      // Update local record first
      await _dbHelper.update(
        'attendance',
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      print("AttendanceRepository: Local record updated");

      // If online, try to update Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('$employeeId-$today')
              .set({
            'checkOut': Timestamp.fromDate(checkOutTime),
            'workStatus': 'Completed',
            'totalHours': hoursWorked,
            'overtimeHours': overtimeHours,
          }, SetOptions(merge: true));

          print("AttendanceRepository: Firestore updated successfully");

          // Mark as synced in local database
          await _dbHelper.update(
            'attendance',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [record.id],
          );
        } catch (e) {
          print("AttendanceRepository: Error updating Firestore: $e");
        }
      } else {
        print("AttendanceRepository: Offline mode - record marked for sync");
      }

      return true;
    } catch (e) {
      print('AttendanceRepository: Error recording check-out: $e');
      return false;
    }
  }

  // Get today's attendance record
  Future<LocalAttendanceRecord?> getTodaysAttendance(String employeeId) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return getAttendanceForDate(employeeId, today);
  }

  // Get attendance for a specific date
  Future<LocalAttendanceRecord?> getAttendanceForDate(String employeeId, String date) async {
    try {
      // Always check local database first
      List<Map<String, dynamic>> records = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [employeeId, date],
      );

      if (records.isNotEmpty) {
        return LocalAttendanceRecord.fromMap(records.first);
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

          // Convert Timestamp to ISO string
          if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
            data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
          }
          if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
            data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
          }

          // Create and save local record
          LocalAttendanceRecord record = LocalAttendanceRecord(
            employeeId: employeeId,
            date: date,
            checkIn: data['checkIn'],
            checkOut: data['checkOut'],
            locationId: data['locationId'],
            isSynced: true,
            rawData: data,
          );

          // Save to local database for future offline use
          await _dbHelper.insert('attendance', record.toMap());

          return record;
        }
      }

      return null;
    } catch (e) {
      print('Error getting attendance for date $date: $e');
      return null;
    }
  }

  // ✅ FIXED: Get attendance records for a date range with FORCE REFRESH option
  Future<List<LocalAttendanceRecord>> getAttendanceForDateRange({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefreshFromFirestore = false, // ✅ NEW: Force refresh option
  }) async {
    try {
      String startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      String endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      print("AttendanceRepository: Getting attendance for $employeeId from $startDateStr to $endDateStr (force: $forceRefreshFromFirestore)");

      Map<String, LocalAttendanceRecord> recordsMap = {};

      // ✅ FIXED: If force refresh OR online, prioritize Firestore data
      if (forceRefreshFromFirestore || _connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          print("🌐 Fetching fresh data from Firestore...");

          // Query Firestore for records in date range
          QuerySnapshot snapshot = await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .where('employeeId', isEqualTo: employeeId)
              .where('date', isGreaterThanOrEqualTo: startDateStr)
              .where('date', isLessThanOrEqualTo: endDateStr)
              .get();

          print("🌐 Found ${snapshot.docs.length} records in Firestore");

          // ✅ FIXED: Process ALL Firestore records and update local cache
          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String recordDate = data['date'] ?? '';

            if (recordDate.isEmpty) continue;

            // Convert Timestamp to ISO string
            if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
              data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
            }
            if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
              data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
            }

            LocalAttendanceRecord record = LocalAttendanceRecord(
              employeeId: employeeId,
              date: recordDate,
              checkIn: data['checkIn'],
              checkOut: data['checkOut'],
              locationId: data['locationId'],
              isSynced: true,
              rawData: data,
            );

            // Add to our collection (Firestore data takes priority)
            recordsMap[recordDate] = record;

            // ✅ FIXED: Update/replace local cache with fresh Firestore data
            try {
              // First, delete any existing local record for this date
              await _dbHelper.delete(
                'attendance',
                where: 'employee_id = ? AND date = ?',
                whereArgs: [employeeId, recordDate],
              );

              // Then insert the fresh data
              await _dbHelper.insert('attendance', record.toMap());
              print("🔄 Updated local cache for date: $recordDate");

            } catch (e) {
              print("⚠️ Error updating local cache for $recordDate: $e");
            }
          }

        } catch (e) {
          print("❌ Error fetching from Firestore: $e");
          // Fall back to local data if Firestore fails
        }
      }

      // ✅ IMPROVED: Also get local records, but Firestore data takes priority
      if (!forceRefreshFromFirestore || recordsMap.isEmpty) {
        print("💾 Getting local records as fallback/supplement...");

        List<Map<String, dynamic>> localRecords = await _dbHelper.query(
          'attendance',
          where: 'employee_id = ? AND date >= ? AND date <= ?',
          whereArgs: [employeeId, startDateStr, endDateStr],
          orderBy: 'date DESC',
        );

        print("💾 Found ${localRecords.length} local records");

        // Add local records only if not already in recordsMap (Firestore takes priority)
        for (var record in localRecords) {
          LocalAttendanceRecord localRecord = LocalAttendanceRecord.fromMap(record);
          if (!recordsMap.containsKey(localRecord.date)) {
            recordsMap[localRecord.date] = localRecord;
          }
        }
      }

      // Convert map to list and sort by date (newest first)
      List<LocalAttendanceRecord> records = recordsMap.values.toList();
      records.sort((a, b) => b.date.compareTo(a.date));

      print("✅ Returning ${records.length} total records for date range");
      return records;

    } catch (e) {
      print('❌ Error getting attendance for date range: $e');
      return [];
    }
  }

  // ✅ NEW: Force refresh specific month from Firestore
  Future<List<LocalAttendanceRecord>> forceRefreshMonthFromFirestore({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    DateTime startDate = DateTime(year, month, 1);
    DateTime endDate = DateTime(year, month + 1, 0);

    print("🔄 Force refreshing month $year-$month from Firestore...");

    return getAttendanceForDateRange(
      employeeId: employeeId,
      startDate: startDate,
      endDate: endDate,
      forceRefreshFromFirestore: true, // ✅ Force refresh from Firestore
    );
  }

  // ✅ FIXED: Get attendance records for a specific month with force refresh option
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

  // Convert LocalAttendanceRecord to AttendanceRecord
  AttendanceRecord convertToAttendanceRecord(LocalAttendanceRecord localRecord) {
    return AttendanceRecord(
      date: localRecord.date,
      checkIn: localRecord.checkIn != null ? DateTime.parse(localRecord.checkIn!) : null,
      checkOut: localRecord.checkOut != null ? DateTime.parse(localRecord.checkOut!) : null,
      location: localRecord.rawData['location'] ?? 'Unknown',
      workStatus: localRecord.rawData['workStatus'] ?? 'Unknown',
      totalHours: (localRecord.rawData['totalHours'] ?? 0.0).toDouble(),
      regularHours: _calculateRegularHours((localRecord.rawData['totalHours'] ?? 0.0).toDouble()),
      overtimeHours: (localRecord.rawData['overtimeHours'] ?? 0.0).toDouble(),
      isWithinGeofence: localRecord.rawData['isWithinGeofence'] ?? false,
      rawData: localRecord.rawData,
    );
  }

  // ✅ FIXED: Get AttendanceRecord objects for a month with force refresh option
  Future<List<AttendanceRecord>> getAttendanceRecordsForMonth({
    required String employeeId,
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    List<LocalAttendanceRecord> localRecords = await getAttendanceForMonth(
      employeeId: employeeId,
      year: year,
      month: month,
      forceRefresh: forceRefresh,
    );

    // Convert to AttendanceRecord objects
    return localRecords.map((localRecord) => convertToAttendanceRecord(localRecord)).toList();
  }

  // ✅ NEW: Force refresh current day from Firestore (for cross-device scenarios)
  Future<LocalAttendanceRecord?> forceRefreshTodayFromFirestore(String employeeId) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    print("🔄 Force refreshing today's attendance from Firestore for $employeeId...");

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
          print("🌐 Found fresh data in Firestore for today");

          // Convert Timestamp to ISO string
          if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
            data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
          }
          if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
            data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
          }

          // Create record
          LocalAttendanceRecord record = LocalAttendanceRecord(
            employeeId: employeeId,
            date: today,
            checkIn: data['checkIn'],
            checkOut: data['checkOut'],
            locationId: data['locationId'],
            isSynced: true,
            rawData: data,
          );

          // ✅ Update local cache with fresh data
          try {
            // Delete existing local record
            await _dbHelper.delete(
              'attendance',
              where: 'employee_id = ? AND date = ?',
              whereArgs: [employeeId, today],
            );

            // Insert fresh data
            await _dbHelper.insert('attendance', record.toMap());
            print("🔄 Updated local cache with fresh data for today");

          } catch (e) {
            print("⚠️ Error updating local cache: $e");
          }

          return record;
        } else {
          print("📭 No record found in Firestore for today");
        }
      }
    } catch (e) {
      print("❌ Error force refreshing today's data: $e");
    }

    return null;
  }

  // Helper: Calculate regular hours (max 8 hours)
  double _calculateRegularHours(double totalHours) {
    const double standardWorkHours = 8.0;
    return totalHours > standardWorkHours ? standardWorkHours : totalHours;
  }

  // Get recent attendance records
  Future<List<LocalAttendanceRecord>> getRecentAttendance(String employeeId, int limit) async {
    try {
      List<LocalAttendanceRecord> records = [];

      // First try local database
      List<Map<String, dynamic>> localRecords = await _dbHelper.query(
        'attendance',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'date DESC',
        limit: limit,
      );

      if (localRecords.isNotEmpty) {
        records = localRecords.map((record) => LocalAttendanceRecord.fromMap(record)).toList();
      }

      // If online and we need more records, check Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online && records.length < limit) {
        final snapshot = await _firestore
            .collection('Attendance_Records')
            .doc('PTSEmployees')
            .collection('Records')
            .where('employeeId', isEqualTo: employeeId)
            .orderBy('date', descending: true)
            .limit(limit)
            .get();

        if (snapshot.docs.isNotEmpty) {
          // Process Firestore records
          List<LocalAttendanceRecord> firestoreRecords = [];

          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data();

            // Convert Timestamps to ISO strings
            if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
              data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
            }
            if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
              data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
            }

            LocalAttendanceRecord record = LocalAttendanceRecord(
              employeeId: employeeId,
              date: data['date'],
              checkIn: data['checkIn'],
              checkOut: data['checkOut'],
              locationId: data['locationId'],
              isSynced: true,
              rawData: data,
            );

            firestoreRecords.add(record);

            // Save to local database for future offline use
            await _dbHelper.insert('attendance', record.toMap());
          }

          // Merge and limit records
          records = [...firestoreRecords];
          if (records.length > limit) {
            records = records.sublist(0, limit);
          }
        }
      }

      return records;
    } catch (e) {
      print('Error getting recent attendance: $e');
      return [];
    }
  }

  // Get pending records that need to be synced
  Future<List<LocalAttendanceRecord>> getPendingRecords() async {
    try {
      List<Map<String, dynamic>> maps = await _dbHelper.query(
        'attendance',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      return maps.map((map) => LocalAttendanceRecord.fromMap(map)).toList();
    } catch (e) {
      print('Error getting pending records: $e');
      return [];
    }
  }

  // Sync pending records with Firestore
  Future<bool> syncPendingRecords() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      print("AttendanceRepository: Cannot sync while offline");
      return false;
    }

    try {
      // Get all pending records
      List<LocalAttendanceRecord> pendingRecords = await getPendingRecords();
      print("AttendanceRepository: Syncing ${pendingRecords.length} pending records");

      int successCount = 0;
      int failureCount = 0;

      for (var record in pendingRecords) {
        try {
          print("AttendanceRepository: Syncing record ${record.id} for date ${record.date}");

          // Prepare Firestore data
          Map<String, dynamic> firestoreData = Map<String, dynamic>.from(record.rawData);

          // Convert ISO string dates to Timestamps for Firestore
          if (firestoreData['checkIn'] != null) {
            firestoreData['checkIn'] = Timestamp.fromDate(
                DateTime.parse(firestoreData['checkIn'])
            );
          }
          if (firestoreData['checkOut'] != null) {
            firestoreData['checkOut'] = Timestamp.fromDate(
                DateTime.parse(firestoreData['checkOut'])
            );
          }

          // Update Firestore
          await _firestore
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${record.employeeId}-${record.date}')
              .set(firestoreData, SetOptions(merge: true));

          // Mark as synced
          await _dbHelper.update(
            'attendance',
            {'is_synced': 1, 'sync_error': null},
            where: 'id = ?',
            whereArgs: [record.id],
          );

          successCount++;
          print("AttendanceRepository: Successfully synced record ${record.id}");
        } catch (e) {
          failureCount++;
          // Update with sync error
          await _dbHelper.update(
            'attendance',
            {'sync_error': e.toString()},
            where: 'id = ?',
            whereArgs: [record.id],
          );
          print('AttendanceRepository: Error syncing record ${record.id}: $e');
        }
      }

      print("AttendanceRepository: Sync completed. Success: $successCount, Failures: $failureCount");
      return failureCount == 0;
    } catch (e) {
      print('AttendanceRepository: Error in syncPendingRecords: $e');
      return false;
    }
  }

  // Get attendance statistics for an employee
  Future<Map<String, dynamic>> getAttendanceStatistics({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Default to current month if no dates provided
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

      for (var record in records) {
        totalDays++;

        if (record.checkIn != null) {
          presentDays++;

          // Calculate hours
          if (record.checkOut != null) {
            double hours = (record.rawData['totalHours'] ?? 0.0).toDouble();
            totalHours += hours;

            double overtime = (record.rawData['overtimeHours'] ?? 0.0).toDouble();
            totalOvertimeHours += overtime;
          }

          // Check for late check-in (after 9:00 AM)
          DateTime checkInTime = DateTime.parse(record.checkIn!);
          if (checkInTime.hour > 9 || (checkInTime.hour == 9 && checkInTime.minute > 0)) {
            lateCheckIns++;
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
      };
    } catch (e) {
      print('Error getting attendance statistics: $e');
      return {};
    }
  }

  // Get locally stored locations - used for testing
  Future<List<Map<String, dynamic>>> getLocalStoredLocations() async {
    try {
      return await _dbHelper.query('locations');
    } catch (e) {
      print('Error getting local locations: $e');
      return [];
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
        print("AttendanceRepository: Cleared attendance data for employee $employeeId");
      } else {
        await _dbHelper.delete('attendance');
        print("AttendanceRepository: Cleared all attendance data");
      }
      return true;
    } catch (e) {
      print('Error clearing attendance data: $e');
      return false;
    }
  }
}