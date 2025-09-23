// lib/dashboard/dashboard_view.dart
import 'dart:convert';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geodesy/geodesy.dart';
import 'dart:io' show Platform;
import 'dart:async' show unawaited;


import 'package:face_auth/model/location_model.dart';
import 'package:face_auth/services/geofence_exit_monitoring_service.dart';

import 'package:flutter/material.dart';
import 'package:face_auth/model/local_attendance_model.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/overtime_approver_service.dart';
import 'package:face_auth/authenticate_face/authentication_success_screen.dart';
import 'package:face_auth/services/work_schedule_service.dart';
// ✅ FIXED: Added missing import
import 'package:face_auth/model/local_attendance_model.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:face_auth/services/overtime_approver_service.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:face_auth/dashboard/user_profile_page.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/utils/geofence_util.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:face_auth/overtime/create_overtime_view.dart';
import 'package:face_auth/overtime/pending_overtime_view.dart';
import 'package:face_auth/utils/overtime_setup_utility.dart';
import 'package:face_auth/repositories/overtime_repository.dart';
import 'package:face_auth/dashboard/my_attendance_view.dart';
import 'package:geodesy/geodesy.dart' as geo;
import 'dart:math';
import 'package:face_auth/debug/debug_data_screen.dart';
import 'package:flutter/foundation.dart';

import 'package:geodesy/geodesy.dart' as geodesy_pkg;
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:face_auth/model/location_model.dart';
import 'package:face_auth/model/overtime_request_model.dart';
import 'package:face_auth/dashboard/team_management_view.dart';
import 'package:face_auth/dashboard/checkout_handler.dart';
import 'package:face_auth/checkout_request/manager_pending_requests_view.dart';
import 'package:face_auth/checkout_request/request_history_view.dart';
import 'package:face_auth/repositories/check_out_request_repository.dart';
import 'package:face_auth/services/notification_service.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/common/widgets/connectivity_banner.dart';
import 'package:face_auth/repositories/attendance_repository.dart';
import 'package:face_auth/repositories/location_repository.dart';
import 'package:face_auth/services/sync_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/test/offline_test_view.dart';
import 'package:face_auth/dashboard/check_in_out_handler.dart';
import 'package:face_auth/services/fcm_token_service.dart';
import 'package:face_auth/utils/enhanced_geofence_util.dart';
import 'package:face_auth/model/polygon_location_model.dart';
import 'package:face_auth/repositories/polygon_location_repository.dart';



import 'package:face_auth/overtime/employee_list_management_view.dart';
import 'package:face_auth/leave/apply_leave_view.dart';
import 'package:face_auth/leave/leave_history_view.dart';
import 'package:face_auth/leave/manager_leave_approval_view.dart';
import 'package:face_auth/services/leave_application_service.dart';
import 'package:face_auth/repositories/leave_application_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face_auth/services/firebase_auth_service.dart';
import 'package:face_auth/services/secure_face_storage_service.dart';


class DashboardView extends StatefulWidget {
  final String employeeId;

  const DashboardView({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<DashboardView> createState() => _DashboardViewState();
}


class _DashboardViewState extends State<DashboardView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  // Animation Controllers - Optimized
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _offsetAnimation;


  late GeofenceExitMonitoringService _geofenceExitService;
  bool _isGeofenceMonitoringActive = false;
  String _monitoringStatus = "Inactive";
  List<GeofenceExitEvent> _recentExitEvents = [];

  bool _isShowingExitWarning = false;
  String? _currentExitEventId;
  Timer? _exitWarningTimer;


  bool _isProcessingCheckInOut = false;




  // Core State Variables
  bool _isLoading = true;
  bool _isDarkMode = false;
  Map<String, dynamic>? _userData;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;

  // Time and Date State
  String _formattedDate = '';
  String _currentTime = '';
  String _greetingMessage = '';


  bool _isOvertimeApprover = false;
  int _pendingOvertimeRequests = 0;
  bool _isLoadingOvertimeApprovals = false;

  //////////////////////////////////////
  Map<String, dynamic>? _nextSaturdayInfo;
  Map<String, dynamic>? _todaySaturdayStatus;
  bool _isLoadingSaturdayInfo = false;

  // Activity and Location State

  DateTime? _lastLocationCheck;
  Position? _cachedPosition;
  bool _isLocationCacheValid = false;
  static const Duration _locationCacheTimeout = Duration(minutes: 2);


  List<OvertimeRequest> _activeOvertimeAssignments = [];
  List<OvertimeRequest> _todayOvertimeSchedule = [];
  bool _isLoadingOvertime = false;
  bool _hasActiveOvertime = false;


  List<Map<String, dynamic>> _todaysActivity = [];
  LocationModel? _nearestLocation;
  List<LocationModel> _availableLocations = [];
  bool _isLocationCheckInProgress = false;


  // Manager and Approval State
  bool _isLineManager = false;
  String? _lineManagerDocumentId;
  Map<String, dynamic>? _lineManagerData;
  int _pendingApprovalRequests = 0;

  int _pendingLeaveApprovals = 0;
  bool _isLoadingLeaveData = false;
  late LeaveApplicationService _leaveService;

  // Work Schedule State
  WorkSchedule? _workSchedule;
  bool _isLoadingSchedule = false;
  Timer? _checkOutReminderTimer;
  Timer? _timeUpdateTimer;
  Timer? _periodicRefreshTimer;
  bool _hasShownCheckOutReminder = false;
  String? _currentTimingMessage;
  Color? _timingMessageColor;

  // Activity Tracking State
  bool _hasTodaysAttendance = false;
  bool _hasTodaysLeaveApplication = false;
  bool _isAbsentToday = false;

  // Geofencing State
  bool _isCheckingLocation = false;

  bool _isWithinGeofence = false;
  double? _distanceToOffice;

  // Authentication State
  bool _isAuthenticating = false;


  Timer? _locationUpdateTimer;
  bool _isLocationRefreshing = false;
  DateTime? _lastSuccessfulLocationCheck;
  static const Duration _locationRefreshInterval = Duration(minutes: 2);
  static const Duration _backgroundLocationInterval = Duration(minutes: 5);



  // Offline Support State
  late ConnectivityService _connectivityService;
  late AttendanceRepository _attendanceRepository;
  late LocationRepository _locationRepository;
  late SyncService _syncService;
  bool _needsSync = false;
  late AppLifecycleObserver _lifecycleObserver;

  final Map<String, DateTime> _lastRefreshTimes = {};
  final Map<String, dynamic> _dataCache = {};
  bool _isRefreshing = false;
  Timer? _smartRefreshTimer;

  static const Map<String, int> _refreshIntervals = {
    'critical': 1,      // Attendance status, check-in state
    'important': 5,     // Location, today's activity
    'normal': 10,       // Overtime, work schedule
    'background': 30,   // User data, notifications
  };

  // Performance Optimization
  @override
  bool get wantKeepAlive => true;



  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeServices();

    _initializeSmartRefresh();
    _loadCachedOvertimeApproverStatus();

    // Initialize geofence service but don't check previous state yet
    _initializeGeofenceExitServiceOnly();

    // Start data initialization with proper attendance state handling
    _initializeDataWithProperState();

    _setupTimers();
  }



  void _initializeDataWithProperState() async {
    try {
      debugPrint("🚀 Starting data initialization with proper state handling...");

      // 1. First load user data
      await _fetchUserData();

      // 2. Then initialize attendance state properly (this is the key fix)
      await _initializeAttendanceState();

      // 3. After attendance status is confirmed, load other data
      await _fetchTodaysActivity();
      await _smartLocationInitialization();
      await _checkGeofenceStatus();
      await _fetchOvertimeAssignments();
      _updateDateTime();
      await _fetchWorkSchedule();
      _setupTimingChecks();

      // 4. Finally setup geofence monitoring based on confirmed state
      _setupGeofenceMonitoringAfterData();

      debugPrint("✅ Data initialization with proper state handling completed");
    } catch (e) {
      debugPrint("❌ Error in data initialization: $e");
    }
  }


  // Add this method to handle offline state restoration



// Also modify your connectivity change handler
  void _handleConnectivityChange(ConnectionStatus status) {
    debugPrint("Connectivity status changed: $status");

    if (status == ConnectionStatus.offline) {
      // Handle going offline
      _handleOfflineStateRestoration();
    } else if (status == ConnectionStatus.online) {
      // Handle coming back online
      if (_needsSync) {
        _syncService.syncData().then((_) {
          _fetchUserData();
          if (_isLineManager) {
            _loadPendingApprovalRequests();
            _loadPendingLeaveApprovals();
          }
          // Refresh attendance state after sync
          _fetchAttendanceStatus();
          _fetchTodaysActivity();
          if (mounted) {
            setState(() {
              _needsSync = false;
            });
          }
        });
      } else {
        // Just refresh attendance state to ensure consistency
        _fetchAttendanceStatus();
      }
    }
  }

  void _setupSmartTimers() {
    // ✅ SINGLE SMART TIMER instead of multiple timers
    _smartRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _performSmartRefresh();
    });

    debugPrint("✅ Smart timer system activated");
  }

  void _initializeSmartRefresh() {
    // Initialize refresh tracking
    final now = DateTime.now();
    _lastRefreshTimes.clear();
    _dataCache.clear();

    debugPrint("🔄 Smart refresh system initialized");
  }


  Future<void> _performSmartRefresh() async {
    if (_isRefreshing || _isProcessingCheckInOut) {
      debugPrint("⚡ Skipping refresh - operation in progress");
      return;
    }

    final now = DateTime.now();
    List<String> toRefresh = [];

    // Check what needs refreshing based on intervals
    _refreshIntervals.forEach((priority, intervalMinutes) {
      final lastRefresh = _lastRefreshTimes[priority];

      if (lastRefresh == null ||
          now.difference(lastRefresh).inMinutes >= intervalMinutes) {
        toRefresh.add(priority);
      }
    });

    if (toRefresh.isNotEmpty) {
      debugPrint("🔄 Smart refresh triggered for: ${toRefresh.join(', ')}");
      await _executeSmartRefresh(toRefresh);
    }
  }

  Future<void> _executeSmartRefresh(List<String> priorities) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    final now = DateTime.now();

    try {
      // ✅ CRITICAL DATA (Every 1 minute)
      if (priorities.contains('critical')) {
        await _refreshCriticalData();
        _lastRefreshTimes['critical'] = now;
      }

      // ✅ IMPORTANT DATA (Every 5 minutes)
      if (priorities.contains('important')) {
        await _refreshImportantData();
        _lastRefreshTimes['important'] = now;
      }

      // ✅ NORMAL DATA (Every 10 minutes)
      if (priorities.contains('normal')) {
        await _refreshNormalData();
        _lastRefreshTimes['normal'] = now;
      }

      // ✅ BACKGROUND DATA (Every 30 minutes)
      if (priorities.contains('background')) {
        await _refreshBackgroundData();
        _lastRefreshTimes['background'] = now;
      }

    } catch (e) {
      debugPrint("❌ Error in smart refresh: $e");
    } finally {
      _isRefreshing = false;
    }
  }

  // ✅ CRITICAL: Attendance status, check-in state, monitoring
  Future<void> _refreshCriticalData() async {
    debugPrint("🔥 Refreshing CRITICAL data...");

    try {
      // Only refresh attendance if there's potential for change
      if (_connectivityService.currentStatus == ConnectionStatus.online) {

        // Smart attendance check - only if needed
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        String cacheKey = 'attendance_$today';

        if (_shouldRefreshData(cacheKey, const Duration(minutes: 2))) {
          await _fetchAttendanceStatusForSync();
          _dataCache[cacheKey] = DateTime.now();
        }
      }

      // Update time display
      _updateDateTime();

      // Check geofence monitoring state
      if (_isCheckedIn) {
        await _checkPreviousMonitoringState();
      }

    } catch (e) {
      debugPrint("❌ Error refreshing critical data: $e");
    }
  }

  // ✅ IMPORTANT: Location, today's activity, timing messages
  Future<void> _refreshImportantData() async {
    debugPrint("📍 Refreshing IMPORTANT data...");

    try {
      // Smart location refresh - only if user moved significantly
      if (_shouldRefreshLocation()) {
        await _autoRefreshLocation();
      }

      // Today's activity - only if state changed
      String cacheKey = 'activity_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      if (_shouldRefreshData(cacheKey, const Duration(minutes: 5))) {
        await _fetchTodaysActivity();
        _dataCache[cacheKey] = DateTime.now();
      }

      // Update timing messages
      _updateCurrentTimingMessage();

    } catch (e) {
      debugPrint("❌ Error refreshing important data: $e");
    }
  }

  // ✅ NORMAL: Overtime, work schedule, notifications
  Future<void> _refreshNormalData() async {
    debugPrint("⏰ Refreshing NORMAL data...");

    if (_connectivityService.currentStatus != ConnectionStatus.online) {
      debugPrint("📱 Offline - skipping normal data refresh");
      return;
    }

    try {
      // Overtime assignments - only for users with overtime access
      if (_userData?['hasOvertimeAccess'] == true) {
        String cacheKey = 'overtime_${widget.employeeId}';
        if (_shouldRefreshData(cacheKey, const Duration(minutes: 10))) {
          await _fetchOvertimeAssignments();
          _dataCache[cacheKey] = DateTime.now();
        }
      }

      // Manager-specific data
      if (_isLineManager) {
        String cacheKey = 'manager_requests_${widget.employeeId}';
        if (_shouldRefreshData(cacheKey, const Duration(minutes: 10))) {
          await _loadPendingApprovalRequests();
          await _loadPendingLeaveApprovals();
          _dataCache[cacheKey] = DateTime.now();
        }
      }

      // Overtime approver data
      if (_isOvertimeApprover) {
        String cacheKey = 'overtime_approvals_${widget.employeeId}';
        if (_shouldRefreshData(cacheKey, const Duration(minutes: 10))) {
          await _loadPendingOvertimeApprovals();
          _dataCache[cacheKey] = DateTime.now();
        }
      }

    } catch (e) {
      debugPrint("❌ Error refreshing normal data: $e");
    }
  }


  Future<void> _refreshBackgroundData() async {
    debugPrint("🔄 Refreshing BACKGROUND data...");

    if (_connectivityService.currentStatus != ConnectionStatus.online) {
      debugPrint("📱 Offline - skipping background data refresh");
      return;
    }

    try {
      // Work schedule - rarely changes
      String cacheKey = 'work_schedule_${widget.employeeId}';
      if (_shouldRefreshData(cacheKey, const Duration(hours: 1))) {
        await _fetchWorkSchedule();
        _dataCache[cacheKey] = DateTime.now();
      }

      // User data - only if older than 1 hour
      String userCacheKey = 'user_data_${widget.employeeId}';
      if (_shouldRefreshData(userCacheKey, const Duration(hours: 1))) {
        // Light user data refresh - don't reload everything
        await _refreshUserDataLight();
        _dataCache[userCacheKey] = DateTime.now();
      }

      // Sync pending data if needed
      final pendingRecords = await _attendanceRepository.getPendingRecords();
      if (mounted && pendingRecords.isNotEmpty != _needsSync) {
        setState(() {
          _needsSync = pendingRecords.isNotEmpty;
        });
      }

    } catch (e) {
      debugPrint("❌ Error refreshing background data: $e");
    }
  }

  // ✅ SMART HELPERS
  bool _shouldRefreshData(String cacheKey, Duration maxAge) {
    final lastRefresh = _dataCache[cacheKey];
    if (lastRefresh == null) return true;

    if (lastRefresh is DateTime) {
      return DateTime.now().difference(lastRefresh) > maxAge;
    }

    return true;
  }

  bool _shouldRefreshLocation() {
    // Only refresh location if:
    // 1. No recent successful check (>2 minutes)
    // 2. User is checking in/out
    // 3. Manual refresh requested

    if (_lastSuccessfulLocationCheck == null) return true;

    Duration timeSinceLastCheck = DateTime.now().difference(_lastSuccessfulLocationCheck!);
    return timeSinceLastCheck > const Duration(minutes: 2);
  }


  Future<void> _refreshUserDataLight() async {
    try {
      debugPrint("🔄 Light user data refresh...");

      // Only check critical user settings that might change
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (employeeDoc.exists && mounted) {
        Map<String, dynamic> freshData = employeeDoc.data() as Map<String, dynamic>;

        // Only update specific fields that matter for dashboard
        Map<String, dynamic> currentData = Map<String, dynamic>.from(_userData ?? {});

        // Update only critical fields
        List<String> criticalFields = [
          'hasOvertimeAccess',
          'hasOvertimeApprovalAccess',
          'eligibleForRestTiming',
          'restTimingStartDate',
          'restTimingEndDate',
          'restTimingStartTime',
          'restTimingEndTime'
        ];

        bool hasChanges = false;
        for (String field in criticalFields) {
          if (currentData[field] != freshData[field]) {
            currentData[field] = freshData[field];
            hasChanges = true;
            debugPrint("🔄 Updated field: $field = ${freshData[field]}");
          }
        }

        if (hasChanges) {
          setState(() {
            _userData = currentData;
          });

          await _saveUserDataLocally(currentData);
          debugPrint("✅ Light user data refresh completed with changes");
        } else {
          debugPrint("✅ Light user data refresh - no changes");
        }
      }

    } catch (e) {
      debugPrint("❌ Error in light user data refresh: $e");
    }
  }

  // ✅ FORCE REFRESH (for manual triggers)
  Future<void> _forceRefreshAll() async {
    debugPrint("🔄 FORCE REFRESH ALL triggered");

    if (_isRefreshing) {
      debugPrint("⚡ Already refreshing - ignoring force refresh");
      return;
    }

    // Clear all cache
    _dataCache.clear();
    _lastRefreshTimes.clear();

    // Force refresh all priorities
    await _executeSmartRefresh(['critical', 'important', 'normal', 'background']);

    debugPrint("✅ Force refresh completed");
  }

  void _setupGeofenceExitListener() {
    final geofenceService = getIt<GeofenceExitMonitoringService>();

    // Listen for exit events in the service
    _listenForLocationChanges();
  }

  void _listenForLocationChanges() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted || !_isGeofenceMonitoringActive) {
        timer.cancel();
        return;
      }

      _checkForExitEvents();
    });
  }

  void _initializeGeofenceExitServiceOnly() {
    try {
      _geofenceExitService = getIt<GeofenceExitMonitoringService>();
      _geofenceExitService.initializeDatabase();
      debugPrint("✅ Geofence service initialized (state check deferred)");
    } catch (e) {
      debugPrint("❌ Error initializing geofence service: $e");
    }
  }
  void _setupGeofenceMonitoringAfterData() {
    // Wait for attendance status to be loaded first
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (mounted) {
        debugPrint("🔄 Setting up geofence monitoring after data load...");
        await _checkPreviousMonitoringState();
        _setupGeofenceExitListener();
      }
    });
  }




  Future<void> _checkForExitEvents() async {
    try {
      final geofenceService = getIt<GeofenceExitMonitoringService>();

      final recentEvents = await geofenceService.getExitHistory(widget.employeeId, limit: 1);

      if (recentEvents.isNotEmpty) {
        final latestEvent = recentEvents.first;

        if (latestEvent.status == 'grace_period' &&
            latestEvent.returnTime == null &&
            _currentExitEventId != latestEvent.id) {

          _currentExitEventId = latestEvent.id;
          _showExitWarningDialog(latestEvent);
        }
      }
    } catch (e) {
      debugPrint("Error checking exit events: $e");
    }
  }


  Widget _buildQuickExitReasonChip(String reason, IconData icon, String eventId) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        reason,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: Colors.blue.shade600,
      onPressed: () async {
        Navigator.pop(context);
        _isShowingExitWarning = false;

        final geofenceService = getIt<GeofenceExitMonitoringService>();
        await geofenceService.recordExitReason(eventId, reason.toLowerCase().replaceAll(' ', '_'));

        CustomSnackBar.successSnackBar("Exit reason recorded: $reason");

        await _loadRecentExitEvents();
      },
    );
  }

  // ✅ NEW: Show real-time exit warning
  void _showExitWarningDialog(GeofenceExitEvent exitEvent) {
    if (_isShowingExitWarning) return;

    _isShowingExitWarning = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.red.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.location_off, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Work Area Exit Detected!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Exit Time:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a - MMM dd').format(exitEvent.exitTime),
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              "You have left the designated work area. Please provide a reason for your exit.",
              style: TextStyle(
                fontSize: 14,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickExitReasonChip("Lunch Break", Icons.restaurant, exitEvent.id),
                _buildQuickExitReasonChip("Client Meeting", Icons.business, exitEvent.id),
                _buildQuickExitReasonChip("Personal Emergency", Icons.emergency, exitEvent.id),
                _buildQuickExitReasonChip("Other", Icons.more_horiz, exitEvent.id),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isShowingExitWarning = false;
              _scheduleExitReminder(exitEvent.id);
            },
            child: Text(
              "Remind Me Later",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Get next check time estimate
  String _getNextCheckTime() {
    try {
      final geofenceService = getIt<GeofenceExitMonitoringService>();
      final status = geofenceService.getMonitoringStatus();

      if (status['lastCheck'] != null) {
        final lastCheck = DateTime.parse(status['lastCheck']);
        final intervalMinutes = status['intervalMinutes'] ?? 120; // Default 2 hours
        final nextCheck = lastCheck.add(Duration(minutes: intervalMinutes));
        final timeUntilNext = nextCheck.difference(DateTime.now());

        if (timeUntilNext.isNegative) {
          return "Now";
        } else if (timeUntilNext.inHours > 0) {
          return "${timeUntilNext.inHours}h ${timeUntilNext.inMinutes % 60}m";
        } else {
          return "${timeUntilNext.inMinutes}m";
        }
      }

      return "Soon";
    } catch (e) {
      return "Unknown";
    }
  }

  void _initializeControllers() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _initializeServices() {
    _loadDarkModePreference();
    _initializeLeaveService();
    _initializeNotifications();


    final notificationService = getIt<NotificationService>();
    notificationService.notificationStream.listen(_handleNotification);

    _connectivityService = getIt<ConnectivityService>();
    _attendanceRepository = getIt<AttendanceRepository>();
    _locationRepository = getIt<LocationRepository>();
    _syncService = getIt<SyncService>();



    _connectivityService.connectionStatusStream.listen(_handleConnectivityChange);

    _lifecycleObserver = AppLifecycleObserver(
      onResume: () async {
        debugPrint("App resumed - Refreshing dashboard with force sync");
        await _forceAttendanceSync();
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  void _initializeData() {
    _fetchUserData();

    // CRITICAL: Fetch attendance status BEFORE any geofence setup
    _fetchAttendanceStatus().then((_) {
      // Only after attendance status is confirmed, load other data
      _fetchTodaysActivity();
      _smartLocationInitialization();
      _checkGeofenceStatus();
      _fetchOvertimeAssignments();
      _updateDateTime();
      _fetchWorkSchedule();
      _setupTimingChecks();
    });
  }

  void _setupTimers() {
    // Time updates for real-time sync
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateDateTime();
      }
    });

    // Dashboard refresh every 10 minutes - but only if not processing check-in/out
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted && !_isProcessingCheckInOut) {
        debugPrint("⏰ Periodic refresh triggered");
        unawaited(_refreshDashboard());
      } else if (!mounted) {
        timer.cancel();
      }
    });

    // Attendance sync every 5 minutes - but avoid during operations
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted &&
          _connectivityService.currentStatus == ConnectionStatus.online &&
          !_isProcessingCheckInOut) {
        debugPrint("🔄 Background attendance sync");
        unawaited(_fetchAttendanceStatusForSync()); // Use sync-only version
      } else if (!mounted) {
        timer.cancel();
      }
    });

    // Location refresh - respect ongoing operations
    _locationUpdateTimer = Timer.periodic(_locationRefreshInterval, (timer) {
      if (mounted && !_isProcessingCheckInOut) {
        debugPrint("📍 Auto location refresh triggered");
        unawaited(_autoRefreshLocation());
      } else if (!mounted) {
        timer.cancel();
      }
    });

    // Background location sync
    Timer.periodic(_backgroundLocationInterval, (timer) {
      if (mounted && !_isProcessingCheckInOut) {
        debugPrint("📍 Background location sync");
        unawaited(_backgroundLocationSync());
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  Future<void> _loadCachedOvertimeApproverStatus() async {
    try {
      bool? cachedStatus = await _getOvertimeApproverStatusLocally();
      if (cachedStatus != null && mounted) {
        setState(() {
          _isOvertimeApprover = cachedStatus;
        });
        debugPrint("📱 Loaded cached overtime approver status: $cachedStatus");
      }
    } catch (e) {
      debugPrint("Error loading cached overtime approver status: $e");
    }
  }

  Future<void> _smartLocationInitialization() async {
    try {
      debugPrint("🎯 Smart location initialization starting...");

      // First, load location data in background
      unawaited(EnhancedGeofenceUtil.refreshLocationData());

      // Then check current location
      await _autoRefreshLocation();

      debugPrint("✅ Smart location initialization completed");
    } catch (e) {
      debugPrint("❌ Error in smart location initialization: $e");
      // Fallback to manual check
      unawaited(_checkGeofenceStatus());
    }
  }


  Future<void> _autoRefreshLocation() async {
    if (_isLocationRefreshing || !mounted) return;

    try {
      _isLocationRefreshing = true;

      // Check if we need to refresh (avoid too frequent updates)
      if (_lastSuccessfulLocationCheck != null) {
        Duration timeSinceLastCheck = DateTime.now().difference(_lastSuccessfulLocationCheck!);
        if (timeSinceLastCheck < const Duration(minutes: 1)) {
          debugPrint("⚡ Skipping location refresh - too recent");
          return;
        }
      }

      debugPrint("📍 Auto-refreshing location...");

      // Use enhanced geofence with employee exemption checking
      Map<String, dynamic> status = await EnhancedGeofenceUtil.checkGeofenceStatusForEmployee(
        context,
        widget.employeeId,
      );

      if (mounted) {
        bool withinGeofence = status['withinGeofence'] as bool;
        double? distance = status['distance'] as double?;
        String locationType = status['locationType'] as String? ?? 'unknown';
        bool isExempted = status['isExempted'] ?? false;

        // Handle different location types
        if (locationType == 'polygon') {
          final polygonLocation = status['location'] as PolygonLocationModel?;
          if (polygonLocation != null) {
            setState(() {
              _isWithinGeofence = withinGeofence;
              _distanceToOffice = distance;
              _nearestLocation = LocationModel(
                id: polygonLocation.id,
                name: polygonLocation.name,
                address: polygonLocation.description,
                latitude: polygonLocation.centerLatitude,
                longitude: polygonLocation.centerLongitude,
                radius: 0,
                isActive: polygonLocation.isActive,
              );
            });
          }
        } else if (locationType == 'exemption') {
          final exemptLocation = status['location'] as LocationModel?;
          setState(() {
            _isWithinGeofence = true; // Always true for exempt employees
            _distanceToOffice = 0.0;
            _nearestLocation = exemptLocation;
          });
          debugPrint("🆓 Employee ${widget.employeeId} is location exempt");
        } else {
          final circularLocation = status['location'] as LocationModel?;
          setState(() {
            _isWithinGeofence = withinGeofence;
            _nearestLocation = circularLocation;
            _distanceToOffice = distance;
          });
        }

        _lastSuccessfulLocationCheck = DateTime.now();

        // Debug location status
        String locationStatus = withinGeofence ? 'INSIDE' : 'OUTSIDE';
        String exemptionStatus = isExempted ? ' (EXEMPT)' : '';
        debugPrint("📍 Auto location update: $locationStatus${exemptionStatus}");

        if (_nearestLocation != null) {
          debugPrint("   Location: ${_nearestLocation!.name}");
          if (distance != null) {
            debugPrint("   Distance: ${distance.toStringAsFixed(0)}m");
          }
        }
      }

    } catch (e) {
      debugPrint("❌ Error in auto location refresh: $e");
      // Don't show error to user for background updates
    } finally {
      _isLocationRefreshing = false;
    }
  }


  Future<void> _backgroundLocationSync() async {
    if (!mounted) return;

    try {
      // Clear location cache to ensure fresh data
      EnhancedGeofenceUtil.clearLocationCache();

      // Refresh location data from server
      await EnhancedGeofenceUtil.refreshLocationData();

      debugPrint("🔄 Background location data synced");
    } catch (e) {
      debugPrint("❌ Background location sync error: $e");
    }
  }



  void _initializeGeofenceExitMonitoring() {
    try {
      _geofenceExitService = getIt<GeofenceExitMonitoringService>();
      debugPrint("✅ Geofence exit monitoring service initialized");

      // Initialize the database table
      _geofenceExitService.initializeDatabase();

      // 🔥 FIXED: Check previous state but with proper validation
      _checkPreviousMonitoringState();

    } catch (e) {
      debugPrint("❌ Error initializing geofence exit monitoring: $e");
    }
  }

  // ✅ NEW: Check previous monitoring state
  Future<void> _checkPreviousMonitoringState() async {
    try {
      bool wasActive = await _geofenceExitService.isMonitoringActive();
      String? currentEmployee = await _geofenceExitService.getCurrentMonitoredEmployee();

      debugPrint("🔍 Previous monitoring state check:");
      debugPrint("  - Was active: $wasActive");
      debugPrint("  - Current employee: $currentEmployee");
      debugPrint("  - Dashboard employee: ${widget.employeeId}");
      debugPrint("  - Dashboard checked in: $_isCheckedIn");

      // 🔥 CRITICAL FIX: Only restore monitoring if BOTH conditions are true:
      // 1. Monitoring was previously active for this employee
      // 2. User is currently checked in (according to dashboard state)
      bool shouldBeActive = wasActive &&
          currentEmployee == widget.employeeId &&
          _isCheckedIn; // ← This is the key fix

      if (mounted) {
        setState(() {
          _isGeofenceMonitoringActive = shouldBeActive;
          _monitoringStatus = shouldBeActive ? "Active" : "Inactive";
        });
      }

      if (wasActive && currentEmployee == widget.employeeId && !_isCheckedIn) {
        // Previous monitoring was active but user is not checked in now
        // This means they were checked out without properly stopping monitoring
        debugPrint("🔧 Cleaning up orphaned monitoring session...");
        await _geofenceExitService.stopMonitoring();

        if (mounted) {
          setState(() {
            _isGeofenceMonitoringActive = false;
            _monitoringStatus = "Inactive";
          });
        }
      }

      // Load recent exit events regardless
      await _loadRecentExitEvents();

      debugPrint("✅ Monitoring state check completed - Active: $shouldBeActive");

    } catch (e) {
      debugPrint("❌ Error checking previous monitoring state: $e");
    }
  }

  // ✅ NEW: Load recent exit events
  Future<void> _loadRecentExitEvents() async {
    try {
      List<GeofenceExitEvent> events = await _geofenceExitService.getExitHistory(
        widget.employeeId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _recentExitEvents = events;
        });
      }

    } catch (e) {
      debugPrint("Error loading recent exit events: $e");
    }
  }











  @override
  void dispose() {
    _smartRefreshTimer?.cancel();
    _exitWarningTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _geofenceExitService.stopMonitoring();
    _timeUpdateTimer?.cancel();
    _periodicRefreshTimer?.cancel();
    _checkOutReminderTimer?.cancel();
    _locationUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _syncService.dispose();
    super.dispose();
  }

  // Responsive Design Helpers - Optimized
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isTablet => screenWidth > 600;
  bool get isSmallScreen => screenWidth < 360;
  bool get isLargeScreen => screenWidth > 800;

  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
    horizontal: isLargeScreen ? 32.0 : (isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0)),
    vertical: isLargeScreen ? 24.0 : (isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0)),
  );

  double get responsiveFontSize {
    if (isLargeScreen) return 1.3;
    if (isTablet) return 1.2;
    if (isSmallScreen) return 0.9;
    return 1.0;
  }

  double get cardBorderRadius => isTablet ? 20.0 : 16.0;
  double get containerSpacing => isTablet ? 20.0 : 16.0;

  // Time and Date Methods
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Good Morning";
    if (hour >= 12 && hour < 17) return "Good Afternoon";
    if (hour >= 17 && hour < 21) return "Good Evening";
    return "Good Night";
  }

  void _updateDateTime() {
    if (mounted) {
      final now = DateTime.now();
      final newFormattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
      final newCurrentTime = DateFormat('h:mm a').format(now);
      final newGreeting = _getTimeBasedGreeting();

      // Only update if changed to prevent unnecessary rebuilds
      if (_formattedDate != newFormattedDate ||
          _currentTime != newCurrentTime ||
          _greetingMessage != newGreeting) {
        setState(() {
          _formattedDate = newFormattedDate;
          _currentTime = newCurrentTime;
          _greetingMessage = newGreeting;
        });
      }
    }
  }









  // Work Schedule Methods - Enhanced
  DateTime _parseTimeForToday(String timeString) {
    DateTime today = DateTime.now();
    try {
      if (timeString.contains('AM') || timeString.contains('PM')) {
        DateFormat format = DateFormat('h:mm a');
        DateTime parsedTime = format.parse(timeString);
        return DateTime(today.year, today.month, today.day, parsedTime.hour, parsedTime.minute);
      }
      List<String> timeParts = timeString.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        return DateTime(today.year, today.month, today.day, hour, minute);
      }
      return today;
    } catch (e) {
      return today;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else {
      return "${duration.inMinutes}m";
    }
  }

  IconData _getTimingMessageIcon() {
    if (_currentTimingMessage == null) return Icons.schedule;
    if (_currentTimingMessage!.contains("Break Time")) return Icons.restaurant;
    if (_currentTimingMessage!.contains("Work starts")) return Icons.alarm;
    if (_currentTimingMessage!.contains("Work ends")) return Icons.timer;
    if (_currentTimingMessage!.contains("ended")) return Icons.check_circle;
    if (_currentTimingMessage!.contains("not checked in")) return Icons.warning;
    return Icons.schedule;
  }

  bool _shouldShowScheduleWarning() {
    if (_workSchedule == null) return false;
    DateTime now = DateTime.now();
    DateTime workStart = _parseTimeForToday(_workSchedule!.startTime);
    DateTime workEnd = _parseTimeForToday(_workSchedule!.endTime);

    if (now.isAfter(workStart) && now.isBefore(workEnd) && !_isCheckedIn) {
      return true;
    }
    if (_isCheckedIn && _checkInTime != null) {
      Duration lateDuration = _checkInTime!.difference(workStart);
      if (lateDuration.inMinutes > 15) {
        return true;
      }
    }
    return false;
  }

  String _getScheduleWarningMessage() {
    if (_workSchedule == null) return "";
    DateTime now = DateTime.now();
    DateTime workStart = _parseTimeForToday(_workSchedule!.startTime);
    DateTime workEnd = _parseTimeForToday(_workSchedule!.endTime);

    if (now.isAfter(workStart) && now.isBefore(workEnd) && !_isCheckedIn) {
      Duration lateBy = now.difference(workStart);
      return "You're ${lateBy.inMinutes} minutes late! Expected start: ${_workSchedule!.startTime}";
    }
    if (_isCheckedIn && _checkInTime != null) {
      Duration lateDuration = _checkInTime!.difference(workStart);
      if (lateDuration.inMinutes > 15) {
        return "Late check-in recorded: ${lateDuration.inMinutes} minutes after ${_workSchedule!.startTime}";
      }
    }
    return "";
  }





  Future<void> _checkOvertimeApproverStatus() async {
    try {
      // ✅ CRITICAL: Ensure user data is available first
      if (_userData == null) {
        debugPrint("⚠️ User data not available, skipping overtime approver check");
        if (mounted) {
          setState(() => _isOvertimeApprover = false);
        }
        return;
      }

      String? employeePin = _userData?['pin']?.toString() ?? widget.employeeId;

      debugPrint("=== CHECKING OVERTIME APPROVER STATUS ===");
      debugPrint("Current Employee ID: ${widget.employeeId}");
      debugPrint("Employee PIN: $employeePin");

      bool isApprover = false;

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Method 1: Check dedicated overtime_approvers collection
        try {
          QuerySnapshot approversSnapshot = await FirebaseFirestore.instance
              .collection('overtime_approvers')
              .where('approverId', isEqualTo: widget.employeeId)
              .where('isActive', isEqualTo: true)
              .get();

          if (approversSnapshot.docs.isNotEmpty) {
            isApprover = true;
            debugPrint("✅ Found in overtime_approvers collection");
          }
        } catch (e) {
          debugPrint("Error checking overtime_approvers: $e");
        }

        // Method 2: Check if employee has overtime approval access
        if (!isApprover && _userData != null) {
          bool hasApprovalAccess = _userData!['hasOvertimeApprovalAccess'] == true;

          if (hasApprovalAccess) {
            isApprover = true;
            debugPrint("✅ Found hasOvertimeApprovalAccess = true in user data");
          }
        }

        // Method 3: Check MasterSheet
        if (!isApprover) {
          try {
            String empId = employeePin != null && employeePin.isNotEmpty
                ? (employeePin.startsWith('EMP') ? employeePin : 'EMP$employeePin')
                : widget.employeeId;

            DocumentSnapshot masterDoc = await FirebaseFirestore.instance
                .collection('MasterSheet')
                .doc('Employee-Data')
                .collection('employees')
                .doc(empId)
                .get();

            if (masterDoc.exists) {
              Map<String, dynamic> data = masterDoc.data() as Map<String, dynamic>;
              if (data['hasOvertimeApprovalAccess'] == true) {
                isApprover = true;
                debugPrint("✅ Found hasOvertimeApprovalAccess in MasterSheet");
              }
            }
          } catch (e) {
            debugPrint("Error checking MasterSheet: $e");
          }
        }
      } else {
        // ✅ OFFLINE MODE: Check local user data
        if (_userData != null) {
          bool hasApprovalAccess = _userData!['hasOvertimeApprovalAccess'] == true;
          if (hasApprovalAccess) {
            isApprover = true;
            debugPrint("✅ Found offline hasOvertimeApprovalAccess = true");
          }
        }
      }

      // ✅ CRITICAL: Always update state, even if unchanged
      if (mounted) {
        setState(() {
          _isOvertimeApprover = isApprover;
        });
        debugPrint("🎯 OVERTIME APPROVER STATUS UPDATED: $isApprover");
        await _saveOvertimeApproverStatus(isApprover);
      }

      if (isApprover) {
        await _loadPendingOvertimeApprovals();
        // Subscribe to overtime approver notifications
        try {
          final notificationService = getIt<NotificationService>();
          await notificationService.subscribeToManagerTopic('overtime_approver_${widget.employeeId}');
          debugPrint("Subscribed to overtime approver notifications");
        } catch (e) {
          debugPrint("Error subscribing to overtime notifications: $e");
        }
      }

    } catch (e) {
      debugPrint("❌ ERROR checking overtime approver status: $e");
      if (mounted) {
        setState(() => _isOvertimeApprover = false);
      }
    }
  }


  Future<void> _saveOvertimeApproverStatus(bool isApprover) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('overtime_approver_${widget.employeeId}', isApprover);
      debugPrint("💾 Overtime approver status saved: $isApprover");
    } catch (e) {
      debugPrint('❌ Error saving overtime approver status: $e');
    }
  }

  Future<bool?> _getOvertimeApproverStatusLocally() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('overtime_approver_${widget.employeeId}');
    } catch (e) {
      debugPrint('❌ Error getting local overtime approver status: $e');
      return null;
    }
  }

