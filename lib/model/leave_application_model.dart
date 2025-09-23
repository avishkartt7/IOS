// lib/model/leave_application_model.dart - STEP 1: FIXED WITH 4 LEAVE TYPES ONLY

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ✅ FIXED: Only 4 leave types as requested
enum LeaveType {
  annual,    // Annual Leave
  sick,      // Sick Leave
  local,     // Local Leave (NEW)
  emergency, // Emergency Leave
}

extension LeaveTypeExtension on LeaveType {
  String get displayName {
    switch (this) {
      case LeaveType.annual:
        return 'Annual Leave';
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.local:
        return 'Local Leave'; // ✅ NEW
      case LeaveType.emergency:
        return 'Emergency Leave';
    }
  }

  String get name {
    return toString().split('.').last;
  }

  // ✅ UPDATED: Leave allocation info for 4 types only
  String get allocationInfo {
    switch (this) {
      case LeaveType.annual:
        return '30 days per year';
      case LeaveType.sick:
        return '15 days per year';
      case LeaveType.local:
        return '10 days per year'; // ✅ NEW
      case LeaveType.emergency:
        return '15 days per year (double deduction)';
    }
  }

  // ✅ FIXED: Certificate requirement logic
  bool isCertificateRequired(bool isAlreadyTaken) {
    // Emergency leave NEVER requires certificate
    if (this == LeaveType.emergency) {
      return false;
    }

    // Sick leave: only required if already taken
    if (this == LeaveType.sick && isAlreadyTaken) {
      return true; // Medical certificate required for sick leave already taken
    }

    // Other leave types: only required if already taken
    if (isAlreadyTaken && (this == LeaveType.annual || this == LeaveType.local)) {
      return true; // Supporting documents required for already taken leave
    }

    return false;
  }

  // ✅ UPDATED: Get certificate requirement message
  String getCertificateRequirement(bool isAlreadyTaken) {
    if (this == LeaveType.emergency) {
      return 'No certificate required for emergency leave';
    }

    if (this == LeaveType.sick && isAlreadyTaken) {
      return 'Medical certificate required for sick leave already taken';
    } else if (isAlreadyTaken) {
      return 'Supporting documents required for leave already taken';
    } else {
      return 'No certificate required';
    }
  }

  // ✅ UPDATED: Check if this leave type has special deduction rules
  bool get hasSpecialDeduction {
    return this == LeaveType.emergency;
  }

  // ✅ UPDATED: Get deduction description
  String get deductionDescription {
    switch (this) {
      case LeaveType.emergency:
        return 'Deducted from both Emergency Leave and Annual Leave balances';
      case LeaveType.annual:
        return 'Deducted from Annual Leave balance';
      case LeaveType.sick:
        return 'Deducted from Sick Leave balance';
      case LeaveType.local:
        return 'Deducted from Local Leave balance'; // ✅ NEW
    }
  }

  // ✅ UPDATED: Get priority level for notifications
  String get priorityLevel {
    switch (this) {
      case LeaveType.emergency:
        return 'high';
      case LeaveType.sick:
        return 'medium';
      case LeaveType.annual:
      case LeaveType.local:
        return 'normal';
    }
  }

  // ✅ UPDATED: Get color for UI display
  String get colorCode {
    switch (this) {
      case LeaveType.emergency:
        return '#FF5722'; // Red-Orange
      case LeaveType.sick:
        return '#F44336'; // Red
      case LeaveType.annual:
        return '#2196F3'; // Blue
      case LeaveType.local:
        return '#4CAF50'; // Green (NEW)
    }
  }

  static LeaveType fromString(String value) {
    return LeaveType.values.firstWhere(
          (type) => type.name == value,
      orElse: () => LeaveType.annual,
    );
  }
}

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

extension LeaveStatusExtension on LeaveStatus {
  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get name {
    return toString().split('.').last;
  }

  String get colorCode {
    switch (this) {
      case LeaveStatus.pending:
        return '#FF9800'; // Orange
      case LeaveStatus.approved:
        return '#4CAF50'; // Green
      case LeaveStatus.rejected:
        return '#F44336'; // Red
      case LeaveStatus.cancelled:
        return '#9E9E9E'; // Grey
    }
  }

  static LeaveStatus fromString(String value) {
    return LeaveStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () => LeaveStatus.pending,
    );
  }
}

class LeaveApplicationModel {
  final String? id;
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final bool isAlreadyTaken;
  final String? certificateUrl;
  final String? certificateFileName;
  final LeaveStatus status;
  final DateTime applicationDate;
  final String lineManagerId;
  final String lineManagerName;
  final DateTime? reviewDate;
  final String? reviewComments;
  final String? reviewedBy;
  final bool isActive;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool requiresCertificateReminder;
  final DateTime? certificateReminderDate;
  final bool certificateReminderSent;
  final int certificateReminderCount;
  final DateTime? certificateUploadedDate;

