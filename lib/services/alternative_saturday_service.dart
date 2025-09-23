// lib/services/alternative_saturday_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class AlternativeSaturdaySchedule {
  final String id;
  final String title;
  final String month;
  final int year;
  final String status;
  final Map<String, dynamic> defaultTiming;
  final List<SaturdayScheduleDay> schedules;
  final Map<String, List<Map<String, dynamic>>> employees;
  final int totalSaturdays;
  final bool isEditable;

  AlternativeSaturdaySchedule({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    required this.status,
    required this.defaultTiming,
    required this.schedules,
    required this.employees,
    required this.totalSaturdays,
    required this.isEditable,
  });

  factory AlternativeSaturdaySchedule.fromFirestore(String id, Map<String, dynamic> data) {
    List<SaturdayScheduleDay> schedulesList = [];
    if (data['schedules'] != null) {
      for (var schedule in data['schedules']) {
        schedulesList.add(SaturdayScheduleDay.fromMap(schedule));
      }
    }

    Map<String, List<Map<String, dynamic>>> employeesMap = {};
    if (data['employees'] != null) {
      Map<String, dynamic> employeesData = data['employees'];
      employeesData.forEach((key, value) {
        if (value is List) {
          employeesMap[key] = List<Map<String, dynamic>>.from(value);
        }
      });
    }

    return AlternativeSaturdaySchedule(
      id: id,
      title: data['title'] ?? '',
      month: data['month'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      status: data['status'] ?? 'draft',
      defaultTiming: data['defaultTiming'] ?? {},
      schedules: schedulesList,
      employees: employeesMap,
      totalSaturdays: data['totalSaturdays'] ?? 0,
      isEditable: data['isEditable'] ?? false,
    );
  }
}

class SaturdayScheduleDay {
  final String date;
  final String offGroup;
  final String workingGroup;
  final Map<String, dynamic> workingTiming;
  final List<dynamic> allSaturdayWorkers;

  SaturdayScheduleDay({
    required this.date,
    required this.offGroup,
    required this.workingGroup,
    required this.workingTiming,
    required this.allSaturdayWorkers,
  });

  factory SaturdayScheduleDay.fromMap(Map<String, dynamic> data) {
    return SaturdayScheduleDay(
      date: data['date'] ?? '',
      offGroup: data['offGroup'] ?? '',
      workingGroup: data['workingGroup'] ?? '',
      workingTiming: data['workingTiming'] ?? {},
      allSaturdayWorkers: data['allSaturdayWorkers'] ?? [],
    );
  }

  String get startTime => workingTiming['startTime'] ?? '08:00';
  String get endTime => workingTiming['endTime'] ?? '14:00';
  String get workingTimingText => '$startTime - $endTime';
}