// ✅ ADD this method after _loadPendingLeaveApprovals() method (around line 1100)

  Future<void> _loadPendingOvertimeApprovals() async {
    if (!_isOvertimeApprover) return;

    try {
      setState(() => _isLoadingOvertimeApprovals = true);

      debugPrint("=== LOADING PENDING OVERTIME APPROVALS (ENHANCED) ===");
      debugPrint("Dashboard Employee ID: ${widget.employeeId}");
      debugPrint("User Data PIN: ${_userData?['pin']}");

      // ✅ ENHANCED: Build comprehensive list of possible approver IDs
      Set<String> possibleApproverIds = {};

      // Add main employee ID
      possibleApproverIds.add(widget.employeeId);

      // Add PIN-based variations
      String? pin = _userData?['pin']?.toString();
      if (pin != null && pin.isNotEmpty) {
        possibleApproverIds.add(pin);
        possibleApproverIds.add('EMP$pin');

        // Handle padded PIN (like EMP3576 vs EMP03576)
        if (!pin.startsWith('EMP')) {
          int pinNumber = int.tryParse(pin) ?? 0;
          if (pinNumber > 0) {
            possibleApproverIds.add('EMP${pinNumber.toString().padLeft(4, '0')}');
            possibleApproverIds.add('EMP$pinNumber');
          }
        }
      }

      // Add variations of existing employee ID
      if (widget.employeeId.startsWith('EMP')) {
        String numPart = widget.employeeId.substring(3);
        possibleApproverIds.add(numPart);
        int num = int.tryParse(numPart) ?? 0;
        if (num > 0) {
          possibleApproverIds.add(num.toString());
          possibleApproverIds.add('EMP${num.toString().padLeft(4, '0')}');
        }
      } else {
        possibleApproverIds.add('EMP${widget.employeeId}');
      }

      debugPrint("🔍 Searching for pending requests with approver IDs: $possibleApproverIds");

      int totalPending = 0;

      // ✅ ENHANCED: Search for each possible ID
      for (String approverId in possibleApproverIds) {
        try {
          debugPrint("🔎 Checking approver ID: $approverId");

          QuerySnapshot pendingSnapshot = await FirebaseFirestore.instance
              .collection('overtime_requests')
              .where('status', isEqualTo: 'pending')
              .where('approverEmpId', isEqualTo: approverId)
              .get();

          int foundCount = pendingSnapshot.docs.length;
          totalPending += foundCount;

          if (foundCount > 0) {
            debugPrint("✅ Found $foundCount pending requests for approver ID: $approverId");

            // Log some details for debugging
            for (var doc in pendingSnapshot.docs.take(2)) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              debugPrint("  📋 Request: ${data['projectName']} by ${data['requesterName']}");
            }
          } else {
            debugPrint("  ❌ No requests found for approver ID: $approverId");
          }
        } catch (e) {
          debugPrint("❌ Error checking approver ID $approverId: $e");
        }
      }

      if (mounted) {
        setState(() {
          _pendingOvertimeRequests = totalPending;
          _isLoadingOvertimeApprovals = false;
        });
      }

      debugPrint("🎯 FINAL RESULT: Total pending overtime approvals: $totalPending");

      // ✅ DEBUGGING: If no requests found, let's check what's actually in the collection
      if (totalPending == 0) {
        debugPrint("🔍 DEBUG: No requests found. Let's check what approver IDs exist...");
        try {
          QuerySnapshot allPending = await FirebaseFirestore.instance
              .collection('overtime_requests')
              .where('status', isEqualTo: 'pending')
              .limit(10)
              .get();

          debugPrint("📊 Found ${allPending.docs.length} total pending requests in database:");
          for (var doc in allPending.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            debugPrint("  - Request ${doc.id}: approverEmpId='${data['approverEmpId']}', project='${data['projectName']}'");
          }
        } catch (e) {
          debugPrint("❌ Error in debug query: $e");
        }
      }

    } catch (e) {
      debugPrint("❌ Error loading pending overtime approvals: $e");
      if (mounted) {
        setState(() {
          _pendingOvertimeRequests = 0;
          _isLoadingOvertimeApprovals = false;
        });
      }
    }
  }











  Future<void> _fetchOvertimeAssignments() async {
    setState(() => _isLoadingOvertime = true);

    try {
      debugPrint("🕐 Setting up REAL-TIME overtime listener for ${widget.employeeId}");
      debugPrint("Looking for EMP ID from PIN: ${_userData?['pin']}");

      // Get the correct EMP ID format
      String empId = "EMP${_userData?['pin'] ?? ''}";
      debugPrint("Searching for overtime with EMP ID: $empId");

      // ✅ REAL-TIME LISTENER - This will update automatically!
      FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('status', isEqualTo: 'approved')
          .where('employeeIds', arrayContains: empId)  // Use EMP3576 format
          .snapshots()  // ✅ Real-time updates!
          .listen((snapshot) {

        debugPrint("🔥 REAL-TIME OVERTIME UPDATE: Found ${snapshot.docs.length} approved requests");

        List<OvertimeRequest> activeOvertime = [];
        List<OvertimeRequest> todayOvertime = [];

        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        DateTime tomorrow = today.add(Duration(days: 1));

        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data();
            OvertimeRequest request = OvertimeRequest.fromMap(doc.id, data);

            debugPrint("Processing overtime: ${request.projectName} - ${request.startTime}");

            // Check if it's today's overtime
            if (request.startTime.isAfter(today) && request.startTime.isBefore(tomorrow)) {
              todayOvertime.add(request);
              debugPrint("✅ Added to today's overtime: ${request.projectName}");

              // Check if currently active
              if (now.isAfter(request.startTime) && now.isBefore(request.endTime)) {
                activeOvertime.add(request);
                debugPrint("🔥 OVERTIME IS ACTIVE NOW: ${request.projectName}");
              }
            }
          } catch (e) {
            debugPrint("Error parsing overtime: $e");
          }
        }

        if (mounted) {
          setState(() {
            _activeOvertimeAssignments = activeOvertime;
            _todayOvertimeSchedule = todayOvertime;
            _hasActiveOvertime = activeOvertime.isNotEmpty || todayOvertime.isNotEmpty;
            _isLoadingOvertime = false;
          });

          debugPrint("🎯 DASHBOARD UPDATED:");
          debugPrint("  - Active Overtime: ${activeOvertime.length}");
          debugPrint("  - Today's Overtime: ${todayOvertime.length}");
          debugPrint("  - Has Active Overtime: $_hasActiveOvertime");
        }
      });

    } catch (e) {
      debugPrint("❌ Error setting up overtime listener: $e");
      if (mounted) {
        setState(() => _isLoadingOvertime = false);
      }
    }
  }

  // Theme Methods
  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    }
  }





  Future<void> _debugGeofenceMonitoring() async {
    try {
      debugPrint("🔍 === GEOFENCE MONITORING DEBUG ===");

      // Check service registration
      final geofenceService = getIt<GeofenceExitMonitoringService>();
      debugPrint("✅ Service retrieved successfully");

      // Initialize database
      await geofenceService.initializeDatabase();
      debugPrint("✅ Database initialized");

      // Check if table exists
      final dbHelper = getIt<DatabaseHelper>();
      final db = await dbHelper.database;

      final tables = await db.query(
          'sqlite_master',
          where: 'type = ? AND name = ?',
          whereArgs: ['table', 'geofence_exit_events']
      );

      debugPrint("📊 Table exists: ${tables.isNotEmpty}");

      // Get current event count before test
      int initialEventCount = 0;
      if (tables.isNotEmpty) {
        final countResult = await db.query('geofence_exit_events');
        initialEventCount = countResult.length;
        debugPrint("📊 Initial events count: $initialEventCount");
      }

      if (tables.isNotEmpty) {
        // Test insert with all required fields
        final testEvent = {
          'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
          'employee_id': widget.employeeId,
          'employee_name': _userData?['name'] ?? 'Test User',
          'exit_time': DateTime.now().toIso8601String(),
          'return_time': null,
          'latitude': 24.985454,
          'longitude': 55.175509,
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
        debugPrint("✅ Test event inserted");

        // Query events after insert
        final events = await db.query('geofence_exit_events');
        debugPrint("📊 Total events in database: ${events.length}");

        // Show latest events
        final latestEvents = await db.query(
          'geofence_exit_events',
          orderBy: 'created_at DESC',
          limit: 5,
        );

        debugPrint("📋 Latest events:");
        for (var event in latestEvents) {
          debugPrint("  - ${event['id']}: ${event['employee_name']} at ${event['exit_time']} (Status: ${event['status']})");
        }

        // Test querying specific employee events
        final employeeEvents = await db.query(
          'geofence_exit_events',
          where: 'employee_id = ?',
          whereArgs: [widget.employeeId],
        );
        debugPrint("📊 Events for current employee (${widget.employeeId}): ${employeeEvents.length}");

        // Test the service method for getting history
        try {
          final historyFromService = await geofenceService.getExitHistory(widget.employeeId, limit: 10);
          debugPrint("📊 History from service: ${historyFromService.length} events");
        } catch (e) {
          debugPrint("❌ Error getting history from service: $e");
        }

        // Clean up test data
        await db.delete('geofence_exit_events', where: 'status = ?', whereArgs: ['test']);
        debugPrint("🧹 Test data cleaned up");

        // Verify cleanup
        final eventsAfterCleanup = await db.query('geofence_exit_events');
        debugPrint("📊 Events after cleanup: ${eventsAfterCleanup.length}");
      }

      // Check monitoring status
      final isActive = await geofenceService.isMonitoringActive();
      final currentEmployee = await geofenceService.getCurrentMonitoredEmployee();

      debugPrint("📊 Monitoring Status:");
      debugPrint("  - Active: $isActive");
      debugPrint("  - Current Employee: $currentEmployee");

      // Test shared preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final monitoringActive = prefs.getBool('geofence_monitoring_active') ?? false;
        final monitoredEmployeeId = prefs.getString('monitored_employee_id') ?? 'none';
        final monitoredEmployeeName = prefs.getString('monitored_employee_name') ?? 'none';

        debugPrint("📊 SharedPreferences Status:");
        debugPrint("  - Monitoring Active: $monitoringActive");
        debugPrint("  - Monitored Employee ID: $monitoredEmployeeId");
        debugPrint("  - Monitored Employee Name: $monitoredEmployeeName");
      } catch (e) {
        debugPrint("❌ Error checking SharedPreferences: $e");
      }

      // Test database schema
      if (tables.isNotEmpty) {
        try {
          final tableInfo = await db.query('PRAGMA table_info(geofence_exit_events)');
          debugPrint("📊 Table Schema:");
          for (var column in tableInfo) {
            debugPrint("  - ${column['name']}: ${column['type']} (${column['notnull'] == 1 ? 'NOT NULL' : 'NULL'})");
          }
        } catch (e) {
          debugPrint("❌ Error getting table schema: $e");
        }
      }

      debugPrint("=== GEOFENCE DEBUG COMPLETE ===");

      // Show results to user
      if (mounted) {
        String dialogContent = "";

        if (tables.isNotEmpty) {
          final finalEvents = await db.query('geofence_exit_events');
          dialogContent = "Database Table: EXISTS\n"
              "Total Events: ${finalEvents.length}\n"
              "Monitoring Active: $isActive\n"
              "Current Employee: ${currentEmployee ?? 'None'}\n"
              "Service Available: ✅\n"
              "Database Operations: ✅\n\n"
              "Check console for detailed logs.";
        } else {
          dialogContent = "Database Table: MISSING\n"
              "Total Events: N/A\n"
              "Monitoring Active: $isActive\n"
              "Current Employee: ${currentEmployee ?? 'None'}\n"
              "Service Available: ✅\n"
              "Database Operations: ❌\n\n"
              "❌ Table needs to be created!\n"
              "Check console for detailed logs.";
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tables.isNotEmpty ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tables.isNotEmpty ? Icons.check_circle : Icons.error,
                    color: tables.isNotEmpty ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Geofence Debug Results",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  dialogContent,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            actions: [
              if (!tables.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Try to force create table
                    try {
                      await geofenceService.initializeDatabase();
                      CustomSnackBar.successSnackBar("Table creation attempted. Run debug again.");
                    } catch (e) {
                      CustomSnackBar.errorSnackBar("Failed to create table: $e");
                    }
                  },
                  child: Text("Create Table", style: TextStyle(color: Colors.orange)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Run debug again
                  _debugGeofenceMonitoring();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Run Again"),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      debugPrint("❌ Error in geofence debug: $e");
      debugPrint("Stack trace: ${StackTrace.current}");

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.error, color: Colors.red, size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Geofence Debug Error",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Error Details:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        e.toString(),
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Check console for detailed logs and stack trace.",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Try to reinitialize
                  _initializeGeofenceExitMonitoring();
                  CustomSnackBar.infoSnackBar("Attempting to reinitialize geofence service...");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        );
      }
    }
  }







  Future<void> _saveDarkModePreference(bool isDarkMode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        color: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Theme(
      data: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            SlideTransition(
              position: _offsetAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    ConnectivityBanner(connectivityService: _connectivityService),
                    if (_needsSync && _connectivityService.currentStatus == ConnectionStatus.online)
                      _buildSyncBanner(),
                    Expanded(
                      child: SafeArea(
                        child: Column(
                          children: [
                            _buildModernHeader(),
                            SizedBox(height: containerSpacing * 0.5),
                            _buildDateTimeSection(),
                            Expanded(
                              child: CustomScrollView(
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(vertical: containerSpacing * 0.5),
                                    sliver: SliverToBoxAdapter(
                                      child: _buildModernStatusCard(),
                                    ),
                                  ),
                                  // ✅ NEW: Add geofence monitoring card
                                  if (_isCheckedIn || _isGeofenceMonitoringActive)
                                    SliverPadding(
                                      padding: EdgeInsets.symmetric(vertical: containerSpacing * 0.5),
                                      sliver: SliverToBoxAdapter(
                                        child: _buildGeofenceMonitoringCard(),
                                      ),
                                    ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(vertical: containerSpacing * 0.5),
                                    sliver: SliverToBoxAdapter(
                                      child: _buildQuickActionsSection(),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(vertical: containerSpacing * 0.5),
                                    sliver: SliverToBoxAdapter(
                                      child: _buildTodaysActivitySection(),
                                    ),
                                  ),
                                  const SliverPadding(
                                    padding: EdgeInsets.only(bottom: 120),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading && _userData == null)
              _buildLoadingOverlay(),
          ],
        ),
        floatingActionButton: _buildCleanFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    // Only show minimal loading indicator, not full overlay
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Syncing...',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugGeofenceOption() {
    return _buildModernSettingsOption(
      icon: Icons.bug_report,
      title: 'Debug Geofence Monitoring',
      subtitle: 'Test geofence monitoring system and database',
      iconColor: Colors.purple,
      onTap: () {
        Navigator.pop(context);
        _debugGeofenceMonitoring();
      },
    );
  }

  Widget _buildCleanFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _isLocationRefreshing ? null : _checkGeofenceStatus,
      tooltip: _isLocationRefreshing ? 'Checking location...' : 'Refresh Location',
      backgroundColor: _isLocationRefreshing
          ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
          : Theme.of(context).colorScheme.primary,
      elevation: 8,
      child: _isLocationRefreshing
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Icon(Icons.my_location_rounded, color: Colors.white),
    );
  }

  Widget _buildSyncBanner() {
    return GestureDetector(
      onTap: _manualSync,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 12 : 10,
          horizontal: containerSpacing,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade500],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Tap to synchronize pending data',
              style: TextStyle(
                color: Colors.white,
                fontSize: (isTablet ? 15 : 13) * responsiveFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserProfile() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch fresh data from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      // Hide loading
      if (mounted) {
        Navigator.pop(context);
      }

      if (doc.exists) {
        Map<String, dynamic> freshUserData = doc.data() as Map<String, dynamic>;

        // Navigate with fresh data
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserProfilePage(
                employeeId: widget.employeeId,
                userData: freshUserData, // Fresh data from Firestore
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          CustomSnackBar.errorSnackBar(context, "User data not found");
        }
      }
    } catch (e) {
      // Hide loading if still showing
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.errorSnackBar(context, "Error loading profile: $e");
      }
    }
  }


  Widget _buildModernHeader() {
    String name = _userData?['name'] ?? 'User';
    String designation = _userData?['designation'] ?? 'Employee';
    String? imageBase64 = _userData?['image'];
    int totalNotificationCount = _pendingApprovalRequests + _pendingLeaveApprovals + _pendingOvertimeRequests;

    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isLargeScreen ? 28 : (isTablet ? 24.0 : 20.0)),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius + 8),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'profile_${widget.employeeId}',
            child: GestureDetector(
              onTap: () {
                if (_userData != null) {
                  // FIXED: Call the new method that fetches fresh data
                  _openUserProfile();
                } else {
                  CustomSnackBar.errorSnackBar(context, "User data not available");
                }
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: CircleAvatar(
                    radius: isLargeScreen ? 40 : (isTablet ? 35 : 28),
                    backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    backgroundImage: imageBase64 != null
                        ? MemoryImage(base64Decode(imageBase64))
                        : null,
                    child: imageBase64 == null
                        ? Icon(
                      Icons.person,
                      color: _isDarkMode ? Colors.grey.shade300 : Colors.grey,
                      size: isLargeScreen ? 40 : (isTablet ? 35 : 28),
                    )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isLargeScreen ? 24 : (isTablet ? 20 : 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingMessage,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.split(' ').first,
                  style: TextStyle(
                    fontSize: (isLargeScreen ? 28 : (isTablet ? 24 : 20)) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderActionButton(
                icon: Icons.notifications_outlined,
                badgeCount: totalNotificationCount,
                onTap: () => _showNotificationMenu(context),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              _buildHeaderActionButton(
                icon: Icons.settings_outlined,
                onTap: () => _showSettingsMenu(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 12 : 10),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
            ),
          ),
          child: Stack(
            children: [
              Icon(
                icon,
                color: _isDarkMode ? Colors.white : Colors.black87,
                size: isTablet ? 24 : 20,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formattedDate,
                    style: TextStyle(
                      fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                      color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentTime,
                style: TextStyle(
                  fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusCard() {
    final String locationName = _nearestLocation?.name ?? 'office location';

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            margin: responsivePadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardBorderRadius + 4),
              // ✅ NEW: Better gradient colors instead of dark gray
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                  const Color(0xFF1E40AF), // Darker blue
                  const Color(0xFF3730A3), // Darker indigo
                ]
                    : [
                  const Color(0xFF1E3A8A), // Navy blue
                  const Color(0xFF581C87), // Dark purple
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? const Color(0xFF1E40AF).withOpacity(0.2)
                      : const Color(0xFF1E3A8A).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 28 : (isTablet ? 24 : 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Status Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Status",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 6),
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isCheckedIn ? _pulseAnimation.value : 1.0,
                                  child: Text(
                                    _isCheckedIn ? "Checked In" : "Ready to Start",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: (isLargeScreen ? 32 : (isTablet ? 28 : 24)) * responsiveFontSize,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_isCheckedIn && _checkInTime != null) ...[
                              SizedBox(height: 4),
                              Text(
                                "Since ${DateFormat('h:mm a').format(_checkInTime!)}",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 16 : (isTablet ? 14 : 12),
                          vertical: isLargeScreen ? 10 : (isTablet ? 8 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: _isCheckedIn
                              ? Colors.green.withOpacity(0.25)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isCheckedIn ? Icons.check_circle : Icons.schedule,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isCheckedIn ? "Active" : "Inactive",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // ✅ SIMPLIFIED: Quick Info Section WITHOUT overtime info
                  Container(
                    padding: EdgeInsets.all(isLargeScreen ? 18 : (isTablet ? 16 : 14)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Work Schedule Info
                        if (_workSchedule != null) ...[
                          _buildInfoRow(
                            icon: Icons.access_time_rounded,
                            label: "Work Hours",
                            value: _workSchedule!.workTiming ?? "${_workSchedule!.startTime} - ${_workSchedule!.endTime}",
                          ),
                          if (_workSchedule!.hasBreakTime) ...[
                            SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.restaurant_rounded,
                              label: "Break Time",
                              value: "${_workSchedule!.breakStartTime} - ${_workSchedule!.breakEndTime}",
                            ),
                          ],
                          SizedBox(height: 8),
                        ],

                        // Current Timing Message
                        if (_currentTimingMessage != null) ...[
                          _buildInfoRow(
                            icon: _getTimingMessageIcon(),
                            label: "Status",
                            value: _currentTimingMessage!,
                            valueColor: _timingMessageColor != null
                                ? _timingMessageColor!.withOpacity(0.9)
                                : null,
                          ),
                          SizedBox(height: 8),
                        ],

                        // Location Status
                        _buildInfoRow(
                          icon: _isWithinGeofence ? Icons.location_on_rounded : Icons.location_off_rounded,
                          label: "Location",
                          value: _isCheckingLocation
                              ? "Checking location..."
                              : _isWithinGeofence
                              ? "At $locationName"
                              : "Outside $locationName ${_distanceToOffice != null ? '(${_distanceToOffice!.toStringAsFixed(0)}m away)' : ''}",
                          valueColor: _isWithinGeofence
                              ? Colors.greenAccent.withOpacity(0.9)
                              : Colors.orangeAccent.withOpacity(0.9),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // ✅ SIMPLIFIED: Status badges WITHOUT overtime (only sync/offline info)
                  if (_needsSync || _connectivityService.currentStatus == ConnectionStatus.offline) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white.withOpacity(0.8), size: 16),
                              SizedBox(width: 8),
                              Text(
                                "Connection Status",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (_needsSync && _isCheckedIn)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync, size: 14, color: Colors.amberAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "Will sync when online",
                                        style: TextStyle(
                                          color: Colors.amberAccent.withOpacity(0.95),
                                          fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (_connectivityService.currentStatus == ConnectionStatus.offline)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.wifi_off, size: 14, color: Colors.orangeAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "Working offline",
                                        style: TextStyle(
                                          color: Colors.orangeAccent.withOpacity(0.95),
                                          fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Schedule Warning (if needed)
                  if (_workSchedule != null && _shouldShowScheduleWarning()) ...[
                    Container(
                      padding: EdgeInsets.all(isLargeScreen ? 16 : (isTablet ? 14 : 12)),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getScheduleWarningMessage(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],

                  // Main Action Button
                  SizedBox(
                    width: double.infinity,
                    height: isLargeScreen ? 60 : (isTablet ? 56 : 52),
                    child: ElevatedButton(
                      onPressed: _isLoading || _isAuthenticating
                          ? null
                          : (!_isCheckedIn && !_isWithinGeofence)
                          ? null
                          : _handleCheckInOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (!_isCheckedIn && !_isWithinGeofence) || _isLoading || _isAuthenticating
                            ? Colors.grey.withOpacity(0.5)
                            : _isCheckedIn
                            ? const Color(0xFFE53E3E) // Red for check out
                            : const Color(0xFF38A169), // Green for check in
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: _isLoading || _isAuthenticating
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCheckedIn ? Icons.logout_rounded : Icons.face_rounded,
                            color: Colors.white,
                            size: isLargeScreen ? 28 : (isTablet ? 24 : 22),
                          ),
                          SizedBox(width: 12),
                          Text(
                            _isCheckedIn ? "CHECK OUT WITH FACE ID" : "CHECK IN WITH FACE ID",
                            style: TextStyle(
                              fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 15)) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Helper method for clean info rows (keep existing)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: (isLargeScreen ? 13 : (isTablet ? 12 : 11)) * responsiveFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white.withOpacity(0.95),
                  fontSize: (isLargeScreen ? 15 : (isTablet ? 14 : 13)) * responsiveFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildStatusBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Updated _buildQuickActionsSection() method

  Widget _buildQuickActionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 8 : 4, bottom: isTablet ? 16 : 12),
            child: Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: (isLargeScreen ? 28 : (isTablet ? 24 : 20)) * responsiveFontSize,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),

          // ✅ NEW: Overtime Status Card (if applicable)
          if (_hasActiveOvertime && (_activeOvertimeAssignments.isNotEmpty || _todayOvertimeSchedule.isNotEmpty))
            _buildOvertimeStatusCard(),

          // Rest Timing Card (if applicable)
          if (_hasActiveRestTiming())
            _buildRestTimingCard(),

          SizedBox(height: containerSpacing * 0.75),

          // Quick Actions Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isLargeScreen ? 4 : (isTablet ? 3 : 2),
            crossAxisSpacing: isTablet ? 12 : 8,
            mainAxisSpacing: isTablet ? 12 : 8,
            childAspectRatio: isLargeScreen ? 1.6 : (isTablet ? 1.4 : 1.2),
            children: [
              _buildCompactQuickActionCard(
                icon: Icons.event_available,
                title: "Apply Leave",
                subtitle: "Request time off",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ApplyLeaveView(
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        employeePin: _userData?['pin'] ?? widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  ).then((_) => _refreshDashboard());
                },
              ),
              _buildCompactQuickActionCard(
                icon: Icons.history,
                title: "Leave History",
                subtitle: "View applications",
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaveHistoryView(
                        employeeId: widget.employeeId,
                        employeeName: _userData?['name'] ?? 'Employee',
                        employeePin: _userData?['pin'] ?? widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  ).then((_) => _refreshDashboard());
                },
              ),

              _buildCompactQuickActionCard(
                icon: Icons.receipt_long,
                title: "Salary Slip",
                subtitle: "Request slip",
                color: Colors.green,
                onTap: () {
                  _showComingSoonDialog("Apply for Salary Slip");
                },
              ),
              _buildCompactQuickActionCard(
                icon: Icons.calendar_view_month,
                title: "My Attendance",
                subtitle: "View records",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyAttendanceView(
                        employeeId: widget.employeeId,
                        userData: _userData ?? {},
                      ),
                    ),
                  );
                },
              ),

              // Overtime approval card for approvers
              if (_isOvertimeApprover)
                _buildCompactQuickActionCard(
                  icon: Icons.approval,
                  title: "Overtime Approvals",
                  subtitle: _pendingOvertimeRequests > 0
                      ? "$_pendingOvertimeRequests pending"
                      : "No pending",
                  color: Colors.orange,
                  showBadge: _pendingOvertimeRequests > 0,
                  badgeCount: _pendingOvertimeRequests,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PendingOvertimeView(
                          approverId: widget.employeeId,
                        ),
                      ),
                    ).then((_) => _loadPendingOvertimeApprovals());
                  },
                ),

              // Overtime creation card
              if (_userData != null &&
                  (_userData!['hasOvertimeAccess'] == true ||
                      _userData!['overtimeAccessGrantedAt'] != null ||
                      _userData!['standardizedOvertimeAccess'] == true))
                _buildCompactQuickActionCard(
                  icon: Icons.access_time,
                  title: "Create Overtime",
                  subtitle: "Request overtime",
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateOvertimeView(
                          requesterId: widget.employeeId,
                        ),
                      ),
                    ).then((_) => _refreshDashboard());
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

// ✅ NEW: Overtime Status Card Method
  Widget _buildOvertimeStatusCard() {
    return Container(
      margin: EdgeInsets.only(bottom: containerSpacing),
      padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _activeOvertimeAssignments.isNotEmpty
              ? [Colors.orange.shade600, Colors.orange.shade400] // Active overtime
              : [Colors.blue.shade600, Colors.blue.shade400], // Scheduled overtime
        ),
        borderRadius: BorderRadius.circular(cardBorderRadius + 4),
        boxShadow: [
          BoxShadow(
            color: (_activeOvertimeAssignments.isNotEmpty ? Colors.orange : Colors.blue).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _activeOvertimeAssignments.isNotEmpty
                      ? Icons.work_history_rounded
                      : Icons.event_available_rounded,
                  color: Colors.white,
                  size: isTablet ? 32 : 28,
                ),
              ),
              SizedBox(width: containerSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeOvertimeAssignments.isNotEmpty
                          ? "Overtime Active Now!"
                          : "Overtime Scheduled Today",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isLargeScreen ? 24 : (isTablet ? 20 : 18)) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeOvertimeAssignments.isNotEmpty
                          ? "${_activeOvertimeAssignments.length} active assignment${_activeOvertimeAssignments.length > 1 ? 's' : ''}"
                          : "${_todayOvertimeSchedule.length} scheduled assignment${_todayOvertimeSchedule.length > 1 ? 's' : ''}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: containerSpacing),
          Container(
            padding: EdgeInsets.all(containerSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(cardBorderRadius - 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_activeOvertimeAssignments.isNotEmpty) ...[
                  // Show active overtime details
                  ...(_activeOvertimeAssignments.take(2).map((overtime) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${overtime.projectName} (${overtime.projectCode})",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 13)) * responsiveFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${DateFormat('h:mm a').format(overtime.startTime)} - ${DateFormat('h:mm a').format(overtime.endTime)}",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  )).toList()),
                  if (_activeOvertimeAssignments.length > 2)
                    Text(
                      "... and ${_activeOvertimeAssignments.length - 2} more active",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ] else if (_todayOvertimeSchedule.isNotEmpty) ...[
                  // Show scheduled overtime details
                  ...(_todayOvertimeSchedule.take(3).map((overtime) => Container(
                    margin: EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${overtime.projectName}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (isLargeScreen ? 15 : (isTablet ? 13 : 12)) * responsiveFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          "${DateFormat('h:mm a').format(overtime.startTime)} - ${DateFormat('h:mm a').format(overtime.endTime)}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: (isLargeScreen ? 13 : (isTablet ? 11 : 10)) * responsiveFontSize,
                          ),
                        ),
                      ],
                    ),
                  )).toList()),
                  if (_todayOvertimeSchedule.length > 3)
                    Text(
                      "... ${_todayOvertimeSchedule.length - 3} more scheduled",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(
              color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            // ✅ REDUCED: Much smaller padding
            padding: EdgeInsets.all(isLargeScreen ? 16 : (isTablet ? 14 : 12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ COMPACT: Icon section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Stack(
                      children: [
                        Container(
                          // ✅ REDUCED: Smaller icon container
                          padding: EdgeInsets.all(isLargeScreen ? 12 : (isTablet ? 10 : 8)),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            // ✅ REDUCED: Smaller icon size
                            size: isLargeScreen ? 24 : (isTablet ? 22 : 20),
                          ),
                        ),
                        // Badge support
                        if (showBadge && badgeCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                badgeCount > 99 ? '99+' : badgeCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ✅ COMPACT: Text section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        // ✅ REDUCED: Smaller title font
                        fontSize: (isLargeScreen ? 16 : (isTablet ? 15 : 14)) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2), // ✅ REDUCED: Less spacing
                    Text(
                      subtitle,
                      style: TextStyle(
                        // ✅ REDUCED: Smaller subtitle font
                        fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimingCard() {
    return Container(
      margin: EdgeInsets.only(bottom: containerSpacing),
      padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.withOpacity(0.8), Colors.cyan.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(cardBorderRadius + 4),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: isTablet ? 32 : 28,
                ),
              ),
              SizedBox(width: containerSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Rest Timing Schedule",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isLargeScreen ? 24 : (isTablet ? 20 : 18)) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRestTimingStatus(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: containerSpacing),
          Container(
            padding: EdgeInsets.all(containerSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(cardBorderRadius - 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Rest Time",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRestTimingHours(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveRestTiming() {
    if (_userData == null) return false;
    if (_userData!['eligibleForRestTiming'] != true) return false;

    final String? startDateStr = _userData!['restTimingStartDate'];
    final String? endDateStr = _userData!['restTimingEndDate'];

    if (startDateStr == null || endDateStr == null) return false;

    try {
      final DateTime startDate = DateTime.parse(startDateStr);
      final DateTime endDate = DateTime.parse(endDateStr);
      final DateTime now = DateTime.now();

      return now.isAfter(startDate.subtract(const Duration(days: 1))) &&
          now.isBefore(endDate.add(const Duration(days: 1)));
    } catch (e) {
      debugPrint("Error parsing rest timing dates: $e");
      return false;
    }
  }

  String _getRestTimingStatus() {
    if (!_hasActiveRestTiming()) return "No active schedule";

    final String? startDateStr = _userData!['restTimingStartDate'];
    final String? endDateStr = _userData!['restTimingEndDate'];

    if (startDateStr == null || endDateStr == null) return "Invalid schedule";

    try {
      final DateTime startDate = DateTime.parse(startDateStr);
      final DateTime endDate = DateTime.parse(endDateStr);
      final DateTime now = DateTime.now();

      if (now.isBefore(startDate)) {
        return "Scheduled to start ${DateFormat('MMM dd').format(startDate)}";
      } else if (now.isAfter(endDate)) {
        return "Schedule completed";
      } else {
        return "Active until ${DateFormat('MMM dd').format(endDate)}";
      }
    } catch (e) {
      return "Invalid schedule dates";
    }
  }

  String _getRestTimingHours() {
    if (!_hasActiveRestTiming()) return "--:-- - --:--";

    final String? startTime = _userData!['restTimingStartTime'];
    final String? endTime = _userData!['restTimingEndTime'];

    if (startTime == null || endTime == null) return "--:-- - --:--";

    return "$startTime - $endTime";
  }

  Widget _buildTodaysActivitySection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 8 : 4, bottom: isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.today_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: isLargeScreen ? 24 : (isTablet ? 22 : 20),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Text(
                  "Today's Activity",
                  style: TextStyle(
                    fontSize: (isLargeScreen ? 28 : (isTablet ? 24 : 20)) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          _buildCleanTodaysActivityCard(),
        ],
      ),
    );
  }


  Widget _buildCleanTodaysActivityCard() {
    // Initialize with default values
    bool hasCheckIn = false;
    bool hasCheckOut = false;
    String checkInTimeStr = "Not recorded";
    String checkOutTimeStr = "Not recorded";
    String workStatus = "Not started";
    String locationName = "Unknown location";

    debugPrint("=== TODAY'S ACTIVITY DEBUG ===");
    debugPrint("_isCheckedIn: $_isCheckedIn");
    debugPrint("_checkInTime: $_checkInTime");
    debugPrint("_todaysActivity length: ${_todaysActivity.length}");

    // PRIORITY 1: Use current dashboard state (most reliable)
    if (_isCheckedIn && _checkInTime != null) {
      checkInTimeStr = DateFormat('h:mm a').format(_checkInTime!);
      hasCheckIn = true;
      workStatus = "In Progress";
      locationName = _nearestLocation?.name ?? "Office location";
      debugPrint("✅ Used current dashboard state - Check-in: $checkInTimeStr");
    }

    // PRIORITY 2: Check today's activity data for additional info
    if (_todaysActivity.isNotEmpty) {
      for (var activity in _todaysActivity) {
        debugPrint("Activity type: ${activity['type']}");

        if (activity['type'] == 'attendance') {
          debugPrint("Attendance activity found: ${activity.keys}");

          // Parse check-in time (but don't override if we already have it from current state)
          if (activity['checkIn'] != null && !hasCheckIn) {
            try {
              DateTime checkInDate;
              if (activity['checkIn'] is Timestamp) {
                checkInDate = (activity['checkIn'] as Timestamp).toDate();
              } else if (activity['checkIn'] is String) {
                checkInDate = DateTime.parse(activity['checkIn']);
              } else {
                continue;
              }
              checkInTimeStr = DateFormat('h:mm a').format(checkInDate);
              hasCheckIn = true;
              debugPrint("✅ Parsed check-in from activity: $checkInTimeStr");
            } catch (e) {
              debugPrint("❌ Error parsing check-in time: $e");
            }
          }

          // Parse check-out time
          if (activity['checkOut'] != null) {
            try {
              DateTime checkOutDate;
              if (activity['checkOut'] is Timestamp) {
                checkOutDate = (activity['checkOut'] as Timestamp).toDate();
              } else if (activity['checkOut'] is String) {
                checkOutDate = DateTime.parse(activity['checkOut']);
              } else {
                continue;
              }
              checkOutTimeStr = DateFormat('h:mm a').format(checkOutDate);
              hasCheckOut = true;
              debugPrint("✅ Parsed check-out from activity: $checkOutTimeStr");
            } catch (e) {
              debugPrint("❌ Error parsing check-out time: $e");
            }
          }

          // Get additional info from activity
          String activityStatus = activity['workStatus'] ?? '';
          String activityLocation = activity['location'] ?? '';

          if (activityStatus.isNotEmpty) {
            workStatus = activityStatus;
          }
          if (activityLocation.isNotEmpty) {
            locationName = activityLocation;
          }

          debugPrint("Activity work status: $activityStatus");
          debugPrint("Activity location: $activityLocation");
          break;
        }
      }
    }

    // PRIORITY 3: Final fallback - use current state even if no _checkInTime
    if (!hasCheckIn && _isCheckedIn) {
      checkInTimeStr = "Just now";
      hasCheckIn = true;
      workStatus = "In Progress";
      debugPrint("✅ Used fallback - user is checked in but no time available");
    }

    // Determine final work status
    if (hasCheckIn && hasCheckOut) {
      workStatus = "Completed";
    } else if (hasCheckIn && !hasCheckOut) {
      workStatus = "In Progress";
    } else {
      workStatus = "Not started";
    }

    debugPrint("=== FINAL RESULTS ===");
    debugPrint("hasCheckIn: $hasCheckIn");
    debugPrint("checkInTimeStr: $checkInTimeStr");
    debugPrint("hasCheckOut: $hasCheckOut");
    debugPrint("workStatus: $workStatus");
    debugPrint("locationName: $locationName");
    debugPrint("=== END DEBUG ===");

    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(cardBorderRadius + 4),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 28 : (isTablet ? 24 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getCleanStatusColor(workStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(workStatus),
                          color: _getCleanStatusColor(workStatus),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: isTablet ? 16 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Work Day Status",
                              style: TextStyle(
                                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              workStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                                color: _isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 10,
                    vertical: isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getCleanStatusColor(workStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getCleanStatusColor(workStatus).withOpacity(0.3)),
                  ),
                  child: Text(
                    hasCheckIn ? (hasCheckOut ? "DONE" : "ACTIVE") : "PENDING",
                    style: TextStyle(
                      color: _getCleanStatusColor(workStatus),
                      fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 24 : 20),

            // Time Information Section
            Container(
              padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(cardBorderRadius),
                border: Border.all(
                  color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Check-in and Check-out Times
                  Row(
                    children: [
                      // Check-in Section
                      Expanded(
                        child: _buildTimeSection(
                          icon: Icons.login_rounded,
                          label: "Check In",
                          time: checkInTimeStr,
                          isRecorded: hasCheckIn,
                          color: Colors.green,
                        ),
                      ),

                      // Divider
                      Container(
                        width: 1,
                        height: 60,
                        margin: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
                        color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3),
                      ),

                      // Check-out Section
                      Expanded(
                        child: _buildTimeSection(
                          icon: Icons.logout_rounded,
                          label: "Check Out",
                          time: checkOutTimeStr,
                          isRecorded: hasCheckOut,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 20 : 16),

                  // Location and Duration Info
                  Container(
                    padding: EdgeInsets.all(isLargeScreen ? 16 : (isTablet ? 14 : 12)),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationName,
                            style: TextStyle(
                              fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasCheckIn && hasCheckOut)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Work Complete",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (hasCheckIn)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "In Progress",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action suggestion (if needed)
            if (!hasCheckIn) ...[
              SizedBox(height: isTablet ? 20 : 16),
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 16 : (isTablet ? 14 : 12)),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Ready to start your work day? Use the Check In button above.",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection({
    required IconData icon,
    required String label,
    required String time,
    required bool isRecorded,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRecorded ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isRecorded ? color : Colors.grey,
            size: isLargeScreen ? 24 : (isTablet ? 22 : 20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
            color: isRecorded
                ? (_isDarkMode ? Colors.white : Colors.black87)
                : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getCleanStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
      case 'active':
        return Colors.blue;
      case 'not started':
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Icons.check_circle_rounded;
      case 'in progress':
      case 'active':
        return Icons.play_circle_rounded;
      case 'not started':
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }









  // Helper Methods for Colors
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getLeaveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Leave Service Initialization
  void _initializeLeaveService() {
    try {
      final repository = getIt<LeaveApplicationRepository>();
      final connectivityService = getIt<ConnectivityService>();

      _leaveService = LeaveApplicationService(
        repository: repository,
        connectivityService: connectivityService,
      );

      debugPrint("Leave service initialized successfully");
    } catch (e) {
      debugPrint("Error initializing leave service: $e");
    }
  }

  Future<void> _loadPendingLeaveApprovals() async {
    if (!_isLineManager) return;

    try {
      setState(() => _isLoadingLeaveData = true);

      final pendingApplications = await _leaveService.getPendingApplicationsForManager(widget.employeeId);

      if (mounted) {
        setState(() {
          _pendingLeaveApprovals = pendingApplications.length;
          _isLoadingLeaveData = false;
        });
      }

      debugPrint("Loaded ${_pendingLeaveApprovals} pending leave approvals");
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLeaveData = false);
      }
      debugPrint("Error loading pending leave approvals: $e");
    }
  }

  // Activity Fetching - Optimized
  Future<void> _fetchTodaysActivity() async {
    try {
      List<Map<String, dynamic>> todaysActivity = [];
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      bool hasAttendance = false;
      bool hasLeaveApplication = false;

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          // Fetch attendance
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .collection('attendance')
              .doc(today)
              .get()
              .timeout(const Duration(seconds: 8));

          if (attendanceDoc.exists) {
            Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;
            todaysActivity.add({
              'type': 'attendance',
              'date': data['date'] ?? today,
              'checkIn': data['checkIn'],
              'checkOut': data['checkOut'],
              'workStatus': data['workStatus'] ?? 'In Progress',
              'totalHours': data['totalHours'],
              'location': data['location'] ?? 'Unknown',
              'isSynced': true,
            });
            hasAttendance = true;
            debugPrint("Found today's attendance record");
          }
        } catch (e) {
          debugPrint("Error fetching today's attendance: $e");
        }

        // Fetch leave applications
        try {
          QuerySnapshot leaveSnapshot = await FirebaseFirestore.instance
              .collection('leave_applications')
              .where('employeeId', isEqualTo: widget.employeeId)
              .where('applicationDate', isEqualTo: today)
              .get()
              .timeout(const Duration(seconds: 8));

          for (var doc in leaveSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            todaysActivity.add({
              'type': 'leave',
              'applicationId': doc.id,
              'date': today,
              'leaveType': data['leaveType'] ?? 'Leave',
              'fromDate': data['fromDate'],
              'toDate': data['toDate'],
              'totalDays': data['totalDays'] ?? 0,
              'status': data['status'] ?? 'pending',
              'reason': data['reason'] ?? '',
              'appliedAt': data['appliedAt'],
              'isSynced': true,
            });
            hasLeaveApplication = true;
            debugPrint("Found today's leave application");
          }
        } catch (e) {
          debugPrint("Error fetching today's leave applications: $e");
        }
      } else {
        // Offline mode
        final localAttendance = await _attendanceRepository.getTodaysAttendance(widget.employeeId);
        if (localAttendance != null) {
          todaysActivity.add(localAttendance.rawData);
          hasAttendance = true;
          debugPrint("Using local attendance data");
        }
      }

      if (mounted) {
        setState(() {
          _todaysActivity = todaysActivity;
          _hasTodaysAttendance = hasAttendance;
          _hasTodaysLeaveApplication = hasLeaveApplication;
          _isAbsentToday = !hasAttendance && !hasLeaveApplication && !_isCheckedIn;
        });
      }

      debugPrint("Today's activity loaded: ${todaysActivity.length} items");

    } catch (e) {
      debugPrint("Error fetching today's activity: $e");
      if (mounted) {
        setState(() {
          _todaysActivity = [];
          _isAbsentToday = !_isCheckedIn;
        });
      }
    }
  }

  // Geofence Status Check - Optimized
  Future<void> _checkGeofenceStatus() async {
    if (!mounted) return;

    // Prevent multiple simultaneous checks
    if (_isLocationRefreshing) {
      debugPrint("⚡ Location check already in progress, skipping...");
      return;
    }

    _isLocationRefreshing = true;

    if (mounted) {
      setState(() {
        _isCheckingLocation = true;
      });
    }

    try {
      debugPrint("📍 Manual location check triggered...");

      // Force fresh location check (bypass cache)
      _isLocationCacheValid = false;
      _cachedPosition = null;

      // Use enhanced geofence with employee exemption checking
      Map<String, dynamic> status = await EnhancedGeofenceUtil.checkGeofenceStatusForEmployee(
        context,
        widget.employeeId,
      );

      if (mounted) {
        bool withinGeofence = status['withinGeofence'] as bool;
        double? distance = status['distance'] as double?;
        String locationType = status['locationType'] as String? ?? 'unknown';
        bool isExempted = status['isExempted'] ?? false;

        // Handle different location types
        if (locationType == 'polygon') {
          final polygonLocation = status['location'] as PolygonLocationModel?;
          if (polygonLocation != null) {
            setState(() {
              _isWithinGeofence = withinGeofence;
              _distanceToOffice = distance;
              _nearestLocation = LocationModel(
                id: polygonLocation.id,
                name: polygonLocation.name,
                address: polygonLocation.description,
                latitude: polygonLocation.centerLatitude,
                longitude: polygonLocation.centerLongitude,
                radius: 0,
                isActive: polygonLocation.isActive,
              );
            });
          }
        } else if (locationType == 'exemption') {
          final exemptLocation = status['location'] as LocationModel?;
          setState(() {
            _isWithinGeofence = true; // Always true for exempt employees
            _distanceToOffice = 0.0;
            _nearestLocation = exemptLocation;
          });
          debugPrint("🆓 Employee ${widget.employeeId} is location exempt");
        } else {
          final circularLocation = status['location'] as LocationModel?;
          setState(() {
            _isWithinGeofence = withinGeofence;
            _nearestLocation = circularLocation;
            _distanceToOffice = distance;
          });
        }

        _lastSuccessfulLocationCheck = DateTime.now();

        // Show success message for manual refresh
        String locationStatus = withinGeofence ? 'INSIDE' : 'OUTSIDE';
        String exemptionStatus = isExempted ? ' (EXEMPT)' : '';
        String locationName = _nearestLocation?.name ?? 'office location';

        if (isExempted) {
          CustomSnackBar.successSnackBar("✅ Location updated! You can check in/out from anywhere.");
        } else if (withinGeofence) {
          CustomSnackBar.successSnackBar("✅ Location updated! You're at $locationName.");
        } else {
          String distanceText = distance != null ? " (${distance.toStringAsFixed(0)}m away)" : "";
          CustomSnackBar.infoSnackBar("📍 Location updated! Outside $locationName$distanceText");
        }

        debugPrint("📍 Manual location update: $locationStatus$exemptionStatus at $locationName");
      }

    } catch (e) {
      debugPrint('❌ Error checking geofence: $e');
      if (mounted) {
        setState(() {
          _isWithinGeofence = false;
          _nearestLocation = null;
          _distanceToOffice = null;
        });
        CustomSnackBar.errorSnackBar("Failed to check location: $e");
      }
    } finally {
      _isLocationRefreshing = false;
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
        });
      }
    }
  }


  Future<void> _processLocationWithPosition(Position position) async {
    try {
      // ✅ ENHANCED: Use new method that supports employee exemptions
      Map<String, dynamic> status = await EnhancedGeofenceUtil.checkGeofenceStatusForEmployee(
          context,
          widget.employeeId,
          currentPosition: position
      );

      bool withinGeofence = status['withinGeofence'] as bool;
      double? distance = status['distance'] as double?;
      String locationType = status['locationType'] as String? ?? 'unknown';
      bool isExempted = status['isExempted'] ?? false;

      if (locationType == 'polygon') {
        final polygonLocation = status['location'] as PolygonLocationModel?;
        if (mounted) {
          setState(() {
            _isWithinGeofence = withinGeofence;
            _distanceToOffice = distance;
            if (polygonLocation != null) {
              _nearestLocation = LocationModel(
                id: polygonLocation.id,
                name: polygonLocation.name,
                address: polygonLocation.description,
                latitude: polygonLocation.centerLatitude,
                longitude: polygonLocation.centerLongitude,
                radius: 0,
                isActive: polygonLocation.isActive,
              );
            }
          });
        }
      } else if (locationType == 'exemption') {
        // Handle exempt employees
        final exemptLocation = status['location'] as LocationModel?;
        if (mounted) {
          setState(() {
            _isWithinGeofence = true; // Always true for exempt employees
            _distanceToOffice = 0.0;
            _nearestLocation = exemptLocation;
          });
        }
        debugPrint("🆓 Employee ${widget.employeeId} is location exempt - can check in/out from anywhere");
      } else {
        final circularLocation = status['location'] as LocationModel?;
        if (mounted) {
          setState(() {
            _isWithinGeofence = withinGeofence;
            _nearestLocation = circularLocation;
            _distanceToOffice = distance;
          });
        }
      }

      String locationStatus = withinGeofence ? 'INSIDE' : 'OUTSIDE';
      String exemptionStatus = isExempted ? ' (EXEMPT)' : '';
      debugPrint("⚡ Location processed: $locationStatus (${distance?.toStringAsFixed(0)}m)$exemptionStatus");

    } catch (e) {
      debugPrint("❌ Error processing location: $e");
    }
  }

  Future<void> _fetchAvailableLocations() async {
    try {
      final locationRepository = getIt<LocationRepository>();
      List<LocationModel> circularLocations = await locationRepository.getActiveLocations();

      final polygonRepository = getIt<PolygonLocationRepository>();
      List<PolygonLocationModel> polygonLocations = await polygonRepository.getActivePolygonLocations();

      List<LocationModel> convertedPolygonLocations = polygonLocations.map((poly) =>
          LocationModel(
            id: poly.id,
            name: "${poly.name} (Polygon)",
            address: poly.description,
            latitude: poly.centerLatitude,
            longitude: poly.centerLongitude,
            radius: 0,
            isActive: poly.isActive,
          )
      ).toList();

      List<LocationModel> allLocations = [...circularLocations, ...convertedPolygonLocations];

      if (mounted) {
        setState(() {
          _availableLocations = allLocations;
        });
      }
    } catch (e) {
      debugPrint('Error fetching available locations: $e');
    }
  }

  // Work Schedule Methods - Enhanced
  Future<void> _fetchWorkSchedule() async {
    if (_userData == null) return;

    if (mounted) {
      setState(() => _isLoadingSchedule = true);
    }

    try {
      debugPrint("=== FETCHING ENHANCED WORK SCHEDULE ===");

      String? employeePin = _userData!['pin']?.toString();

      // ✅ Use enhanced work schedule service
      WorkSchedule? schedule = await WorkScheduleService.getEmployeeWorkSchedule(
          widget.employeeId,
          employeePin
      );

      if (mounted) {
        setState(() {
          _workSchedule = schedule;
          _isLoadingSchedule = false;
        });

        if (schedule != null) {
          debugPrint("✅ Enhanced work schedule loaded successfully");
          debugPrint("  - Is Alternative Saturday: ${schedule.isAlternativeSaturday}");
          debugPrint("  - Status: ${schedule.alternativeSaturdayStatus}");
          debugPrint("  - Message: ${schedule.alternativeSaturdayMessage}");
          debugPrint("  - Timing: ${schedule.alternativeSaturdayTiming}");

          if (!schedule.isOffDay) {
            _setupCheckOutReminder();
          }
          _updateCurrentTimingMessage();
        } else {
          debugPrint("⚠️ No work schedule found");
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching enhanced work schedule: $e");
      if (mounted) {
        setState(() => _isLoadingSchedule = false);
      }
    }
  }

  void _setupTimingChecks() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateCurrentTimingMessage();
    });
  }

  void _updateCurrentTimingMessage() {
    if (_workSchedule == null) return;

    DateTime now = DateTime.now();
    String message = "";
    Color messageColor = Colors.blue;

    try {
      // ✅ SIMPLIFIED: Handle only regular work schedule (no Saturday logic)
      if (WorkScheduleService.isInBreakTime(_workSchedule!, now)) {
        message = "Break Time: ${_workSchedule!.breakStartTime} - ${_workSchedule!.breakEndTime}";
        messageColor = Colors.orange;
      } else {
        DateTime workStart = _parseTimeForToday(_workSchedule!.startTime);
        DateTime workEnd = _parseTimeForToday(_workSchedule!.endTime);

        if (now.isBefore(workStart)) {
          Duration timeUntilWork = workStart.difference(now);
          message = "Work starts in ${_formatDuration(timeUntilWork)} at ${_workSchedule!.startTime}";
          messageColor = Colors.blue;
        } else if (now.isAfter(workEnd)) {
          message = "Work day ended at ${_workSchedule!.endTime}";
          messageColor = Colors.green;
        } else if (_isCheckedIn) {
          Duration timeUntilEnd = workEnd.difference(now);
          message = "Work ends in ${_formatDuration(timeUntilEnd)} at ${_workSchedule!.endTime}";
          messageColor = Colors.green;
        } else {
          message = "Work hours active: ${_workSchedule!.startTime} - ${_workSchedule!.endTime}";
          messageColor = Colors.red;
        }
      }

      if (mounted && _currentTimingMessage != message) {
        setState(() {
          _currentTimingMessage = message;
          _timingMessageColor = messageColor;
        });
      }
    } catch (e) {
      debugPrint("Error updating timing message: $e");
    }
  }

  void _setupCheckOutReminder() {
    if (_workSchedule == null || !_isCheckedIn) return;

    _checkOutReminderTimer?.cancel();
    _hasShownCheckOutReminder = false;

    _checkOutReminderTimer = WorkScheduleService.setupCheckOutReminder(
      _workSchedule!,
      _showCheckOutReminder,
    );
  }

  void _showCheckOutReminder() {
    if (!mounted || _hasShownCheckOutReminder || !_isCheckedIn) return;

    _hasShownCheckOutReminder = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Container(
          padding: EdgeInsets.all(containerSpacing),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(cardBorderRadius - 4),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white, size: 32),
              SizedBox(width: containerSpacing * 0.75),
              Expanded(
                child: Text(
                  "Check-Out Reminder!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (isLargeScreen ? 22 : (isTablet ? 18 : 16)) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Your work day ends at ${_workSchedule?.endTime ?? 'unknown time'}.",
              style: TextStyle(
                fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange, size: 24),
                  SizedBox(width: containerSpacing * 0.75),
                  Expanded(
                    child: Text(
                      "Don't forget to check out when leaving the office!",
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Got it!", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Check Out Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handleCheckInOut();
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showTimingValidationDialog(ScheduleCheckResult result) async {
    if (result.isOnTime) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Icon(
              result.isLate ? Icons.schedule : Icons.warning,
              color: result.isLate ? Colors.red : Colors.orange,
              size: 32,
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                result.isLate
                    ? "Late ${result.scheduleType == ScheduleEventType.checkIn ? 'Check-In' : 'Check-Out'}"
                    : "Early Check-Out",
                style: TextStyle(
                  color: result.isLate ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: (isLargeScreen ? 22 : (isTablet ? 18 : 16)) * responsiveFontSize,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message,
              style: TextStyle(
                fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: (result.isLate ? Colors.red : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(
                  color: (result.isLate ? Colors.red : Colors.orange).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: result.isLate ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Schedule Details:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (result.isLate ? Colors.red : Colors.orange).shade800,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Expected: ${DateFormat('h:mm a').format(result.expectedTime)}",
                    style: TextStyle(
                      color: (result.isLate ? Colors.red : Colors.orange).shade700,
                      fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                    ),
                  ),
                  Text(
                    "Actual: ${DateFormat('h:mm a').format(result.actualTime)}",
                    style: TextStyle(
                      color: (result.isLate ? Colors.red : Colors.orange).shade700,
                      fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                    ),
                  ),
                  if (_workSchedule?.workTiming != null)
                    Text(
                      "Work Hours: ${_workSchedule!.workTiming}",
                      style: TextStyle(
                        color: (result.isLate ? Colors.red : Colors.orange).shade700,
                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: containerSpacing),
            Text(
              "Do you want to proceed with ${result.scheduleType == ScheduleEventType.checkIn ? 'check-in' : 'check-out'}?",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: result.isLate ? Colors.red : Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Proceed"),
          ),
        ],
      ),
    ) ?? false;
  }

  // Complete User Data Fetching Implementation
  Future<void> _fetchUserData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      debugPrint("=== FETCHING USER DATA (COMPLETE WITH WORK SCHEDULE) ===");
      debugPrint("Dashboard widget.employeeId: ${widget.employeeId}");
      debugPrint("Connectivity: ${_connectivityService.currentStatus}");

      Map<String, dynamic>? localData = await _getUserDataLocally();

      if (localData != null && mounted) {
        debugPrint("✅ Found local cached data with ${localData.keys.length} fields");
        setState(() {
          _userData = localData;
          _isLoading = false;
        });
        _validateFaceDataInBackground();
      }

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        debugPrint("🌐 FORCING FRESH DATA FETCH FROM FIRESTORE");

        try {
          Map<String, dynamic> combinedData = localData ?? {};

          DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 10));

          if (employeeDoc.exists) {
            Map<String, dynamic> employeeData = employeeDoc.data() as Map<String, dynamic>;
            combinedData.addAll(employeeData);
            debugPrint("✅ FRESH: Employee data fetched (${employeeData.keys.length} fields)");

            String? employeePin = employeeData['pin']?.toString();
            if (employeePin != null && employeePin.isNotEmpty) {
              try {
                String masterSheetEmployeeId = employeePin;
                if (masterSheetEmployeeId.startsWith('EMP')) {
                  masterSheetEmployeeId = masterSheetEmployeeId.substring(3);
                }

                int pinNumber = int.parse(masterSheetEmployeeId);
                masterSheetEmployeeId = 'EMP${pinNumber.toString().padLeft(4, '0')}';

                debugPrint("🔍 Fetching MasterSheet data for: $masterSheetEmployeeId");

                DocumentSnapshot masterSheetDoc = await FirebaseFirestore.instance
                    .collection('MasterSheet')
                    .doc('Employee-Data')
                    .collection('employees')
                    .doc(masterSheetEmployeeId)
                    .get()
                    .timeout(const Duration(seconds: 5));

                if (masterSheetDoc.exists) {
                  Map<String, dynamic> masterSheetData = masterSheetDoc.data() as Map<String, dynamic>;
                  combinedData.addAll(masterSheetData);
                  debugPrint("✅ FRESH: MasterSheet data fetched (${masterSheetData.keys.length} fields)");

                  debugPrint("📅 Work Schedule Fields from MasterSheet:");
                  debugPrint("  - workTiming: ${masterSheetData['workTiming']}");
                  debugPrint("  - startTime: ${masterSheetData['startTime']}");
                  debugPrint("  - breakStartTime: ${masterSheetData['breakStartTime']}");
                  debugPrint("  - breakEndTime: ${masterSheetData['breakEndTime']}");
                } else {
                  debugPrint("⚠️ No MasterSheet document found for: $masterSheetEmployeeId");
                }
              } catch (masterSheetError) {
                debugPrint("⚠️ Could not fetch MasterSheet data: $masterSheetError");
              }
            } else {
              debugPrint("⚠️ No employee PIN found for MasterSheet lookup");
            }

            _standardizeOvertimeFieldsFromDatabase(combinedData);

            await _saveUserDataLocally(combinedData);
            if (mounted) {
              setState(() {
                _userData = combinedData;
                _isLoading = false;
              });
            }

            debugPrint("✅ COMPLETE: User data updated with database values");

          } else {
            debugPrint("⚠️ No employee document found in Firestore");
            if (localData != null) {
              _standardizeOvertimeFieldsFromDatabase(localData);
              if (mounted) {
                setState(() {
                  _userData = localData;
                  _isLoading = false;
                });
              }
            }
          }

        } catch (e) {
          debugPrint("⚠️ Error in online data fetch: $e");
          if (localData != null) {
            _standardizeOvertimeFieldsFromDatabase(localData);
            if (mounted) {
              setState(() {
                _userData = localData;
                _isLoading = false;
              });
            }
          }
        }
      } else {
        debugPrint("📱 OFFLINE MODE: Using cached data");
        if (localData != null) {
          _standardizeOvertimeFieldsFromDatabase(localData);
          if (mounted) {
            setState(() {
              _userData = localData;
              _isLoading = false;
            });
          }
        }
      }

      _debugOvertimeAccessFromDatabase();
      _debugUserDataSummary();

    } catch (e) {
      debugPrint("❌ Critical error in _fetchUserData: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    await _checkLineManagerStatus();

    await _checkOvertimeApproverStatus();

    debugPrint("=== FETCH USER DATA COMPLETE ===");

    debugPrint("🕐 Starting work schedule fetch...");
    _fetchWorkSchedule();
  }




  void _showAttendanceAnalytics() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Loading analytics..."),
            ],
          ),
        ),
      );

      final attendanceRepo = getIt<AttendanceRepository>();

      // Get current month statistics
      DateTime now = DateTime.now();
      Map<String, dynamic> currentMonthStats = await attendanceRepo.getAttendanceStatistics(
        employeeId: widget.employeeId,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      );

      // Get last month statistics for comparison
      DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
      Map<String, dynamic> lastMonthStats = await attendanceRepo.getAttendanceStatistics(
        employeeId: widget.employeeId,
        startDate: lastMonth,
        endDate: DateTime(now.year, now.month, 0),
      );

      Navigator.pop(context); // Close loading dialog

      // Show analytics dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Attendance Analytics"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Current Month (${DateFormat('MMMM yyyy').format(now)})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildAnalyticsRow("Present Days", "${currentMonthStats['presentDays'] ?? 0}"),
                  _buildAnalyticsRow("Total Hours", "${(currentMonthStats['totalHours'] ?? 0).toStringAsFixed(1)}h"),
                  _buildAnalyticsRow("Overtime Hours", "${(currentMonthStats['totalOvertimeHours'] ?? 0).toStringAsFixed(1)}h"),
                  _buildAnalyticsRow("Attendance Rate", "${(currentMonthStats['attendancePercentage'] ?? 0).toStringAsFixed(1)}%"),
                  _buildAnalyticsRow("On-Time Rate", "${(currentMonthStats['onTimePercentage'] ?? 0).toStringAsFixed(1)}%"),
                  _buildAnalyticsRow("Unique Locations", "${currentMonthStats['uniqueLocationsCount'] ?? 0}"),

                  const SizedBox(height: 16),
                  Text("Last Month Comparison",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildComparisonRow("Present Days",
                      currentMonthStats['presentDays'] ?? 0,
                      lastMonthStats['presentDays'] ?? 0),
                  _buildComparisonRow("Total Hours",
                      currentMonthStats['totalHours'] ?? 0.0,
                      lastMonthStats['totalHours'] ?? 0.0),
                  _buildComparisonRow("Attendance Rate",
                      currentMonthStats['attendancePercentage'] ?? 0.0,
                      lastMonthStats['attendancePercentage'] ?? 0.0),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      CustomSnackBar.errorSnackBar("Error loading analytics: $e");
    }
  }

  Widget _buildAnalyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, dynamic current, dynamic last) {
    double change = 0.0;
    if (last != null && last != 0) {
      change = ((current - last) / last) * 100;
    }

    Color changeColor = change > 0 ? Colors.green : (change < 0 ? Colors.red : Colors.grey);
    String changeText = change > 0 ? '+${change.toStringAsFixed(1)}%' : '${change.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(current.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(changeText, style: TextStyle(color: changeColor, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

// 🆕 NEW: Force sync all data
  Future<void> _forceSyncAllData() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Syncing all data..."),
            ],
          ),
        ),
      );

      // Perform comprehensive sync
      final syncService = getIt<SyncService>();
      bool success = await syncService.manualSync();

      // Also force refresh dashboard data
      await _forceAttendanceSync();

      Navigator.pop(context); // Close loading dialog

      if (success) {
        CustomSnackBar.successSnackBar("All data synchronized successfully!");
      } else {
        CustomSnackBar.errorSnackBar("Some data failed to sync. Check debug screen for details.");
      }

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      CustomSnackBar.errorSnackBar("Sync error: $e");
    }
  }

// 🆕 NEW: Show developer console (for advanced debugging)
  void _showDeveloperConsole() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Developer Console"),
        content: const Text(
            "This section contains advanced debugging tools and system information.\n\n"
                "• View real-time logs\n"
                "• Database schema information\n"
                "• Network request monitoring\n"
                "• Performance metrics\n\n"
                "This feature is currently in development."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement advanced developer console
              CustomSnackBar.infoSnackBar("Developer console coming soon!");
            },
            child: const Text("Open Console"),
          ),
        ],
      ),
    );
  }

  void _standardizeOvertimeFieldsFromDatabase(Map<String, dynamic> data) {
    debugPrint("🔧 STANDARDIZING OVERTIME FIELDS (DATABASE ONLY)");

    List<String> accessFields = [
      'hasOvertimeAccess',
      'hasOvertimeApprovalAccess',
      'overtime_access',
      'overtimeAccess',
      'canRequestOvertime',
      'has_overtime_access',
      'allowOvertimeRequests',
    ];

    List<String> grantedFields = [
      'overtimeAccessGrantedAt',
      'overtime_access_granted_at',
      'overtimeGrantedAt',
      'granted_at',
      'accessGrantedDate',
      'overtimeApprovedDate',
    ];

    bool hasAccess = false;
    String? foundAccessField;
    for (String field in accessFields) {
      var value = data[field];
      if (value == true || value == 'true' || value == 1 || value == '1') {
        hasAccess = true;
        foundAccessField = field;
        debugPrint("  ✅ Found database access via field: $field = $value");
        break;
      }
    }

    bool hasGrantedDate = false;
    dynamic grantedValue;
    String? foundGrantedField;
    for (String field in grantedFields) {
      var value = data[field];
      if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
        hasGrantedDate = true;
        grantedValue = value;
        foundGrantedField = field;
        debugPrint("  ✅ Found database granted date via field: $field = $value");
        break;
      }
    }

    bool finalOvertimeAccess = hasAccess || hasGrantedDate;

    debugPrint("  📊 DATABASE ACCESS DECISION:");
    debugPrint("    - hasAccess: $hasAccess ${foundAccessField != null ? '($foundAccessField)' : ''}");
    debugPrint("    - hasGrantedDate: $hasGrantedDate ${foundGrantedField != null ? '($foundGrantedField)' : ''}");
    debugPrint("    - FINAL RESULT: $finalOvertimeAccess");

    data['hasOvertimeAccess'] = finalOvertimeAccess;
    data['standardizedOvertimeAccess'] = finalOvertimeAccess;

    if (hasGrantedDate && grantedValue != null) {
      data['overtimeAccessGrantedAt'] = grantedValue;
    }

    data['overtimeAccessSource'] = foundAccessField ?? foundGrantedField ?? 'none';
  }

  void _debugOvertimeAccessFromDatabase() {
    if (_userData == null) return;

    debugPrint("=== 🔍 DATABASE OVERTIME ACCESS DEBUG ===");
    debugPrint("Employee ID: ${widget.employeeId}");
    debugPrint("Employee Name: ${_userData!['name']}");
    debugPrint("Department: ${_userData!['department'] ?? _userData!['Department']}");

    debugPrint("--- EXACT DATABASE VALUES ---");
    debugPrint("hasOvertimeAccess: ${_userData!['hasOvertimeAccess']} (${_userData!['hasOvertimeAccess'].runtimeType})");
    debugPrint("overtimeAccessGrantedAt: ${_userData!['overtimeAccessGrantedAt']} (${_userData!['overtimeAccessGrantedAt'].runtimeType})");
    debugPrint("standardizedOvertimeAccess: ${_userData!['standardizedOvertimeAccess']}");
    debugPrint("overtimeAccessSource: ${_userData!['overtimeAccessSource']}");

    List<String> allFields = _userData!.keys.where((key) =>
    key.toLowerCase().contains('overtime') ||
        key.toLowerCase().contains('access')).toList();

    debugPrint("--- ALL OVERTIME-RELATED FIELDS FROM DATABASE ---");
    for (String field in allFields) {
      debugPrint("  $field: ${_userData![field]}");
    }

    bool hasAccess = _userData!['hasOvertimeAccess'] == true;
    bool hasGrantedAt = _userData!['overtimeAccessGrantedAt'] != null;
    bool hasStandardized = _userData!['standardizedOvertimeAccess'] == true;
    bool databaseResult = hasAccess || hasGrantedAt || hasStandardized;

    debugPrint("🔍 DIRECT DATABASE CHECK:");
    debugPrint("Employee: ${widget.employeeId}");
    debugPrint("  - hasOvertimeAccess: $hasAccess");
    debugPrint("  - overtimeAccessGrantedAt: $hasGrantedAt");
    debugPrint("  - standardizedOvertimeAccess: $hasStandardized");
    debugPrint("  - DATABASE RESULT: $databaseResult");

    debugPrint("=== END DATABASE DEBUG ===");
  }

  void _debugUserDataSummary() {
    if (_userData == null) return;

    debugPrint("=== 📊 USER DATA SUMMARY ===");
    debugPrint("Employee ID: ${widget.employeeId}");
    debugPrint("Employee PIN: ${_userData!['pin']}");
    debugPrint("Employee Name: ${_userData!['name']}");
    debugPrint("Department: ${_userData!['department'] ?? _userData!['Department']}");
    debugPrint("Designation: ${_userData!['designation'] ?? _userData!['title']}");

    debugPrint("--- WORK SCHEDULE FIELDS ---");
    debugPrint("workTiming: ${_userData!['workTiming']}");
    debugPrint("startTime: ${_userData!['startTime']}");
    debugPrint("breakStartTime: ${_userData!['breakStartTime']}");
    debugPrint("breakEndTime: ${_userData!['breakEndTime']}");

    debugPrint("--- OVERTIME ACCESS ---");
    debugPrint("hasOvertimeAccess: ${_userData!['hasOvertimeAccess']}");
    debugPrint("standardizedOvertimeAccess: ${_userData!['standardizedOvertimeAccess']}");

    debugPrint("--- DATA SOURCES ---");
    debugPrint("Total fields: ${_userData!.keys.length}");
    debugPrint("Has image: ${_userData!['image'] != null}");
    debugPrint("Has PIN: ${_userData!['pin'] != null}");

    debugPrint("=== END USER DATA SUMMARY ===");
  }

  Future<void> _validateFaceDataInBackground() async {
    try {
      debugPrint("🔍 Validating face data in background...");

      final secureFaceStorage = getIt<SecureFaceStorageService>();
      bool isValid = await secureFaceStorage.validateLocalFaceData(widget.employeeId);

      if (!isValid) {
        debugPrint("⚠️ Face data validation failed, attempting recovery...");
        bool recovered = await secureFaceStorage.ensureFaceDataAvailable(widget.employeeId);

        if (recovered) {
          debugPrint("✅ Face data successfully recovered in background");
          if (mounted) {
            CustomSnackBar.successSnackBar("Face data restored from cloud");
          }
        } else {
          debugPrint("❌ Face data recovery failed");
        }
      } else {
        debugPrint("✅ Face data validation passed");
      }
    } catch (e) {
      debugPrint("❌ Error during background face data validation: $e");
    }
  }

  Future<void> _checkLineManagerStatus() async {
    try {
      String? employeePin = _userData?['pin']?.toString() ?? widget.employeeId;

      debugPrint("=== CHECKING LINE MANAGER STATUS ===");
      debugPrint("Current Employee ID: ${widget.employeeId}");
      debugPrint("Employee PIN: $employeePin");

      bool isLineManager = false;
      Map<String, dynamic>? foundLineManagerData;
      String? lineManagerDocId;

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        var lineManagersSnapshot = await FirebaseFirestore.instance
            .collection('line_managers')
            .get();

        for (var doc in lineManagersSnapshot.docs) {
          Map<String, dynamic> data = doc.data();
          String managerId = data['managerId'] ?? '';

          if (managerId == widget.employeeId ||
              managerId == 'EMP${widget.employeeId}' ||
              managerId == 'EMP$employeePin' ||
              (employeePin != null && managerId == employeePin)) {
            isLineManager = true;
            lineManagerDocId = doc.id;
            foundLineManagerData = data;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLineManager = isLineManager;
          _lineManagerDocumentId = lineManagerDocId;
          _lineManagerData = foundLineManagerData;
        });
      }

      _handleLineManagerStatusDetermined(_isLineManager);

    } catch (e) {
      debugPrint("❌ ERROR checking line manager status: $e");
      if (mounted) {
        setState(() {
          _isLineManager = false;
          _lineManagerData = null;
        });
      }
    }
  }

  Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      // ✅ Convert Timestamps BEFORE encoding
      Map<String, dynamic> cleanData = _convertTimestampsForLocalStorage(userData);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_${widget.employeeId}', jsonEncode(cleanData));
      await prefs.setString('user_name_${widget.employeeId}', userData['name'] ?? '');

      debugPrint("💾 User data saved locally for ID: ${widget.employeeId}");
    } catch (e) {
      debugPrint('❌ Error saving user data locally: $e');
    }
  }

  Future<Map<String, dynamic>?> _getUserDataLocally() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user_data_${widget.employeeId}');

      if (userData != null) {
        Map<String, dynamic> data = jsonDecode(userData) as Map<String, dynamic>;
        debugPrint("📱 Retrieved complete user data from local storage");
        return data;
      }

      String? userName = prefs.getString('user_name_${widget.employeeId}');
      if (userName != null && userName.isNotEmpty) {
        return {'name': userName};
      }

      debugPrint("📱 No local user data found for ID: ${widget.employeeId}");
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user data locally: $e');
      return null;
    }
  }



// Add this new method to sync monitoring state
  Future<void> _fetchAttendanceStatus() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint("🔍 === FETCHING ATTENDANCE STATUS (COMPLETE FIXED) ===");
      debugPrint("Employee ID: ${widget.employeeId}");
      debugPrint("Date: $today");
      debugPrint("Connectivity: ${_connectivityService.currentStatus}");

      // Step 1: ALWAYS check local data first (highest priority)
      final localRecord = await _attendanceRepository.getTodaysAttendance(widget.employeeId);

      bool localCheckedIn = false;
      DateTime? localCheckInTime;
      bool hasUnsynced = false;

      if (localRecord != null) {
        localCheckedIn = localRecord.hasCheckIn && !localRecord.hasCheckOut;
        hasUnsynced = !localRecord.isSynced;

        if (localCheckedIn && localRecord.checkIn != null) {
          try {
            localCheckInTime = DateTime.parse(localRecord.checkIn!);
          } catch (e) {
            debugPrint("❌ Error parsing local check-in time: $e");
            localCheckedIn = false;
          }
        }

        debugPrint("📱 LOCAL DATA:");
        debugPrint("  - Checked in: $localCheckedIn");
        debugPrint("  - Check-in time: $localCheckInTime");
        debugPrint("  - Is synced: ${!hasUnsynced}");
        debugPrint("  - Has unsynced data: $hasUnsynced");
      } else {
        debugPrint("📱 LOCAL DATA: No record found");
      }

      // Step 2: If offline OR local has unsynced data, use local as authoritative
      if (_connectivityService.currentStatus == ConnectionStatus.offline || hasUnsynced) {
        debugPrint("🏠 USING LOCAL DATA AS AUTHORITATIVE");
        debugPrint("  Reason: ${_connectivityService.currentStatus == ConnectionStatus.offline ? 'OFFLINE' : 'UNSYNCED LOCAL DATA'}");

        if (mounted) {
          setState(() {
            _isCheckedIn = localCheckedIn;
            _checkInTime = localCheckInTime;
          });
        }

        // Sync monitoring with local state
        await _syncMonitoringWithAttendanceState(localCheckedIn);
        debugPrint("✅ Using local data - State: ${localCheckedIn ? 'CHECKED IN' : 'CHECKED OUT'}");
        return;
      }

      // Step 3: If online and no unsynced local data, check Firestore
      bool firestoreCheckedIn = false;
      DateTime? firestoreCheckInTime;
      bool firestoreDataExists = false;

      try {
        debugPrint("🌐 Checking Firestore data...");
        DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
            .collection('Attendance_Records')
            .doc('PTSEmployees')
            .collection('Records')
            .doc('${widget.employeeId}-$today')
            .get()
            .timeout(const Duration(seconds: 8));

        if (attendanceDoc.exists) {
          firestoreDataExists = true;
          Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;

          DateTime? fsCheckIn;
          DateTime? fsCheckOut;

          // Parse check-in
          if (data['checkIn'] != null) {
            if (data['checkIn'] is Timestamp) {
              fsCheckIn = (data['checkIn'] as Timestamp).toDate();
            } else if (data['checkIn'] is String) {
              try {
                fsCheckIn = DateTime.parse(data['checkIn']);
              } catch (e) {
                debugPrint("❌ Error parsing Firestore checkIn: $e");
              }
            }
          }

          // Parse check-out
          if (data['checkOut'] != null) {
            if (data['checkOut'] is Timestamp) {
              fsCheckOut = (data['checkOut'] as Timestamp).toDate();
            } else if (data['checkOut'] is String) {
              try {
                fsCheckOut = DateTime.parse(data['checkOut']);
              } catch (e) {
                debugPrint("❌ Error parsing Firestore checkOut: $e");
              }
            }
          }

          firestoreCheckedIn = fsCheckIn != null && fsCheckOut == null;
          firestoreCheckInTime = fsCheckIn;

          debugPrint("🌐 FIRESTORE DATA:");
          debugPrint("  - Document exists: true");
          debugPrint("  - Checked in: $firestoreCheckedIn");
          debugPrint("  - Check-in time: $firestoreCheckInTime");
          debugPrint("  - Check-out time: $fsCheckOut");

          // Update local cache with Firestore data
          await _updateRepositoryCache(data, today);
        } else {
          debugPrint("🌐 FIRESTORE DATA: No document found");
        }
      } catch (e) {
        debugPrint("❌ Error fetching Firestore data: $e");
      }

      // Step 4: Determine final state with priority logic
      bool finalCheckedIn;
      DateTime? finalCheckInTime;
      String source;

      if (localRecord != null && localRecord.isSynced && firestoreDataExists && firestoreCheckedIn != localCheckedIn) {
        // Data mismatch between synced local and Firestore - Firestore wins (more recent)
        finalCheckedIn = firestoreCheckedIn;
        finalCheckInTime = firestoreCheckInTime;
        source = "Firestore (resolved conflict)";
        debugPrint("⚠️ Conflict resolved: Local=$localCheckedIn, Firestore=$firestoreCheckedIn -> Using Firestore");
      } else if (localRecord != null) {
        // Use local data (synced or unsynced)
        finalCheckedIn = localCheckedIn;
        finalCheckInTime = localCheckInTime;
        source = "Local (${localRecord.isSynced ? 'synced' : 'unsynced'})";
      } else if (firestoreDataExists) {
        // No local data, use Firestore
        finalCheckedIn = firestoreCheckedIn;
        finalCheckInTime = firestoreCheckInTime;
        source = "Firestore (no local data)";
      } else {
        // No data anywhere - fresh start
        finalCheckedIn = false;
        finalCheckInTime = null;
        source = "Default (no data found)";
      }

      debugPrint("🎯 FINAL DECISION:");
      debugPrint("  - State: ${finalCheckedIn ? 'CHECKED IN' : 'CHECKED OUT'}");
      debugPrint("  - Source: $source");
      debugPrint("  - Check-in time: $finalCheckInTime");

      // Step 5: Update UI state only if changed
      bool stateChanged = _isCheckedIn != finalCheckedIn;
      bool timeChanged = _checkInTime != finalCheckInTime;

      if (stateChanged || timeChanged) {
        debugPrint("🔄 State changed - updating UI");
        if (mounted) {
          setState(() {
            _isCheckedIn = finalCheckedIn;
            _checkInTime = finalCheckInTime;
          });
        }
      } else {
        debugPrint("✅ State unchanged - no UI update needed");
      }

      // Step 6: Sync monitoring with final state
      await _syncMonitoringWithAttendanceState(finalCheckedIn);

      debugPrint("✅ Attendance status fetch completed successfully");

    } catch (e) {
      debugPrint("❌ Critical error in _fetchAttendanceStatus: $e");
      debugPrint("Stack trace: ${StackTrace.current}");

      // Fallback to local data if available
      try {
        debugPrint("🔄 Attempting fallback to local data...");
        final localRecord = await _attendanceRepository.getTodaysAttendance(widget.employeeId);
        if (localRecord != null && mounted) {
          bool fallbackState = localRecord.hasCheckIn && !localRecord.hasCheckOut;
          DateTime? fallbackTime;

          if (fallbackState && localRecord.checkIn != null) {
            try {
              fallbackTime = DateTime.parse(localRecord.checkIn!);
            } catch (parseError) {
              debugPrint("❌ Error parsing fallback time: $parseError");
              fallbackState = false;
            }
          }

          setState(() {
            _isCheckedIn = fallbackState;
            _checkInTime = fallbackTime;
          });

          await _syncMonitoringWithAttendanceState(fallbackState);
          debugPrint("✅ Fallback successful: ${fallbackState ? 'CHECKED IN' : 'CHECKED OUT'}");
        } else {
          debugPrint("❌ No fallback data available");
          if (mounted) {
            setState(() {
              _isCheckedIn = false;
              _checkInTime = null;
            });
          }
          await _syncMonitoringWithAttendanceState(false);
        }
      } catch (fallbackError) {
        debugPrint("❌ Fallback also failed: $fallbackError");
        // Final safety - ensure user can still use app
        if (mounted) {
          setState(() {
            _isCheckedIn = false;
            _checkInTime = null;
          });
        }
      }
    }
  }

// Helper method to sync monitoring state
  Future<void> _syncMonitoringWithAttendanceState(bool isCheckedIn) async {
    try {
      debugPrint("🔄 Syncing monitoring with attendance state: $isCheckedIn");
      debugPrint("  Current monitoring active: $_isGeofenceMonitoringActive");

      if (isCheckedIn && !_isGeofenceMonitoringActive) {
        // Should be monitoring but isn't
        debugPrint("🛡️ Starting monitoring - user is checked in");
        await _startGeofenceExitMonitoring();
      } else if (!isCheckedIn && _isGeofenceMonitoringActive) {
        // Shouldn't be monitoring but is
        debugPrint("🛑 Stopping monitoring - user is checked out");
        await _stopGeofenceExitMonitoring();
      } else {
        debugPrint("✅ Monitoring state is already correct");
      }
    } catch (e) {
      debugPrint("❌ Error syncing monitoring state: $e");
    }
  }

// Helper method for offline state restoration
  Future<void> _handleOfflineStateRestoration() async {
    try {
      debugPrint("📱 Handling offline state restoration...");

      final localRecord = await _attendanceRepository.getTodaysAttendance(widget.employeeId);

      if (localRecord != null) {
        bool shouldBeCheckedIn = localRecord.hasCheckIn && !localRecord.hasCheckOut;
        DateTime? checkInTime;

        if (shouldBeCheckedIn && localRecord.checkIn != null) {
          try {
            checkInTime = DateTime.parse(localRecord.checkIn!);
          } catch (e) {
            debugPrint("Error parsing offline check-in time: $e");
            shouldBeCheckedIn = false;
          }
        }

        debugPrint("📱 OFFLINE STATE RESTORATION:");
        debugPrint("  - Local record exists: true");
        debugPrint("  - Should be checked in: $shouldBeCheckedIn");
        debugPrint("  - Check-in time: $checkInTime");
        debugPrint("  - Is synced: ${localRecord.isSynced}");

        if (mounted) {
          setState(() {
            _isCheckedIn = shouldBeCheckedIn;
            _checkInTime = checkInTime;
          });
        }

        // Start/stop monitoring based on offline state
        await _syncMonitoringWithAttendanceState(shouldBeCheckedIn);

        debugPrint("✅ Offline state restoration completed");

        // Show user feedback about offline mode
        if (!localRecord.isSynced) {
          CustomSnackBar.infoSnackBar("Working offline - data will sync when connected");
        }

      } else {
        debugPrint("📱 No local record found for offline restoration");

        if (mounted) {
          setState(() {
            _isCheckedIn = false;
            _checkInTime = null;
          });
        }

        // Ensure monitoring is stopped if no local record
        await _syncMonitoringWithAttendanceState(false);
      }

    } catch (e) {
      debugPrint("❌ Error in offline state restoration: $e");
    }
  }

// Also add this method to ensure proper initialization
  Future<void> _initializeAttendanceState() async {
    try {
      debugPrint("🚀 Initializing attendance state on app start...");

      // Clear any existing state
      _isCheckedIn = false;
      _checkInTime = null;
      _isGeofenceMonitoringActive = false;

      // Fetch fresh state
      await _fetchAttendanceStatus();

      debugPrint("✅ Attendance state initialization completed");
    } catch (e) {
      debugPrint("❌ Error initializing attendance state: $e");
    }
  }


  Future<void> _updateRepositoryCache(Map<String, dynamic> firestoreData, String date) async {
    try {
      debugPrint("🔄 === UPDATING REPOSITORY CACHE (ENHANCED) ===");

      // Create clean data for local storage
      Map<String, dynamic> localData = {};

      // Copy all non-timestamp fields
      firestoreData.forEach((key, value) {
        if (value is! Timestamp) {
          localData[key] = value;
        }
      });

      // Handle timestamps with validation
      if (firestoreData['checkIn'] != null) {
        if (firestoreData['checkIn'] is Timestamp) {
          DateTime checkInDate = (firestoreData['checkIn'] as Timestamp).toDate();
          localData['checkIn'] = checkInDate.toIso8601String();
          debugPrint("✅ Converted checkIn: ${localData['checkIn']}");
        } else {
          localData['checkIn'] = firestoreData['checkIn'].toString();
        }
      }

      if (firestoreData['checkOut'] != null) {
        if (firestoreData['checkOut'] is Timestamp) {
          DateTime checkOutDate = (firestoreData['checkOut'] as Timestamp).toDate();
          localData['checkOut'] = checkOutDate.toIso8601String();
          debugPrint("✅ Converted checkOut: ${localData['checkOut']}");
        } else {
          localData['checkOut'] = firestoreData['checkOut'].toString();
        }
      }

      // Validate data integrity
      if (localData['checkIn'] != null && localData['checkOut'] != null) {
        try {
          DateTime checkInTime = DateTime.parse(localData['checkIn']);
          DateTime checkOutTime = DateTime.parse(localData['checkOut']);

          if (checkOutTime.isBefore(checkInTime)) {
            debugPrint("🚨 Invalid data: Check-out before check-in - removing check-out");
            localData.remove('checkOut');
          }
        } catch (e) {
          debugPrint("❌ Error validating timestamps: $e");
        }
      }

      // Create and save record
      LocalAttendanceRecord record = LocalAttendanceRecord(
        employeeId: widget.employeeId,
        date: localData['date'] ?? date,
        checkIn: localData['checkIn']?.toString(),
        checkOut: localData['checkOut']?.toString(),
        checkInLocationId: localData['checkInLocation']?.toString(),
        checkOutLocationId: localData['checkOutLocation']?.toString(),
        checkInLocationName: localData['checkInLocationName']?.toString(),
        checkOutLocationName: localData['checkOutLocationName']?.toString(),
        isSynced: true,
        rawData: localData,
      );

      // Atomic database update
      final dbHelper = getIt<DatabaseHelper>();
      await dbHelper.database.then((db) async {
        await db.transaction((txn) async {
          await txn.delete(
            'attendance',
            where: 'employee_id = ? AND date = ?',
            whereArgs: [widget.employeeId, date],
          );
          await txn.insert('attendance', record.toMap());
        });
      });

      debugPrint("✅ Repository cache updated with integrity checks");

    } catch (e) {
      debugPrint("❌ Error updating repository cache: $e");
    }
  }



  Future<void> _verifyAndFixAttendanceState() async {
    try {
      debugPrint("🔍 === VERIFYING ATTENDANCE STATE ===");

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get data from all sources
      Map<String, dynamic> firestoreData = {};
      LocalAttendanceRecord? localData;

      // Check Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${widget.employeeId}-$today')
              .get();

          if (doc.exists) {
            firestoreData = doc.data() as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint("Error fetching Firestore data: $e");
        }
      }

      // Check local database
      try {
        localData = await _attendanceRepository.getTodaysAttendance(widget.employeeId);
      } catch (e) {
        debugPrint("Error fetching local data: $e");
      }

      // Compare and determine correct state
      bool firestoreHasCheckIn = false;
      bool firestoreHasCheckOut = false;
      bool localHasCheckIn = false;
      bool localHasCheckOut = false;

      // Parse Firestore data
      if (firestoreData.isNotEmpty) {
        firestoreHasCheckIn = firestoreData['checkIn'] != null;
        firestoreHasCheckOut = firestoreData['checkOut'] != null;
      }

      // Parse local data
      if (localData != null) {
        localHasCheckIn = localData.checkIn != null;
        localHasCheckOut = localData.checkOut != null;
      }

      debugPrint("📊 STATE COMPARISON:");
      debugPrint("  Dashboard state: $_isCheckedIn");
      debugPrint("  Firestore: checkIn=$firestoreHasCheckIn, checkOut=$firestoreHasCheckOut");
      debugPrint("  Local DB: checkIn=$localHasCheckIn, checkOut=$localHasCheckOut");

      // Determine the TRUTH (priority: Firestore > Local > Dashboard)
      bool correctState = false;
      DateTime? correctCheckInTime;

      if (firestoreData.isNotEmpty) {
        // Use Firestore as source of truth
        if (firestoreHasCheckIn && !firestoreHasCheckOut) {
          correctState = true;
          try {
            if (firestoreData['checkIn'] is Timestamp) {
              correctCheckInTime = (firestoreData['checkIn'] as Timestamp).toDate();
            } else if (firestoreData['checkIn'] is String) {
              correctCheckInTime = DateTime.parse(firestoreData['checkIn']);
            }
          } catch (e) {
            debugPrint("Error parsing check-in time: $e");
          }
        }
      } else if (localData != null) {
        // Fallback to local data
        if (localHasCheckIn && !localHasCheckOut) {
          correctState = true;
          try {
            correctCheckInTime = DateTime.parse(localData.checkIn!);
          } catch (e) {
            debugPrint("Error parsing local check-in time: $e");
          }
        }
      }

      // Fix dashboard state if incorrect
      bool timeIncorrect = false;
      if (correctState && _checkInTime != null && correctCheckInTime != null) {
        int timeDifferenceMinutes = _checkInTime!.difference(correctCheckInTime).abs().inMinutes;
        timeIncorrect = timeDifferenceMinutes > 5;
      }

      if (_isCheckedIn != correctState || timeIncorrect) {

        debugPrint("🔧 FIXING DASHBOARD STATE:");
        debugPrint("  Changing from: $_isCheckedIn -> $correctState");
        debugPrint("  Time from: $_checkInTime -> $correctCheckInTime");

        setState(() {
          _isCheckedIn = correctState;
          _checkInTime = correctCheckInTime;
        });

        // Show user notification about state correction
        if (mounted) {
          CustomSnackBar.infoSnackBar(
              correctState
                  ? "✅ State corrected: You are checked in"
                  : "✅ State corrected: You are checked out"
          );
        }
      } else {
        debugPrint("✅ Dashboard state is correct");
      }

    } catch (e) {
      debugPrint("❌ Error in state verification: $e");
    }
  }


  Map<String, dynamic> _convertTimestampsForLocalStorage(Map<String, dynamic> data) {
    Map<String, dynamic> cleanData = Map<String, dynamic>.from(data);

    // Convert all Timestamp fields to ISO strings
    cleanData.forEach((key, value) {
      if (value is Timestamp) {
        cleanData[key] = value.toDate().toIso8601String();
        debugPrint("🔄 Converted $key from Timestamp to: ${cleanData[key]}");
      }
    });

    return cleanData;
  }

  Future<void> _saveAttendanceStatusLocally(String date, Map<String, dynamic> data) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ✅ Convert Timestamps BEFORE encoding
      Map<String, dynamic> cleanData = _convertTimestampsForLocalStorage(data);

      await prefs.setString('attendance_${widget.employeeId}_$date', jsonEncode(cleanData));
      debugPrint("✅ Attendance status saved locally for date: $date");
    } catch (e) {
      debugPrint('❌ Error saving attendance status locally: $e');
    }
  }




  // lib/dashboard/dashboard_view.dart - REQUIRED CHANGES ONLY

