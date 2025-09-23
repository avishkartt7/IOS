// lib/model/local_attendance_model.dart - COMPLETE AND PROPER VERSION

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// LocalAttendanceRecord model for storing attendance data in local SQLite database
/// Supports separate check-in and check-out locations to prevent data overriding
class LocalAttendanceRecord {
  /// Local database auto-increment ID
  final int? id;

  /// Employee ID (required)
  final String employeeId;

  /// Date in YYYY-MM-DD format (required)
  final String date;

  /// Check-in timestamp in ISO 8601 format
  final String? checkIn;

  /// Check-out timestamp in ISO 8601 format
  final String? checkOut;

  /// ✅ NEW: Separate check-in location ID
  final String? checkInLocationId;

  /// ✅ NEW: Separate check-out location ID
  final String? checkOutLocationId;

  /// ✅ NEW: Human-readable check-in location name
  final String? checkInLocationName;

  /// ✅ NEW: Human-readable check-out location name
  final String? checkOutLocationName;

  /// Sync status with cloud database
  final bool isSynced;

  /// Error message if sync failed
  final String? syncError;

  /// Additional raw data from Firestore or other sources
  final Map<String, dynamic> rawData;

  /// Constructor
  LocalAttendanceRecord({
    this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkInLocationId,
    this.checkOutLocationId,
    this.checkInLocationName,
    this.checkOutLocationName,
    this.isSynced = false,
    this.syncError,
    required this.rawData,
  });

  /// ✅ DEPRECATED: Legacy location getter for backward compatibility
  /// Returns check-in location ID or falls back to legacy location field
  String? get locationId => checkInLocationId ?? rawData['location_id'];

  /// ✅ DEPRECATED: Legacy location name getter for backward compatibility
  String? get locationName => checkInLocationName ?? rawData['locationName'] ?? rawData['location_name'];

