// lib/services/work_schedule_service.dart
// ✅ FIXED VERSION - No Alternative Saturday Service

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
      debugPrint("=== GETTING WORK SCHEDULE (SIMPLIFIED) ===");
      debugPrint("Employee ID: $employeeId");
      debugPrint("Employee PIN: $employeePin");

      DateTime today = DateTime.now();
      debugPrint("Today: ${DateFormat('EEEE, yyyy-MM-dd').format(today)}");

      // ✅ STEP 1: Check if today is Sunday (always off)
      if (today.weekday == DateTime.sunday) {
        debugPrint("📅 Today is Sunday - Off Day");
        return WorkSchedule.forOffDay(
          status: 'sunday_off',
          message: 'Sunday (Holiday) - Off Day',
        );
      }

      // ✅ STEP 2: Saturday is now a regular working day (no alternative logic)
      if (today.weekday == DateTime.saturday) {
        debugPrint("📅 Today is Saturday - Regular Working Day");

        // Get regular work schedule for Saturday
        WorkSchedule? schedule = await _getRegularWorkSchedule(employeeId, employeePin);

        if (schedule != null) {
          return WorkSchedule(
            startTime: schedule.startTime,
            endTime: schedule.endTime,
            breakStartTime: schedule.breakStartTime,
            breakEndTime: schedule.breakEndTime,
            workTiming: schedule.workTiming,
            dataSource: 'saturday_working',
            isAlternativeSaturday: false, // ✅ No alternative Saturday
            alternativeSaturdayStatus: 'Saturday Working Day',
            alternativeSaturdayMessage: 'Regular Saturday Working Day',
            alternativeSaturdayTiming: schedule.workTiming,
          );
        }
      }

      // ✅ STEP 3: Get regular work schedule for weekdays
      debugPrint("📅 Getting regular weekday schedule...");
      WorkSchedule? schedule = await _getRegularWorkSchedule(employeeId, employeePin);

      if (schedule != null) {
        return schedule;
      }

      debugPrint("❌ No work schedule found - returning default");
      return _getDefaultSchedule();

    } catch (e) {
      debugPrint("❌ Error getting work schedule: $e");
      return _getDefaultSchedule();
    }
  }

  /// Get regular work schedule from database (no alternative Saturday logic)
  static Future<WorkSchedule?> _getRegularWorkSchedule(String employeeId, String? employeePin) async {
    try {
      // ✅ STEP 1: Get break timing from employees collection
      Map<String, dynamic> employeeData = {};

      try {
        DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)
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

      // ✅ STEP 2: Get work timing from MasterSheet
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
      debugPrint("❌ Error getting regular work schedule: $e");
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

  /// Get default work schedule
  static WorkSchedule _getDefaultSchedule() {
    return WorkSchedule(
      startTime: '08:00',
      endTime: '18:00',
      workTiming: '08:00 - 18:00',
      dataSource: 'default',
      isAlternativeSaturday: false,
      alternativeSaturdayStatus: 'Default Schedule',
      alternativeSaturdayMessage: 'Using default work schedule',
      alternativeSaturdayTiming: '08:00 - 18:00',
    );
  }

  /// Check if current time is late for check-in
  static ScheduleCheckResult checkCheckInTiming(WorkSchedule schedule, DateTime checkInTime) {
    try {
      debugPrint("⏰ Checking check-in timing...");
      debugPrint("Schedule: ${schedule.workTiming}");
      debugPrint("Check-in time: ${DateFormat('HH:mm').format(checkInTime)}");

      // ✅ Handle off days
      if (schedule.isOffDay) {
        debugPrint("📅 Off day - allowing check-in (will be overtime)");
        return ScheduleCheckResult(
          isLate: false,
          isEarly: false,
          lateDuration: Duration.zero,
          earlyDuration: Duration.zero,
          message: "${schedule.alternativeSaturdayMessage} - Check-in will be recorded as overtime",
          expectedTime: checkInTime,
          actualTime: checkInTime,
          scheduleType: ScheduleEventType.checkIn,
        );
      }

      // ✅ Handle regular working days (including Saturday)
      DateTime expectedCheckIn = _parseTimeForToday(schedule.startTime);
      Duration difference = checkInTime.difference(expectedCheckIn);

      bool isLate = difference.inMinutes > 15; // 15 minutes grace period
      bool isEarly = difference.inMinutes < -30; // 30 minutes early limit

      String message;
      if (isLate) {
        message = "You are ${difference.inMinutes} minutes late. Expected check-in: ${DateFormat('h:mm a').format(expectedCheckIn)}";
      } else if (isEarly) {
        message = "Early check-in (expected: ${schedule.startTime})";
      } else {
        message = "On time! Check-in successful.";
      }

      return ScheduleCheckResult(
        isLate: isLate,
        isEarly: isEarly,
        lateDuration: isLate ? difference : Duration.zero,
        earlyDuration: isEarly ? difference.abs() : Duration.zero,
        message: message,
        expectedTime: expectedCheckIn,
        actualTime: checkInTime,
        scheduleType: ScheduleEventType.checkIn,
      );

    } catch (e) {
      debugPrint("❌ Error checking check-in timing: $e");
      return ScheduleCheckResult.error("Error validating check-in timing");
    }
  }

  /// Check if current time is early for check-out
  static ScheduleCheckResult checkCheckOutTiming(WorkSchedule schedule, DateTime checkOutTime) {
    try {
      debugPrint("⏰ Checking check-out timing...");
      debugPrint("Schedule: ${schedule.workTiming}");
      debugPrint("Check-out time: ${DateFormat('HH:mm').format(checkOutTime)}");

      // ✅ Handle off days - always allow (overtime)
      if (schedule.isOffDay) {
        return ScheduleCheckResult(
          isLate: false,
          isEarly: false,
          lateDuration: Duration.zero,
          earlyDuration: Duration.zero,
          message: "${schedule.alternativeSaturdayMessage} - Check-out recorded as overtime",
          expectedTime: checkOutTime,
          actualTime: checkOutTime,
          scheduleType: ScheduleEventType.checkOut,
        );
      }

      // ✅ Handle regular schedule (including Saturday)
      DateTime expectedCheckOut = _parseTimeForToday(schedule.endTime);
      Duration difference = expectedCheckOut.difference(checkOutTime);

      bool isEarly = difference.inMinutes > 30; // 30 minutes early limit
      bool isLate = checkOutTime.isAfter(expectedCheckOut.add(Duration(minutes: 15))); // 15 minutes late (overtime)

      String message;
      if (isEarly) {
        message = "You are checking out ${difference.inMinutes} minutes early. Expected check-out: ${DateFormat('h:mm a').format(expectedCheckOut)}";
      } else if (isLate) {
        message = "Late check-out - overtime recorded (expected: ${schedule.endTime})";
      } else {
        message = "Work day completed! Check-out successful.";
      }

      return ScheduleCheckResult(
        isLate: isLate,
        isEarly: isEarly,
        lateDuration: Duration.zero,
        earlyDuration: isEarly ? difference : Duration.zero,
        message: message,
        expectedTime: expectedCheckOut,
        actualTime: checkOutTime,
        scheduleType: ScheduleEventType.checkOut,
      );

    } catch (e) {
      debugPrint("❌ Error checking check-out timing: $e");
      return ScheduleCheckResult.error("Error validating check-out timing");
    }
  }

  /// Get next Saturday info for dashboard (simplified - no alternative Saturday)
  static Future<Map<String, dynamic>> getNextSaturdayInfo(String employeeId, String? employeePin) async {
    try {
      debugPrint("📅 Getting next Saturday info (simplified)...");

      // Calculate next Saturday
      DateTime now = DateTime.now();
      DateTime nextSaturday = now.add(Duration(days: (DateTime.saturday - now.weekday + 7) % 7));
      if (nextSaturday.isBefore(now) || nextSaturday.isAtSameMomentAs(now)) {
        nextSaturday = nextSaturday.add(Duration(days: 7));
      }

      // ✅ SIMPLIFIED: Saturday is always a working day now
      WorkSchedule? schedule = await _getRegularWorkSchedule(employeeId, employeePin);

      return {
        'hasNextSaturday': true,
        'nextSaturdayDate': DateFormat('yyyy-MM-dd').format(nextSaturday),
        'isInAlternativeSystem': false, // ✅ No alternative system
        'shouldWork': true, // ✅ Always work on Saturday
        'status': 'saturday_working_day',
        'message': 'Saturday Working Day',
        'timing': {
          'startTime': schedule?.startTime ?? '08:00',
          'endTime': schedule?.endTime ?? '18:00',
          'workTiming': schedule?.workTiming ?? '08:00 - 18:00',
        },
        'workingHours': schedule?.workTiming ?? '08:00 - 18:00',
      };
    } catch (e) {
      debugPrint("❌ Error getting next Saturday info: $e");
      return {
        'hasNextSaturday': false,
        'error': e.toString(),
      };
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

  /// Get check-out reminder time (30 minutes before end)
  static DateTime? getCheckOutReminderTime(WorkSchedule schedule) {
    if (schedule.isOffDay) return null;

    try {
      DateTime workEnd = _parseTimeForToday(schedule.endTime);
      return workEnd.subtract(const Duration(minutes: 30));
    } catch (e) {
      debugPrint("Error getting check-out reminder time: $e");
      return null;
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
  final String dataSource;

  // ✅ Simplified Alternative Saturday fields (for compatibility)
  final bool isAlternativeSaturday;
  final String? alternativeSaturdayStatus;
  final String? alternativeSaturdayMessage;
  final String? alternativeSaturdayTiming;

  WorkSchedule({
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    this.workTiming,
    this.dataSource = 'combined',
    this.isAlternativeSaturday = false,
    this.alternativeSaturdayStatus,
    this.alternativeSaturdayMessage,
    this.alternativeSaturdayTiming,
  }) : hasBreakTime = breakStartTime != null && breakEndTime != null;

  /// Create from combined employee and MasterSheet data
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
      breakStartTime: data['breakStartTime']?.toString(),
      breakEndTime: data['breakEndTime']?.toString(),
      workTiming: workTiming,
      dataSource: 'employees+mastersheet',
      isAlternativeSaturday: false, // ✅ No alternative Saturday
      alternativeSaturdayStatus: 'Regular Working Day',
      alternativeSaturdayMessage: 'Standard work schedule',
      alternativeSaturdayTiming: workTiming,
    );
  }

  /// Create off day schedule (Sunday)
  factory WorkSchedule.forOffDay({
    required String status,
    required String message,
  }) {
    return WorkSchedule(
      startTime: '00:00',
      endTime: '00:00',
      workTiming: 'Off Day',
      dataSource: 'off_day',
      isAlternativeSaturday: true,
      alternativeSaturdayStatus: status,
      alternativeSaturdayMessage: message,
      alternativeSaturdayTiming: 'Off Day',
    );
  }

  bool get isOffDay => startTime == '00:00' && endTime == '00:00';
  bool get isSaturdayWorking => false; // ✅ No special Saturday logic
  bool get isSaturdayOff => false; // ✅ No special Saturday logic

  /// ✅ Keep for backward compatibility
  factory WorkSchedule.fromMasterSheetData(Map<String, dynamic> data) {
    return WorkSchedule.fromCombinedData(data);
  }

  @override
  String toString() {
    if (isOffDay) {
      return 'WorkSchedule(Off Day: $alternativeSaturdayMessage, source: $dataSource)';
    }
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