// ================ REPLACE THE _handleCheckInOut METHOD ================

  /// Enhanced check in/out handler with proper authentication flow
  Future<void> _handleCheckInOut() async {
    if (_isAuthenticating || !mounted) {
      debugPrint("⚠️ Already authenticating or widget unmounted");
      return;
    }

    debugPrint("🔄 Starting ${_isCheckedIn ? 'check-out' : 'check-in'} process...");

    if (!_isCheckedIn) {
      // ================ CHECK-IN FLOW ================
      debugPrint("✅ Starting check-in process...");

      // Fast location check using cached data
      if (!_isWithinGeofence) {
        _showLocationErrorDialog("check-in");
        return;
      }

      // Validate work schedule timing if available
      if (_workSchedule != null) {
        DateTime checkInTime = DateTime.now();
        ScheduleCheckResult result = WorkScheduleService.checkCheckInTiming(_workSchedule!, checkInTime);
        bool shouldProceed = await _showTimingValidationDialog(result);
        if (!shouldProceed) return;
      }

      if (!mounted) return;

      // 🔥 NEW: Set authenticating state and show immediate UI feedback
      setState(() => _isAuthenticating = true);

      // Show immediate feedback
      CustomSnackBar.infoSnackBar("Authenticating for check-in...");

      try {
        // Navigate to face authentication
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => AuthenticateFaceView(
              employeeId: widget.employeeId,
              actionType: 'check_in',
              onAuthenticationComplete: (bool success) {
                debugPrint("📞 Check-in authentication callback: $success");
              },
            ),
          ),
        );

        if (!mounted) return;

        debugPrint("🔍 Check-in authentication result: $result");

        if (result == true) {
          debugPrint("✅ Face authentication successful for check-in");

          // 🔥 CRITICAL FIX: Update UI state IMMEDIATELY
          DateTime checkInTime = DateTime.now();
          setState(() {
            _isCheckedIn = true;
            _checkInTime = checkInTime;
            _isAuthenticating = false;
          });

          // Show immediate success feedback
          String locationName = _nearestLocation?.name ?? 'office location';
          CustomSnackBar.successSnackBar("✅ Checked in at $locationName (${DateFormat('h:mm a').format(checkInTime)})");

          // Start monitoring immediately after UI update
          await _startGeofenceExitMonitoring();

          // Database operations happen in background
          unawaited(_processCheckInInBackground(checkInTime));

        } else {
          setState(() => _isAuthenticating = false);
          debugPrint("❌ Face authentication failed for check-in");
          CustomSnackBar.errorSnackBar("Face authentication failed. Please try again.");
        }
      } catch (e) {
        setState(() => _isAuthenticating = false);
        debugPrint("❌ Error during check-in: $e");
        CustomSnackBar.errorSnackBar("Check-in failed: $e");
      }

    } else {
      // ================ CHECK-OUT FLOW ================
      debugPrint("✅ Starting check-out process...");

      // Store original state for potential rollback
      DateTime? originalCheckInTime = _checkInTime;

      // Fast location check using cached data
      if (!_isWithinGeofence) {
        _showLocationErrorDialog("check-out");
        return;
      }

      // Validate work schedule timing if available
      if (_workSchedule != null) {
        DateTime checkOutTime = DateTime.now();
        ScheduleCheckResult result = WorkScheduleService.checkCheckOutTiming(_workSchedule!, checkOutTime);
        bool shouldProceed = await _showTimingValidationDialog(result);
        if (!shouldProceed) return;
      }

      if (!mounted) return;

      // 🔥 NEW: Set authenticating state and show immediate UI feedback
      setState(() => _isAuthenticating = true);

      // Show immediate feedback
      CustomSnackBar.infoSnackBar("Authenticating for check-out...");

      try {
        // Navigate to face authentication
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => AuthenticateFaceView(
              employeeId: widget.employeeId,
              actionType: 'check_out',
              onAuthenticationComplete: (bool success) {
                debugPrint("📞 Check-out authentication callback: $success");
              },
            ),
          ),
        );

        if (!mounted) return;

        debugPrint("🔍 Check-out authentication result: $result");

        if (result == true) {
          debugPrint("✅ Face authentication successful for check-out");

          // 🔥 CRITICAL FIX: Update UI state IMMEDIATELY
          DateTime checkOutTime = DateTime.now();
          setState(() {
            _isCheckedIn = false;
            _checkInTime = null;
            _isAuthenticating = false;
          });

          // Show immediate success feedback
          String locationName = _nearestLocation?.name ?? 'office location';
          CustomSnackBar.successSnackBar("✅ Checked out from $locationName (${DateFormat('h:mm a').format(checkOutTime)})");

          // Stop monitoring immediately after UI update
          await _stopGeofenceExitMonitoring();

          // Database operations happen in background
          unawaited(_processCheckOutInBackground(checkOutTime));

        } else {
          setState(() => _isAuthenticating = false);
          debugPrint("❌ Face authentication failed for check-out");
          CustomSnackBar.errorSnackBar("Face authentication failed. Please try again.");
        }
      } catch (e) {
        setState(() => _isAuthenticating = false);
        debugPrint("❌ Error during check-out: $e");
        CustomSnackBar.errorSnackBar("Check-out failed: $e");
      }
    }
  }

  /// Background check-in processing (doesn't affect UI)
  Future<void> _processCheckInInBackground(DateTime checkInTime) async {
    try {
      debugPrint("🔄 Processing check-in in background...");

      Position? currentPosition = await GeofenceUtil.getCurrentPosition();
      String locationId = _nearestLocation?.id ?? 'default';
      String locationName = _nearestLocation?.name ?? 'Unknown Location';

      // Database operations
      bool checkInSuccess = await _attendanceRepository.recordCheckIn(
        employeeId: widget.employeeId,
        checkInTime: checkInTime,
        locationId: locationId,
        locationName: locationName,
        locationLat: currentPosition?.latitude ?? _nearestLocation?.latitude ?? 0.0,
        locationLng: currentPosition?.longitude ?? _nearestLocation?.longitude ?? 0.0,
        additionalData: {
          'checkInMethod': 'face_authentication',
          'deviceInfo': 'mobile_app',
          'geofenceStatus': _isWithinGeofence ? 'inside' : 'outside',
          'distanceToOffice': _distanceToOffice,
          'locationAddress': _nearestLocation?.address ?? 'Unknown Address',
          'locationRadius': _nearestLocation?.radius ?? 0,
        },
      );

      if (!checkInSuccess && mounted) {
        // 🔥 ROLLBACK: If database write fails, revert UI state
        debugPrint("❌ Check-in database write failed - reverting UI state");
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
        await _stopGeofenceExitMonitoring();
        CustomSnackBar.errorSnackBar("❌ Failed to record check-in. Please try again.");
        return;
      }

      debugPrint("✅ Check-in background processing completed");

      // Refresh activity in background (optional)
      unawaited(_fetchTodaysActivity());

    } catch (e) {
      debugPrint("❌ Error in background check-in processing: $e");

      // 🔥 ROLLBACK: Revert UI state on error
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
        await _stopGeofenceExitMonitoring();
        CustomSnackBar.errorSnackBar("Check-in error: $e");
      }
    }
  }

  /// Background check-out processing (doesn't affect UI)
  Future<void> _processCheckOutInBackground(DateTime checkOutTime) async {
    try {
      debugPrint("🔄 Processing check-out in background...");

      Position? currentPosition = await GeofenceUtil.getCurrentPosition();
      String locationId = _nearestLocation?.id ?? 'default';
      String locationName = _nearestLocation?.name ?? 'Unknown Location';

      // Database operations
      bool checkOutSuccess = await _attendanceRepository.recordCheckOut(
        employeeId: widget.employeeId,
        checkOutTime: checkOutTime,
        locationId: locationId,
        locationName: locationName,
        locationLat: currentPosition?.latitude ?? _nearestLocation?.latitude ?? 0.0,
        locationLng: currentPosition?.longitude ?? _nearestLocation?.longitude ?? 0.0,
        additionalData: {
          'checkOutMethod': 'face_authentication',
          'deviceInfo': 'mobile_app',
          'geofenceStatus': _isWithinGeofence ? 'inside' : 'outside',
          'distanceToOffice': _distanceToOffice,
          'locationAddress': _nearestLocation?.address ?? 'Unknown Address',
          'locationRadius': _nearestLocation?.radius ?? 0,
        },
      );

      if (!checkOutSuccess && mounted) {
        // 🔥 ROLLBACK: If database write fails, revert UI state
        debugPrint("❌ Check-out database write failed - reverting UI state");
        setState(() {
          _isCheckedIn = true;
          _checkInTime = _checkInTime; // Restore original time
        });
        await _startGeofenceExitMonitoring();
        CustomSnackBar.errorSnackBar("❌ Failed to record check-out. Please try again.");
        return;
      }

      debugPrint("✅ Check-out background processing completed");

      // Refresh activity in background (optional)
      unawaited(_fetchTodaysActivity());

    } catch (e) {
      debugPrint("❌ Error in background check-out processing: $e");

      // 🔥 ROLLBACK: Revert UI state on error
      if (mounted) {
        setState(() {
          _isCheckedIn = true;
          // Note: We need to store original check-in time to restore properly
        });
        await _startGeofenceExitMonitoring();
        CustomSnackBar.errorSnackBar("Check-out error: $e");
      }
    }
  }