  /// Convert to Map for SQLite database storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'date': date,
      'check_in': checkIn,
      'check_out': checkOut,
      'check_in_location_id': checkInLocationId,
      'check_out_location_id': checkOutLocationId,
      'check_in_location_name': checkInLocationName,
      'check_out_location_name': checkOutLocationName,
      // ✅ Keep legacy field for backward compatibility
      'location_id': checkInLocationId ?? locationId,
      'is_synced': isSynced ? 1 : 0,
      'sync_error': syncError,
      'raw_data': jsonEncode(rawData),
    };
  }

  /// Create from SQLite database Map
  factory LocalAttendanceRecord.fromMap(Map<String, dynamic> map) {
    // ✅ Parse raw data safely
    Map<String, dynamic> rawData = {};
    try {
      if (map['raw_data'] != null && map['raw_data'].toString().isNotEmpty) {
        rawData = jsonDecode(map['raw_data'].toString());
      }
    } catch (e) {
      print("Warning: Error parsing raw_data in LocalAttendanceRecord: $e");
      rawData = {};
    }

    return LocalAttendanceRecord(
      id: map['id'] as int?,
      employeeId: map['employee_id']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      checkIn: map['check_in']?.toString(),
      checkOut: map['check_out']?.toString(),
      checkInLocationId: map['check_in_location_id']?.toString(),
      checkOutLocationId: map['check_out_location_id']?.toString(),
      checkInLocationName: map['check_in_location_name']?.toString(),
      checkOutLocationName: map['check_out_location_name']?.toString(),
      isSynced: (map['is_synced'] ?? 0) == 1,
      syncError: map['sync_error']?.toString(),
      rawData: rawData,
    );
  }

  /// ✅ Convert to Firestore format for cloud sync
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    // ✅ Add core attendance data
    data['employeeId'] = employeeId;
    data['date'] = date;

    // ✅ Add timestamp data
    if (checkIn != null) {
      data['checkIn'] = checkIn;
    }
    if (checkOut != null) {
      data['checkOut'] = checkOut;
    }

    // ✅ Add separate location data (NEW APPROACH)
    if (checkInLocationId != null) {
      data['checkInLocation'] = checkInLocationId;
    }
    if (checkOutLocationId != null) {
      data['checkOutLocation'] = checkOutLocationId;
    }
    if (checkInLocationName != null) {
      data['checkInLocationName'] = checkInLocationName;
    }
    if (checkOutLocationName != null) {
      data['checkOutLocationName'] = checkOutLocationName;
    }

    // ✅ BACKWARD COMPATIBILITY: Keep legacy location field
    if (checkInLocationId != null) {
      data['location'] = checkInLocationId;
      if (checkInLocationName != null) {
        data['locationName'] = checkInLocationName;
      }
    }

    // ✅ Add sync metadata
    data['lastUpdated'] = FieldValue.serverTimestamp();
    data['syncedAt'] = DateTime.now().toIso8601String();

    return data;
  }

  /// ✅ Create from Firestore document data
  factory LocalAttendanceRecord.fromFirestore(
      String employeeId,
      Map<String, dynamic> firestoreData,
      ) {
    // ✅ Handle Firestore Timestamps
    String? checkIn;
    String? checkOut;

    if (firestoreData['checkIn'] != null) {
      if (firestoreData['checkIn'] is Timestamp) {
        checkIn = (firestoreData['checkIn'] as Timestamp).toDate().toIso8601String();
      } else {
        checkIn = firestoreData['checkIn'].toString();
      }
    }

    if (firestoreData['checkOut'] != null) {
      if (firestoreData['checkOut'] is Timestamp) {
        checkOut = (firestoreData['checkOut'] as Timestamp).toDate().toIso8601String();
      } else {
        checkOut = firestoreData['checkOut'].toString();
      }
    }

    return LocalAttendanceRecord(
      employeeId: employeeId,
      date: firestoreData['date']?.toString() ?? '',
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocationId: firestoreData['checkInLocation']?.toString() ??
          firestoreData['location']?.toString(), // Fallback to legacy
      checkOutLocationId: firestoreData['checkOutLocation']?.toString(),
      checkInLocationName: firestoreData['checkInLocationName']?.toString() ??
          firestoreData['locationName']?.toString(), // Fallback to legacy
      checkOutLocationName: firestoreData['checkOutLocationName']?.toString(),
      isSynced: true, // Coming from Firestore means it's synced
      rawData: firestoreData,
    );
  }

  /// ✅ Create from attendance data (for new records)
  factory LocalAttendanceRecord.fromAttendanceData(
      String employeeId,
      Map<String, dynamic> attendanceData,
      ) {
    return LocalAttendanceRecord(
      employeeId: employeeId,
      date: attendanceData['date']?.toString() ?? '',
      checkIn: attendanceData['checkIn']?.toString(),
      checkOut: attendanceData['checkOut']?.toString(),
      checkInLocationId: attendanceData['checkInLocation']?.toString() ??
          attendanceData['location']?.toString(),
      checkOutLocationId: attendanceData['checkOutLocation']?.toString(),
      checkInLocationName: attendanceData['checkInLocationName']?.toString() ??
          attendanceData['locationName']?.toString(),
      checkOutLocationName: attendanceData['checkOutLocationName']?.toString(),
      isSynced: false, // New record, needs sync
      rawData: attendanceData,
    );
  }

  /// ✅ Update record with check-out data (preserves check-in location)
  LocalAttendanceRecord updateWithCheckOut({
    required String checkOut,
    required String? checkOutLocationId,
    required String? checkOutLocationName,
    Map<String, dynamic>? additionalData,
  }) {
    // ✅ Preserve existing data and add check-out info
    Map<String, dynamic> updatedRawData = Map<String, dynamic>.from(rawData);
    updatedRawData['checkOut'] = checkOut;

    if (checkOutLocationId != null) {
      updatedRawData['checkOutLocation'] = checkOutLocationId;
    }
    if (checkOutLocationName != null) {
      updatedRawData['checkOutLocationName'] = checkOutLocationName;
    }

    if (additionalData != null) {
      updatedRawData.addAll(additionalData);
    }

    return LocalAttendanceRecord(
      id: id,
      employeeId: employeeId,
      date: date,
      checkIn: checkIn, // ✅ PRESERVE existing check-in
      checkOut: checkOut,
      checkInLocationId: checkInLocationId, // ✅ PRESERVE existing check-in location
      checkOutLocationId: checkOutLocationId,
      checkInLocationName: checkInLocationName, // ✅ PRESERVE existing check-in location name
      checkOutLocationName: checkOutLocationName,
      isSynced: false, // Reset sync status since data changed
      syncError: null, // Clear previous errors
      rawData: updatedRawData,
    );
  }

  /// ✅ Update record with check-in data only
  LocalAttendanceRecord updateWithCheckIn({
    required String checkIn,
    required String? checkInLocationId,
    required String? checkInLocationName,
    Map<String, dynamic>? additionalData,
  }) {
    Map<String, dynamic> updatedRawData = Map<String, dynamic>.from(rawData);
    updatedRawData['checkIn'] = checkIn;

    if (checkInLocationId != null) {
      updatedRawData['checkInLocation'] = checkInLocationId;
    }
    if (checkInLocationName != null) {
      updatedRawData['checkInLocationName'] = checkInLocationName;
    }

    if (additionalData != null) {
      updatedRawData.addAll(additionalData);
    }

    return LocalAttendanceRecord(
      id: id,
      employeeId: employeeId,
      date: date,
      checkIn: checkIn,
      checkOut: checkOut, // ✅ PRESERVE existing check-out
      checkInLocationId: checkInLocationId,
      checkOutLocationId: checkOutLocationId, // ✅ PRESERVE existing check-out location
      checkInLocationName: checkInLocationName,
      checkOutLocationName: checkOutLocationName, // ✅ PRESERVE existing check-out location name
      isSynced: false, // Reset sync status since data changed
      syncError: null, // Clear previous errors
      rawData: updatedRawData,
    );
  }

  /// ✅ Mark record as successfully synced
  LocalAttendanceRecord markAsSynced() {
    return LocalAttendanceRecord(
      id: id,
      employeeId: employeeId,
      date: date,
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocationId: checkInLocationId,
      checkOutLocationId: checkOutLocationId,
      checkInLocationName: checkInLocationName,
      checkOutLocationName: checkOutLocationName,
      isSynced: true,
      syncError: null, // Clear any previous error
      rawData: rawData,
    );
  }

  /// ✅ Mark record with sync error
  LocalAttendanceRecord markSyncError(String error) {
    return LocalAttendanceRecord(
      id: id,
      employeeId: employeeId,
      date: date,
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocationId: checkInLocationId,
      checkOutLocationId: checkOutLocationId,
      checkInLocationName: checkInLocationName,
      checkOutLocationName: checkOutLocationName,
      isSynced: false,
      syncError: error,
      rawData: rawData,
    );
  }

  /// ✅ Create a copy with updated data
  LocalAttendanceRecord copyWith({
    int? id,
    String? employeeId,
    String? date,
    String? checkIn,
    String? checkOut,
    String? checkInLocationId,
    String? checkOutLocationId,
    String? checkInLocationName,
    String? checkOutLocationName,
    bool? isSynced,
    String? syncError,
    Map<String, dynamic>? rawData,
  }) {
    return LocalAttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      checkInLocationId: checkInLocationId ?? this.checkInLocationId,
      checkOutLocationId: checkOutLocationId ?? this.checkOutLocationId,
      checkInLocationName: checkInLocationName ?? this.checkInLocationName,
      checkOutLocationName: checkOutLocationName ?? this.checkOutLocationName,
      isSynced: isSynced ?? this.isSynced,
      syncError: syncError ?? this.syncError,
      rawData: rawData ?? this.rawData,
    );
  }

  // ===========================
  // HELPER METHODS & GETTERS
  // ===========================

  /// Check if record has check-in time
  bool get hasCheckIn => checkIn != null && checkIn!.isNotEmpty;

  /// Check if record has check-out time
  bool get hasCheckOut => checkOut != null && checkOut!.isNotEmpty;

  /// Check if record is complete (has both check-in and check-out)
  bool get isCompleteDay => hasCheckIn && hasCheckOut;

  /// Check if record has sync error
  bool get hasError => syncError != null && syncError!.isNotEmpty;

  /// Check if record needs syncing
  bool get needsSync => !isSynced || hasError;

  /// Get total work duration in hours (if complete day)
  double get totalHours {
    if (!isCompleteDay) return 0.0;

    try {
      final checkInTime = DateTime.parse(checkIn!);
      final checkOutTime = DateTime.parse(checkOut!);
      final duration = checkOutTime.difference(checkInTime);
      return duration.inMinutes / 60.0;
    } catch (e) {
      print("Error calculating total hours: $e");
      return 0.0;
    }
  }

  /// ✅ Get location summary string
  String get locationSummary {
    if (checkInLocationName == null && checkOutLocationName == null) {
      // Fallback to legacy location if available
      if (locationName != null) {
        return locationName!;
      }
      return 'Unknown Location';
    }

    if (checkInLocationName != null && checkOutLocationName != null) {
      if (checkInLocationName == checkOutLocationName) {
        return checkInLocationName!; // Same location
      } else {
        return '$checkInLocationName → $checkOutLocationName'; // Different locations
      }
    }

    if (checkInLocationName != null) {
      return 'In: $checkInLocationName';
    }

    if (checkOutLocationName != null) {
      return 'Out: $checkOutLocationName';
    }

    return 'Unknown Location';
  }

  /// ✅ Get detailed location information
  String get detailedLocationInfo {
    List<String> parts = [];

    if (checkInLocationName != null) {
      parts.add('Check-in: $checkInLocationName');
    } else if (checkInLocationId != null) {
      parts.add('Check-in: $checkInLocationId');
    }

    if (checkOutLocationName != null) {
      parts.add('Check-out: $checkOutLocationName');
    } else if (checkOutLocationId != null) {
      parts.add('Check-out: $checkOutLocationId');
    }

    if (parts.isEmpty) {
      return 'No location information available';
    }

    return parts.join(' • ');
  }

  /// ✅ Check if employee worked from multiple locations
  bool get hasMultipleLocations {
    return checkInLocationId != null &&
        checkOutLocationId != null &&
        checkInLocationId != checkOutLocationId;
  }

  /// ✅ Get work status based on timestamps
  String get workStatus {
    if (!hasCheckIn && !hasCheckOut) {
      return 'Absent';
    } else if (hasCheckIn && !hasCheckOut) {
      return 'In Progress';
    } else if (hasCheckIn && hasCheckOut) {
      return 'Complete';
    } else {
      return 'Unknown';
    }
  }

  /// Get formatted check-in time
  String get formattedCheckIn {
    if (!hasCheckIn) return '-';
    try {
      final time = DateTime.parse(checkIn!);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return checkIn!;
    }
  }

  /// Get formatted check-out time
  String get formattedCheckOut {
    if (!hasCheckOut) return '-';
    try {
      final time = DateTime.parse(checkOut!);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return checkOut!;
    }
  }

  /// Get formatted total hours
  String get formattedTotalHours {
    if (totalHours <= 0) return '-';
    return '${totalHours.toStringAsFixed(1)}h';
  }

  /// Get formatted date
  String get formattedDate {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  // ===========================
  // VALIDATION METHODS
  // ===========================

  /// ✅ Validate record data
  bool get isValid {
    return employeeId.isNotEmpty && date.isNotEmpty;
  }

  /// ✅ Get validation errors
  List<String> get validationErrors {
    List<String> errors = [];

    if (employeeId.isEmpty) {
      errors.add('Employee ID is required');
    }

    if (date.isEmpty) {
      errors.add('Date is required');
    }

    if (checkIn != null && checkIn!.isNotEmpty) {
      try {
        DateTime.parse(checkIn!);
      } catch (e) {
        errors.add('Invalid check-in time format');
      }
    }

    if (checkOut != null && checkOut!.isNotEmpty) {
      try {
        DateTime.parse(checkOut!);
      } catch (e) {
        errors.add('Invalid check-out time format');
      }
    }

    return errors;
  }

  // ===========================
  // OBJECT OVERRIDES
  // ===========================

  @override
  String toString() {
    return 'LocalAttendanceRecord('
        'id: $id, '
        'employeeId: $employeeId, '
        'date: $date, '
        'checkIn: $checkIn, '
        'checkOut: $checkOut, '
        'checkInLocation: $checkInLocationName, '
        'checkOutLocation: $checkOutLocationName, '
        'isSynced: $isSynced, '
        'hasError: $hasError'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocalAttendanceRecord &&
        other.employeeId == employeeId &&
        other.date == date;
  }

  @override
  int get hashCode {
    return employeeId.hashCode ^ date.hashCode;
  }

  /// ✅ Convert to JSON string for debugging/logging
  String toJson() {
    return jsonEncode(toMap());
  }

  /// ✅ Create from JSON string
  factory LocalAttendanceRecord.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return LocalAttendanceRecord.fromMap(map);
  }
}