// lib/model/location_exemption_model.dart

class LocationExemptionModel {
  String? id;
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final String reason;
  final DateTime grantedAt;
  final String grantedBy;
  final bool isActive;
  final DateTime? expiryDate;
  final String? notes;

  LocationExemptionModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.reason,
    required this.grantedAt,
    required this.grantedBy,
    this.isActive = true,
    this.expiryDate,
    this.notes,
  });

  factory LocationExemptionModel.fromJson(Map<String, dynamic> json) {
    return LocationExemptionModel(
      id: json['id'],
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      employeePin: json['employeePin'] ?? '',
      reason: json['reason'] ?? '',
      grantedAt: DateTime.parse(json['grantedAt']),
      grantedBy: json['grantedBy'] ?? '',
      isActive: json['isActive'] ?? true,
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeePin': employeePin,
      'reason': reason,
      'grantedAt': grantedAt.toIso8601String(),
      'grantedBy': grantedBy,
      'isActive': isActive,
      'expiryDate': expiryDate?.toIso8601String(),
      'notes': notes,
    };
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isCurrentlyActive => isActive && !isExpired;
}