// 🆕 ADD: Location error dialog method
  void _showLocationErrorDialog(String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_off, color: Colors.orange, size: 24),
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                "Location Required",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "You need to be at the office location to $action.",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            SizedBox(height: containerSpacing),
            if (_distanceToOffice != null)
              Container(
                padding: EdgeInsets.all(containerSpacing),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You are ${_distanceToOffice!.toStringAsFixed(0)}m away from the office. Please move closer and try again.",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(containerSpacing),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Tap 'Refresh Location' to check your current position.",
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Refresh Location"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              if (mounted) {
                setState(() {
                  _isCheckingLocation = true;
                });
              }

              // Force fresh location check
              _isLocationCacheValid = false; // Clear cache
              await _checkGeofenceStatus();

              // Show result to user
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  if (_isWithinGeofence) {
                    CustomSnackBar.successSnackBar("✅ Location updated! You're now at the office.");
                  } else {
                    String message = "❌ Still outside office location";
                    if (_distanceToOffice != null) {
                      message += " (${_distanceToOffice!.toStringAsFixed(0)}m away)";
                    }
                    CustomSnackBar.errorSnackBar(message);
                  }
                }
              });
            },
          ),
        ],
      ),
    );
  }

// ================ ADD THESE NEW METHODS ================

  /// Process check-in after successful authentication
  Future<void> _processCheckIn() async {
    try {
      debugPrint("🚀 === PROCESSING CHECK-IN WITH IMMEDIATE UI UPDATE ===");

      Position? currentPosition = await GeofenceUtil.getCurrentPosition();
      String locationId = _nearestLocation?.id ?? 'default';
      String locationName = _nearestLocation?.name ?? 'Unknown Location';

      // ✅ CRITICAL: Update UI state IMMEDIATELY before any database operations
      DateTime nowTime = DateTime.now();
      if (mounted) {
        setState(() {
          _isCheckedIn = true;
          _checkInTime = nowTime;
        });
      }

      // Show immediate success feedback
      CustomSnackBar.successSnackBar("✅ Checked in successfully at $locationName (${DateFormat('h:mm a').format(nowTime)})");

      await CheckInOutHandler.handleOffLocationAction(
        context: context,
        employeeId: widget.employeeId,
        employeeName: _userData?['name'] ?? 'Employee',
        isWithinGeofence: _isWithinGeofence,
        currentPosition: currentPosition,
        isCheckIn: true,
        onRegularAction: () async {
          debugPrint("🏢 Recording check-in with geofence monitoring...");

          _isLocationCacheValid = false;

          // Database operations happen in background - UI is already updated
          bool checkInSuccess = await _attendanceRepository.recordCheckIn(
            employeeId: widget.employeeId,
            checkInTime: nowTime, // Use the same time as UI
            locationId: locationId,
            locationName: locationName,
            locationLat: currentPosition?.latitude ?? _nearestLocation?.latitude ?? 0.0,
            locationLng: currentPosition?.longitude ?? _nearestLocation?.longitude ?? 0.0,
            additionalData: {
              'checkInMethod': 'face_authentication',
              'deviceInfo': 'mobile_app',
              'geofenceStatus': _isWithinGeofence ? 'inside' : 'outside',
              'distanceToOffice': _distanceToOffice,
              'locationAddress': _nearestLocation?.address ?? 'Unknown Address',
              'locationRadius': _nearestLocation?.radius ?? 0,
            },
          );

          if (!checkInSuccess && mounted) {
            // ✅ ROLLBACK: If database write fails, revert UI state
            debugPrint("❌ Check-in database write failed - reverting UI state");
            setState(() {
              _isCheckedIn = false;
              _checkInTime = null;
            });
            CustomSnackBar.errorSnackBar("❌ Failed to record check-in. Please try again.");
            return;
          }

          // ✅ SUCCESS: Start geofence monitoring after successful DB write
          await _startGeofenceExitMonitoring();
          _setupCheckOutReminder();

          // Background refresh (no UI impact)
          Future.delayed(const Duration(seconds: 3), () async {
            if (mounted) {
              await _fetchTodaysActivity(); // Update activity history only
            }
          });

          debugPrint("✅ Check-in completed successfully with immediate UI update");
        },
      );
    } catch (e) {
      debugPrint("❌ Error processing check-in: $e");

      // ✅ ROLLBACK: Revert UI state on error
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
      }
      CustomSnackBar.errorSnackBar("Check-in error: $e");
    }
  }



  /// Process check-out after successful authentication
  Future<void> _processCheckOut() async {
    try {
      debugPrint("🚀 === PROCESSING CHECK-OUT WITH IMMEDIATE UI UPDATE ===");

      Position? currentPosition = await GeofenceUtil.getCurrentPosition();
      String locationId = _nearestLocation?.id ?? 'default';
      String locationName = _nearestLocation?.name ?? 'Unknown Location';

      // ✅ CRITICAL: Update UI state IMMEDIATELY before any database operations
      DateTime nowTime = DateTime.now();
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
      }

      // Show immediate success feedback
      CustomSnackBar.successSnackBar("✅ Checked out successfully from $locationName (${DateFormat('h:mm a').format(nowTime)})");

      await CheckInOutHandler.handleOffLocationAction(
        context: context,
        employeeId: widget.employeeId,
        employeeName: _userData?['name'] ?? 'Employee',
        isWithinGeofence: _isWithinGeofence,
        currentPosition: currentPosition,
        isCheckIn: false,
        onRegularAction: () async {
          debugPrint("🏃‍♂️ Recording check-out and stopping monitoring...");

          _isLocationCacheValid = false;

          // Database operations happen in background - UI is already updated
          bool checkOutSuccess = await _attendanceRepository.recordCheckOut(
            employeeId: widget.employeeId,
            checkOutTime: nowTime, // Use the same time as UI
            locationId: locationId,
            locationName: locationName,
            locationLat: currentPosition?.latitude ?? _nearestLocation?.latitude ?? 0.0,
            locationLng: currentPosition?.longitude ?? _nearestLocation?.longitude ?? 0.0,
            additionalData: {
              'checkOutMethod': 'face_authentication',
              'deviceInfo': 'mobile_app',
              'geofenceStatus': _isWithinGeofence ? 'inside' : 'outside',
              'distanceToOffice': _distanceToOffice,
              'locationAddress': _nearestLocation?.address ?? 'Unknown Address',
              'locationRadius': _nearestLocation?.radius ?? 0,
            },
          );

          if (!checkOutSuccess && mounted) {
            // ✅ ROLLBACK: If database write fails, revert UI state
            debugPrint("❌ Check-out database write failed - reverting UI state");
            setState(() {
              _isCheckedIn = true;
              _checkInTime = _checkInTime; // Restore previous check-in time
            });
            CustomSnackBar.errorSnackBar("❌ Failed to record check-out. Please try again.");
            return;
          }

          // ✅ SUCCESS: Stop geofence monitoring after successful DB write
          await _stopGeofenceExitMonitoring();
          _checkOutReminderTimer?.cancel();

          // Background refresh (no UI impact)
          Future.delayed(const Duration(seconds: 3), () async {
            if (mounted) {
              await _fetchTodaysActivity(); // Update activity history only
            }
          });

          debugPrint("✅ Check-out completed successfully with immediate UI update");
        },
      );
    } catch (e) {
      debugPrint("❌ Error processing check-out: $e");

      // ✅ ROLLBACK: Revert UI state on error
      if (mounted) {
        setState(() {
          _isCheckedIn = true;
          // Note: We would need to store the original check-in time to restore it properly
          // For now, we'll trigger a state refresh
        });

        // Force refresh to get correct state from database
        await _fetchAttendanceStatus();
      }
      CustomSnackBar.errorSnackBar("Check-out error: $e");
    }
  }

  Future<void> _fetchAttendanceStatusForSync() async {
    try {
      debugPrint("🔄 Fetching attendance status for sync verification only...");

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Only check if there's a data mismatch that needs correction
      final localRecord = await _attendanceRepository.getTodaysAttendance(widget.employeeId);

      if (localRecord != null) {
        bool expectedState = localRecord.hasCheckIn && !localRecord.hasCheckOut;

        // Only update UI if there's a significant mismatch
        if (_isCheckedIn != expectedState) {
          debugPrint("⚠️ UI state mismatch detected - correcting...");

          DateTime? correctCheckInTime;
          if (expectedState && localRecord.checkIn != null) {
            try {
              correctCheckInTime = DateTime.parse(localRecord.checkIn!);
            } catch (e) {
              debugPrint("❌ Error parsing check-in time: $e");
            }
          }

          if (mounted) {
            setState(() {
              _isCheckedIn = expectedState;
              _checkInTime = correctCheckInTime;
            });
          }

          debugPrint("🔧 UI state corrected to match database");
        }
      }

    } catch (e) {
      debugPrint("❌ Error in sync verification: $e");
    }
  }

  DateTime? _originalCheckInTime;


  Future<void> _storeOriginalCheckInState() async {
    _originalCheckInTime = _checkInTime;
  }

