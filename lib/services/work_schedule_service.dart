// lib/services/work_schedule_service.dart
// ✅ CORRECTED VERSION - Break timing from employees collection, work timing from MasterSheet

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class WorkScheduleService {
  static const String _masterSheetPath = 'MasterSheet';
  static const String _employeeDataDoc = 'Employee-Data';
  static const String _employeesCollection = 'employees';

  /// Get work schedule for employee from BOTH employees collection AND MasterSheet
  static Future<WorkSchedule?> getEmployeeWorkSchedule(String employeeId, String? employeePin) async {
    try {
      debugPrint("=== FETCHING WORK SCHEDULE (CORRECTED - FROM BOTH SOURCES) ===");
      debugPrint("Employee ID: $employeeId");
      debugPrint("Employee PIN: $employeePin");

      // ✅ STEP 1: Get break timing from employees collection (auto-generated ID)
      Map<String, dynamic> employeeData = {};
      
      try {
        DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)  // ← Use the actual employeeId (like MidMRRsslPHsTokhSk43)
            .get()
            .timeout(const Duration(seconds: 10));

        if (employeeDoc.exists) {
          employeeData = employeeDoc.data() as Map<String, dynamic>;
          debugPrint("✅ Employee data fetched from employees/$employeeId");
          debugPrint("   - breakStartTime: ${employeeData['breakStartTime']}");
          debugPrint("   - breakEndTime: ${employeeData['breakEndTime']}");
          debugPrint("   - pin: ${employeeData['pin']}");
        } else {
          debugPrint("⚠️ No employee document found for: $employeeId");
        }
      } catch (e) {
        debugPrint("❌ Error fetching employee data: $e");
      }

      // ✅ STEP 2: Get work timing from MasterSheet (using PIN relationship)
      Map<String, dynamic> masterSheetData = {};
      
      if (employeePin != null || employeeData['pin'] != null) {
        try {
          String pin = employeePin ?? employeeData['pin']?.toString() ?? '';
          String masterSheetEmployeeId = _getMasterSheetId(employeeId, pin);
          debugPrint("🔍 Fetching work timing from MasterSheet: $masterSheetEmployeeId");

          DocumentSnapshot masterSheetDoc = await FirebaseFirestore.instance
              .collection(_masterSheetPath)
              .doc(_employeeDataDoc)
              .collection(_employeesCollection)
              .doc(masterSheetEmployeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (masterSheetDoc.exists) {
            masterSheetData = masterSheetDoc.data() as Map<String, dynamic>;
            debugPrint("✅ MasterSheet data fetched");
            debugPrint("   - workTiming: ${masterSheetData['workTiming']}");
            debugPrint("   - startTime: ${masterSheetData['startTime']}");
          } else {
            debugPrint("⚠️ No MasterSheet data found for: $masterSheetEmployeeId");
          }
        } catch (e) {
          debugPrint("❌ Error fetching MasterSheet data: $e");
        }
      }

      // ✅ STEP 3: Combine data from both sources
      Map<String, dynamic> combinedData = {};
      combinedData.addAll(masterSheetData);  // Work timing from MasterSheet
      combinedData.addAll(employeeData);     // Break timing from employees (overwrites if exists)

      if (combinedData.isEmpty) {
        debugPrint("❌ No work schedule data found from either source");
        return null;
      }

      WorkSchedule schedule = WorkSchedule.fromCombinedData(combinedData);
      debugPrint("✅ Work schedule loaded: ${schedule.toString()}");
      return schedule;

    } catch (e) {
      debugPrint("❌ Error fetching work schedule: $e");
      return null;
    }
  }

  /// Convert PIN to MasterSheet employee ID format
  static String _getMasterSheetId(String employeeId, String? employeePin) {
    String masterSheetEmployeeId = employeePin ?? employeeId;
    
    // Remove EMP prefix if present
    if (masterSheetEmployeeId.startsWith('EMP')) {
      masterSheetEmployeeId = masterSheetEmployeeId.substring(3);
    }

    // Parse as number and format with leading zeros
    try {
      int pinNumber = int.parse(masterSheetEmployeeId);
      masterSheetEmployeeId = 'EMP${pinNumber.toString().padLeft(4, '0')}';
    } catch (e) {
      // If parsing fails, use original format
      if (!masterSheetEmployeeId.startsWith('EMP')) {
        masterSheetEmployeeId = 'EMP$masterSheetEmployeeId';
      }
    }

    return masterSheetEmployeeId;
  }

  /// Check if current time is late for check-in
  static ScheduleCheckResult checkCheckInTiming(WorkSchedule schedule, DateTime checkInTime) {
    try {
      DateTime expectedStartTime = _parseTimeForToday(schedule.startTime);
      Duration lateDuration = checkInTime.difference(expectedStartTime);

      bool isLate = lateDuration.inMinutes > 0;
      
      return ScheduleCheckResult(
        isLate: isLate,
        lateDuration: isLate ? lateDuration : Duration.zero,
        expectedTime: expectedStartTime,
        actualTime: checkInTime,
        message: isLate 
            ? "You are ${lateDuration.inMinutes} minutes late. Expected check-in: ${DateFormat('h:mm a').format(expectedStartTime)}"
            : "On time! Check-in successful.",
        scheduleType: ScheduleEventType.checkIn,
      );
    } catch (e) {
      debugPrint("Error checking check-in timing: $e");
      return ScheduleCheckResult.error("Error validating check-in timing");
    }
  }

  /// Check if current time is early for check-out
  static ScheduleCheckResult checkCheckOutTiming(WorkSchedule schedule, DateTime checkOutTime) {
    try {
      DateTime expectedEndTime = _parseTimeForToday(schedule.endTime);
      Duration earlyDuration = expectedEndTime.difference(checkOutTime);

      bool isEarly = earlyDuration.inMinutes > 0;
      
      return ScheduleCheckResult(
        isEarly: isEarly,
        earlyDuration: isEarly ? earlyDuration : Duration.zero,
        expectedTime: expectedEndTime,
        actualTime: checkOutTime,
        message: isEarly 
            ? "You are checking out ${earlyDuration.inMinutes} minutes early. Expected check-out: ${DateFormat('h:mm a').format(expectedEndTime)}"
            : "Work day completed! Check-out successful.",
        scheduleType: ScheduleEventType.checkOut,
      );
    } catch (e) {
      debugPrint("Error checking check-out timing: $e");
      return ScheduleCheckResult.error("Error validating check-out timing");
    }
  }

  /// Get check-out reminder time (30 minutes before end)
  static DateTime? getCheckOutReminderTime(WorkSchedule schedule) {
    try {
      DateTime expectedEndTime = _parseTimeForToday(schedule.endTime);
      return expectedEndTime.subtract(const Duration(minutes: 30));
    } catch (e) {
      debugPrint("Error calculating check-out reminder time: $e");
      return null;
    }
  }

  /// Check if user is currently in break time
  static bool isInBreakTime(WorkSchedule schedule, DateTime currentTime) {
    if (!schedule.hasBreakTime) return false;

    try {
      DateTime breakStart = _parseTimeForToday(schedule.breakStartTime!);
      DateTime breakEnd = _parseTimeForToday(schedule.breakEndTime!);
      
      return currentTime.isAfter(breakStart) && currentTime.isBefore(breakEnd);
    } catch (e) {
      debugPrint("Error checking break time: $e");
      return false;
    }
  }

  /// Parse time string (like "08:00" or "12:00 PM") for today's date
  static DateTime _parseTimeForToday(String timeString) {
    DateTime today = DateTime.now();
    
    try {
      // Handle formats like "12:00 PM" or "1:00 PM"
      if (timeString.contains('AM') || timeString.contains('PM')) {
        DateFormat format = DateFormat('h:mm a');
        DateTime parsedTime = format.parse(timeString);
        return DateTime(today.year, today.month, today.day, parsedTime.hour, parsedTime.minute);
      }
      
      // Handle 24-hour format like "08:00" or "18:00"
      List<String> timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        return DateTime(today.year, today.month, today.day, hour, minute);
      }
      
      throw FormatException('Invalid time format: $timeString');
    } catch (e) {
      debugPrint("Error parsing time '$timeString': $e");
      // Fallback to current time
      return today;
    }
  }

  /// Setup automatic check-out reminder
  static Timer? setupCheckOutReminder(WorkSchedule schedule, Function() onReminder) {
    DateTime? reminderTime = getCheckOutReminderTime(schedule);
    if (reminderTime == null) return null;

    DateTime now = DateTime.now();
    if (reminderTime.isBefore(now)) {
      debugPrint("Check-out reminder time has already passed");
      return null;
    }

    Duration timeUntilReminder = reminderTime.difference(now);
    debugPrint("Setting up check-out reminder in ${timeUntilReminder.inMinutes} minutes");

    return Timer(timeUntilReminder, () {
      debugPrint("🔔 Triggering check-out reminder");
      onReminder();
    });
  }
}

