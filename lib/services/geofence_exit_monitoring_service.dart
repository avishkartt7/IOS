// lib/services/geofence_exit_monitoring_service.dart - COMPLETE IMPLEMENTATION

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/notification_service.dart';
import 'package:face_auth_compatible/utils/enhanced_geofence_util.dart';
import 'package:intl/intl.dart';

class GeofenceExitEvent {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime exitTime;
  final DateTime? returnTime;
  final double latitude;
  final double longitude;
  final String? locationName;
  final String? exitReason;
  final int durationMinutes;
  final String status;
  final bool hrNotified;
  final bool reminderSent;
  final DateTime createdAt;
  final bool isSynced;
  final String? syncError;

  GeofenceExitEvent({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.exitTime,
    this.returnTime,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.exitReason,
    this.durationMinutes = 0,
    this.status = 'active',
    this.hrNotified = false,
    this.reminderSent = false,
    required this.createdAt,
    this.isSynced = false,
    this.syncError,
  });

  factory GeofenceExitEvent.fromMap(Map<String, dynamic> map) {
    return GeofenceExitEvent(
      id: map['id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      exitTime: DateTime.parse(map['exit_time']),
      returnTime: map['return_time'] != null ? DateTime.parse(map['return_time']) : null,
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      locationName: map['location_name'],
      exitReason: map['exit_reason'],
      durationMinutes: map['duration_minutes'] ?? 0,
      status: map['status'] ?? 'active',
      hrNotified: (map['hr_notified'] ?? 0) == 1,
      reminderSent: (map['reminder_sent'] ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']),
      isSynced: (map['is_synced'] ?? 0) == 1,
      syncError: map['sync_error'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'exit_time': exitTime.toIso8601String(),
      'return_time': returnTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'exit_reason': exitReason,
      'duration_minutes': durationMinutes,
      'status': status,
      'hr_notified': hrNotified ? 1 : 0,
      'reminder_sent': reminderSent ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'sync_error': syncError,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'exitTime': Timestamp.fromDate(exitTime),
      'returnTime': returnTime != null ? Timestamp.fromDate(returnTime!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'exitReason': exitReason,
      'durationMinutes': durationMinutes,
      'status': status,
      'hrNotified': hrNotified,
      'reminderSent': reminderSent,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class GeofenceExitMonitoringService {
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivityService;
  final NotificationService _notificationService;

  // Monitoring state
  Timer? _monitoringTimer;
  Timer? _syncTimer;
  String? _currentEmployeeId;
  String? _currentEmployeeName;
  bool _isMonitoring = false;
  Position? _lastKnownPosition;
  bool _wasInsideGeofence = true;
  DateTime? _lastLocationCheck;
  DateTime? _lastSyncAttempt;

  // Configuration - SET YOUR PREFERRED INTERVAL HERE
  late Duration _currentCheckInterval;
  bool _isHighFrequencyMode = false;

  // CONFIGURABLE INTERVALS
  static const Duration _defaultCheckInterval = Duration(hours: 2);  // Every 2 hours (PRODUCTION)
  static const Duration _testingCheckInterval = Duration(minutes: 2); // Every 2 minutes (TESTING)
  static const Duration _balancedCheckInterval = Duration(minutes: 30); // Every 30 minutes (BALANCED)

  static const Duration _graceExitPeriod = Duration(minutes: 5);
  static const Duration _hrNotificationDelay = Duration(minutes: 15);
  static const Duration _syncInterval = Duration(minutes: 10); // Sync every 10 minutes

  GeofenceExitMonitoringService({
    required DatabaseHelper dbHelper,
    required ConnectivityService connectivityService,
    required NotificationService notificationService,
    Duration? checkInterval,
  }) : _dbHelper = dbHelper,
        _connectivityService = connectivityService,
        _notificationService = notificationService {

    // Set monitoring interval - CHANGE THIS BASED ON YOUR NEEDS
    _currentCheckInterval = checkInterval ?? _defaultCheckInterval; // Use 2 hours by default
    debugPrint("🕐 Geofence monitoring interval set to: ${_getIntervalDescription()}");

    // Setup periodic sync
    _setupPeriodicSync();
  }

  String _getIntervalDescription() {
    if (_currentCheckInterval.inHours > 0) {
      return "${_currentCheckInterval.inHours} hour${_currentCheckInterval.inHours > 1 ? 's' : ''}";
    } else {
      return "${_currentCheckInterval.inMinutes} minute${_currentCheckInterval.inMinutes > 1 ? 's' : ''}";
    }
  }

  // Setup periodic sync timer
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        _syncPendingEvents();
      }
    });
  }

  // Initialize the database table
  Future<void> initializeDatabase() async {
    try {
      debugPrint("🔧 Initializing geofence exit monitoring database...");

      final db = await _dbHelper.database;

      // Check if table exists
      final tables = await db.query(
          'sqlite_master',
          where: 'type = ? AND name = ?',
          whereArgs: ['table', 'geofence_exit_events']
      );

      if (tables.isEmpty) {
        debugPrint("⚠️ Geofence exit events table not found, creating...");

        await db.execute('''
        CREATE TABLE IF NOT EXISTS geofence_exit_events(
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          employee_name TEXT NOT NULL,
          exit_time TEXT NOT NULL,
          return_time TEXT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          location_name TEXT,
          exit_reason TEXT,
          duration_minutes INTEGER DEFAULT 0,
          status TEXT DEFAULT 'active',
          hr_notified INTEGER DEFAULT 0,
          reminder_sent INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          sync_error TEXT
        )
        ''');

        // Create indexes for performance
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_employee ON geofence_exit_events(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_status ON geofence_exit_events(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_synced ON geofence_exit_events(is_synced)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_exit_time ON geofence_exit_events(exit_time)');

        debugPrint("✅ Geofence exit events table created successfully");
      } else {
        debugPrint("✅ Geofence exit events table already exists");
      }

      // Test the table with count
      final count = await db.query('geofence_exit_events', columns: ['COUNT(*) as count']);
      debugPrint("📊 Current geofence events count: ${count.first['count']}");

      // Test insert to verify table works
      await _testDatabaseOperations();

    } catch (e) {
      debugPrint("❌ Error initializing geofence database: $e");
      rethrow;
    }
  }

  // Test database operations
  Future<void> _testDatabaseOperations() async {
    try {
      final db = await _dbHelper.database;

      // Test insert
      final testEvent = {
        'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'employee_id': 'test_employee',
        'employee_name': 'Test User',
        'exit_time': DateTime.now().toIso8601String(),
        'return_time': null,
        'latitude': 25.0,
        'longitude': 55.0,
        'location_name': 'Test Location',
        'exit_reason': null,
        'duration_minutes': 0,
        'status': 'test',
        'hr_notified': 0,
        'reminder_sent': 0,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
        'sync_error': null,
      };

      await db.insert('geofence_exit_events', testEvent);

      // Test query
      final results = await db.query(
          'geofence_exit_events',
          where: 'status = ?',
          whereArgs: ['test']
      );

      if (results.isNotEmpty) {
        debugPrint("✅ Database operations test successful");

        // Clean up test data
        await db.delete('geofence_exit_events', where: 'status = ?', whereArgs: ['test']);
      } else {
        debugPrint("⚠️ Database operations test failed - no results found");
      }
    } catch (e) {
      debugPrint("❌ Database operations test failed: $e");
    }
  }

  // Start monitoring for an employee
  Future<bool> startMonitoring(String employeeId, String employeeName, {Duration? customInterval}) async {
    try {
      debugPrint("🟢 Starting geofence exit monitoring for: $employeeName ($employeeId)");

      // Use custom interval if provided
      if (customInterval != null) {
        _currentCheckInterval = customInterval;
        debugPrint("🕐 Using custom monitoring interval: ${_getIntervalDescription()}");
      }

      // Stop any existing monitoring
      await stopMonitoring();

      // Initialize database
      await initializeDatabase();

      _currentEmployeeId = employeeId;
      _currentEmployeeName = employeeName;
      _isMonitoring = true;
      _wasInsideGeofence = true;
      _lastLocationCheck = DateTime.now();

      // Save monitoring state
      await _saveMonitoringState();

      // Get initial position
      await _updateCurrentPosition();

      // Start the monitoring timer
      _monitoringTimer = Timer.periodic(_currentCheckInterval, (timer) {
        debugPrint("⏰ Geofence check triggered (Interval: ${_getIntervalDescription()})");
        _performLocationCheck();
      });

      // Immediate first check
      Timer(const Duration(seconds: 5), () {
        debugPrint("🚀 Performing initial geofence check...");
        _performLocationCheck();
      });

      debugPrint("✅ Geofence exit monitoring started successfully");
      debugPrint("📊 Monitoring Configuration:");
      debugPrint("  - Employee: $employeeName ($employeeId)");
      debugPrint("  - Check Interval: ${_getIntervalDescription()}");
      debugPrint("  - Grace Period: ${_graceExitPeriod.inMinutes} minutes");
      debugPrint("  - HR Notification Delay: ${_hrNotificationDelay.inMinutes} minutes");

      return true;

    } catch (e) {
      debugPrint("❌ Error starting geofence monitoring: $e");
      return false;
    }
  }

  // Stop monitoring
  Future<void> stopMonitoring() async {
    try {
      debugPrint("🔴 Stopping geofence exit monitoring");

      _monitoringTimer?.cancel();
      _monitoringTimer = null;
      _isMonitoring = false;

      // Final sync before stopping
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncPendingEvents();
      }

      // Clear monitoring state
      await _clearMonitoringState();

      debugPrint("✅ Geofence exit monitoring stopped");

    } catch (e) {
      debugPrint("❌ Error stopping geofence monitoring: $e");
    }
  }

  // Perform location check
  Future<void> _performLocationCheck() async {
    if (!_isMonitoring || _currentEmployeeId == null) {
      debugPrint("⚠️ Monitoring not active or no employee ID");
      return;
    }

    try {
      debugPrint("📍 Performing geofence check for employee: $_currentEmployeeId");

      // Update current position
      bool positionUpdated = await _updateCurrentPosition();

      if (!positionUpdated || _lastKnownPosition == null) {
        debugPrint("⚠️ No location available for geofence check - will retry next interval");
        return;
      }

      debugPrint("📍 Current position: ${_lastKnownPosition!.latitude}, ${_lastKnownPosition!.longitude}");

      // Check geofence status using enhanced utility
      Map<String, dynamic> geofenceStatus = await EnhancedGeofenceUtil.checkGeofenceStatusForEmployeeBackground(
        _currentEmployeeId!,
        currentPosition: _lastKnownPosition,
      );

      bool isCurrentlyInside = geofenceStatus['withinGeofence'] as bool;
      String locationType = geofenceStatus['locationType'] as String? ?? 'unknown';
      double? distance = geofenceStatus['distance'] as double?;
      bool isExempted = geofenceStatus['isExempted'] ?? false;

      debugPrint("📊 Geofence Status:");
      debugPrint("  - Currently Inside: $isCurrentlyInside");
      debugPrint("  - Location Type: $locationType");
      debugPrint("  - Distance: ${distance?.toStringAsFixed(0)}m");
      debugPrint("  - Employee Exempted: $isExempted");
      debugPrint("  - Previous State: ${_wasInsideGeofence ? 'INSIDE' : 'OUTSIDE'}");

      // Skip monitoring for exempt employees unless they exit the exempted area
      if (isExempted && isCurrentlyInside) {
        debugPrint("🆓 Employee is location exempt and within allowed area - no monitoring needed");
        _wasInsideGeofence = true;
        _lastLocationCheck = DateTime.now();
        return;
      }

      // Check for state changes
      if (_wasInsideGeofence && !isCurrentlyInside) {
        debugPrint("🚨 GEOFENCE EXIT DETECTED!");
        await _handleGeofenceExit(distance);
      } else if (!_wasInsideGeofence && isCurrentlyInside) {
        debugPrint("🏠 GEOFENCE RETURN DETECTED!");
        await _handleGeofenceReturn();
      } else {
        debugPrint("📍 No state change - employee still ${isCurrentlyInside ? 'INSIDE' : 'OUTSIDE'}");
      }

      _wasInsideGeofence = isCurrentlyInside;
      _lastLocationCheck = DateTime.now();

      // Sync pending events if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        Timer(const Duration(seconds: 2), () {
          _syncPendingEvents();
        });
      }

    } catch (e) {
      debugPrint("❌ Error in geofence location check: $e");
    }
  }

  // Handle geofence exit
  Future<void> _handleGeofenceExit(double? distance) async {
    try {
      if (_lastKnownPosition == null || _currentEmployeeId == null) {
        debugPrint("❌ Cannot handle geofence exit - missing position or employee ID");
        return;
      }

      debugPrint("📝 Recording geofence exit event");

      final exitEvent = GeofenceExitEvent(
        id: 'exit_${_currentEmployeeId}_${DateTime.now().millisecondsSinceEpoch}',
        employeeId: _currentEmployeeId!,
        employeeName: _currentEmployeeName ?? 'Unknown Employee',
        exitTime: DateTime.now(),
        latitude: _lastKnownPosition!.latitude,
        longitude: _lastKnownPosition!.longitude,
        locationName: 'Work Area',
        status: 'grace_period',
        createdAt: DateTime.now(),
      );

      // Save to local database
      await _saveExitEventLocally(exitEvent);

      // Schedule notifications
      await _scheduleExitNotifications(exitEvent);

      debugPrint("✅ Geofence exit event recorded: ${exitEvent.id}");
      debugPrint("📊 Exit Details:");
      debugPrint("  - Employee: ${exitEvent.employeeName} (${exitEvent.employeeId})");
      debugPrint("  - Exit Time: ${DateFormat('MMM dd, yyyy h:mm a').format(exitEvent.exitTime)}");
      debugPrint("  - Location: ${exitEvent.latitude}, ${exitEvent.longitude}");
      debugPrint("  - Distance from office: ${distance?.toStringAsFixed(0)}m");

    } catch (e) {
      debugPrint("❌ Error handling geofence exit: $e");
    }
  }

  // Handle geofence return
  Future<void> _handleGeofenceReturn() async {
    try {
      debugPrint("📝 Processing geofence return");

      // Find the most recent active exit event
      final activeEvent = await _getActiveExitEvent(_currentEmployeeId!);

      if (activeEvent != null) {
        final duration = DateTime.now().difference(activeEvent.exitTime);

        debugPrint("📊 Return Details:");
        debugPrint("  - Exit Event ID: ${activeEvent.id}");
        debugPrint("  - Exit Time: ${DateFormat('h:mm a').format(activeEvent.exitTime)}");
        debugPrint("  - Return Time: ${DateFormat('h:mm a').format(DateTime.now())}");
        debugPrint("  - Total Duration: ${duration.inMinutes} minutes");

        final updatedEvent = GeofenceExitEvent(
          id: activeEvent.id,
          employeeId: activeEvent.employeeId,
          employeeName: activeEvent.employeeName,
          exitTime: activeEvent.exitTime,
          returnTime: DateTime.now(),
          latitude: activeEvent.latitude,
          longitude: activeEvent.longitude,
          locationName: activeEvent.locationName,
          exitReason: activeEvent.exitReason,
          durationMinutes: duration.inMinutes,
          status: 'resolved',
          hrNotified: activeEvent.hrNotified,
          reminderSent: activeEvent.reminderSent,
          createdAt: activeEvent.createdAt,
          isSynced: false, // Will be synced in next cycle
        );

        await _updateExitEventLocally(updatedEvent);

        debugPrint("✅ Geofence return processed: ${updatedEvent.id} (Duration: ${duration.inMinutes} minutes)");

        // Send return notification if duration was significant
        if (duration.inMinutes >= 15) {
          await _sendReturnNotification(updatedEvent);
        }

      } else {
        debugPrint("⚠️ No active exit event found for return processing");
      }

    } catch (e) {
      debugPrint("❌ Error handling geofence return: $e");
    }
  }

  // Save exit event to local database
  Future<void> _saveExitEventLocally(GeofenceExitEvent event) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('geofence_exit_events', event.toMap());
      debugPrint("💾 Exit event saved locally: ${event.id}");
    } catch (e) {
      debugPrint("❌ Error saving exit event locally: $e");
      rethrow;
    }
  }

  // Update exit event in local database
  Future<void> _updateExitEventLocally(GeofenceExitEvent event) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'geofence_exit_events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      debugPrint("💾 Exit event updated locally: ${event.id}");
    } catch (e) {
      debugPrint("❌ Error updating exit event locally: $e");
      rethrow;
    }
  }

  // Get active exit event for employee
  Future<GeofenceExitEvent?> _getActiveExitEvent(String employeeId) async {
    try {
      final db = await _dbHelper.database;
      final events = await db.query(
        'geofence_exit_events',
        where: 'employee_id = ? AND status IN (?, ?)',
        whereArgs: [employeeId, 'active', 'grace_period'],
        orderBy: 'exit_time DESC',
        limit: 1,
      );

      if (events.isNotEmpty) {
        return GeofenceExitEvent.fromMap(events.first);
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error getting active exit event: $e");
      return null;
    }
  }

  // Schedule exit notifications
  Future<void> _scheduleExitNotifications(GeofenceExitEvent event) async {
    try {
      debugPrint("📅 Scheduling exit notifications for event: ${event.id}");

      // Immediate notification to employee (1 minute delay for grace period)
      Timer(const Duration(minutes: 1), () async {
        debugPrint("📱 Sending immediate employee exit prompt");
        await _sendEmployeeExitPrompt(event);
      });

      // HR notification after delay (15 minutes)
      Timer(_hrNotificationDelay, () async {
        debugPrint("🔔 Sending HR notification after ${_hrNotificationDelay.inMinutes} minutes");
        await _sendHRNotification(event);
      });

      debugPrint("✅ Exit notifications scheduled successfully");

    } catch (e) {
      debugPrint("❌ Error scheduling exit notifications: $e");
    }
  }

  // Send exit prompt to employee
  Future<void> _sendEmployeeExitPrompt(GeofenceExitEvent event) async {
    try {
      debugPrint("📱 Sending exit prompt to employee: ${event.employeeId}");

      // Send local notification
      await _notificationService.showLocalNotification(
        'Work Area Exit Detected',
        'Hi ${event.employeeName.split(' ').first}! Please provide a reason for leaving the work area.',
        data: {
          'type': 'geofence_exit_prompt',
          'eventId': event.id,
          'employeeId': event.employeeId,
          'employeeName': event.employeeName,
          'exitTime': event.exitTime.toIso8601String(),
        },
      );

      // Update event to mark reminder sent
      final updatedEvent = GeofenceExitEvent(
        id: event.id,
        employeeId: event.employeeId,
        employeeName: event.employeeName,
        exitTime: event.exitTime,
        returnTime: event.returnTime,
        latitude: event.latitude,
        longitude: event.longitude,
        locationName: event.locationName,
        exitReason: event.exitReason,
        durationMinutes: event.durationMinutes,
        status: event.status,
        hrNotified: event.hrNotified,
        reminderSent: true,
        createdAt: event.createdAt,
        isSynced: false,
      );

      await _updateExitEventLocally(updatedEvent);

      debugPrint("✅ Exit prompt sent to employee: ${event.employeeId}");

    } catch (e) {
      debugPrint("❌ Error sending employee exit prompt: $e");
    }
  }

  // Send HR notification
  Future<void> _sendHRNotification(GeofenceExitEvent event) async {
    try {
      debugPrint("🔔 Creating HR notification for event: ${event.id}");

      // Create HR notification in Firebase
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await FirebaseFirestore.instance
            .collection('hr_notifications')
            .add({
          'type': 'geofence_exit',
          'employeeId': event.employeeId,
          'employeeName': event.employeeName,
          'exitTime': Timestamp.fromDate(event.exitTime),
          'location': {
            'latitude': event.latitude,
            'longitude': event.longitude,
            'name': event.locationName,
          },
          'status': 'unread',
          'priority': event.exitReason == null ? 'high' : 'medium',
          'message': '${event.employeeName} has left the work area${event.exitReason != null ? ' (Reason: ${event.exitReason})' : ' (No reason provided)'}',
          'duration': event.durationMinutes > 0 ? '${event.durationMinutes} minutes' : 'Ongoing',
          'createdAt': FieldValue.serverTimestamp(),
          'notificationSent': true,
          'requiresFollowUp': event.exitReason == null,
        });

        debugPrint("✅ HR notification created in Firebase for event: ${event.id}");
      } else {
        debugPrint("⚠️ Offline - HR notification will be synced when online");
      }

      // Update local event to mark HR notified
      final updatedEvent = GeofenceExitEvent(
        id: event.id,
        employeeId: event.employeeId,
        employeeName: event.employeeName,
        exitTime: event.exitTime,
        returnTime: event.returnTime,
        latitude: event.latitude,
        longitude: event.longitude,
        locationName: event.locationName,
        exitReason: event.exitReason,
        durationMinutes: event.durationMinutes,
        status: 'active',
        hrNotified: true,
        reminderSent: event.reminderSent,
        createdAt: event.createdAt,
        isSynced: _connectivityService.currentStatus == ConnectionStatus.online,
      );

      await _updateExitEventLocally(updatedEvent);

    } catch (e) {
      debugPrint("❌ Error creating HR notification: $e");
    }
  }

  // Send return notification
  Future<void> _sendReturnNotification(GeofenceExitEvent event) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await FirebaseFirestore.instance
            .collection('hr_notifications')
            .add({
          'type': 'geofence_return',
          'employeeId': event.employeeId,
          'employeeName': event.employeeName,
          'exitTime': Timestamp.fromDate(event.exitTime),
          'returnTime': event.returnTime != null ? Timestamp.fromDate(event.returnTime!) : null,
          'duration': '${event.durationMinutes} minutes',
          'exitReason': event.exitReason,
          'status': 'resolved',
          'priority': 'low',
          'message': '${event.employeeName} has returned to work area after ${event.durationMinutes} minutes',
          'createdAt': FieldValue.serverTimestamp(),
        });

        debugPrint("✅ Return notification created in Firebase");
      }
    } catch (e) {
      debugPrint("❌ Error sending return notification: $e");
    }
  }

  // Record exit reason
  Future<void> recordExitReason(String eventId, String reason) async {
    try {
      debugPrint("📝 Recording exit reason: $reason for event: $eventId");

      final db = await _dbHelper.database;
      final events = await db.query(
        'geofence_exit_events',
        where: 'id = ?',
        whereArgs: [eventId],
      );

      if (events.isNotEmpty) {
        final event = GeofenceExitEvent.fromMap(events.first);

        final updatedEvent = GeofenceExitEvent(
          id: event.id,
          employeeId: event.employeeId,
          employeeName: event.employeeName,
          exitTime: event.exitTime,
          returnTime: event.returnTime,
          latitude: event.latitude,
          longitude: event.longitude,
          locationName: event.locationName,
          exitReason: reason,
          durationMinutes: event.durationMinutes,
          status: event.status,
          hrNotified: event.hrNotified,
          reminderSent: event.reminderSent,
          createdAt: event.createdAt,
          isSynced: false, // Mark for sync
        );

        await _updateExitEventLocally(updatedEvent);

        // Update HR notification with reason if online
        if (_connectivityService.currentStatus == ConnectionStatus.online) {
          await _updateHRNotificationWithReason(eventId, reason);
        }

        debugPrint("✅ Exit reason recorded successfully: $reason");

      } else {
        debugPrint("⚠️ Event not found for reason recording: $eventId");
      }

    } catch (e) {
      debugPrint("❌ Error recording exit reason: $e");
    }
  }

  // Update HR notification with exit reason
  Future<void> _updateHRNotificationWithReason(String eventId, String reason) async {
    try {
      final hrNotifications = await FirebaseFirestore.instance
          .collection('hr_notifications')
          .where('type', isEqualTo: 'geofence_exit')
          .where('employeeId', isEqualTo: _currentEmployeeId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (hrNotifications.docs.isNotEmpty) {
        final doc = hrNotifications.docs.first;
        await doc.reference.update({
          'exitReason': reason,
          'message': '${_currentEmployeeName} left the work area (Reason: ${reason.replaceAll('_', ' ').toUpperCase()})',
          'priority': 'medium',
          'requiresFollowUp': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint("✅ HR notification updated with exit reason: $reason");
      }
    } catch (e) {
      debugPrint("❌ Error updating HR notification with reason: $e");
    }
  }

  // Sync pending events to Firestore
  Future<void> _syncPendingEvents() async {
    try {
      if (_connectivityService.currentStatus != ConnectionStatus.online) {
        debugPrint("📱 Offline - skipping sync");
        return;
      }

      final db = await _dbHelper.database;
      final pendingEvents = await db.query(
        'geofence_exit_events',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (pendingEvents.isEmpty) {
        debugPrint("✅ No pending events to sync");
        return;
      }

      debugPrint("🔄 Syncing ${pendingEvents.length} pending exit events to Firebase");
      _lastSyncAttempt = DateTime.now();

      int successCount = 0;
      int errorCount = 0;

      for (var eventMap in pendingEvents) {
        try {
          final event = GeofenceExitEvent.fromMap(eventMap);

          // Sync to geofence_exit_events collection
          await FirebaseFirestore.instance
              .collection('geofence_exit_events')
              .doc(event.id)
              .set({
            'employeeId': event.employeeId,
            'employeeName': event.employeeName,
            'exitTime': Timestamp.fromDate(event.exitTime),
            'returnTime': event.returnTime != null ? Timestamp.fromDate(event.returnTime!) : null,
            'latitude': event.latitude,
            'longitude': event.longitude,
            'locationName': event.locationName,
            'exitReason': event.exitReason,
            'durationMinutes': event.durationMinutes,
            'status': event.status,
            'hrNotified': event.hrNotified,
            'reminderSent': event.reminderSent,
            'createdAt': Timestamp.fromDate(event.createdAt),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Mark as synced locally
          await db.update(
            'geofence_exit_events',
            {'is_synced': 1, 'sync_error': null},
            where: 'id = ?',
            whereArgs: [event.id],
          );

          successCount++;
          debugPrint("✅ Synced event: ${event.id}");

        } catch (e) {
          errorCount++;
          debugPrint("❌ Error syncing event ${eventMap['id']}: $e");

          // Mark sync error locally
          await db.update(
            'geofence_exit_events',
            {'sync_error': e.toString()},
            where: 'id = ?',
            whereArgs: [eventMap['id']],
          );
        }
      }

      debugPrint("📊 Sync Results:");
      debugPrint("  - Successful: $successCount");
      debugPrint("  - Errors: $errorCount");
      debugPrint("  - Collections Created: geofence_exit_events, hr_notifications");

      if (successCount > 0) {
        debugPrint("🎉 Firebase collections should now be visible in console!");
      }

    } catch (e) {
      debugPrint("❌ Error during sync process: $e");
    }
  }

  // Update current position
  Future<bool> _updateCurrentPosition() async {
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (_lastKnownPosition != null) {
        debugPrint("📍 Position updated: ${_lastKnownPosition!.latitude.toStringAsFixed(6)}, ${_lastKnownPosition!.longitude.toStringAsFixed(6)}");
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("⚠️ Could not get current position: $e");

      // Try with lower accuracy as fallback
      try {
        _lastKnownPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );

        if (_lastKnownPosition != null) {
          debugPrint("📍 Position updated (medium accuracy): ${_lastKnownPosition!.latitude.toStringAsFixed(6)}, ${_lastKnownPosition!.longitude.toStringAsFixed(6)}");
          return true;
        }
      } catch (e2) {
        debugPrint("⚠️ Fallback position request also failed: $e2");
      }

      return false;
    }
  }

  // Save monitoring state
  Future<void> _saveMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('geofence_monitoring_active', _isMonitoring);
      await prefs.setString('monitored_employee_id', _currentEmployeeId ?? '');
      await prefs.setString('monitored_employee_name', _currentEmployeeName ?? '');
      await prefs.setInt('monitoring_interval_minutes', _currentCheckInterval.inMinutes);
      await prefs.setBool('high_frequency_mode', _isHighFrequencyMode);
      await prefs.setString('last_location_check', _lastLocationCheck?.toIso8601String() ?? '');

      debugPrint("💾 Monitoring state saved successfully");
    } catch (e) {
      debugPrint("❌ Error saving monitoring state: $e");
    }
  }

  // Clear monitoring state
  Future<void> _clearMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('geofence_monitoring_active');
      await prefs.remove('monitored_employee_id');
      await prefs.remove('monitored_employee_name');
      await prefs.remove('monitoring_interval_minutes');
      await prefs.remove('high_frequency_mode');
      await prefs.remove('last_location_check');

      _currentEmployeeId = null;
      _currentEmployeeName = null;

      debugPrint("🧹 Monitoring state cleared");
    } catch (e) {
      debugPrint("❌ Error clearing monitoring state: $e");
    }
  }

  // Enable high-frequency monitoring mode
  Future<void> enableHighFrequencyMode({Duration? highFreqInterval}) async {
    if (!_isMonitoring) {
      debugPrint("⚠️ Cannot enable high-frequency mode - monitoring not active");
      return;
    }

    Duration newInterval = highFreqInterval ?? _testingCheckInterval;

    debugPrint("🚀 Enabling high-frequency monitoring mode: ${_getIntervalDescription()}");

    _isHighFrequencyMode = true;
    _currentCheckInterval = newInterval;

    // Restart timer with new interval
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(_currentCheckInterval, (timer) {
      debugPrint("⚡ High-frequency geofence check (${_getIntervalDescription()})");
      _performLocationCheck();
    });

    await _saveMonitoringState();
  }

  // Disable high-frequency mode
  Future<void> disableHighFrequencyMode() async {
    if (!_isMonitoring || !_isHighFrequencyMode) {
      debugPrint("⚠️ High-frequency mode not active");
      return;
    }

    debugPrint("🔄 Returning to normal monitoring frequency");

    _isHighFrequencyMode = false;
    _currentCheckInterval = _defaultCheckInterval;

    // Restart timer with normal interval
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(_currentCheckInterval, (timer) {
      debugPrint("⏰ Normal geofence check (${_getIntervalDescription()})");
      _performLocationCheck();
    });

    await _saveMonitoringState();
  }

  // Get exit history for employee
  Future<List<GeofenceExitEvent>> getExitHistory(String employeeId, {int limit = 10}) async {
    try {
      final db = await _dbHelper.database;
      final events = await db.query(
        'geofence_exit_events',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'exit_time DESC',
        limit: limit,
      );

      final exitEvents = events.map((e) => GeofenceExitEvent.fromMap(e)).toList();

      debugPrint("📊 Retrieved ${exitEvents.length} exit events for employee: $employeeId");

      return exitEvents;

    } catch (e) {
      debugPrint("❌ Error getting exit history: $e");
      return [];
    }
  }

  // Get unsynced events count
  Future<int> getUnsyncedEventsCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'geofence_exit_events',
        columns: ['COUNT(*) as count'],
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint("❌ Error getting unsynced events count: $e");
      return 0;
    }
  }

  // Get total events count
  Future<int> getTotalEventsCount() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'geofence_exit_events',
        columns: ['COUNT(*) as count'],
      );

      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint("❌ Error getting total events count: $e");
      return 0;
    }
  }

  // Check if monitoring is active
  Future<bool> isMonitoringActive() async {
    try {
      if (_isMonitoring) return true;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('geofence_monitoring_active') ?? false;
    } catch (e) {
      debugPrint("❌ Error checking monitoring status: $e");
      return false;
    }
  }

  // Get current monitored employee
  Future<String?> getCurrentMonitoredEmployee() async {
    try {
      if (_currentEmployeeId != null) return _currentEmployeeId;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('monitored_employee_id');
    } catch (e) {
      debugPrint("❌ Error getting monitored employee: $e");
      return null;
    }
  }

  // Get monitoring status with detailed info
  Map<String, dynamic> getMonitoringStatus() {
    return {
      'isActive': _isMonitoring,
      'employeeId': _currentEmployeeId,
      'employeeName': _currentEmployeeName,
      'intervalMinutes': _currentCheckInterval.inMinutes,
      'intervalDescription': _getIntervalDescription(),
      'isHighFrequency': _isHighFrequencyMode,
      'lastCheck': _lastLocationCheck?.toIso8601String(),
      'lastSync': _lastSyncAttempt?.toIso8601String(),
      'wasInsideGeofence': _wasInsideGeofence,
      'hasPosition': _lastKnownPosition != null,
      'currentPosition': _lastKnownPosition != null ? {
        'latitude': _lastKnownPosition!.latitude,
        'longitude': _lastKnownPosition!.longitude,
        'accuracy': _lastKnownPosition!.accuracy,
      } : null,
    };
  }

  // Force immediate location check (for testing)
  Future<void> forceLocationCheck() async {
    if (!_isMonitoring) {
      debugPrint("⚠️ Cannot force location check - monitoring not active");
      return;
    }

    debugPrint("🚀 Force location check initiated");
    await _performLocationCheck();
  }

  // Force immediate sync (for testing)
  Future<void> forceSync() async {
    debugPrint("🚀 Force sync initiated");
    await _syncPendingEvents();
  }

  // Clean up old events (optional maintenance)
  Future<void> cleanupOldEvents({int keepDays = 30}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));

      final deletedCount = await db.delete(
        'geofence_exit_events',
        where: 'created_at < ? AND is_synced = ?',
        whereArgs: [cutoffDate.toIso8601String(), 1],
      );

      debugPrint("🧹 Cleaned up $deletedCount old events (older than $keepDays days)");

    } catch (e) {
      debugPrint("❌ Error cleaning up old events: $e");
    }
  }

  // Get monitoring statistics
  Future<Map<String, dynamic>> getMonitoringStatistics({int days = 7}) async {
    try {
      final db = await _dbHelper.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final totalEvents = await db.query(
        'geofence_exit_events',
        columns: ['COUNT(*) as count'],
        where: 'created_at >= ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      final syncedEvents = await db.query(
        'geofence_exit_events',
        columns: ['COUNT(*) as count'],
        where: 'created_at >= ? AND is_synced = ?',
        whereArgs: [cutoffDate.toIso8601String(), 1],
      );

      final activeEvents = await db.query(
        'geofence_exit_events',
        columns: ['COUNT(*) as count'],
        where: 'status IN (?, ?)',
        whereArgs: ['active', 'grace_period'],
      );

      return {
        'periodDays': days,
        'totalEvents': (totalEvents.first['count'] as int?) ?? 0,
        'syncedEvents': (syncedEvents.first['count'] as int?) ?? 0,
        'activeEvents': (activeEvents.first['count'] as int?) ?? 0,
        'isMonitoring': _isMonitoring,
        'lastCheck': _lastLocationCheck?.toIso8601String(),
        'intervalMinutes': _currentCheckInterval.inMinutes,
      };

    } catch (e) {
      debugPrint("❌ Error getting monitoring statistics: $e");
      return {
        'error': e.toString(),
        'isMonitoring': _isMonitoring,
      };
    }
  }

  // Dispose resources
  void dispose() {
    debugPrint("🔚 Disposing geofence monitoring service");
    _monitoringTimer?.cancel();
    _syncTimer?.cancel();
  }

  // Debug method to get all events for an employee
  Future<List<Map<String, dynamic>>> debugGetAllEvents(String employeeId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'geofence_exit_events',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint("❌ Error in debug get all events: $e");
      return [];
    }
  }

  // Debug method to clear all events for testing
  Future<void> debugClearAllEvents() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('geofence_exit_events');
      debugPrint("🧹 All geofence events cleared for debugging");
    } catch (e) {
      debugPrint("❌ Error clearing debug events: $e");
    }
  }
}