// ✅ MODIFIED: Enhanced rollback for check-out
  void _rollbackCheckOutState() {
    if (mounted) {
      setState(() {
        _isCheckedIn = true;
        _checkInTime = _originalCheckInTime;
      });
    }
  }


  Future<void> _startGeofenceExitMonitoring() async {
    // 🔥 CRITICAL FIX: Only start if actually checked in
    if (!_isCheckedIn) {
      debugPrint("⚠️ Not starting geofence monitoring - user is not checked in");
      return;
    }

    try {
      debugPrint("🔄 Starting geofence exit monitoring for checked-in user...");

      String employeeName = _userData?['name'] ?? 'Employee';
      bool started = await _geofenceExitService.startMonitoring(widget.employeeId, employeeName);

      if (started && mounted) {
        setState(() {
          _isGeofenceMonitoringActive = true;
          _monitoringStatus = "Active";
        });

        debugPrint("✅ Geofence exit monitoring started successfully");
        CustomSnackBar.infoSnackBar("🛡️ Phoenician Work area monitoring is now active");

      } else {
        debugPrint("⚠️ Failed to start geofence exit monitoring");
      }

    } catch (e) {
      debugPrint("❌ Error starting geofence exit monitoring: $e");
    }
  }

  // ✅ NEW: Stop geofence exit monitoring
  Future<void> _stopGeofenceExitMonitoring() async {
    try {
      debugPrint("🔄 Stopping geofence exit monitoring...");

      await _geofenceExitService.stopMonitoring();

      if (mounted) {
        setState(() {
          _isGeofenceMonitoringActive = false;
          _monitoringStatus = "Inactive";
        });
      }

      debugPrint("✅ Geofence exit monitoring stopped");

    } catch (e) {
      debugPrint("❌ Error stopping geofence exit monitoring: $e");
    }
  }


  // ✅ NEW: Handle geofence exit notifications (Employee only)
  void _handleGeofenceExitNotification(Map<String, dynamic> data) {
    final notificationType = data['type'];

    if (notificationType == 'geofence_exit_prompt') {
      // Employee needs to provide exit reason
      String eventId = data['eventId'] ?? '';
      _showExitReasonDialog(eventId);
    }
    // Note: No HR notifications since they use separate platform
  }


  void _showExitReasonDialog(String eventId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_searching, color: Colors.blue, size: 24),
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                "Quick Check-in",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Hi ${_userData?['name']?.split(' ').first ?? 'there'}! We noticed you stepped away from the work area.",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This helps us ensure safety and project coordination. Where are you headed?",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: containerSpacing),

            // Quick reason buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickReasonChip("Lunch Break", Icons.restaurant, eventId),
                _buildQuickReasonChip("Client Meeting", Icons.business, eventId),
                _buildQuickReasonChip("Personal Emergency", Icons.emergency, eventId),
                _buildQuickReasonChip("Bathroom Break", Icons.wc, eventId),
                _buildQuickReasonChip("Material Pickup", Icons.inventory, eventId),
                _buildQuickReasonChip("Other", Icons.more_horiz, eventId),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Record "No reason provided" after 30 seconds
              Timer(const Duration(seconds: 30), () {
                _geofenceExitService.recordExitReason(eventId, "no_reason_provided");
              });
            },
            child: Text("Skip", style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }



  Widget _buildQuickReasonChip(String reason, IconData icon, String eventId) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        reason,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: Colors.blue.shade600,
      onPressed: () async {
        Navigator.pop(context);
        _isShowingExitWarning = false;

        // Record the reason
        final geofenceService = getIt<GeofenceExitMonitoringService>();
        await geofenceService.recordExitReason(eventId, reason.toLowerCase().replaceAll(' ', '_'));

        // Show success message
        CustomSnackBar.successSnackBar("Exit reason recorded: $reason");

        // Update UI to show the reason
        setState(() {
          // Trigger refresh of exit events display
        });

        await _loadRecentExitEvents();
      },
    );
  }

  void _scheduleExitReminder(String eventId) {
    _exitWarningTimer?.cancel();
    _exitWarningTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && _currentExitEventId == eventId) {
        CustomSnackBar.infoSnackBar("Don't forget to provide your exit reason!");
      }
    });
  }


  String _getNextGeofenceCheckTime() {
    try {
      final geofenceService = getIt<GeofenceExitMonitoringService>();
      final status = geofenceService.getMonitoringStatus();

      if (status['lastCheck'] != null) {
        final lastCheck = DateTime.parse(status['lastCheck']);
        final intervalMinutes = status['intervalMinutes'] ?? 120;
        final nextCheck = lastCheck.add(Duration(minutes: intervalMinutes));
        final timeUntilNext = nextCheck.difference(DateTime.now());

        if (timeUntilNext.isNegative) {
          return "Now";
        } else if (timeUntilNext.inHours > 0) {
          return "${timeUntilNext.inHours}h ${timeUntilNext.inMinutes % 60}m";
        } else {
          return "${timeUntilNext.inMinutes}m";
        }
      }

      return "Soon";
    } catch (e) {
      return "Unknown";
    }
  }


  // Complete _buildGeofenceMonitoringCard() Widget Implementation