  const LeaveApplicationModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    this.isAlreadyTaken = false,
    this.certificateUrl,
    this.certificateFileName,
    this.status = LeaveStatus.pending,
    required this.applicationDate,
    required this.lineManagerId,
    required this.lineManagerName,
    this.reviewDate,
    this.reviewComments,
    this.reviewedBy,
    this.isActive = true,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,

    this.requiresCertificateReminder = false,
    this.certificateReminderDate,
    this.certificateReminderSent = false,
    this.certificateReminderCount = 0,
    this.certificateUploadedDate,
  });

  // Create a copy with updated values
  LeaveApplicationModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeePin,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? reason,
    bool? isAlreadyTaken,
    String? certificateUrl,
    String? certificateFileName,
    LeaveStatus? status,
    DateTime? applicationDate,
    String? lineManagerId,
    String? lineManagerName,
    DateTime? reviewDate,
    String? reviewComments,
    String? reviewedBy,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,

    bool? requiresCertificateReminder,
    DateTime? certificateReminderDate,
    bool? certificateReminderSent,
    int? certificateReminderCount,
    DateTime? certificateUploadedDate,
  }) {
    return LeaveApplicationModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeePin: employeePin ?? this.employeePin,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      isAlreadyTaken: isAlreadyTaken ?? this.isAlreadyTaken,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      certificateFileName: certificateFileName ?? this.certificateFileName,
      status: status ?? this.status,
      applicationDate: applicationDate ?? this.applicationDate,
      lineManagerId: lineManagerId ?? this.lineManagerId,
      lineManagerName: lineManagerName ?? this.lineManagerName,
      reviewDate: reviewDate ?? this.reviewDate,
      reviewComments: reviewComments ?? this.reviewComments,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,

      requiresCertificateReminder: requiresCertificateReminder ?? this.requiresCertificateReminder,
      certificateReminderDate: certificateReminderDate ?? this.certificateReminderDate,
      certificateReminderSent: certificateReminderSent ?? this.certificateReminderSent,
      certificateReminderCount: certificateReminderCount ?? this.certificateReminderCount,
      certificateUploadedDate: certificateUploadedDate ?? this.certificateUploadedDate,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeePin': employeePin,
      'leaveType': leaveType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'reason': reason,
      'isAlreadyTaken': isAlreadyTaken,
      'certificateUrl': certificateUrl,
      'certificateFileName': certificateFileName,
      'status': status.name,
      'applicationDate': Timestamp.fromDate(applicationDate),
      'lineManagerId': lineManagerId,
      'lineManagerName': lineManagerName,
      'reviewDate': reviewDate != null ? Timestamp.fromDate(reviewDate!) : null,
      'reviewComments': reviewComments,
      'reviewedBy': reviewedBy,
      'isActive': isActive,
      'isEmergencyLeave': leaveType == LeaveType.emergency,
      'hasSpecialDeduction': leaveType.hasSpecialDeduction,
      'priorityLevel': leaveType.priorityLevel,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      'requiresCertificateReminder': requiresCertificateReminder,
      'certificateReminderDate': certificateReminderDate != null ? Timestamp.fromDate(certificateReminderDate!) : null,
      'certificateReminderSent': certificateReminderSent,
      'certificateReminderCount': certificateReminderCount,
      'certificateUploadedDate': certificateUploadedDate != null ? Timestamp.fromDate(certificateUploadedDate!) : null,
    };
  }

  // Convert to Map for local database
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_pin': employeePin,
      'leave_type': leaveType.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_days': totalDays,
      'reason': reason,
      'is_already_taken': isAlreadyTaken ? 1 : 0,
      'certificate_url': certificateUrl,
      'certificate_file_name': certificateFileName,
      'status': status.name,
      'application_date': applicationDate.toIso8601String(),
      'line_manager_id': lineManagerId,
      'line_manager_name': lineManagerName,
      'review_date': reviewDate?.toIso8601String(),
      'review_comments': reviewComments,
      'reviewed_by': reviewedBy,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'is_emergency_leave': leaveType == LeaveType.emergency ? 1 : 0,
      'has_special_deduction': leaveType.hasSpecialDeduction ? 1 : 0,
      'priority_level': leaveType.priorityLevel,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),

      'requires_certificate_reminder': requiresCertificateReminder ? 1 : 0,
      'certificate_reminder_date': certificateReminderDate?.toIso8601String(),
      'certificate_reminder_sent': certificateReminderSent ? 1 : 0,
      'certificate_reminder_count': certificateReminderCount,
      'certificate_uploaded_date': certificateUploadedDate?.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory LeaveApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveApplicationModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      employeePin: data['employeePin'] ?? '',
      leaveType: LeaveTypeExtension.fromString(data['leaveType'] ?? 'annual'),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalDays: data['totalDays'] ?? 0,
      reason: data['reason'] ?? 'No specific reason provided',
      isAlreadyTaken: data['isAlreadyTaken'] ?? false,
      certificateUrl: data['certificateUrl'],
      certificateFileName: data['certificateFileName'],
      status: LeaveStatusExtension.fromString(data['status'] ?? 'pending'),
      applicationDate: (data['applicationDate'] as Timestamp).toDate(),
      lineManagerId: data['lineManagerId'] ?? '',
      lineManagerName: data['lineManagerName'] ?? '',
      reviewDate: data['reviewDate'] != null ? (data['reviewDate'] as Timestamp).toDate() : null,
      reviewComments: data['reviewComments'],
      reviewedBy: data['reviewedBy'],
      isActive: data['isActive'] ?? true,
      isSynced: true,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,

      requiresCertificateReminder: data['requiresCertificateReminder'] ?? false,
      certificateReminderDate: data['certificateReminderDate'] != null ? (data['certificateReminderDate'] as Timestamp).toDate() : null,
      certificateReminderSent: data['certificateReminderSent'] ?? false,
      certificateReminderCount: data['certificateReminderCount'] ?? 0,
      certificateUploadedDate: data['certificateUploadedDate'] != null ? (data['certificateUploadedDate'] as Timestamp).toDate() : null,
    );
  }

  // Create from local database map
  factory LeaveApplicationModel.fromMap(Map<String, dynamic> map) {
    return LeaveApplicationModel(
      id: map['id'],
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      employeePin: map['employee_pin'] ?? '',
      leaveType: LeaveTypeExtension.fromString(map['leave_type'] ?? 'annual'),
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      totalDays: map['total_days'] ?? 0,
      reason: map['reason'] ?? 'No specific reason provided',
      isAlreadyTaken: (map['is_already_taken'] ?? 0) == 1,
      certificateUrl: map['certificate_url'],
      certificateFileName: map['certificate_file_name'],
      status: LeaveStatusExtension.fromString(map['status'] ?? 'pending'),
      applicationDate: DateTime.parse(map['application_date']),
      lineManagerId: map['line_manager_id'] ?? '',
      lineManagerName: map['line_manager_name'] ?? '',
      reviewDate: map['review_date'] != null ? DateTime.parse(map['review_date']) : null,
      reviewComments: map['review_comments'],
      reviewedBy: map['reviewed_by'],
      isActive: (map['is_active'] ?? 1) == 1,
      isSynced: (map['is_synced'] ?? 0) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,

      requiresCertificateReminder: (map['requires_certificate_reminder'] ?? 0) == 1,
      certificateReminderDate: map['certificate_reminder_date'] != null ? DateTime.parse(map['certificate_reminder_date']) : null,
      certificateReminderSent: (map['certificate_reminder_sent'] ?? 0) == 1,
      certificateReminderCount: map['certificate_reminder_count'] ?? 0,
      certificateUploadedDate: map['certificate_uploaded_date'] != null ? DateTime.parse(map['certificate_uploaded_date']) : null,
    );
  }

  // Formatted date range string
  String get dateRange {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }

  bool get needsCertificateReminder {
    return leaveType == LeaveType.sick &&
        !isAlreadyTaken &&
        status == LeaveStatus.approved &&
        certificateUrl == null &&
        requiresCertificateReminder;
  }

  bool get shouldSendReminderToday {
    if (!needsCertificateReminder || certificateReminderDate == null) return false;

    final today = DateTime.now();
    final reminderDate = DateTime(
        certificateReminderDate!.year,
        certificateReminderDate!.month,
        certificateReminderDate!.day
    );
    final todayDate = DateTime(today.year, today.month, today.day);

    return todayDate.isAtSameMomentAs(reminderDate) || todayDate.isAfter(reminderDate);
  }

  // Check if the application can be cancelled
  bool get canBeCancelled {
    return status == LeaveStatus.pending && isActive;
  }

  // Check if the application can be reviewed
  bool get canBeReviewed {
    return status == LeaveStatus.pending && isActive;
  }

  // Check if this is an emergency leave
  bool get isEmergencyLeave {
    return leaveType == LeaveType.emergency;
  }

  // Check if this leave has special deduction rules
  bool get hasSpecialDeduction {
    return leaveType.hasSpecialDeduction;
  }

  // Get deduction description for this application
  String get deductionDescription {
    return leaveType.deductionDescription;
  }

  // Get priority level for this application
  String get priorityLevel {
    return leaveType.priorityLevel;
  }

  // Check if certificate is required for this specific application
  bool get isCertificateRequiredForThisApplication {
    return leaveType.isCertificateRequired(isAlreadyTaken);
  }

  // Get certificate requirement message for this application
  String get certificateRequirementMessage {
    return leaveType.getCertificateRequirement(isAlreadyTaken);
  }

  @override
  String toString() {
    return 'LeaveApplicationModel(id: $id, employeeName: $employeeName, leaveType: ${leaveType.displayName}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaveApplicationModel &&
        other.id == id &&
        other.employeeId == employeeId &&
        other.leaveType == leaveType &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    employeeId.hashCode ^
    leaveType.hashCode ^
    startDate.hashCode ^
    endDate.hashCode;
  }
}
