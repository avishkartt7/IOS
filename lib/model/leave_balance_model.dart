// lib/model/leave_balance_model.dart - STEP 2: FIXED BALANCE RESTORATION LOGIC

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveBalance {
  final String employeeId;
  final int year;
  final Map<String, int> totalDays;
  final Map<String, int> usedDays;
  final Map<String, int> pendingDays;
  final DateTime? lastUpdated;

  const LeaveBalance({
    required this.employeeId,
    required this.year,
    required this.totalDays,
    required this.usedDays,
    required this.pendingDays,
    this.lastUpdated,
  });

  // ✅ FIXED: Create default leave balance with only 4 leave types
  factory LeaveBalance.createDefault(String employeeId, {int? year}) {
    final currentYear = year ?? DateTime.now().year;

    return LeaveBalance(
      employeeId: employeeId,
      year: currentYear,
      totalDays: {
        'annual': 30,        // 30 days annual leave
        'sick': 15,          // 15 days sick leave
        'local': 10,         // 10 days local leave (NEW)
        'emergency': 15,     // 15 days emergency leave
      },
      usedDays: {
        'annual': 0,
        'sick': 0,
        'local': 0,          // ✅ NEW
        'emergency': 0,
      },
      pendingDays: {
        'annual': 0,
        'sick': 0,
        'local': 0,          // ✅ NEW
        'emergency': 0,
      },
      lastUpdated: DateTime.now(),
    );
  }

  // Create from Firestore document
  factory LeaveBalance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LeaveBalance(
      employeeId: data['employeeId'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      totalDays: Map<String, int>.from(data['totalDays'] ?? {}),
      usedDays: Map<String, int>.from(data['usedDays'] ?? {}),
      pendingDays: Map<String, int>.from(data['pendingDays'] ?? {}),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'year': year,
      'totalDays': totalDays,
      'usedDays': usedDays,
      'pendingDays': pendingDays,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Get remaining days for a specific leave type
  int getRemainingDays(String leaveType) {
    final total = totalDays[leaveType] ?? 0;
    final used = usedDays[leaveType] ?? 0;
    final pending = pendingDays[leaveType] ?? 0;

    final remaining = total - used - pending;
    return remaining < 0 ? 0 : remaining;
  }

  // Check if employee has enough balance for requested days
  bool hasEnoughBalance(String leaveType, int requestedDays) {
    final remaining = getRemainingDays(leaveType);
    return remaining >= requestedDays;
  }

  // ✅ FIXED: Add pending days (when leave is applied)
  LeaveBalance addPendingDays(String leaveType, int days) {
    print("🔄 Adding $days pending days to $leaveType");
    print("📊 Before: Pending ${pendingDays[leaveType] ?? 0} days");

    final newPendingDays = Map<String, int>.from(pendingDays);
    newPendingDays[leaveType] = (newPendingDays[leaveType] ?? 0) + days;

    print("📊 After: Pending ${newPendingDays[leaveType]} days");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ FIXED: Remove pending days (when leave is rejected/cancelled)
  LeaveBalance removePendingDays(String leaveType, int days) {
    print("🔄 Removing $days pending days from $leaveType");
    print("📊 Before: Pending ${pendingDays[leaveType] ?? 0} days");

    final newPendingDays = Map<String, int>.from(pendingDays);
    final currentPending = newPendingDays[leaveType] ?? 0;

    // Calculate new pending days, ensuring it doesn't go below 0
    final newPendingValue = currentPending - days;
    newPendingDays[leaveType] = newPendingValue < 0 ? 0 : newPendingValue;

    print("📊 After: Pending ${newPendingDays[leaveType]} days");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ FIXED: Approve leave (move from pending to used)
  LeaveBalance approveLeave(String leaveType, int days) {
    print("✅ Approving $days days for $leaveType");
    print("📊 Before: Used ${usedDays[leaveType] ?? 0}, Pending ${pendingDays[leaveType] ?? 0}");

    final newUsedDays = Map<String, int>.from(usedDays);
    final newPendingDays = Map<String, int>.from(pendingDays);

    // Add to used days
    newUsedDays[leaveType] = (newUsedDays[leaveType] ?? 0) + days;

    // Remove from pending days
    final currentPending = newPendingDays[leaveType] ?? 0;
    final newPendingValue = currentPending - days;
    newPendingDays[leaveType] = newPendingValue < 0 ? 0 : newPendingValue;

    print("📊 After: Used ${newUsedDays[leaveType]}, Pending ${newPendingDays[leaveType]}");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: newUsedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ NEW: Special method for emergency leave - add pending to both emergency and annual
  LeaveBalance addEmergencyPendingDays(int days) {
    print("🚨 Adding $days emergency pending days (double deduction)");

    final newPendingDays = Map<String, int>.from(pendingDays);

    // Add to emergency leave pending
    newPendingDays['emergency'] = (newPendingDays['emergency'] ?? 0) + days;
    print("📊 Emergency pending: ${newPendingDays['emergency']} days");

    // Add to annual leave pending
    newPendingDays['annual'] = (newPendingDays['annual'] ?? 0) + days;
    print("📊 Annual pending: ${newPendingDays['annual']} days");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ NEW: Special method for emergency leave - remove pending from both emergency and annual
  LeaveBalance removeEmergencyPendingDays(int days) {
    print("🚨 Removing $days emergency pending days (double deduction restoration)");

    final newPendingDays = Map<String, int>.from(pendingDays);

    // Remove from emergency leave pending
    final currentEmergencyPending = newPendingDays['emergency'] ?? 0;
    final newEmergencyPending = currentEmergencyPending - days;
    newPendingDays['emergency'] = newEmergencyPending < 0 ? 0 : newEmergencyPending;
    print("📊 Emergency pending: ${newPendingDays['emergency']} days");

    // Remove from annual leave pending
    final currentAnnualPending = newPendingDays['annual'] ?? 0;
    final newAnnualPending = currentAnnualPending - days;
    newPendingDays['annual'] = newAnnualPending < 0 ? 0 : newAnnualPending;
    print("📊 Annual pending: ${newPendingDays['annual']} days");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: usedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // ✅ NEW: Special method for emergency leave approval - move from pending to used for both
  LeaveBalance approveEmergencyLeave(int days) {
    print("🚨 Approving $days emergency leave days (double deduction)");

    final newUsedDays = Map<String, int>.from(usedDays);
    final newPendingDays = Map<String, int>.from(pendingDays);

    // Move emergency leave from pending to used
    newUsedDays['emergency'] = (newUsedDays['emergency'] ?? 0) + days;
    final currentEmergencyPending = newPendingDays['emergency'] ?? 0;
    final newEmergencyPending = currentEmergencyPending - days;
    newPendingDays['emergency'] = newEmergencyPending < 0 ? 0 : newEmergencyPending;
    print("📊 Emergency - Used: ${newUsedDays['emergency']}, Pending: ${newPendingDays['emergency']}");

    // Move annual leave from pending to used
    newUsedDays['annual'] = (newUsedDays['annual'] ?? 0) + days;
    final currentAnnualPending = newPendingDays['annual'] ?? 0;
    final newAnnualPending = currentAnnualPending - days;
    newPendingDays['annual'] = newAnnualPending < 0 ? 0 : newAnnualPending;
    print("📊 Annual - Used: ${newUsedDays['annual']}, Pending: ${newPendingDays['annual']}");

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: totalDays,
      usedDays: newUsedDays,
      pendingDays: newPendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Add compensate leave days (earned overtime compensation)
  LeaveBalance addCompensateDays(int days) {
    final newTotalDays = Map<String, int>.from(totalDays);
    newTotalDays['compensate'] = (newTotalDays['compensate'] ?? 0) + days;

    return LeaveBalance(
      employeeId: employeeId,
      year: year,
      totalDays: newTotalDays,
      usedDays: usedDays,
      pendingDays: pendingDays,
      lastUpdated: DateTime.now(),
    );
  }

  // Get summary of all leave types
  Map<String, Map<String, int>> getSummary() {
    final summary = <String, Map<String, int>>{};

    // ✅ FIXED: Only include 4 leave types
    final leaveTypes = ['annual', 'sick', 'local', 'emergency'];

    for (String leaveType in leaveTypes) {
      final total = totalDays[leaveType] ?? 0;
      final used = usedDays[leaveType] ?? 0;
      final pending = pendingDays[leaveType] ?? 0;
      final remaining = total - used - pending;

      summary[leaveType] = {
        'total': total,
        'used': used,
        'pending': pending,
        'remaining': remaining < 0 ? 0 : remaining,
      };
    }

    return summary;
  }

  // Get total days taken this year
  int getTotalDaysTaken() {
    return usedDays.values.fold(0, (sum, days) => sum + days);
  }

  // Get total pending days
  int getTotalPendingDays() {
    return pendingDays.values.fold(0, (sum, days) => sum + days);
  }

  // Check if this is a new balance (no days used yet)
  bool get isNew {
    return getTotalDaysTaken() == 0 && getTotalPendingDays() == 0;
  }

  // Copy with updated values
  LeaveBalance copyWith({
    String? employeeId,
    int? year,
    Map<String, int>? totalDays,
    Map<String, int>? usedDays,
    Map<String, int>? pendingDays,
    DateTime? lastUpdated,
  }) {
    return LeaveBalance(
      employeeId: employeeId ?? this.employeeId,
      year: year ?? this.year,
      totalDays: totalDays ?? this.totalDays,
      usedDays: usedDays ?? this.usedDays,
      pendingDays: pendingDays ?? this.pendingDays,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // ✅ DEBUG: Print current balance state
  void printBalanceState() {
    print("=== LEAVE BALANCE STATE ===");
    print("Employee: $employeeId, Year: $year");
    print("TOTAL DAYS: $totalDays");
    print("USED DAYS: $usedDays");
    print("PENDING DAYS: $pendingDays");
    print("REMAINING DAYS:");
    for (String type in ['annual', 'sick', 'local', 'emergency']) {
      print("  $type: ${getRemainingDays(type)} days");
    }
    print("===========================");
  }

  @override
  String toString() {
    return 'LeaveBalance(employeeId: $employeeId, year: $year, totalTaken: ${getTotalDaysTaken()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaveBalance &&
        other.employeeId == employeeId &&
        other.year == year;
  }

  @override
  int get hashCode {
    return employeeId.hashCode ^ year.hashCode;
  }
}