class AlternativeSaturdayService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current month's Alternative Saturday schedule
  static Future<AlternativeSaturdaySchedule?> getCurrentMonthSchedule() async {
    try {
      DateTime now = DateTime.now();
      String currentMonth = DateFormat('yyyy-MM').format(now);

      debugPrint("🗓️ Fetching Alternative Saturday schedule for: $currentMonth");

      QuerySnapshot snapshot = await _firestore
          .collection('alternative_saturday_schedules')
          .where('month', isEqualTo: currentMonth)
          .where('status', whereIn: ['active', 'published'])
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        var schedule = AlternativeSaturdaySchedule.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);

        debugPrint("✅ Found Alternative Saturday schedule: ${schedule.title}");
        debugPrint("   - Total Saturdays: ${schedule.totalSaturdays}");
        debugPrint("   - Groups: ${schedule.employees.keys.toList()}");

        return schedule;
      }

      debugPrint("⚠️ No Alternative Saturday schedule found for $currentMonth");
      return null;
    } catch (e) {
      debugPrint("❌ Error fetching Alternative Saturday schedule: $e");
      return null;
    }
  }

  /// Check if employee is in Alternative Saturday system
  static Future<bool> isEmployeeInAlternativeSaturday(String employeeId, String? employeePin) async {
    try {
      var schedule = await getCurrentMonthSchedule();
      if (schedule == null) return false;

      // Check both employeeId and PIN formats
      List<String> searchIds = [
        employeeId,
        'EMP$employeePin',
        employeePin ?? '',
      ];

      for (var groupName in schedule.employees.keys) {
        var groupEmployees = schedule.employees[groupName] ?? [];
        for (var employee in groupEmployees) {
          String empId = employee['id'] ?? '';
          String empNumber = employee['employeeNumber'] ?? '';

          if (searchIds.contains(empId) || searchIds.contains(empNumber)) {
            debugPrint("✅ Employee $employeeId found in Alternative Saturday group: $groupName");
            return true;
          }
        }
      }

      debugPrint("❌ Employee $employeeId not found in Alternative Saturday system");
      return false;
    } catch (e) {
      debugPrint("❌ Error checking Alternative Saturday membership: $e");
      return false;
    }
  }

  /// Get employee's group (A or B)
  static Future<String?> getEmployeeGroup(String employeeId, String? employeePin) async {
    try {
      var schedule = await getCurrentMonthSchedule();
      if (schedule == null) return null;

      List<String> searchIds = [
        employeeId,
        'EMP$employeePin',
        employeePin ?? '',
      ];

      for (var groupName in schedule.employees.keys) {
        var groupEmployees = schedule.employees[groupName] ?? [];
        for (var employee in groupEmployees) {
          String empId = employee['id'] ?? '';
          String empNumber = employee['employeeNumber'] ?? '';

          if (searchIds.contains(empId) || searchIds.contains(empNumber)) {
            debugPrint("✅ Employee $employeeId is in group: $groupName");
            return groupName;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error getting employee group: $e");
      return null;
    }
  }

  /// Get Saturday schedule for specific date
  static Future<SaturdayScheduleDay?> getSaturdayScheduleForDate(DateTime date) async {
    try {
      // Only check for Saturdays
      if (date.weekday != DateTime.saturday) return null;

      var schedule = await getCurrentMonthSchedule();
      if (schedule == null) return null;

      String dateStr = DateFormat('yyyy-MM-dd').format(date);

      for (var saturdaySchedule in schedule.schedules) {
        if (saturdaySchedule.date == dateStr) {
          debugPrint("✅ Found Saturday schedule for $dateStr");
          debugPrint("   - Working Group: ${saturdaySchedule.workingGroup}");
          debugPrint("   - Off Group: ${saturdaySchedule.offGroup}");
          debugPrint("   - Timing: ${saturdaySchedule.workingTimingText}");
          return saturdaySchedule;
        }
      }

      debugPrint("⚠️ No Saturday schedule found for $dateStr");
      return null;
    } catch (e) {
      debugPrint("❌ Error getting Saturday schedule: $e");
      return null;
    }
  }

  /// Check if employee should work on specific Saturday
  static Future<bool> shouldEmployeeWorkOnSaturday(String employeeId, String? employeePin, DateTime saturday) async {
    try {
      if (saturday.weekday != DateTime.saturday) return false;

      var employeeGroup = await getEmployeeGroup(employeeId, employeePin);
      if (employeeGroup == null) return false; // Not in Alternative Saturday system

      var saturdaySchedule = await getSaturdayScheduleForDate(saturday);
      if (saturdaySchedule == null) return false;

      bool shouldWork = saturdaySchedule.workingGroup.toLowerCase().contains(employeeGroup.toLowerCase());

      debugPrint("🗓️ Saturday ${DateFormat('yyyy-MM-dd').format(saturday)}:");
      debugPrint("   - Employee Group: $employeeGroup");
      debugPrint("   - Working Group: ${saturdaySchedule.workingGroup}");
      debugPrint("   - Should Work: $shouldWork");

      return shouldWork;
    } catch (e) {
      debugPrint("❌ Error checking Saturday work schedule: $e");
      return false;
    }
  }








  /// Get Saturday work timing for employee
  static Future<Map<String, String>?> getSaturdayWorkTiming(String employeeId, String? employeePin, DateTime saturday) async {
    try {
      bool shouldWork = await shouldEmployeeWorkOnSaturday(employeeId, employeePin, saturday);
      if (!shouldWork) return null;

      var saturdaySchedule = await getSaturdayScheduleForDate(saturday);
      if (saturdaySchedule == null) return null;

      return {
        'startTime': saturdaySchedule.startTime,
        'endTime': saturdaySchedule.endTime,
        'workTiming': saturdaySchedule.workingTimingText,
      };
    } catch (e) {
      debugPrint("❌ Error getting Saturday work timing: $e");
      return null;
    }
  }

  /// Get next Saturday status for employee
  static Future<Map<String, dynamic>> getNextSaturdayStatus(String employeeId, String? employeePin) async {
    try {
      DateTime now = DateTime.now();
      DateTime nextSaturday = _getNextSaturday(now);

      debugPrint("📅 Getting next Saturday status for $employeeId");
      debugPrint("   - Next Saturday: ${DateFormat('yyyy-MM-dd').format(nextSaturday)}");

      bool isInAlternativeSystem = await isEmployeeInAlternativeSaturday(employeeId, employeePin);
      if (!isInAlternativeSystem) {
        debugPrint("❌ Employee not in Alternative Saturday system");
        return {
          'isInAlternativeSystem': false,
          'nextSaturday': nextSaturday,
          'shouldWork': false,
          'status': 'regular_saturday',
          'message': 'Regular Saturday (Off)',
        };
      }

      bool shouldWork = await shouldEmployeeWorkOnSaturday(employeeId, employeePin, nextSaturday);
      Map<String, String>? timing = await getSaturdayWorkTiming(employeeId, employeePin, nextSaturday);

      return {
        'isInAlternativeSystem': true,
        'nextSaturday': nextSaturday,
        'shouldWork': shouldWork,
        'status': shouldWork ? 'alternative_saturday_working' : 'alternative_saturday_off',
        'message': shouldWork ? 'Alternative Saturday Working' : 'Alternative Saturday Off',
        'timing': timing,
        'workingHours': timing != null ? '${timing['startTime']} - ${timing['endTime']}' : null,
      };
    } catch (e) {
      debugPrint("❌ Error getting next Saturday status: $e");
      return {
        'isInAlternativeSystem': false,
        'nextSaturday': _getNextSaturday(DateTime.now()),
        'shouldWork': false,
        'status': 'error',
        'message': 'Error checking Saturday status',
      };
    }
  }

  /// Get today's Saturday status if today is Saturday
  static Future<Map<String, dynamic>> getTodaySaturdayStatus(String employeeId, String? employeePin) async {
    try {
      DateTime today = DateTime.now();

      if (today.weekday != DateTime.saturday) {
        return {
          'isSaturday': false,
          'status': 'not_saturday',
          'message': 'Today is not Saturday',
        };
      }

      debugPrint("📅 Getting today's Saturday status for $employeeId");

      bool isInAlternativeSystem = await isEmployeeInAlternativeSaturday(employeeId, employeePin);
      if (!isInAlternativeSystem) {
        return {
          'isSaturday': true,
          'isInAlternativeSystem': false,
          'status': 'regular_saturday_off',
          'message': 'Regular Saturday (Off)',
          'canWorkAsOvertime': true,
        };
      }

      bool shouldWork = await shouldEmployeeWorkOnSaturday(employeeId, employeePin, today);
      Map<String, String>? timing = await getSaturdayWorkTiming(employeeId, employeePin, today);

      return {
        'isSaturday': true,
        'isInAlternativeSystem': true,
        'shouldWork': shouldWork,
        'status': shouldWork ? 'alternative_saturday_working' : 'alternative_saturday_off',
        'message': shouldWork ? 'Alternative Saturday Working' : 'Alternative Saturday Off',
        'timing': timing,
        'workingHours': timing != null ? '${timing['startTime']} - ${timing['endTime']}' : null,
        'canWorkAsOvertime': !shouldWork, // If off, can work as overtime
      };
    } catch (e) {
      debugPrint("❌ Error getting today's Saturday status: $e");
      return {
        'isSaturday': true,
        'isInAlternativeSystem': false,
        'status': 'error',
        'message': 'Error checking Saturday status',
      };
    }
  }

  /// Check if date is Sunday (always off for regular employees)
  static bool isSunday(DateTime date) {
    return date.weekday == DateTime.sunday;
  }

  /// Get Sunday status (always off, but can work as overtime)
  static Map<String, dynamic> getSundayStatus() {
    return {
      'isSunday': true,
      'status': 'sunday_off',
      'message': 'Sunday (Holiday)',
      'canWorkAsOvertime': true,
    };
  }

  /// Helper method to get next Saturday
  static DateTime _getNextSaturday(DateTime from) {
    int daysUntilSaturday = DateTime.saturday - from.weekday;
    if (daysUntilSaturday <= 0) {
      daysUntilSaturday += 7; // Next week's Saturday
    }
    return from.add(Duration(days: daysUntilSaturday));
  }

  /// Check if date should be counted as present (even if off)
  static Future<bool> shouldCountAsPresent(String employeeId, String? employeePin, DateTime date) async {
    try {
      if (date.weekday == DateTime.sunday) {
        // Sunday is always counted as present (holiday)
        return true;
      }

      if (date.weekday == DateTime.saturday) {
        bool isInAlternativeSystem = await isEmployeeInAlternativeSaturday(employeeId, employeePin);
        if (isInAlternativeSystem) {
          // Alternative Saturday off days count as present
          bool shouldWork = await shouldEmployeeWorkOnSaturday(employeeId, employeePin, date);
          return !shouldWork; // If they're off, it counts as present
        }
        // Regular Saturday is always counted as present (off day)
        return true;
      }

      // Regular weekdays should be checked for actual attendance
      return false;
    } catch (e) {
      debugPrint("❌ Error checking if date should count as present: $e");
      return false;
    }
  }
}
