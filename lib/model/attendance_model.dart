// lib/model/attendance_model.dart - FIXED WITH PROPER LOCATION HANDLING

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceRecord {
  final String date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? checkInLocation;     // ✅ NEW: Separate check-in location
  final String? checkOutLocation;    // ✅ NEW: Separate check-out location
  final String? checkInLocationName; // ✅ NEW: Human-readable check-in location name
  final String? checkOutLocationName;// ✅ NEW: Human-readable check-out location name
  final String workStatus;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final bool isWithinGeofence;
  final Map<String, dynamic> rawData;

  // ✅ ENHANCED: Better location getter with proper fallback logic
  String get location {
    // Priority 1: Use check-in location name if available
    if (checkInLocationName != null && checkInLocationName!.isNotEmpty &&
        checkInLocationName != 'Unknown Location' && checkInLocationName != 'Unknown location') {
      return checkInLocationName!;
    }

    // Priority 2: Use legacy locationName from rawData
    String? legacyName = rawData['locationName']?.toString();
    if (legacyName != null && legacyName.isNotEmpty &&
        legacyName != 'Unknown Location' && legacyName != 'Unknown location') {
      return legacyName;
    }

    // Priority 3: Use check-in location ID (less ideal)
    if (checkInLocation != null && checkInLocation!.isNotEmpty) {
      return checkInLocation!;
    }

    // Priority 4: Use legacy location from rawData
    String? legacyLocation = rawData['location']?.toString();
    if (legacyLocation != null && legacyLocation.isNotEmpty) {
      return legacyLocation;
    }

    return 'Unknown Location';
  }

  // ✅ NEW: Enhanced location summary that shows both locations properly
  String get locationSummary {
    String? checkInName = checkInLocationName ?? checkInLocation;
    String? checkOutName = checkOutLocationName ?? checkOutLocation;

    // Clean up names - remove UUID-like strings
    if (checkInName != null && checkInName.length > 20 && checkInName.contains('-')) {
      checkInName = 'Location ${checkInName.substring(0, 8)}...';
    }
    if (checkOutName != null && checkOutName.length > 20 && checkOutName.contains('-')) {
      checkOutName = 'Location ${checkOutName.substring(0, 8)}...';
    }

    if (checkInName == null && checkOutName == null) {
      return 'Unknown Location';
    }

    if (checkInName != null && checkOutName != null) {
      if (checkInName == checkOutName) {
        return checkInName;
      } else {
        return '$checkInName → $checkOutName';
      }
    }

    if (checkInName != null) {
      return 'In: $checkInName';
    }

    if (checkOutName != null) {
      return 'Out: $checkOutName';
    }

    return 'Unknown Location';
  }

  AttendanceRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInLocationName,
    this.checkOutLocationName,
    required this.workStatus,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.isWithinGeofence,
    required this.rawData,
  });

  factory AttendanceRecord.fromFirestore(Map<String, dynamic> data, {bool isOffDay = false}) {
    DateTime? checkIn;
    DateTime? checkOut;

    // ✅ FIXED: Safe type casting for checkIn
    if (data['checkIn'] != null) {
      try {
        if (data['checkIn'] is Timestamp) {
          checkIn = (data['checkIn'] as Timestamp).toDate();
        } else if (data['checkIn'] is String) {
          checkIn = DateTime.parse(data['checkIn'] as String);
        }
      } catch (e) {
        print("Error parsing checkIn: $e");
        checkIn = null;
      }
    }

    // ✅ FIXED: Safe type casting for checkOut
    if (data['checkOut'] != null) {
      try {
        if (data['checkOut'] is Timestamp) {
          checkOut = (data['checkOut'] as Timestamp).toDate();
        } else if (data['checkOut'] is String) {
          checkOut = DateTime.parse(data['checkOut'] as String);
        }
      } catch (e) {
        print("Error parsing checkOut: $e");
        checkOut = null;
      }
    }

    // Calculate hours with enhanced overtime logic
    double totalHours = 0.0;
    double overtimeHours = 0.0;
    double regularHours = 0.0;

    if (checkIn != null && checkOut != null) {
      Duration workDuration = checkOut.difference(checkIn);
      totalHours = workDuration.inMinutes / 60.0;

      // ✅ ENHANCED OVERTIME LOGIC with off day support
      if (isOffDay) {
        // All hours on off days (Saturday off, Sunday) are overtime
        overtimeHours = totalHours;
        regularHours = 0.0;
        print("Off day work detected: ${totalHours.toStringAsFixed(2)}h total (all overtime)");
      } else {
        // Standard work day logic
        const double standardWorkHours = 10.0;

        // Calculate overtime based on day type and time
        overtimeHours = _calculateOvertimeHours(checkIn, checkOut, isOffDay: isOffDay);

        // Regular hours is total hours minus overtime, capped at standard hours
        if (isOffDay) {
          regularHours = 0.0; // No regular hours on off days
        } else if (totalHours > standardWorkHours) {
          regularHours = standardWorkHours;
        } else {
          regularHours = totalHours - overtimeHours;
          if (regularHours < 0) regularHours = 0.0;
        }
      }
    }

    // Override with stored overtime hours if available
    if (data.containsKey('overtimeHours')) {
      overtimeHours = (data['overtimeHours'] ?? 0.0).toDouble();
    }

    // ✅ ENHANCED: Extract separate check-in and check-out locations with better fallback
    String? checkInLocation = data['checkInLocation']?.toString();
    String? checkOutLocation = data['checkOutLocation']?.toString();
    String? checkInLocationName = data['checkInLocationName']?.toString();
    String? checkOutLocationName = data['checkOutLocationName']?.toString();

    // ✅ IMPROVED: Better backward compatibility logic
    if (checkInLocation == null && data['location'] != null) {
      checkInLocation = data['location'].toString();
    }

    if (checkInLocationName == null) {
      // Try to get from multiple possible field names
      checkInLocationName = data['locationName']?.toString() ??
          data['checkInLocationName']?.toString() ??
          data['location_name']?.toString();
    }

    // ✅ DEBUG: Log location data for troubleshooting
    print("📍 AttendanceRecord location debug for ${data['date']}:");
    print("  checkInLocation: $checkInLocation");
    print("  checkInLocationName: $checkInLocationName");
    print("  checkOutLocation: $checkOutLocation");
    print("  checkOutLocationName: $checkOutLocationName");
    print("  legacy location: ${data['location']}");
    print("  legacy locationName: ${data['locationName']}");

    return AttendanceRecord(
      date: data['date'] ?? '',
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocation: checkInLocation,
      checkOutLocation: checkOutLocation,
      checkInLocationName: checkInLocationName,
      checkOutLocationName: checkOutLocationName,
      workStatus: data['workStatus'] ?? 'Unknown',
      totalHours: totalHours,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      isWithinGeofence: data['isWithinGeofence'] ?? false,
      rawData: data,
    );
  }

  // ✅ NEW: Calculate overtime hours based on time after 6:30 PM
  static double _calculateOvertimeHours(DateTime checkIn, DateTime checkOut, {bool isOffDay = false}) {
    try {
      // ✅ If it's an off day (Saturday off, Sunday), all hours are overtime
      if (isOffDay) {
        Duration workDuration = checkOut.difference(checkIn);
        double overtimeHours = workDuration.inMinutes / 60.0;
        print("Off day overtime: ${overtimeHours.toStringAsFixed(2)} hours");
        return overtimeHours > 0 ? overtimeHours : 0.0;
      }

      // ✅ Check if it's Saturday
      if (checkOut.weekday == DateTime.saturday) {
        Duration workDuration = checkOut.difference(checkIn);
        double overtimeHours = workDuration.inMinutes / 60.0;
        return overtimeHours > 0 ? overtimeHours : 0.0;
      }

      // ✅ For regular weekdays: overtime after 6:30 PM
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

      // Ensure overtime is not negative
      return overtimeHours > 0 ? overtimeHours : 0.0;
    } catch (e) {
      print("Error calculating overtime hours: $e");
      return 0.0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'checkInLocationName': checkInLocationName,
      'checkOutLocationName': checkOutLocationName,
      // ✅ Keep legacy location field for backward compatibility
      'location': checkInLocation ?? location,
      'locationName': checkInLocationName ?? (rawData['locationName'] ?? 'Unknown Location'),
      'workStatus': workStatus,
      'totalHours': totalHours,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'isWithinGeofence': isWithinGeofence,
      'rawData': rawData,
    };
  }

  // Helper methods
  bool get hasCheckIn => checkIn != null;
  bool get hasCheckOut => checkOut != null;
  bool get isCompleteDay => hasCheckIn && hasCheckOut;
  bool get hasOvertime => overtimeHours > 0;

  // ✅ NEW: Check if day requires sick leave application
  bool get requiresSickLeave => !hasCheckIn && !hasCheckOut && (rawData['hasRecord'] ?? true) == false;

  String get formattedCheckIn => hasCheckIn
      ? DateFormat('HH:mm').format(checkIn!)
      : '-';

  String get formattedCheckOut => hasCheckOut
      ? DateFormat('HH:mm').format(checkOut!)
      : '-';

  String get formattedTotalHours => totalHours > 0
      ? '${totalHours.toStringAsFixed(1)}h'
      : '-';

  String get formattedOvertimeHours => overtimeHours > 0
      ? '${overtimeHours.toStringAsFixed(1)}h'
      : '-';

  String get formattedDate {
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  String get dayOfWeek {
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
      return DateFormat('EEE').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  // ✅ NEW: Get detailed overtime information
  String get overtimeDetails {
    if (!hasOvertime) return 'No overtime';

    if (hasCheckOut) {
      DateTime overtimeStart = DateTime(
        checkOut!.year,
        checkOut!.month,
        checkOut!.day,
        18,
        30,
      );

      return 'Overtime from ${DateFormat('HH:mm').format(overtimeStart)} to ${DateFormat('HH:mm').format(checkOut!)}';
    }

    return 'Overtime: ${formattedOvertimeHours}';
  }

  // ✅ NEW: Get detailed location info
  String get detailedLocationInfo {
    List<String> parts = [];

    if (checkInLocationName != null && checkInLocationName!.isNotEmpty) {
      parts.add('Check-in: $checkInLocationName');
    } else if (checkInLocation != null && checkInLocation!.isNotEmpty) {
      parts.add('Check-in: $checkInLocation');
    }

    if (checkOutLocationName != null && checkOutLocationName!.isNotEmpty) {
      parts.add('Check-out: $checkOutLocationName');
    } else if (checkOutLocation != null && checkOutLocation!.isNotEmpty) {
      parts.add('Check-out: $checkOutLocation');
    }

    if (parts.isEmpty) {
      // Try legacy location data
      String? legacyName = rawData['locationName']?.toString();
      String? legacyLocation = rawData['location']?.toString();

      if (legacyName != null && legacyName.isNotEmpty) {
        return 'Location: $legacyName';
      } else if (legacyLocation != null && legacyLocation.isNotEmpty) {
        return 'Location: $legacyLocation';
      }

      return 'No location information available';
    }

    return parts.join(' • ');
  }
}

// Monthly summary class with updated calculations
class MonthlyAttendanceSummary {
  final String month;
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int sickLeaveDays;
  final double totalWorkHours;
  final double totalOvertimeHours;
  final double totalRegularHours;
  final int daysWithOvertime;
  final List<AttendanceRecord> records;

  MonthlyAttendanceSummary({
    required this.month,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.sickLeaveDays,
    required this.totalWorkHours,
    required this.totalOvertimeHours,
    required this.totalRegularHours,
    required this.daysWithOvertime,
    required this.records,
  });

  factory MonthlyAttendanceSummary.fromRecords(
      String month,
      List<AttendanceRecord> records,
      ) {
    int totalDays = records.length;
    int presentDays = 0;
    int absentDays = 0;
    int sickLeaveDays = 0;
    double totalWorkHours = 0;
    double totalOvertimeHours = 0;
    double totalRegularHours = 0;
    int daysWithOvertime = 0;

    for (var record in records) {
      bool hasRecord = record.rawData['hasRecord'] ?? true;

      if (record.requiresSickLeave) {
        sickLeaveDays++;
      } else if (!hasRecord || (!record.hasCheckIn && !record.hasCheckOut)) {
        absentDays++;
      } else {
        presentDays++;
      }

      totalWorkHours += record.totalHours;
      totalOvertimeHours += record.overtimeHours;
      totalRegularHours += record.regularHours;
      if (record.hasOvertime) daysWithOvertime++;
    }

    return MonthlyAttendanceSummary(
      month: month,
      totalDays: totalDays,
      presentDays: presentDays,
      absentDays: absentDays,
      sickLeaveDays: sickLeaveDays,
      totalWorkHours: totalWorkHours,
      totalOvertimeHours: totalOvertimeHours,
      totalRegularHours: totalRegularHours,
      daysWithOvertime: daysWithOvertime,
      records: records,
    );
  }

  double get averageHoursPerDay => presentDays > 0 ? totalWorkHours / presentDays : 0.0;
  double get averageOvertimePerDay => presentDays > 0 ? totalOvertimeHours / presentDays : 0.0;
  double get overtimePercentage => presentDays > 0 ? (daysWithOvertime / presentDays) * 100 : 0.0;
  double get attendancePercentage => totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;
}

