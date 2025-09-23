// lib/services/dashboard_overtime_service.dart
// Builds on top of existing EmployeeOvertimeService for dashboard integration

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:face_auth_compatible/services/employee_overtime_service.dart';
import 'package:face_auth_compatible/model/overtime_request_model.dart';

class DashboardOvertimeService {
  final EmployeeOvertimeService _overtimeService = EmployeeOvertimeService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get today's overtime status for dashboard display
  Future<DashboardOvertimeInfo?> getTodayDashboardOvertimeStatus(String employeeId) async {
    try {
      debugPrint("=== GETTING DASHBOARD OVERTIME STATUS ===");
      debugPrint("Employee ID: $employeeId");

      // Use existing service to get today's overtime
      List<OvertimeRequest> todayOvertime = await _overtimeService.getTodayOvertimeForEmployee(employeeId);

      if (todayOvertime.isEmpty) {
        debugPrint("❌ No overtime found for today");
        return null;
      }

      // Get the first (most recent) overtime for today
      OvertimeRequest overtime = todayOvertime.first;

      debugPrint("✅ Found today's overtime:");
      debugPrint("  - Project: ${overtime.projectName}");
      debugPrint("  - Code: ${overtime.projectCode}");
      debugPrint("  - Time: ${DateFormat('h:mm a').format(overtime.startTime)} - ${DateFormat('h:mm a').format(overtime.endTime)}");

      // Determine current overtime status
      DateTime now = DateTime.now();
      OvertimePhase currentPhase = _determineOvertimePhase(overtime, now);

      return DashboardOvertimeInfo(
        requestId: overtime.id,
        projectName: overtime.projectName,
        projectCode: overtime.projectCode,
        startTime: overtime.startTime,
        endTime: overtime.endTime,
        totalDuration: overtime.totalDurationHours,
        currentPhase: currentPhase,
        requesterName: overtime.requesterName,
        approverName: overtime.approverName,
        isActive: overtime.isActive,
        timeUntilStart: _calculateTimeUntilStart(overtime.startTime, now),
        timeRemaining: _calculateTimeRemaining(overtime.endTime, now),
        projects: overtime.projects,
        totalProjects: overtime.totalProjects,
      );

    } catch (e) {
      debugPrint("❌ Error getting dashboard overtime status: $e");
      return null;
    }
  }