// Place this in your dashboard_view.dart file

  Widget _buildGeofenceMonitoringCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(
              color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isGeofenceMonitoringActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isGeofenceMonitoringActive ? Icons.shield : Icons.shield_outlined,
                        color: _isGeofenceMonitoringActive ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: containerSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Work Area Monitoring",
                            style: TextStyle(
                              fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isGeofenceMonitoringActive
                                ? "Active - Checking every 2 hours"
                                : "Check in to enable monitoring",
                            style: TextStyle(
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isGeofenceMonitoringActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isGeofenceMonitoringActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            _monitoringStatus ?? "Inactive",
                            style: TextStyle(
                              color: _isGeofenceMonitoringActive ? Colors.green : Colors.grey,
                              fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Monitoring Details Section (when active)
                if (_isGeofenceMonitoringActive) ...[
                  SizedBox(height: containerSpacing),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Text(
                              "Monitoring Schedule",
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Frequency: Every 2 hours\nNext check in approximately: ${_getNextCheckTime()}",
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: (isLargeScreen ? 13 : (isTablet ? 12 : 11)) * responsiveFontSize,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Monitoring tracks your location only during work hours for safety and compliance purposes.",
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: (isLargeScreen ? 11 : (isTablet ? 10 : 9)) * responsiveFontSize,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Recent Activity Section
                if (_recentExitEvents.isNotEmpty) ...[
                  SizedBox(height: containerSpacing),
                  Divider(color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)),
                  SizedBox(height: containerSpacing * 0.5),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recent Activity",
                        style: TextStyle(
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      // Live indicator
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              "LIVE",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: (isLargeScreen ? 10 : (isTablet ? 9 : 8)) * responsiveFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: containerSpacing * 0.5),

                  // Recent Events List
                  ...(_recentExitEvents.take(3).map((event) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: event.returnTime == null ? Border.all(
                        color: Colors.orange.withOpacity(0.5),
                        width: 1,
                      ) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getEventStatusIcon(event.status),
                              color: _getEventStatusColor(event.status),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${DateFormat('MMM dd, h:mm a').format(event.exitTime)}",
                                    style: TextStyle(
                                      fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: _isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  if (event.exitReason != null) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      "Reason: ${event.exitReason!.replaceAll('_', ' ').toUpperCase()}",
                                      style: TextStyle(
                                        fontSize: (isLargeScreen ? 10 : (isTablet ? 9 : 8)) * responsiveFontSize,
                                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (event.returnTime == null)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "ACTIVE",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: (isLargeScreen ? 9 : (isTablet ? 8 : 7)) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (event.durationMinutes > 0)
                                  Text(
                                    "${event.durationMinutes}m",
                                    style: TextStyle(
                                      fontSize: (isLargeScreen ? 11 : (isTablet ? 10 : 9)) * responsiveFontSize,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Show return time if available
                        if (event.returnTime != null) ...[
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.keyboard_return, color: Colors.green, size: 12),
                              SizedBox(width: 6),
                              Text(
                                "Returned: ${DateFormat('h:mm a').format(event.returnTime!)}",
                                style: TextStyle(
                                  fontSize: (isLargeScreen ? 10 : (isTablet ? 9 : 8)) * responsiveFontSize,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )).toList()),

                  // Show more button
                  if (_recentExitEvents.length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _showFullExitHistory(),
                          icon: Icon(
                            Icons.history,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            "View All (${_recentExitEvents.length})",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                // No Activity Message
                if (_isGeofenceMonitoringActive && _recentExitEvents.isEmpty) ...[
                  SizedBox(height: containerSpacing),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "No Recent Activity",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "You've been within the work area during all recent checks.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons (if monitoring not active)
                if (!_isGeofenceMonitoringActive && _isCheckedIn) ...[
                  SizedBox(height: containerSpacing),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Monitoring Not Active",
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Work area monitoring should activate automatically when you check in.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper method to get next check time





  // ✅ NEW: Add geofence monitoring card to your dashboard


  // Helper methods for event status
  IconData _getEventStatusIcon(String status) {
    switch (status) {
      case 'resolved':
        return Icons.check_circle;
      case 'active':
        return Icons.warning;
      case 'grace_period':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  Color _getEventStatusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'active':
        return Colors.orange;
      case 'grace_period':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Show full exit history
  void _showFullExitHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(cardBorderRadius + 12)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: containerSpacing * 0.75),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(containerSpacing),
              child: Row(
                children: [
                  Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: containerSpacing),
                  Text(
                    "Exit History",
                    style: TextStyle(
                      fontSize: (isLargeScreen ? 24 : (isTablet ? 20 : 18)) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: containerSpacing),
                itemCount: _recentExitEvents.length,
                itemBuilder: (context, index) {
                  GeofenceExitEvent event = _recentExitEvents[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _getEventStatusIcon(event.status),
                        color: _getEventStatusColor(event.status),
                      ),
                      title: Text("${DateFormat('MMM dd, yyyy h:mm a').format(event.exitTime)}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Duration: ${event.durationMinutes} minutes"),
                          if (event.exitReason != null)
                            Text("Reason: ${event.exitReason!.replaceAll('_', ' ')}"),
                          Text("Status: ${event.status.replaceAll('_', ' ')}"),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show sync dialog for check-out state issues
  void _showCheckOutSyncDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.sync_problem, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(
              "Sync Issue",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Your check-out was recorded but the app state needs to be synced. Would you like to sync now?",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Later", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _forceAttendanceSync();
            },
            icon: Icon(Icons.sync, size: 16),
            label: Text("Sync Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }




  // Check In/Out Handler - Optimized


  // Add this method to your _DashboardViewState class

  Future<void> _forceAttendanceSync() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    debugPrint("🔄 === FORCING COMPREHENSIVE ATTENDANCE SYNC WITH PRIORITY ===");

    try {
      // Step 1: Force sync all pending attendance records with priority logic
      final attendanceRepo = getIt<AttendanceRepository>();
      bool attendanceSync = await attendanceRepo.syncPendingRecordsWithPriority();

      // Step 2: Force sync today's specific record
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      bool todaySync = await attendanceRepo.forceSyncAttendanceForDate(widget.employeeId, today);

      // Step 3: Force refresh dashboard state from authoritative source
      await _fetchAttendanceStatus();

      // Step 4: Refresh today's activity
      await _fetchTodaysActivity();

      debugPrint("✅ Force attendance sync completed");

      // Show user feedback
      if (attendanceSync && todaySync) {
        CustomSnackBar.successSnackBar("Attendance data synchronized successfully with priority logic!");
      } else if (todaySync) {
        CustomSnackBar.successSnackBar("Today's attendance synchronized successfully!");
      } else {
        CustomSnackBar.infoSnackBar("Attendance data sync completed with some warnings");
      }

    } catch (e) {
      debugPrint("❌ Error during force attendance sync: $e");
      CustomSnackBar.errorSnackBar("Sync failed: $e");
    }
  }


  Future<void> _debugAttendanceState() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint("🔍 === ATTENDANCE STATE DEBUG ===");
      debugPrint("Date: $today");
      debugPrint("Employee: ${widget.employeeId}");
      debugPrint("Current Dashboard State: _isCheckedIn = $_isCheckedIn");

      // Check local database
      final attendanceRepo = getIt<AttendanceRepository>();
      final localRecord = await attendanceRepo.getTodaysAttendance(widget.employeeId);

      debugPrint("\n📱 LOCAL DATABASE:");
      if (localRecord != null) {
        debugPrint("  ✅ Record exists");
        debugPrint("  - Check-in: ${localRecord.checkIn}");
        debugPrint("  - Check-out: ${localRecord.checkOut}");
        debugPrint("  - Has check-in: ${localRecord.hasCheckIn}");
        debugPrint("  - Has check-out: ${localRecord.hasCheckOut}");
        debugPrint("  - Is synced: ${localRecord.isSynced}");
        debugPrint("  - Expected state: CHECKED ${localRecord.hasCheckIn && !localRecord.hasCheckOut ? 'IN' : 'OUT'}");
        debugPrint("  - Location: ${localRecord.locationSummary}");
      } else {
        debugPrint("  ❌ No local record found");
      }

      // Check Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        debugPrint("\n🌐 FIRESTORE:");
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${widget.employeeId}-$today')
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            debugPrint("  ✅ Firestore record exists");

            // Parse timestamps
            DateTime? fsCheckIn;
            DateTime? fsCheckOut;

            if (data['checkIn'] is Timestamp) {
              fsCheckIn = (data['checkIn'] as Timestamp).toDate();
            } else if (data['checkIn'] is String) {
              fsCheckIn = DateTime.tryParse(data['checkIn']);
            }

            if (data['checkOut'] is Timestamp) {
              fsCheckOut = (data['checkOut'] as Timestamp).toDate();
            } else if (data['checkOut'] is String) {
              fsCheckOut = DateTime.tryParse(data['checkOut']);
            }

            debugPrint("  - Check-in: $fsCheckIn");
            debugPrint("  - Check-out: $fsCheckOut");
            debugPrint("  - Has check-in: ${fsCheckIn != null}");
            debugPrint("  - Has check-out: ${fsCheckOut != null}");
            debugPrint("  - Expected state: CHECKED ${fsCheckIn != null && fsCheckOut == null ? 'IN' : 'OUT'}");
            debugPrint("  - Raw checkIn: ${data['checkIn']}");
            debugPrint("  - Raw checkOut: ${data['checkOut']}");

          } else {
            debugPrint("  ❌ No Firestore record found");
          }
        } catch (e) {
          debugPrint("  ❌ Firestore error: $e");
        }
      } else {
        debugPrint("\n🌐 FIRESTORE: Offline - cannot check");
      }

      debugPrint("\n🎯 ANALYSIS:");
      debugPrint("  - Dashboard shows: ${_isCheckedIn ? 'CHECK OUT' : 'CHECK IN'} button");
      debugPrint("  - User should see: ${localRecord?.hasCheckIn == true && localRecord?.hasCheckOut != true ? 'CHECK OUT' : 'CHECK IN'} button");

      bool isCorrect = _isCheckedIn == (localRecord?.hasCheckIn == true && localRecord?.hasCheckOut != true);
      debugPrint("  - State is correct: ${isCorrect ? '✅ YES' : '❌ NO'}");

      if (!isCorrect) {
        debugPrint("\n🔧 RECOMMENDED ACTIONS:");
        debugPrint("  1. Run _fetchAttendanceStatus() to refresh state");
        debugPrint("  2. If still incorrect, force sync with _forceAttendanceSync()");
        debugPrint("  3. Check for data corruption in local database");
      }

      debugPrint("=== END ATTENDANCE DEBUG ===\n");

      // Show results in a dialog for easy viewing
      if (mounted) {
        String message = "Debug Results:\n\n";
        message += "Dashboard State: ${_isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT'}\n";

        if (localRecord != null) {
          message += "Local DB: ${localRecord.hasCheckIn && !localRecord.hasCheckOut ? 'CHECKED IN' : 'CHECKED OUT'}\n";
          message += "Synced: ${localRecord.isSynced ? 'YES' : 'NO'}\n";
        } else {
          message += "Local DB: NO RECORD\n";
        }

        message += "States Match: ${isCorrect ? 'YES' : 'NO'}\n";

        if (!isCorrect) {
          message += "\n⚠️ State mismatch detected!\nTry refreshing or force sync.";
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Attendance Debug Results"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              if (!isCorrect) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchAttendanceStatus();
                  },
                  child: const Text("Refresh State"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _forceAttendanceSync();
                  },
                  child: const Text("Force Sync"),
                ),
              ],
            ],
          ),
        );
      }

    } catch (e) {
      debugPrint("❌ Error in attendance debug: $e");
      if (mounted) {
        CustomSnackBar.errorSnackBar("Debug error: $e");
      }
    }
  }



  // ADD THESE METHODS TO YOUR _DashboardViewState class in dashboard_view.dart

// ✅ ENHANCED: Force sync attendance with proper priority


// ✅ ENHANCED: Manual sync with better error handling
  Future<void> _manualSync() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    // Show toast instead of full loading overlay
    CustomSnackBar.infoSnackBar("Synchronizing data with priority logic...");

    try {
      // Use enhanced sync service
      await _syncService.manualSync();

      // Force attendance sync with priority
      await _forceAttendanceSync();

      if (mounted) {
        setState(() {
          _needsSync = false;
        });
      }

      CustomSnackBar.successSnackBar("Data synchronized successfully with local priority");
    } catch (e) {
      debugPrint("❌ Error during manual sync: $e");
      CustomSnackBar.errorSnackBar("Sync failed: $e");
    }
  }

// ✅ NEW: Debug attendance state with detailed analysis
  Future<void> _debugAttendanceStateDetailed() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint("🔍 === DETAILED ATTENDANCE STATE DEBUG ===");
      debugPrint("Date: $today");
      debugPrint("Employee: ${widget.employeeId}");
      debugPrint("Current Dashboard State: _isCheckedIn = $_isCheckedIn");

      // Check local database
      final attendanceRepo = getIt<AttendanceRepository>();
      final localRecord = await attendanceRepo.getTodaysAttendance(widget.employeeId);

      debugPrint("\n📱 LOCAL DATABASE:");
      if (localRecord != null) {
        debugPrint("  ✅ Record exists");
        debugPrint("  - Check-in: ${localRecord.checkIn}");
        debugPrint("  - Check-out: ${localRecord.checkOut}");
        debugPrint("  - Has check-in: ${localRecord.hasCheckIn}");
        debugPrint("  - Has check-out: ${localRecord.hasCheckOut}");
        debugPrint("  - Is synced: ${localRecord.isSynced}");
        debugPrint("  - Expected state: CHECKED ${localRecord.hasCheckIn && !localRecord.hasCheckOut ? 'IN' : 'OUT'}");
        debugPrint("  - Location: ${localRecord.locationSummary}");
        debugPrint("  - Raw data keys: ${localRecord.rawData.keys.toList()}");
      } else {
        debugPrint("  ❌ No local record found");
      }

      // Check Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        debugPrint("\n🌐 FIRESTORE:");
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${widget.employeeId}-$today')
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            debugPrint("  ✅ Firestore record exists");

            // Parse timestamps
            DateTime? fsCheckIn;
            DateTime? fsCheckOut;

            if (data['checkIn'] is Timestamp) {
              fsCheckIn = (data['checkIn'] as Timestamp).toDate();
            } else if (data['checkIn'] is String) {
              fsCheckIn = DateTime.tryParse(data['checkIn']);
            }

            if (data['checkOut'] is Timestamp) {
              fsCheckOut = (data['checkOut'] as Timestamp).toDate();
            } else if (data['checkOut'] is String) {
              fsCheckOut = DateTime.tryParse(data['checkOut']);
            }

            debugPrint("  - Check-in: $fsCheckIn");
            debugPrint("  - Check-out: $fsCheckOut");
            debugPrint("  - Has check-in: ${fsCheckIn != null}");
            debugPrint("  - Has check-out: ${fsCheckOut != null}");
            debugPrint("  - Expected state: CHECKED ${fsCheckIn != null && fsCheckOut == null ? 'IN' : 'OUT'}");
            debugPrint("  - Raw checkIn: ${data['checkIn']}");
            debugPrint("  - Raw checkOut: ${data['checkOut']}");
            debugPrint("  - Last sync: ${data['lastSyncedAt']}");
            debugPrint("  - Sync source: ${data['syncSource']}");

          } else {
            debugPrint("  ❌ No Firestore record found");
          }
        } catch (e) {
          debugPrint("  ❌ Firestore error: $e");
        }
      } else {
        debugPrint("\n🌐 FIRESTORE: Offline - cannot check");
      }

      debugPrint("\n🎯 ANALYSIS:");
      debugPrint("  - Dashboard shows: ${_isCheckedIn ? 'CHECK OUT' : 'CHECK IN'} button");

      bool expectedState = localRecord?.hasCheckIn == true && localRecord?.hasCheckOut != true;
      debugPrint("  - User should see: ${expectedState ? 'CHECK OUT' : 'CHECK IN'} button");

      bool isCorrect = _isCheckedIn == expectedState;
      debugPrint("  - State is correct: ${isCorrect ? '✅ YES' : '❌ NO'}");

      if (localRecord != null) {
        debugPrint("  - Local sync status: ${localRecord.isSynced ? 'SYNCED' : 'UNSYNCED'}");
        if (!localRecord.isSynced) {
          debugPrint("  - ⚠️ LOCAL DATA NOT SYNCED - This should take priority!");
        }
      }

      if (!isCorrect) {
        debugPrint("\n🔧 RECOMMENDED ACTIONS:");
        debugPrint("  1. Run _fetchAttendanceStatus() to refresh state");
        debugPrint("  2. If still incorrect, run _forceAttendanceSync()");
        debugPrint("  3. Check for data corruption in local database");
        if (localRecord != null && !localRecord.isSynced) {
          debugPrint("  4. PRIORITY: Sync local unsynced data to Firestore");
        }
      }

      debugPrint("=== END DETAILED ATTENDANCE DEBUG ===\n");

      // Show results in a dialog for easy viewing
      if (mounted) {
        String message = "Debug Results:\n\n";
        message += "Dashboard State: ${_isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT'}\n";

        if (localRecord != null) {
          message += "Local DB: ${localRecord.hasCheckIn && !localRecord.hasCheckOut ? 'CHECKED IN' : 'CHECKED OUT'}\n";
          message += "Synced: ${localRecord.isSynced ? 'YES' : 'NO'}\n";
          if (!localRecord.isSynced) {
            message += "⚠️ LOCAL DATA UNSYNCED\n";
          }
        } else {
          message += "Local DB: NO RECORD\n";
        }

        message += "States Match: ${isCorrect ? 'YES' : 'NO'}\n";

        if (!isCorrect || (localRecord != null && !localRecord.isSynced)) {
          message += "\n⚠️ Issues detected!\n";
          if (!localRecord!.isSynced) {
            message += "Local data needs sync priority.";
          }
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Detailed Attendance Debug"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              if (!isCorrect) ...[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchAttendanceStatus();
                  },
                  child: const Text("Refresh State"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _forceAttendanceSync();
                  },
                  child: const Text("Force Sync"),
                ),
              ],
              if (localRecord != null && !localRecord.isSynced) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _forceSyncPriorityData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("Sync Local Priority"),
                ),
              ],
            ],
          ),
        );
      }

    } catch (e) {
      debugPrint("❌ Error in detailed attendance debug: $e");
      if (mounted) {
        CustomSnackBar.errorSnackBar("Debug error: $e");
      }
    }
  }