/// Work schedule data model
class WorkSchedule {
  final String startTime;
  final String endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final String? workTiming;
  final bool hasBreakTime;
  final String dataSource; // ✅ NEW: Track where data came from

  WorkSchedule({
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    this.workTiming,
    this.dataSource = 'combined',
  }) : hasBreakTime = breakStartTime != null && breakEndTime != null;

  /// ✅ NEW: Create from combined data (employees + MasterSheet)
  factory WorkSchedule.fromCombinedData(Map<String, dynamic> data) {
    String? workTiming = data['workTiming']?.toString();
    String startTime = data['startTime']?.toString() ?? '08:00';
    String endTime = '18:00'; // Default end time

    // Parse workTiming if available (format: "08:00 - 18:00")
    if (workTiming != null && workTiming.contains(' - ')) {
      List<String> timings = workTiming.split(' - ');
      if (timings.length == 2) {
        startTime = timings[0].trim();
        endTime = timings[1].trim();
      }
    }

    return WorkSchedule(
      startTime: startTime,
      endTime: endTime,
      breakStartTime: data['breakStartTime']?.toString(), // ← From employees collection
      breakEndTime: data['breakEndTime']?.toString(),     // ← From employees collection
      workTiming: workTiming,                             // ← From MasterSheet
      dataSource: 'employees+mastersheet',
    );
  }