  /// Stream for real-time overtime status updates
  Stream<DashboardOvertimeInfo?> watchTodayOvertimeStatus(String employeeId) async* {
    debugPrint("👁️ Starting real-time overtime status watch for: $employeeId");

    try {
      // Get employee's EMP ID for monitoring
      String? empId = await _getEmployeeEMPId(employeeId);
      List<String> idsToWatch = [employeeId];
      if (empId != null) idsToWatch.add(empId);

      debugPrint("Watching overtime for IDs: $idsToWatch");

      // Listen to overtime_requests collection for real-time changes
      await for (QuerySnapshot snapshot in _firestore
          .collection('overtime_requests')
          .where('status', isEqualTo: 'approved')
          .where('employeeIds', arrayContainsAny: idsToWatch)
          .snapshots()) {

        debugPrint("🔄 Overtime data changed, processing ${snapshot.docs.length} documents");

        // Process documents to find today's overtime
        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            if (data['startTime'] != null) {
              DateTime overtimeDate = (data['startTime'] as Timestamp).toDate();
              String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              String overtimeDateStr = DateFormat('yyyy-MM-dd').format(overtimeDate);

              if (overtimeDateStr == today) {
                debugPrint("✅ Found today's overtime update");

                // Convert to dashboard info
                DashboardOvertimeInfo? info = _convertToGroupDashboardInfo(doc.id, data);
                yield info;
                return; // Exit after finding today's overtime
              }
            }
          } catch (e) {
            debugPrint("Error processing overtime document: $e");
            continue;
          }
        }

        // If no today's overtime found, yield null
        yield null;
      }
    } catch (e) {
      debugPrint("❌ Error in real-time overtime watch: $e");
      yield null;
    }
  }

  /// Check if employee currently has active overtime (quick check)
  Future<bool> hasActiveOvertimeToday(String employeeId) async {
    try {
      DashboardOvertimeInfo? info = await getTodayDashboardOvertimeStatus(employeeId);
      return info != null && (info.currentPhase == OvertimePhase.scheduled ||
          info.currentPhase == OvertimePhase.active);
    } catch (e) {
      debugPrint("Error checking active overtime: $e");
      return false;
    }
  }

  /// Get overtime timing message for dashboard display
  Future<String?> getOvertimeTimingMessage(String employeeId) async {
    try {
      DashboardOvertimeInfo? info = await getTodayDashboardOvertimeStatus(employeeId);
      if (info == null) return null;

      switch (info.currentPhase) {
        case OvertimePhase.scheduled:
          if (info.timeUntilStart != null) {
            return "Overtime starts in ${_formatDuration(info.timeUntilStart!)} at ${DateFormat('h:mm a').format(info.startTime)}";
          }
          return "Overtime scheduled: ${DateFormat('h:mm a').format(info.startTime)} - ${DateFormat('h:mm a').format(info.endTime)}";

        case OvertimePhase.active:
          if (info.timeRemaining != null) {
            return "Overtime active: ${_formatDuration(info.timeRemaining!)} remaining";
          }
          return "Currently in overtime: ${info.projectName}";

        case OvertimePhase.completed:
          return "Overtime completed: ${info.projectName}";

        case OvertimePhase.missed:
          return "Overtime missed: ${info.projectName}";
      }
    } catch (e) {
      debugPrint("Error getting overtime timing message: $e");
      return null;
    }
  }

  /// Get employee's EMP ID for database queries
  Future<String?> _getEmployeeEMPId(String employeeId) async {
    try {
      if (employeeId.startsWith('EMP')) return employeeId;

      DocumentSnapshot empDoc = await _firestore
          .collection('employees')
          .doc(employeeId)
          .get();

      if (empDoc.exists) {
        Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;
        String? pin = data['pin']?.toString();
        if (pin != null) {
          return 'EMP$pin';
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error getting EMP ID: $e");
      return null;
    }
  }

  /// Determine what phase the overtime is currently in
  OvertimePhase _determineOvertimePhase(OvertimeRequest overtime, DateTime now) {
    DateTime startTime = overtime.startTime;
    DateTime endTime = overtime.endTime;

    if (now.isBefore(startTime)) {
      return OvertimePhase.scheduled; // Overtime hasn't started yet
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return OvertimePhase.active; // Overtime is currently happening
    } else if (now.isAfter(endTime)) {
      return OvertimePhase.completed; // Overtime has ended
    } else {
      return OvertimePhase.missed; // Something went wrong
    }
  }

  /// Calculate time until overtime starts
  Duration? _calculateTimeUntilStart(DateTime startTime, DateTime now) {
    if (now.isBefore(startTime)) {
      return startTime.difference(now);
    }
    return null;
  }

  /// Calculate time remaining in overtime
  Duration? _calculateTimeRemaining(DateTime endTime, DateTime now) {
    if (now.isBefore(endTime)) {
      return endTime.difference(now);
    }
    return null;
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  /// Convert Firestore data to dashboard info
  DashboardOvertimeInfo? _convertToGroupDashboardInfo(String id, Map<String, dynamic> data) {
    try {
      DateTime startTime = (data['startTime'] as Timestamp).toDate();
      DateTime endTime = (data['endTime'] as Timestamp).toDate();
      DateTime now = DateTime.now();

      // Create a temporary OvertimeRequest for phase calculation
      OvertimeRequest tempRequest = OvertimeRequest(
        id: id,
        requesterId: data['requesterId'] ?? '',
        requesterName: data['requesterName'] ?? '',
        approverEmpId: data['approverEmpId'] ?? '',
        approverName: data['approverName'] ?? '',
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: startTime,
        endTime: endTime,
        employeeIds: List<String>.from(data['employeeIds'] ?? []),
        requestTime: (data['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: OvertimeRequestStatus.approved,
        totalDurationHours: (data['totalHours'] ?? 0).toDouble(),
        totalProjects: data['totalProjects'] ?? 1,
        totalEmployeeCount: data['totalEmployees'] ?? 0,
      );

      OvertimePhase currentPhase = _determineOvertimePhase(tempRequest, now);

      return DashboardOvertimeInfo(
        requestId: id,
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: startTime,
        endTime: endTime,
        totalDuration: (data['totalHours'] ?? 0).toDouble(),
        currentPhase: currentPhase,
        requesterName: data['requesterName'] ?? '',
        approverName: data['approverName'] ?? '',
        isActive: data['isActive'] ?? true,
        timeUntilStart: _calculateTimeUntilStart(startTime, now),
        timeRemaining: _calculateTimeRemaining(endTime, now),
        totalProjects: data['totalProjects'] ?? 1,
      );

    } catch (e) {
      debugPrint("Error converting to dashboard info: $e");
      return null;
    }
  }
}

/// Enum for overtime phases
enum OvertimePhase {
  scheduled,  // Overtime is scheduled but hasn't started
  active,     // Overtime is currently happening
  completed,  // Overtime has ended
  missed,     // Overtime was scheduled but time passed
}

/// Dashboard-specific overtime information
class DashboardOvertimeInfo {
  final String requestId;
  final String projectName;
  final String projectCode;
  final DateTime startTime;
  final DateTime endTime;
  final double totalDuration;
  final OvertimePhase currentPhase;
  final String requesterName;
  final String approverName;
  final bool isActive;
  final Duration? timeUntilStart;
  final Duration? timeRemaining;
  final List<OvertimeProjectEntry>? projects;
  final int totalProjects;

  DashboardOvertimeInfo({
    required this.requestId,
    required this.projectName,
    required this.projectCode,
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.currentPhase,
    required this.requesterName,
    required this.approverName,
    required this.isActive,
    this.timeUntilStart,
    this.timeRemaining,
    this.projects,
    this.totalProjects = 1,
  });

  /// Get display text for the current phase
  String get phaseDisplayText {
    switch (currentPhase) {
      case OvertimePhase.scheduled:
        return "Overtime Scheduled";
      case OvertimePhase.active:
        return "Currently in Overtime";
      case OvertimePhase.completed:
        return "Overtime Completed";
      case OvertimePhase.missed:
        return "Overtime Missed";
    }
  }

  /// Get color for the current phase
  Color get phaseColor {
    switch (currentPhase) {
      case OvertimePhase.scheduled:
        return const Color(0xFF2563EB); // Blue
      case OvertimePhase.active:
        return const Color(0xFFEA580C); // Orange
      case OvertimePhase.completed:
        return const Color(0xFF16A34A); // Green
      case OvertimePhase.missed:
        return const Color(0xFFDC2626); // Red
    }
  }

  /// Get formatted time range
  String get formattedTimeRange {
    return "${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}";
  }

  /// Get formatted duration
  String get formattedDuration {
    return "${totalDuration.toStringAsFixed(1)} hours";
  }

  /// Check if overtime is happening now
  bool get isCurrentlyActive {
    return currentPhase == OvertimePhase.active;
  }

  /// Check if overtime is scheduled for later today
  bool get isScheduledForToday {
    return currentPhase == OvertimePhase.scheduled;
  }

  /// Get countdown text
  String? get countdownText {
    if (timeUntilStart != null && currentPhase == OvertimePhase.scheduled) {
      int hours = timeUntilStart!.inHours;
      int minutes = timeUntilStart!.inMinutes % 60;

      if (hours > 0) {
        return "Starts in ${hours}h ${minutes}m";
      } else {
        return "Starts in ${minutes}m";
      }
    }

    if (timeRemaining != null && currentPhase == OvertimePhase.active) {
      int hours = timeRemaining!.inHours;
      int minutes = timeRemaining!.inMinutes % 60;

      if (hours > 0) {
        return "${hours}h ${minutes}m remaining";
      } else {
        return "${minutes}m remaining";
      }
    }

    return null;
  }
}



