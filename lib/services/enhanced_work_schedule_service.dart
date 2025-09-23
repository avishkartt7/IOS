// lib/services/enhanced_work_schedule_service.dart


import 'package:face_auth/services/work_schedule_service.dart';
import 'package:intl/intl.dart';

class EnhancedWorkScheduleService {

  /// Get complete work schedule including alternative Saturday adjustments
  static Future<EnhancedWorkSchedule?> getEnhancedWorkSchedule(
      String employeeId,
      String? employeePin,
      DateTime date
      ) async {
    try {
      print("🕐 Getting enhanced work schedule for $employeeId on ${DateFormat('yyyy-MM-dd').format(date)}");

      // Get base work schedule
      WorkSchedule? baseSchedule = await WorkScheduleService.getEmployeeWorkSchedule(
          employeeId,
          employeePin
      );

      // Get day status (Saturday/Sunday logic)
      DayStatus dayStatus = await AlternativeSaturdayService.getDayStatus(employeeId, date);

      print("📅 Day status: ${dayStatus.primaryMessage}");
      print("🏢 Is working day: ${dayStatus.isWorkingDay}");

      return EnhancedWorkSchedule(
        baseSchedule: baseSchedule,
        dayStatus: dayStatus,
        effectiveSchedule: _calculateEffectiveSchedule(baseSchedule, dayStatus),
      );

    } catch (e) {
      print("❌ Error getting enhanced work schedule: $e");
      return null;
    }
  }

  /// Calculate the effective work schedule based on day status
  static EffectiveSchedule _calculateEffectiveSchedule(
      WorkSchedule? baseSchedule,
      DayStatus dayStatus
      ) {
    // Sunday - Always holiday
    if (dayStatus.sundayStatus.isSunday) {
      return EffectiveSchedule(
        isWorkingDay: false,
        startTime: null,
        endTime: null,
        breakStartTime: null,
        breakEndTime: null,
        workTiming: null,
        message: 'Sunday - Holiday',
        messageColor: ScheduleMessageColor.info,
        scheduleType: ScheduleType.holiday,
        allowsCheckIn: true, // Can still check in for overtime
        overtimeAfter: null,
      );
    }

    // Saturday - Alternative Saturday logic
    if (dayStatus.saturdayStatus.isSaturday) {
      if (dayStatus.saturdayStatus.isWorkingDay) {
        // Working Saturday - 8:00 to 14:00, no break
        return EffectiveSchedule(
          isWorkingDay: true,
          startTime: dayStatus.saturdayStatus.workTiming?.startTime ?? '08:00',
          endTime: dayStatus.saturdayStatus.workTiming?.endTime ?? '14:00',
          breakStartTime: null,
          breakEndTime: null,
          workTiming: dayStatus.saturdayStatus.workTiming?.displayTiming ?? '08:00 - 14:00',
          message: 'Alternative Saturday - Working Day (${dayStatus.saturdayStatus.group ?? 'Group'} Schedule)',
          messageColor: ScheduleMessageColor.working,
          scheduleType: ScheduleType.alternativeSaturday,
          allowsCheckIn: true,
          overtimeAfter: dayStatus.saturdayStatus.workTiming?.endTime ?? '14:00',
        );
      } else {
        // Off Saturday - Still counts as present but no work required
        return EffectiveSchedule(
          isWorkingDay: false,
          startTime: null,
          endTime: null,
          breakStartTime: null,
          breakEndTime: null,
          workTiming: null,
          message: 'Alternative Saturday - Off Day (${dayStatus.saturdayStatus.group ?? 'Group'} Rest)',
          messageColor: ScheduleMessageColor.off,
          scheduleType: ScheduleType.alternativeSaturdayOff,
          allowsCheckIn: true, // Can still check in
          overtimeAfter: null,
        );
      }
    }

    // Regular weekday - Use base schedule
    if (baseSchedule != null) {
      return EffectiveSchedule(
        isWorkingDay: true,
        startTime: baseSchedule.startTime,
        endTime: baseSchedule.endTime,
        breakStartTime: baseSchedule.breakStartTime,
        breakEndTime: baseSchedule.breakEndTime,
        workTiming: baseSchedule.workTiming,
        message: 'Regular Work Day',
        messageColor: ScheduleMessageColor.working,
        scheduleType: ScheduleType.regular,
        allowsCheckIn: true,
        overtimeAfter: baseSchedule.endTime,
      );
    }

    // Fallback
    return EffectiveSchedule(
      isWorkingDay: true,
      startTime: null,
      endTime: null,
      breakStartTime: null,
      breakEndTime: null,
      workTiming: null,
      message: 'No Schedule Found',
      messageColor: ScheduleMessageColor.warning,
      scheduleType: ScheduleType.unknown,
      allowsCheckIn: true,
      overtimeAfter: null,
    );
  }