// ✅ NEW: Force sync with local data priority
  Future<void> _forceSyncPriorityData() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    try {
      CustomSnackBar.infoSnackBar("Force syncing local priority data...");

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendanceRepo = getIt<AttendanceRepository>();

      // Force sync today's record with local priority
      bool success = await attendanceRepo.forceSyncAttendanceForDate(widget.employeeId, today);

      if (success) {
        // Refresh dashboard state
        await _fetchAttendanceStatus();
        await _fetchTodaysActivity();

        CustomSnackBar.successSnackBar("Local priority data synced successfully!");
      } else {
        CustomSnackBar.errorSnackBar("Failed to sync local priority data");
      }

    } catch (e) {
      debugPrint("❌ Error in force sync priority: $e");
      CustomSnackBar.errorSnackBar("Force sync error: $e");
    }
  }



  // Add this debug method to your _DashboardViewState class for testing



  Future<void> _refreshDashboard() async {
    debugPrint("🔄 Dashboard refresh requested...");

    if (_isProcessingCheckInOut) {
      debugPrint("⚡ Skipping refresh - check-in/out in progress");
      return;
    }

    // Smart refresh - only refresh what's needed
    await _executeSmartRefresh(['important', 'normal']);
  }

  Future<void> _onAppResume() async {
    debugPrint("📱 App resumed - smart refresh");

    // Clear cache for critical data to force fresh check
    final now = DateTime.now();
    _dataCache.remove('attendance_${DateFormat('yyyy-MM-dd').format(now)}');

    // Force refresh critical and important data
    await _executeSmartRefresh(['critical', 'important']);
  }

  Future<void> _processCheckInWithFlag() async {
    _isProcessingCheckInOut = true;
    try {
      await _processCheckIn();
    } finally {
      _isProcessingCheckInOut = false;
    }
  }

  Future<void> _processCheckOutWithFlag() async {
    _isProcessingCheckInOut = true;
    try {
      await _processCheckOut();
    } finally {
      _isProcessingCheckInOut = false;
    }
  }







  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Text(
          "Logout",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        if (_needsSync && _connectivityService.currentStatus == ConnectionStatus.online) {
          bool syncFirst = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
              title: Text(
                "Unsynchronized Data",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                "You have data that hasn't been synchronized. Would you like to sync before logging out?",
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("No", style: TextStyle(color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Yes"),
                ),
              ],
            ),
          ) ?? false;

          if (syncFirst) {
            await _manualSync();
          }
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('authenticated_user_id');

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const PinEntryView(),
            ),
                (route) => false,
          );
        }
      } catch (e) {
        CustomSnackBar.errorSnackBar("Error during logout: $e");
      }
    }
  }

  // Complete Implementation of All Remaining Methods

  Future<void> _initializeNotifications() async {
    try {
      final notificationService = getIt<NotificationService>();
      final fcmTokenService = getIt<FcmTokenService>();
      await fcmTokenService.registerTokenForUser(widget.employeeId);
      await notificationService.subscribeToEmployeeTopic(widget.employeeId);
      debugPrint("Dashboard: Initialized notifications for employee ${widget.employeeId}");
    } catch (e) {
      debugPrint("Dashboard: Error initializing notifications: $e");
    }
  }

  void _handleLineManagerStatusDetermined(bool isManager) {
    if (isManager) {
      try {
        final notificationService = getIt<NotificationService>();
        notificationService.subscribeToManagerTopic('manager_${widget.employeeId}');

        if (widget.employeeId.startsWith('EMP')) {
          notificationService.subscribeToManagerTopic('manager_${widget.employeeId.substring(3)}');
        }

        debugPrint("Dashboard: Subscribed to manager notifications");
        _loadPendingApprovalRequests();
        _loadPendingLeaveApprovals();
      } catch (e) {
        debugPrint("Dashboard: Error subscribing to manager notifications: $e");
      }
    }
  }

  Future<void> _loadPendingApprovalRequests() async {
    if (!_isLineManager) return;

    try {
      final repository = getIt<CheckOutRequestRepository>();
      final requests = await repository.getPendingRequestsForManager(widget.employeeId);

      if (mounted) {
        setState(() {
          _pendingApprovalRequests = requests.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending approval requests: $e');
    }
  }











  void _handleNotification(Map<String, dynamic> data) {
    final notificationType = data['type'];
    debugPrint("=== NOTIFICATION RECEIVED ===");
    debugPrint("Type: $notificationType");
    debugPrint("Data: $data");
    debugPrint("Current Employee: ${widget.employeeId}");

    if (notificationType == 'geofence_exit_prompt') {
      _handleGeofenceExitNotification(data);
      return;
    }

    // REST TIMING SCHEDULE NOTIFICATIONS
    if (notificationType == 'rest_timing_schedule') {
      debugPrint("⚠️ REST TIMING SCHEDULE NOTIFICATION RECEIVED");

      final String scheduleTitle = data['scheduleTitle'] ?? 'Rest Timing Schedule';
      final String scheduleReason = data['scheduleReason'] ?? '';
      final String startDate = data['startDate'] ?? '';
      final String endDate = data['endDate'] ?? '';
      final String restStartTime = data['restStartTime'] ?? '';
      final String restEndTime = data['restEndTime'] ?? '';
      final String status = data['status'] ?? '';
      final String scheduleId = data['scheduleId'] ?? '';

      String title, message;
      Color backgroundColor;
      IconData iconData;

      if (status == 'active') {
        title = "🕐 Rest Timing Active!";
        message = "Your rest timing schedule is now active";
        backgroundColor = Colors.green;
        iconData = Icons.play_circle;
      } else if (status == 'scheduled') {
        title = "📅 Rest Timing Scheduled";
        message = "New rest timing schedule created for you";
        backgroundColor = Colors.blue;
        iconData = Icons.schedule;
      } else {
        title = "Rest Timing Update";
        message = "Rest timing schedule has been updated";
        backgroundColor = Colors.orange;
        iconData = Icons.update;
      }



      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          title: Container(
            padding: EdgeInsets.all(containerSpacing),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundColor, backgroundColor.withOpacity(0.8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(cardBorderRadius - 4),
            ),
            child: Row(
              children: [
                Icon(
                  iconData,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(width: containerSpacing * 0.75),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: containerSpacing),
                _buildNotificationDetailRow("Schedule:", scheduleTitle),
                if (scheduleReason.isNotEmpty)
                  _buildNotificationDetailRow("Reason:", scheduleReason),
                _buildNotificationDetailRow("Period:", "$startDate to $endDate"),
                _buildNotificationDetailRow("Rest Time:", "$restStartTime - $restEndTime"),
                _buildNotificationDetailRow("Status:", status.toUpperCase()),
                if (scheduleId.isNotEmpty)
                  _buildNotificationDetailRow("Schedule ID:", scheduleId.substring(0, 8) + "..."),
                SizedBox(height: containerSpacing),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(containerSpacing),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                    border: Border.all(color: backgroundColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: backgroundColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            status == 'active' ? "Effective Immediately" : "Schedule Information",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                              fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status == 'active'
                            ? "This rest timing schedule is now in effect. Please follow the specified rest hours during your work day."
                            : "This rest timing schedule will be effective from the start date. You'll be notified when it becomes active.",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Later", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("View Details"),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showRestTimingDetails(data);
              },
            ),
          ],
        ),
      );

      _refreshDashboard();
    }

    // Add this case to the _handleNotification method
    else if (notificationType == 'overtime_approved') {
      debugPrint("⚠️ OVERTIME APPROVED NOTIFICATION RECEIVED");

      final String projectName = data['projectName'] ?? 'Project';
      final String totalHours = data['totalHours'] ?? '0';
      final String requestId = data['requestId'] ?? '';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          title: Container(
            padding: EdgeInsets.all(containerSpacing),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green, Colors.green.withOpacity(0.8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(cardBorderRadius - 4),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 32),
                SizedBox(width: containerSpacing * 0.75),
                Expanded(
                  child: Text(
                    "Overtime Approved!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: containerSpacing),
                _buildNotificationDetailRow("Project:", projectName),
                _buildNotificationDetailRow("Duration:", "${totalHours}h"),
                _buildNotificationDetailRow("Request ID:", requestId.substring(0, 8) + "..."),
                SizedBox(height: containerSpacing),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(containerSpacing),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "You're Approved for Overtime!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                              fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You have been approved for overtime work. The overtime details will appear on your dashboard during the scheduled hours.",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Later", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Dashboard"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _refreshDashboard();
              },
            ),
          ],
        ),
      );

      // Refresh overtime assignments
      _fetchOvertimeAssignments();
    }

    // LEAVE APPLICATION NOTIFICATIONS
    else if (notificationType == 'leave_application') {
      debugPrint("⚠️ LEAVE APPLICATION NOTIFICATION RECEIVED");

      final String employeeName = data['employeeName'] ?? 'Someone';
      final String leaveType = data['leaveType'] ?? 'leave';
      final String totalDays = data['totalDays'] ?? '0';
      final String applicationId = data['applicationId'] ?? '';

      if (_isLineManager) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
            title: Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.green],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white, size: 32),
                  SizedBox(width: containerSpacing * 0.75),
                  Expanded(
                    child: Text(
                      "New Leave Application!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: containerSpacing),
                  _buildNotificationDetailRow("Employee:", employeeName),
                  _buildNotificationDetailRow("Leave Type:", leaveType),
                  _buildNotificationDetailRow("Duration:", "$totalDays days"),
                  _buildNotificationDetailRow("Application ID:", applicationId),
                  SizedBox(height: containerSpacing),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(containerSpacing),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Action Required",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This leave application needs your approval. Please review the details carefully before making a decision.",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Later", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text("Review Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerLeaveApprovalView(
                        managerId: widget.employeeId,
                        managerName: _userData?['name'] ?? 'Manager',
                      ),
                    ),
                  ).then((_) => _loadPendingLeaveApprovals());
                },
              ),
            ],
          ),
        );

        _loadPendingLeaveApprovals();
      }
    }

    // LEAVE APPLICATION STATUS UPDATE
    else if (notificationType == 'leave_application_update') {
      debugPrint("⚠️ LEAVE STATUS UPDATE NOTIFICATION RECEIVED");

      final String status = data['status'] ?? '';
      final String leaveType = data['leaveType'] ?? 'leave';
      final String comments = data['comments'] ?? '';

      final bool isApproved = status == 'approved';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          title: Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.green : Colors.red,
                size: 32,
              ),
              SizedBox(width: containerSpacing * 0.75),
              Expanded(
                child: Text(
                  isApproved ? "Leave Application Approved!" : "Leave Application Rejected",
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApproved
                    ? "Your $leaveType application has been approved."
                    : "Your $leaveType application has been rejected.",
                style: TextStyle(
                  fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
                  color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              if (comments.isNotEmpty) ...[
                SizedBox(height: containerSpacing),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(containerSpacing * 0.75),
                  decoration: BoxDecoration(
                    color: (isApproved ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                    border: Border.all(
                      color: (isApproved ? Colors.green : Colors.red).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Manager Comments:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isApproved ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comments,
                        style: TextStyle(
                          color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproved ? Colors.green : Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }

    // CHECK-OUT REQUEST NOTIFICATIONS
    else if (notificationType == 'check_out_request_update') {
      final String status = data['status'] ?? '';
      final String requestType = data['requestType'] ?? 'check-out';
      final String message = data['message'] ?? '';

      if (_isLineManager) {
        _loadPendingApprovalRequests();
      }

      final bool isApproved = status == 'approved';
      CustomSnackBar.successSnackBar(
          isApproved
              ? "Your ${requestType.replaceAll('-', ' ')} request has been approved"
              : "Your ${requestType.replaceAll('-', ' ')} request has been rejected${message.isNotEmpty ? ': $message' : ''}"
      );
    }
    else if (notificationType == 'new_check_out_request') {
      final String employeeName = data['employeeName'] ?? 'An employee';
      final String requestType = data['requestType'] ?? 'check-out';

      if (_isLineManager) {
        _loadPendingApprovalRequests();
        CustomSnackBar.successSnackBar(
            "$employeeName has requested to ${requestType.replaceAll('-', ' ')} from an offsite location"
        );

        if (data['fromNotificationTap'] == 'true') {
          _navigateToPendingRequests();
        }
      }
    }

    // OVERTIME NOTIFICATIONS

    else if (notificationType == 'overtime_request_update') {
      final String status = data['status'] ?? '';
      final String projectName = data['projectName'] ?? '';
      final String message = data['message'] ?? '';

      final bool isApproved = status == 'approved';
      CustomSnackBar.successSnackBar(
          isApproved
              ? "Your overtime request for $projectName has been approved"
              : "Your overtime request for $projectName has been rejected${message.isNotEmpty ? ': $message' : ''}"
      );
    }



    _refreshDashboard();
    debugPrint("=== NOTIFICATION HANDLED ===");
  }

  void _showRestTimingDetails(Map<String, dynamic> scheduleData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Colors.blue, size: 24),
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                "Rest Timing Schedule Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Schedule:", scheduleData['scheduleTitle'] ?? ''),
              _buildDetailRow("Reason:", scheduleData['scheduleReason'] ?? ''),
              _buildDetailRow("Start Date:", scheduleData['startDate'] ?? ''),
              _buildDetailRow("End Date:", scheduleData['endDate'] ?? ''),
              _buildDetailRow("Rest Time:", "${scheduleData['restStartTime']} - ${scheduleData['restEndTime']}"),
              _buildDetailRow("Status:", (scheduleData['status'] ?? '').toUpperCase()),
              if (scheduleData['scheduleId']?.isNotEmpty == true)
                _buildDetailRow("Schedule ID:", scheduleData['scheduleId'].substring(0, 8) + "..."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh Data"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _refreshDashboard();
            },
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPendingRequests() {
    if (_isLineManager) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ManagerPendingRequestsView(
            managerId: widget.employeeId,
          ),
        ),
      ).then((_) => _loadPendingApprovalRequests());
    }
  }


  void _showFaceDataRecoveryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.face_retouching_natural, color: Colors.blue, size: 24),
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                "Recover Face Data",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will download your face authentication data from the cloud backup.",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "When to use this:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "• After clearing app data/storage\n• When face authentication is not working\n• After reinstalling the app",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _forceFaceDataRecovery();
            },
            icon: const Icon(Icons.cloud_download, size: 18),
            label: const Text("Recover"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }


  void _showSimpleFaceDataRecovery() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.face_retouching_natural, color: Colors.blue, size: 24),
            ),
            SizedBox(width: containerSpacing * 0.75),
            Expanded(
              child: Text(
                "Recover Face Data",
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will download your face authentication data from the cloud backup.",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Use this only if face authentication is not working properly.",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSimpleFaceDataRecovery();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("OK, Recover"),
          ),
        ],
      ),
    );
  }

  void _performSimpleFaceDataRecovery() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        content: Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "Recovering face data...",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final secureFaceStorage = getIt<SecureFaceStorageService>();
      bool recovered = await secureFaceStorage.downloadFaceDataFromCloud(widget.employeeId);

      Navigator.pop(context); // Close loading dialog

      // Show result dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          title: Row(
            children: [
              Icon(
                recovered ? Icons.check_circle : Icons.error,
                color: recovered ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recovered ? "Success!" : "Failed",
                  style: TextStyle(
                    color: recovered ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            recovered
                ? "Face data has been successfully recovered from cloud backup. Face authentication should work now."
                : "Failed to recover face data. Please check your internet connection and try again.",
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: recovered ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("OK"),
            ),
          ],
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 32),
              const SizedBox(width: 12),
              Text(
                "Error",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "An error occurred while recovering face data: $e",
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  // Settings Menu - Complete Implementation
  void _showSettingsMenu(BuildContext context) {
    debugPrint("=== SETTINGS MENU DEBUG ===");
    debugPrint("Current time: ${DateTime.now()}");
    debugPrint("_userData != null: ${_userData != null}");
    debugPrint("_isLoading: $_isLoading");
    debugPrint("Widget mounted: $mounted");
    debugPrint("========================");

    // Force state refresh BEFORE showing settings
    if (mounted) {
      setState(() {});
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext freshContext) {
        // Use StatefulBuilder to ensure fresh rebuild
        return StatefulBuilder(
          key: ValueKey('settings_${DateTime.now().millisecondsSinceEpoch}'),
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8, // Increased height for debug option
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(cardBorderRadius + 12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: containerSpacing * 0.75),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 32 : (isTablet ? 28 : 24)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.settings,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: containerSpacing),
                        Text(
                          'Settings & Preferences',
                          style: TextStyle(
                            fontSize: (isLargeScreen ? 32 : (isTablet ? 28 : 24)) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings options
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 32 : (isTablet ? 28 : 24)),
                      child: Column(
                        children: [
                          // ======= MAIN SETTINGS =======
                          _buildSettingsSection("Main Settings", [
                            _buildModernSettingsOption(
                              icon: Icons.calendar_view_month,
                              title: 'My Attendance',
                              subtitle: 'View your attendance history and records',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MyAttendanceView(
                                      employeeId: widget.employeeId,
                                      userData: _userData ?? {},
                                    ),
                                  ),
                                );
                              },
                            ),

                            _buildModernSettingsOption(
                              icon: Icons.event_note,
                              title: 'Leave Management',
                              subtitle: 'View leave balance, history, and apply for leave',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LeaveHistoryView(
                                      employeeId: widget.employeeId,
                                      employeeName: _userData?['name'] ?? 'Employee',
                                      employeePin: _userData?['pin'] ?? widget.employeeId,
                                      userData: _userData ?? {},
                                    ),
                                  ),
                                ).then((_) => _refreshDashboard());
                              },
                            ),




                            _buildModernSettingsOption(
                              icon: Icons.receipt_long,
                              title: 'Apply for Salary Slip',
                              subtitle: 'Request and download salary slips',
                              iconColor: Colors.green,
                              onTap: () {
                                Navigator.pop(context);
                                _showComingSoonDialog("Apply for Salary Slip");
                              },
                            ),

                            _buildModernSettingsOption(
                              icon: Icons.history,
                              title: 'Check-Out Request History',
                              subtitle: 'View your remote check-out requests',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CheckOutRequestHistoryView(
                                      employeeId: widget.employeeId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ]),



                          // ======= ADVANCED SETTINGS =======
                          _buildSettingsSection("Advanced", [
                            if (_userData != null &&
                                (_userData!['hasOvertimeAccess'] == true ||
                                    _userData!['overtimeAccessGrantedAt'] != null))
                              _buildModernSettingsOption(
                                icon: Icons.people_outline,
                                title: 'Manage Employee List',
                                subtitle: 'Create custom employee list for overtime requests',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EmployeeListManagementView(
                                        requesterId: widget.employeeId,
                                      ),
                                    ),
                                  );
                                },
                              ),

                            _buildModernSettingsOption(
                              icon: Icons.dark_mode_outlined,
                              title: 'Dark mode',
                              subtitle: 'Switch between light and dark themes',
                              hasToggle: true,
                              toggleValue: _isDarkMode,
                              onToggleChanged: (value) {
                                setState(() {
                                  _isDarkMode = value;
                                  _saveDarkModePreference(value);
                                });
                              },
                            ),

                            _buildDebugGeofenceOption(),

                            _buildModernSettingsOption(
                              icon: Icons.face_retouching_natural,
                              title: 'Recover Face Data',
                              subtitle: 'Restore face authentication data from cloud backup',
                              iconColor: Colors.blue,
                              onTap: () {
                                Navigator.pop(context);
                                _showFaceDataRecoveryDialog();
                              },
                            ),
                          ]),



                          // ======= LOGOUT =======
                          SizedBox(height: containerSpacing),

                          _buildModernSettingsOption(
                            icon: Icons.logout,
                            title: 'Log out',
                            subtitle: 'Sign out of your account',
                            textColor: Colors.red,
                            iconColor: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _logout();
                            },
                          ),

                          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        title: Container(
          padding: EdgeInsets.all(containerSpacing),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(cardBorderRadius - 4),
          ),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.white, size: 32),
              SizedBox(width: containerSpacing * 0.75),
              Expanded(
                child: Text(
                  "Coming Soon!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (isLargeScreen ? 22 : (isTablet ? 20 : 18)) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: containerSpacing),
            Container(
              padding: EdgeInsets.all(containerSpacing),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(cardBorderRadius - 4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.construction, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Feature in Development",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 13)) * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$featureName is currently under development and will be available in a future update.",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: containerSpacing),
            Text(
              "We're working hard to bring you this feature. Stay tuned for updates!",
              style: TextStyle(
                fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 13)) * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.notifications_active, size: 18),
            label: const Text("Notify Me"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              CustomSnackBar.successSnackBar("You'll be notified when $featureName is available!");
            },
          ),
        ],
      ),
    );
  }



  Widget _buildSettingsSection(String title, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 8,
            bottom: containerSpacing * 0.75,
            top: containerSpacing,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: (isLargeScreen ? 18 : (isTablet ? 16 : 14)) * responsiveFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...options,
      ],
    );
  }

  Widget _buildModernSettingsOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool hasToggle = false,
    bool toggleValue = false,
    Function(bool)? onToggleChanged,
    Color? iconColor,
    Color? textColor,
    bool isEnabled = true,
  }) {
    final effectiveIconColor = iconColor ?? (_isDarkMode ? Colors.white70 : Colors.black54);
    final effectiveTextColor = textColor ?? (_isDarkMode ? Colors.white : Colors.black87);
    final opacity = isEnabled ? 1.0 : 0.5;

    return Container(
      margin: EdgeInsets.only(bottom: containerSpacing * 0.75),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? (hasToggle ? null : onTap) : null,
            borderRadius: BorderRadius.circular(cardBorderRadius),
            child: Padding(
              padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: effectiveIconColor, size: 20),
                  ),

                  SizedBox(width: containerSpacing),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                            fontWeight: FontWeight.w600,
                            color: effectiveTextColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (hasToggle)
                    Switch.adaptive(
                      value: toggleValue,
                      onChanged: isEnabled ? onToggleChanged : null,
                      activeColor: Theme.of(context).colorScheme.primary,
                    )
                  else if (onTap != null && isEnabled)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Notification Menu - Complete Implementation
  void _showNotificationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(cardBorderRadius + 12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: containerSpacing * 0.75),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(isLargeScreen ? 32 : (isTablet ? 28 : 24)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: containerSpacing),
                  Text(
                    'Notifications & Actions',
                    style: TextStyle(
                      fontSize: (isLargeScreen ? 32 : (isTablet ? 28 : 24)) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Notification options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 32 : (isTablet ? 28 : 24)),
                child: Column(
                  children: [
                    // Leave management section
                    _buildNotificationOption(
                      icon: Icons.event_available,
                      title: 'Apply for Leave',
                      subtitle: 'Submit a new leave application',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ApplyLeaveView(
                              employeeId: widget.employeeId,
                              employeeName: _userData?['name'] ?? 'Employee',
                              employeePin: _userData?['pin'] ?? widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        ).then((_) => _refreshDashboard());
                      },
                    ),

                    _buildNotificationOption(
                      icon: Icons.history,
                      title: 'Leave History',
                      subtitle: 'View your leave applications and balance',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeaveHistoryView(
                              employeeId: widget.employeeId,
                              employeeName: _userData?['name'] ?? 'Employee',
                              employeePin: _userData?['pin'] ?? widget.employeeId,
                              userData: _userData ?? {},
                            ),
                          ),
                        ).then((_) => _refreshDashboard());
                      },
                    ),

                    // ✅ ADD: Overtime approval notification option for overtime approvers
                    if (_isOvertimeApprover)
                      _buildNotificationOption(
                        icon: Icons.access_time_filled,
                        title: 'Overtime Approvals',
                        subtitle: _pendingOvertimeRequests > 0
                            ? '$_pendingOvertimeRequests requests waiting'
                            : 'No pending overtime requests',
                        showBadge: _pendingOvertimeRequests > 0,
                        badgeCount: _pendingOvertimeRequests,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PendingOvertimeView(
                                approverId: widget.employeeId,
                                // ✅ FIX: Remove approverName parameter
                              ),
                            ),
                          ).then((_) => _loadPendingOvertimeApprovals());
                        },
                      ),

                    // Leave approvals for line managers
                    if (_isLineManager)
                      _buildNotificationOption(
                        icon: Icons.approval,
                        title: 'Leave Approvals',
                        subtitle: _pendingLeaveApprovals > 0
                            ? '$_pendingLeaveApprovals applications waiting'
                            : 'No pending leave applications',
                        showBadge: _pendingLeaveApprovals > 0,
                        badgeCount: _pendingLeaveApprovals,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManagerLeaveApprovalView(
                                managerId: widget.employeeId,
                                managerName: _userData?['name'] ?? 'Manager',
                              ),
                            ),
                          ).then((_) => _loadPendingLeaveApprovals());
                        },
                      ),

                    // Line manager options
                    if (_isLineManager) ...[
                      _buildNotificationOption(
                        icon: Icons.people_outline,
                        title: 'My Team',
                        subtitle: 'View team members and attendance',
                        onTap: () {
                          Navigator.pop(context);
                          if (_lineManagerData != null) {
                            String managerId = _lineManagerData!['managerId'] ?? '';
                            if (managerId.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => TeamManagementView(
                                    managerId: managerId,
                                    managerData: _userData!,
                                  ),
                                ),
                              );
                            } else {
                              CustomSnackBar.errorSnackBar(context, "Manager ID not found");
                            }
                          }
                        },
                      ),

                      _buildNotificationOption(
                        icon: Icons.approval,
                        title: 'Pending Check-Out Requests',
                        subtitle: _pendingApprovalRequests > 0
                            ? '$_pendingApprovalRequests requests waiting'
                            : 'No pending requests',
                        showBadge: _pendingApprovalRequests > 0,
                        badgeCount: _pendingApprovalRequests,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ManagerPendingRequestsView(
                                managerId: widget.employeeId,
                              ),
                            ),
                          ).then((_) => _loadPendingApprovalRequests());
                        },
                      ),
                    ],

                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: containerSpacing * 0.75),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardBorderRadius),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    if (showBadge && badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: containerSpacing),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Location Menu - Complete Implementation
  void _showLocationMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(cardBorderRadius + 12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: containerSpacing * 0.75),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(isLargeScreen ? 32 : (isTablet ? 28 : 24)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: containerSpacing),
                    Expanded(
                      child: Text(
                        'Available Locations',
                        style: TextStyle(
                          fontSize: (isLargeScreen ? 32 : (isTablet ? 28 : 24)) * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _checkGeofenceStatus();
                        CustomSnackBar.successSnackBar(context, "Locations refreshed");
                      },
                      icon: Icon(
                        Icons.refresh,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              // Locations list
              Expanded(
                child: _availableLocations.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isLargeScreen ? 28 : (isTablet ? 24 : 20)),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: isLargeScreen ? 72 : (isTablet ? 64 : 48),
                          color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: containerSpacing),
                      Text(
                        "No locations available",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: (isLargeScreen ? 24 : (isTablet ? 20 : 18)) * responsiveFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 32 : (isTablet ? 28 : 24)),
                  itemCount: _availableLocations.length,
                  itemBuilder: (context, index) {
                    final location = _availableLocations[index];
                    final isNearest = _nearestLocation?.id == location.id;
                    final isWithin = _isWithinGeofence && isNearest;

                    return Container(
                      margin: EdgeInsets.only(bottom: containerSpacing * 0.75),
                      decoration: BoxDecoration(
                        color: isWithin
                            ? Colors.green.withOpacity(0.1)
                            : (_isDarkMode ? const Color(0xFF334155) : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(cardBorderRadius),
                        border: Border.all(
                          color: isWithin
                              ? Colors.green
                              : (_isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 12 : 10),
                              decoration: BoxDecoration(
                                color: isWithin
                                    ? Colors.green.withOpacity(0.2)
                                    : (_isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isWithin
                                    ? Icons.location_on_rounded
                                    : isNearest
                                    ? Icons.location_searching
                                    : Icons.location_on_outlined,
                                color: isWithin
                                    ? Colors.green
                                    : (_isDarkMode ? Colors.white70 : Colors.grey.shade600),
                                size: 24,
                              ),
                            ),

                            SizedBox(width: containerSpacing),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location.name,
                                    style: TextStyle(
                                      fontWeight: isNearest ? FontWeight.bold : FontWeight.w600,
                                      fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                                      color: _isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    location.address,
                                    style: TextStyle(
                                      color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                      fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (location.radius > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Radius: ${location.radius.toInt()}m',
                                      style: TextStyle(
                                        color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isWithin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 10)) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else if (isNearest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'NEAREST',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 10)) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_distanceToOffice != null && isNearest) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_distanceToOffice!.toStringAsFixed(0)}m',
                                      style: TextStyle(
                                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 12 : 11)) * responsiveFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Force Face Data Recovery
  Future<void> _forceFaceDataRecovery() async {
    try {
      debugPrint("🔄 Forcing face data recovery...");

      if (mounted) {
        setState(() => _isLoading = true);
      }

      final secureFaceStorage = getIt<SecureFaceStorageService>();
      bool recovered = await secureFaceStorage.downloadFaceDataFromCloud(widget.employeeId);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (recovered) {
        CustomSnackBar.successSnackBar("Face data successfully recovered from cloud");
      } else {
        CustomSnackBar.errorSnackBar("Failed to recover face data. Please check your connection.");
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      CustomSnackBar.errorSnackBar("Error recovering face data: $e");
    }
  }
}

// App lifecycle observer class
class AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback? onResume;

  AppLifecycleObserver({this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && onResume != null) {
      debugPrint("📱 App resumed - forcing attendance sync for cross-device compatibility");
      onResume!();
    }
  }
}