  /// ✅ LEGACY: Keep for backward compatibility
  factory WorkSchedule.fromMasterSheetData(Map<String, dynamic> data) {
    return WorkSchedule.fromCombinedData(data);
  }

  @override
  String toString() {
    return 'WorkSchedule(start: $startTime, end: $endTime, break: ${hasBreakTime ? "$breakStartTime-$breakEndTime" : "None"}, source: $dataSource)';
  }
}

/// Result of schedule timing check
class ScheduleCheckResult {
  final bool isLate;
  final bool isEarly;
  final Duration lateDuration;
  final Duration earlyDuration;
  final DateTime expectedTime;
  final DateTime actualTime;
  final String message;
  final ScheduleEventType scheduleType;
  final bool hasError;
  final String? errorMessage;

  ScheduleCheckResult({
    this.isLate = false,
    this.isEarly = false,
    this.lateDuration = Duration.zero,
    this.earlyDuration = Duration.zero,
    required this.expectedTime,
    required this.actualTime,
    required this.message,
    required this.scheduleType,
    this.hasError = false,
    this.errorMessage,
  });

  factory ScheduleCheckResult.error(String errorMessage) {
    DateTime now = DateTime.now();
    return ScheduleCheckResult(
      expectedTime: now,
      actualTime: now,
      message: errorMessage,
      scheduleType: ScheduleEventType.checkIn,
      hasError: true,
      errorMessage: errorMessage,
    );
  }

  bool get isOnTime => !isLate && !isEarly && !hasError;
}

enum ScheduleEventType { checkIn, checkOut }