  /// Get today's enhanced schedule
  static Future<EnhancedWorkSchedule?> getTodaySchedule(String employeeId, String? employeePin) async {
    return await getEnhancedWorkSchedule(employeeId, employeePin, DateTime.now());
  }

  /// Check if overtime applies based on enhanced schedule
  static bool isOvertimeHours(EffectiveSchedule schedule, DateTime checkTime) {
    if (schedule.scheduleType == ScheduleType.holiday ||
        schedule.scheduleType == ScheduleType.alternativeSaturdayOff) {
      // Any work on holidays or off days is overtime
      return true;
    }

    if (schedule.overtimeAfter != null) {
      try {
        List<String> timeParts = schedule.overtimeAfter!.split(':');
        int overtimeHour = int.parse(timeParts[0]);
        int overtimeMinute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

        DateTime overtimeStart = DateTime(
          checkTime.year,
          checkTime.month,
          checkTime.day,
          overtimeHour,
          overtimeMinute,
        );

        return checkTime.isAfter(overtimeStart);
      } catch (e) {
        print("Error parsing overtime time: $e");
        return false;
      }
    }

    return false;
  }

  /// Format timing message for dashboard display
  static String formatTimingMessage(EffectiveSchedule schedule, DateTime currentTime) {
    DateTime now = currentTime;
    String formattedTime = DateFormat('h:mm a').format(now);

    switch (schedule.scheduleType) {
      case ScheduleType.holiday:
        return "Sunday Holiday - Any work is overtime";

      case ScheduleType.alternativeSaturday:
        if (schedule.workTiming != null) {
          return "Alternative Saturday Work: ${schedule.workTiming} (No Break)";
        }
        return "Alternative Saturday - Working Day";

      case ScheduleType.alternativeSaturdayOff:
        return "Alternative Saturday Off - Counts as Present";

      case ScheduleType.regular:
        if (schedule.workTiming != null) {
          return "Work Hours: ${schedule.workTiming}";
        }
        return "Regular Work Day";

      default:
        return "Schedule not available";
    }
  }
}

// Enhanced Data Models
class EnhancedWorkSchedule {
  final WorkSchedule? baseSchedule;
  final DayStatus dayStatus;
  final EffectiveSchedule effectiveSchedule;

  EnhancedWorkSchedule({
    required this.baseSchedule,
    required this.dayStatus,
    required this.effectiveSchedule,
  });

  bool get isWorkingDay => effectiveSchedule.isWorkingDay;
  bool get allowsCheckIn => effectiveSchedule.allowsCheckIn;
  String get displayMessage => effectiveSchedule.message;
  ScheduleMessageColor get messageColor => effectiveSchedule.messageColor;
}

class EffectiveSchedule {
  final bool isWorkingDay;
  final String? startTime;
  final String? endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final String? workTiming;
  final String message;
  final ScheduleMessageColor messageColor;
  final ScheduleType scheduleType;
  final bool allowsCheckIn;
  final String? overtimeAfter;

  EffectiveSchedule({
    required this.isWorkingDay,
    this.startTime,
    this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    this.workTiming,
    required this.message,
    required this.messageColor,
    required this.scheduleType,
    required this.allowsCheckIn,
    this.overtimeAfter,
  });

  bool get hasBreak => breakStartTime != null && breakEndTime != null;

  String get timingDisplay {
    if (workTiming != null) return workTiming!;
    if (startTime != null && endTime != null) return "$startTime - $endTime";
    return "No timing specified";
  }
}

enum ScheduleType {
  regular,
  alternativeSaturday,
  alternativeSaturdayOff,
  holiday,
  unknown,
}

enum ScheduleMessageColor {
  working,    // Blue/Green - Normal working
  off,        // Orange - Off day but counts as present
  info,       // Blue - Information
  warning,    // Yellow - Warning/Unknown
  overtime,   // Purple - Overtime applicable
}



