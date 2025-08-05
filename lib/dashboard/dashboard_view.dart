// lib/dashboard/dashboard_view.dart
import 'dart:convert';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geodesy/geodesy.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:face_auth/model/local_attendance_model.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/overtime_approver_service.dart';
import 'package:face_auth/authenticate_face/authentication_success_screen.dart';
import 'package:face_auth/services/work_schedule_service.dart';
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
import 'package:face_auth/admin/notification_admin_view.dart';
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
import 'package:face_auth/admin/geojson_importer_view.dart';
import 'package:face_auth/admin/polygon_map_view.dart';
import 'package:face_auth/admin/map_navigation.dart';
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

  // Activity and Location State
  List<Map<String, dynamic>> _todaysActivity = [];
  LocationModel? _nearestLocation;
  List<LocationModel> _availableLocations = [];

  List<OvertimeRequest> _activeOvertimeAssignments = [];
  List<OvertimeRequest> _todayOvertimeSchedule = [];
  bool _isLoadingOvertime = false;
  bool _hasActiveOvertime = false;


  // Manager and Approval State
  bool _isLineManager = false;
  String? _lineManagerDocumentId;
  Map<String, dynamic>? _lineManagerData;
  int _pendingApprovalRequests = 0;
  int _pendingOvertimeRequests = 0;
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
  bool _isOvertimeApprover = false;
  Map<String, dynamic>? _approverInfo;
  bool _checkingApproverStatus = true;

  // Offline Support State
  late ConnectivityService _connectivityService;
  late AttendanceRepository _attendanceRepository;
  late LocationRepository _locationRepository;
  late SyncService _syncService;
  bool _needsSync = false;
  late AppLifecycleObserver _lifecycleObserver;

  // Performance Optimization
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeServices();
    _initializeData();
    _setupTimers();
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
    _setupOvertimeApproverIfNeeded();
    _checkOvertimeApproverStatus();

    final notificationService = getIt<NotificationService>();
    notificationService.notificationStream.listen(_handleNotification);

    _connectivityService = getIt<ConnectivityService>();
    _attendanceRepository = getIt<AttendanceRepository>();
    _locationRepository = getIt<LocationRepository>();
    _syncService = getIt<SyncService>();

    if (widget.employeeId == 'EMP1289') {
      _setupOvertimeApproverNotifications();
      _loadPendingOvertimeRequests();
    }

    _connectivityService.connectionStatusStream.listen(_handleConnectivityChange);

    _lifecycleObserver = AppLifecycleObserver(
      onResume: () async {
        debugPrint("App resumed - Refreshing dashboard with force sync");
        await _forceAttendanceSync(); // Use the enhanced sync method
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  void _initializeData() {
    _fetchUserData();
    _fetchAttendanceStatus();
    _fetchTodaysActivity();
    _checkGeofenceStatus();
    _fetchOvertimeAssignments();
    _updateDateTime();
    _fetchWorkSchedule();
    _setupTimingChecks();
  }

  void _setupTimers() {
    // ✅ ENHANCED: More frequent time updates for real-time sync
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _updateDateTime();

        // ✅ NEW: Also check attendance status every minute when online
        if (_connectivityService.currentStatus == ConnectionStatus.online) {
          _fetchAttendanceStatus();
        }
      }
    });

    // ✅ ENHANCED: More frequent overtime refresh for approvers
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isOvertimeApprover) {
        _loadPendingOvertimeRequests();
      } else if (!mounted) {
        timer.cancel();
      }
    });

    // ✅ ENHANCED: More frequent dashboard refresh for cross-device sync
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        debugPrint("⏰ Periodic refresh triggered for cross-device sync");
        _refreshDashboard();
      } else {
        timer.cancel();
      }
    });

    // ✅ NEW: Specific timer for attendance status sync (every 30 seconds when online)
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _connectivityService.currentStatus == ConnectionStatus.online) {
        debugPrint("🔄 Syncing attendance status for cross-device compatibility");
        _fetchAttendanceStatus();
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }





  void _handleConnectivityChange(ConnectionStatus status) {
    debugPrint("Connectivity status changed: $status");
    if (status == ConnectionStatus.online && _needsSync) {
      _syncService.syncData().then((_) {
        _fetchUserData();
        if (_isLineManager) {
          _loadPendingApprovalRequests();
          _loadPendingLeaveApprovals();
        }
        _fetchAttendanceStatus();
        _fetchTodaysActivity();
        if (mounted) {
          setState(() {
            _needsSync = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _timeUpdateTimer?.cancel();
    _periodicRefreshTimer?.cancel();
    _checkOutReminderTimer?.cancel();
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (CustomSnackBar.context == null) {
      CustomSnackBar.context = context;
    }

    return Theme(
      data: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // Main Content - Always visible
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

            // Loading Overlay - Only shows when loading
            if (_isLoading)
              _buildLoadingOverlay(),
          ],
        ),
        floatingActionButton: _buildCleanFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
      child: Center(
        child: Container(
          padding: EdgeInsets.all(isLargeScreen ? 32 : (isTablet ? 28 : 24)),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(cardBorderRadius + 8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: containerSpacing),
              Text(
                'Refreshing Dashboard...',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we sync your data',
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _checkGeofenceStatus,
      tooltip: 'Refresh Location',
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 8,
      child: const Icon(Icons.my_location_rounded, color: Colors.white),
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

  Widget _buildModernHeader() {
    String name = _userData?['name'] ?? 'User';
    String designation = _userData?['designation'] ?? 'Employee';
    String? imageBase64 = _userData?['image'];
    int totalNotificationCount = _pendingApprovalRequests + _pendingOvertimeRequests + _pendingLeaveApprovals;

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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(
                        employeeId: widget.employeeId,
                        userData: _userData!,
                      ),
                    ),
                  );
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
              // 🎨 Dark Modern Gradient for better contrast
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [const Color(0xFF1F2937), const Color(0xFF374151)] // Dark gray gradient
                    : [const Color(0xFF1F2937), const Color(0xFF4B5563)], // Consistent dark theme
              ),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF1F2937).withOpacity(0.15),
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
                                color: Colors.white.withOpacity(0.85),
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
                                  color: Colors.white.withOpacity(0.8),
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
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
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

                  // ✅ ENHANCED: Quick Info Section with Overtime Integration
                  Container(
                    padding: EdgeInsets.all(isLargeScreen ? 18 : (isTablet ? 16 : 14)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ✅ PRIORITY: Active Overtime Information (Show First)
                        if (_hasActiveOvertime && _activeOvertimeAssignments.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.work_history_rounded, color: Colors.orangeAccent, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "OVERTIME ACTIVE NOW",
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ...(_activeOvertimeAssignments.take(2).map((overtime) => Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    children: [
                                      _buildInfoRow(
                                        icon: Icons.business_center_rounded,
                                        label: "Project",
                                        value: "${overtime.projectName} (${overtime.projectCode})",
                                        valueColor: Colors.orangeAccent.withOpacity(0.95),
                                      ),
                                      SizedBox(height: 6),
                                      _buildInfoRow(
                                        icon: Icons.access_time_rounded,
                                        label: "Hours",
                                        value: "${DateFormat('h:mm a').format(overtime.startTime)} - ${DateFormat('h:mm a').format(overtime.endTime)}",
                                        valueColor: Colors.greenAccent.withOpacity(0.9),
                                      ),
                                    ],
                                  ),
                                )).toList()),
                                if (_activeOvertimeAssignments.length > 2)
                                  Text(
                                    "... and ${_activeOvertimeAssignments.length - 2} more active",
                                    style: TextStyle(
                                      color: Colors.orangeAccent.withOpacity(0.8),
                                      fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                        ],

                        // ✅ SECONDARY: Today's Scheduled Overtime (If no active overtime)
                        if (_hasActiveOvertime && _todayOvertimeSchedule.isNotEmpty && _activeOvertimeAssignments.isEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.event_available_rounded, color: Colors.blueAccent, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "📅 TODAY'S OVERTIME SCHEDULE",
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: (isLargeScreen ? 14 : (isTablet ? 13 : 12)) * responsiveFontSize,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ...(_todayOvertimeSchedule.take(3).map((overtime) => Container(
                                  margin: EdgeInsets.only(bottom: 6),
                                  child: _buildInfoRow(
                                    icon: Icons.schedule_rounded,
                                    label: "${overtime.projectName}",
                                    value: "${DateFormat('h:mm a').format(overtime.startTime)} - ${DateFormat('h:mm a').format(overtime.endTime)}",
                                    valueColor: Colors.blueAccent.withOpacity(0.9),
                                  ),
                                )).toList()),
                                if (_todayOvertimeSchedule.length > 3)
                                  Text(
                                    "... ${_todayOvertimeSchedule.length - 3} more scheduled",
                                    style: TextStyle(
                                      color: Colors.blueAccent.withOpacity(0.8),
                                      fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                        ],

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

                  // ✅ ENHANCED: Status badges with overtime integration
                  if (_needsSync || _connectivityService.currentStatus == ConnectionStatus.offline || _hasActiveOvertime) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white.withOpacity(0.7), size: 16),
                              SizedBox(width: 8),
                              Text(
                                "Status Indicators",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
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
                              // ✅ Active Overtime Badge
                              if (_hasActiveOvertime && _activeOvertimeAssignments.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.work_history, size: 14, color: Colors.orangeAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "Overtime Active",
                                        style: TextStyle(
                                          color: Colors.orangeAccent.withOpacity(0.95),
                                          fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // ✅ Scheduled Overtime Badge
                              if (_hasActiveOvertime && _todayOvertimeSchedule.isNotEmpty && _activeOvertimeAssignments.isEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available, size: 14, color: Colors.blueAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "${_todayOvertimeSchedule.length} Overtime Scheduled",
                                        style: TextStyle(
                                          color: Colors.blueAccent.withOpacity(0.95),
                                          fontSize: (isLargeScreen ? 12 : (isTablet ? 11 : 10)) * responsiveFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Existing badges
                              if (_needsSync && _isCheckedIn)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync, size: 14, color: Colors.amberAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "Pending Sync",
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
                                    color: Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.wifi_off, size: 14, color: Colors.redAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        "Offline Mode",
                                        style: TextStyle(
                                          color: Colors.redAccent.withOpacity(0.95),
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
                        color: Colors.orangeAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.3),
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
                            ? const Color(0xFFE53E3E) // More vibrant red for check out
                            : const Color(0xFF38A169), // More vibrant green for check in
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

  Widget _buildQuickActionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 8 : 4, bottom: isTablet ? 20 : 16),
            child: Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: (isLargeScreen ? 28 : (isTablet ? 24 : 20)) * responsiveFontSize,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),

          if (_hasActiveRestTiming())
            _buildRestTimingCard(),

          SizedBox(height: containerSpacing),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isLargeScreen ? 4 : (isTablet ? 4 : 2),
            crossAxisSpacing: isTablet ? 16 : 12,
            mainAxisSpacing: isTablet ? 16 : 12,
            childAspectRatio: isLargeScreen ? 1.3 : (isTablet ? 1.2 : 1.1),
            children: [
              _buildQuickActionCard(
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
              _buildQuickActionCard(
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
              _buildQuickActionCard(
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
              if (_userData != null &&
                  (_userData!['hasOvertimeAccess'] == true ||
                      _userData!['overtimeAccessGrantedAt'] != null ||
                      _userData!['standardizedOvertimeAccess'] == true))
                _buildQuickActionCard(
                  icon: Icons.access_time,
                  title: "Overtime",
                  subtitle: "Request overtime",
                  color: Colors.orange,
                  onTap: () {
                    debugPrint("🎯 DATABASE-VERIFIED: Overtime card tapped");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateOvertimeView(
                          requesterId: widget.employeeId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardBorderRadius + 4),
        child: Container(
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isLargeScreen ? 16 : (isTablet ? 12 : 10)),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isLargeScreen ? 32 : (isTablet ? 28 : 24),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                    color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

    setState(() {
      _isCheckingLocation = true;
    });

    try {
      Map<String, dynamic> status = await EnhancedGeofenceUtil.checkGeofenceStatus(context);

      bool withinGeofence = status['withinGeofence'] as bool;
      double? distance = status['distance'] as double?;
      String locationType = status['locationType'] as String? ?? 'unknown';

      if (locationType == 'polygon') {
        final polygonLocation = status['location'] as PolygonLocationModel?;

        if (mounted) {
          setState(() {
            _isWithinGeofence = withinGeofence;
            _distanceToOffice = distance;

            if (polygonLocation != null) {
              _nearestLocation = LocationModel(
                id: polygonLocation.id,
                name: "${polygonLocation.name} (Polygon Boundary)",
                address: polygonLocation.description,
                latitude: polygonLocation.centerLatitude,
                longitude: polygonLocation.centerLongitude,
                radius: 0,
                isActive: polygonLocation.isActive,
              );
            } else {
              _nearestLocation = null;
            }

            _isCheckingLocation = false;
          });
        }
      } else {
        final circularLocation = status['location'] as LocationModel?;

        if (mounted) {
          setState(() {
            _isWithinGeofence = withinGeofence;
            _nearestLocation = circularLocation;
            _distanceToOffice = distance;
            _isCheckingLocation = false;
          });
        }
      }

      if (mounted) {
        _fetchAvailableLocations();
      }
    } catch (e) {
      debugPrint('Error checking geofence: $e');
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
        });
        CustomSnackBar.errorSnackBar(context, "Error checking geofence status: $e");
      }
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
      debugPrint("=== FETCHING WORK SCHEDULE ===");

      String? employeePin = _userData!['pin']?.toString();
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
          debugPrint("✅ Work schedule loaded successfully");
          _setupCheckOutReminder();
          _updateCurrentTimingMessage();
        } else {
          debugPrint("⚠️ No work schedule found");
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching work schedule: $e");
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

    debugPrint("=== FETCH USER DATA COMPLETE ===");

    debugPrint("🕐 Starting work schedule fetch...");
    _fetchWorkSchedule();
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
      Map<String, dynamic> dataCopy = Map<String, dynamic>.from(userData);

      dataCopy.forEach((key, value) {
        if (value is Timestamp) {
          dataCopy[key] = value.toDate().toIso8601String();
        }
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data_${widget.employeeId}', jsonEncode(dataCopy));
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

  Future<void> _fetchAttendanceStatus() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // ✅ STEP 1: Always check local data first
      final localAttendance = await _attendanceRepository.getTodaysAttendance(widget.employeeId);

      if (localAttendance != null && mounted) {
        setState(() {
          _isCheckedIn = localAttendance.checkIn != null && localAttendance.checkOut == null;
          if (_isCheckedIn && localAttendance.checkIn != null) {
            _checkInTime = DateTime.parse(localAttendance.checkIn!);
          } else {
            _checkInTime = null;
          }
        });

        debugPrint("📱 Local attendance status: CheckedIn=$_isCheckedIn, CheckOut=${localAttendance.checkOut}");
      }

      // ✅ STEP 2: If online, force refresh from the CORRECT Firestore path
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          // 🔥 FIXED: Use the same path as the repository
          DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
              .collection('Attendance_Records')
              .doc('PTSEmployees')
              .collection('Records')
              .doc('${widget.employeeId}-$today')
              .get()
              .timeout(const Duration(seconds: 5));

          if (attendanceDoc.exists && mounted) {
            Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;

            debugPrint("🌐 Fresh Firestore data: $data");

            // Convert Timestamp to DateTime for state management
            DateTime? firestoreCheckIn;
            DateTime? firestoreCheckOut;

            if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
              firestoreCheckIn = (data['checkIn'] as Timestamp).toDate();
            }

            if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
              firestoreCheckOut = (data['checkOut'] as Timestamp).toDate();
            }

            setState(() {
              _isCheckedIn = firestoreCheckIn != null && firestoreCheckOut == null;
              if (_isCheckedIn && firestoreCheckIn != null) {
                _checkInTime = firestoreCheckIn;
              } else {
                _checkInTime = null;
              }
            });

            debugPrint("🔄 Updated dashboard state: CheckedIn=$_isCheckedIn, CheckIn=$firestoreCheckIn, CheckOut=$firestoreCheckOut");

            // ✅ STEP 3: Update local cache with fresh Firestore data
            await _saveAttendanceStatusLocally(today, data);

            // ✅ STEP 4: Also update the repository's local cache
            await _updateRepositoryCache(data, today);

          } else {
            debugPrint("📭 No attendance record found in Firestore for today");
          }
        } catch (e) {
          debugPrint("❌ Network error fetching from correct Firestore path: $e");
        }
      }
    } catch (e) {
      debugPrint("❌ Error in _fetchAttendanceStatus: $e");
      if (mounted) {
        setState(() {
          _isCheckedIn = false;
          _checkInTime = null;
        });
      }
    }
  }


  Future<void> _updateRepositoryCache(Map<String, dynamic> firestoreData, String date) async {
    try {
      // Convert Timestamps to ISO strings
      Map<String, dynamic> localData = Map<String, dynamic>.from(firestoreData);

      if (localData['checkIn'] != null && localData['checkIn'] is Timestamp) {
        localData['checkIn'] = (localData['checkIn'] as Timestamp).toDate().toIso8601String();
      }
      if (localData['checkOut'] != null && localData['checkOut'] is Timestamp) {
        localData['checkOut'] = (localData['checkOut'] as Timestamp).toDate().toIso8601String();
      }

      // Create/update local record through repository
      LocalAttendanceRecord record = LocalAttendanceRecord(
        employeeId: widget.employeeId,
        date: date,
        checkIn: localData['checkIn'],
        checkOut: localData['checkOut'],
        locationId: localData['locationId'] ?? 'unknown',
        isSynced: true,
        rawData: localData,
      );

      // Update local database directly
      final dbHelper = getIt<DatabaseHelper>();

      // Delete existing record for today
      await dbHelper.delete(
        'attendance',
        where: 'employee_id = ? AND date = ?',
        whereArgs: [widget.employeeId, date],
      );

      // Insert fresh record
      await dbHelper.insert('attendance', record.toMap());

      debugPrint("✅ Repository cache updated with fresh Firestore data");

    } catch (e) {
      debugPrint("❌ Error updating repository cache: $e");
    }
  }

  Future<void> _saveAttendanceStatusLocally(String date, Map<String, dynamic> data) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (data['checkIn'] != null && data['checkIn'] is Timestamp) {
        data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
      }
      if (data['checkOut'] != null && data['checkOut'] is Timestamp) {
        data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
      }
      await prefs.setString('attendance_${widget.employeeId}_$date', jsonEncode(data));
      debugPrint("Attendance status saved locally for date: $date");
    } catch (e) {
      debugPrint('Error saving attendance status locally: $e');
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

    await _checkGeofenceStatus();

    if (!_isCheckedIn) {
      // ================ CHECK-IN FLOW ================
      debugPrint("✅ Starting check-in process...");

      // Validate work schedule timing if available
      if (_workSchedule != null) {
        DateTime checkInTime = DateTime.now();
        ScheduleCheckResult result = WorkScheduleService.checkCheckInTiming(_workSchedule!, checkInTime);
        bool shouldProceed = await _showTimingValidationDialog(result);
        if (!shouldProceed) return;
      }

      if (!mounted) return;
      setState(() => _isAuthenticating = true);

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

        setState(() => _isAuthenticating = false);

        debugPrint("🔍 Check-in authentication result: $result");

        if (result == true) {
          debugPrint("✅ Face authentication successful for check-in");
          await _processCheckIn();
        } else {
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

      // Validate work schedule timing if available
      if (_workSchedule != null) {
        DateTime checkOutTime = DateTime.now();
        ScheduleCheckResult result = WorkScheduleService.checkCheckOutTiming(_workSchedule!, checkOutTime);
        bool shouldProceed = await _showTimingValidationDialog(result);
        if (!shouldProceed) return;
      }

      if (!mounted) return;
      setState(() => _isAuthenticating = true);

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

        setState(() => _isAuthenticating = false);

        debugPrint("🔍 Check-out authentication result: $result");

        if (result == true) {
          debugPrint("✅ Face authentication successful for check-out");
          await _processCheckOut();
        } else {
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

// ================ ADD THESE NEW METHODS ================

  /// Process check-in after successful authentication
  Future<void> _processCheckIn() async {
    try {
      Position? currentPosition = await GeofenceUtil.getCurrentPosition();

      await CheckInOutHandler.handleOffLocationAction(
        context: context,
        employeeId: widget.employeeId,
        employeeName: _userData?['name'] ?? 'Employee',
        isWithinGeofence: _isWithinGeofence,
        currentPosition: currentPosition,
        isCheckIn: true,
        onRegularAction: () async {
          debugPrint("🏢 Recording check-in...");

          bool checkInSuccess = await _attendanceRepository.recordCheckIn(
            employeeId: widget.employeeId,
            checkInTime: DateTime.now(),
            locationId: _nearestLocation?.id ?? 'default',
            locationName: _nearestLocation?.name ?? 'Unknown',
            locationLat: currentPosition?.latitude ?? _nearestLocation!.latitude,
            locationLng: currentPosition?.longitude ?? _nearestLocation!.longitude,
          );

          if (checkInSuccess && mounted) {
            // ✅ Update state immediately
            setState(() {
              _isCheckedIn = true;
              _checkInTime = DateTime.now();
              if (_connectivityService.currentStatus == ConnectionStatus.offline) {
                _needsSync = true;
              }
            });

            _setupCheckOutReminder();

            // ✅ Force refresh dashboard state
            await Future.delayed(const Duration(milliseconds: 500));
            await _fetchAttendanceStatus();
            await _fetchTodaysActivity();

            CustomSnackBar.successSnackBar("✅ Checked in successfully at $_currentTime");

            // Final verification
            Timer(const Duration(seconds: 2), () async {
              if (mounted) {
                await _fetchAttendanceStatus();
                debugPrint("✅ Check-in state verified: _isCheckedIn = $_isCheckedIn");
              }
            });

          } else if (mounted) {
            CustomSnackBar.errorSnackBar("❌ Failed to record check-in. Please try again.");
          }
        },
      );
    } catch (e) {
      debugPrint("❌ Error processing check-in: $e");
      CustomSnackBar.errorSnackBar("Check-in error: $e");
    }
  }

  /// Process check-out after successful authentication
  Future<void> _processCheckOut() async {
    try {
      Position? currentPosition = await GeofenceUtil.getCurrentPosition();

      await CheckInOutHandler.handleOffLocationAction(
        context: context,
        employeeId: widget.employeeId,
        employeeName: _userData?['name'] ?? 'Employee',
        isWithinGeofence: _isWithinGeofence,
        currentPosition: currentPosition,
        isCheckIn: false,
        onRegularAction: () async {
          debugPrint("🏃‍♂️ Recording check-out...");

          bool checkOutSuccess = await _attendanceRepository.recordCheckOut(
            employeeId: widget.employeeId,
            checkOutTime: DateTime.now(),
          );

          if (checkOutSuccess && mounted) {
            // ✅ Update state immediately
            setState(() {
              _isCheckedIn = false;
              _checkInTime = null;
              if (_connectivityService.currentStatus == ConnectionStatus.offline) {
                _needsSync = true;
              }
            });

            _checkOutReminderTimer?.cancel();

            // ✅ Force refresh dashboard state
            await Future.delayed(const Duration(milliseconds: 500));
            await _fetchAttendanceStatus();
            await _fetchTodaysActivity();

            CustomSnackBar.successSnackBar("✅ Checked out successfully at $_currentTime");

            // Enhanced verification for Android
            Timer(const Duration(seconds: 2), () async {
              if (mounted) {
                await _fetchAttendanceStatus();
                if (_isCheckedIn) {
                  debugPrint("⚠️ Check-out state inconsistency detected, forcing refresh...");

                  // Force refresh from Firestore
                  await _attendanceRepository.forceRefreshTodayFromFirestore(widget.employeeId);
                  await _fetchAttendanceStatus();

                  if (_isCheckedIn) {
                    debugPrint("🚨 State still inconsistent after force refresh!");
                    CustomSnackBar.errorSnackBar("⚠️ Check-out recorded but state inconsistent. Please sync manually.");
                  } else {
                    debugPrint("✅ Check-out state corrected after force refresh");
                  }
                }
                debugPrint("✅ Check-out state verified: _isCheckedIn = $_isCheckedIn");
              }
            });

            // ✅ Additional verification after longer delay
            Timer(const Duration(seconds: 5), () async {
              if (mounted) {
                await _fetchAttendanceStatus();
                debugPrint("✅ Check-out state final verification: _isCheckedIn = $_isCheckedIn");

                // If still showing as checked in, show manual sync option
                if (_isCheckedIn) {
                  _showCheckOutSyncDialog();
                }
              }
            });

          } else if (mounted) {
            CustomSnackBar.errorSnackBar("❌ Failed to record check-out. Please try again.");
          }
        },
      );
    } catch (e) {
      debugPrint("❌ Error processing check-out: $e");
      CustomSnackBar.errorSnackBar("Check-out error: $e");
    }
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


  Future<void> _forceAttendanceSync() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    setState(() => _isLoading = true); // Only show loading for manual actions

    try {
      debugPrint("🔄 Starting force attendance sync...");

      await _attendanceRepository.forceRefreshTodayFromFirestore(widget.employeeId);
      await _fetchAttendanceStatus();
      await _fetchTodaysActivity();
      await _attendanceRepository.syncPendingRecords();

      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchAttendanceStatus();

      setState(() {
        _needsSync = false;
        _isLoading = false;
      });

      debugPrint("✅ Force attendance sync completed");
      CustomSnackBar.successSnackBar("Attendance data synchronized successfully!");

    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("❌ Error during force attendance sync: $e");
      CustomSnackBar.errorSnackBar("Sync failed: $e");
    }
  }

  Future<void> _refreshDashboard() async {
    debugPrint("🔄 Starting dashboard refresh...");

    // Force refresh attendance status first
    await _fetchAttendanceStatus();

    // Then refresh other data
    await _fetchUserData();
    await _fetchTodaysActivity();
    await _fetchOvertimeAssignments(); // ✅ ADD THIS LINE
    await _checkGeofenceStatus();

    if (_connectivityService.currentStatus == ConnectionStatus.online) {
      final pendingRecords = await _attendanceRepository.getPendingRecords();
      if (mounted) {
        setState(() {
          _needsSync = pendingRecords.isNotEmpty;
        });
      }
    }

    if (_isLineManager) {
      await _loadPendingApprovalRequests();
      await _loadPendingLeaveApprovals();
    }

    debugPrint("Enhanced dashboard refresh completed");
  }

  Future<void> _manualSync() async {
    if (_connectivityService.currentStatus == ConnectionStatus.offline) {
      CustomSnackBar.errorSnackBar("Cannot sync while offline. Please check your connection.");
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _syncService.manualSync();

      await _fetchUserData();
      await _fetchAttendanceStatus();
      await _fetchTodaysActivity();

      if (mounted) {
        setState(() {
          _needsSync = false;
          _isLoading = false;
        });
      }

      CustomSnackBar.successSnackBar("Data synchronized successfully");
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      CustomSnackBar.errorSnackBar("Error during sync: $e");
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

  Future<void> _checkOvertimeApproverStatus() async {
    if (mounted) {
      setState(() => _checkingApproverStatus = true);
    }

    try {
      debugPrint("=== DASHBOARD: CHECKING OVERTIME APPROVER STATUS ===");
      debugPrint("Current Employee: ${widget.employeeId}");
      debugPrint("Employee Name: ${_userData?['name']}");
      debugPrint("Employee PIN: ${_userData?['pin']}");

      bool isApprover = await OvertimeApproverService.isApprover(widget.employeeId);

      debugPrint("🎯 APPROVER SERVICE RESULT: $isApprover");

      if (isApprover) {
        debugPrint("✅ User IS an overtime approver");

        Map<String, dynamic>? approverInfo = await OvertimeApproverService.getCurrentApprover();

        if (approverInfo != null) {
          debugPrint("✅ Approver info retrieved:");
          debugPrint("  - ID: ${approverInfo['approverId']}");
          debugPrint("  - Name: ${approverInfo['approverName']}");
          debugPrint("  - Source: ${approverInfo['source']}");
        }

        await _setupApproverNotifications();

        if (mounted) {
          setState(() {
            _isOvertimeApprover = true;
            _approverInfo = approverInfo;
            _checkingApproverStatus = false;
          });
        }

        await _loadPendingOvertimeRequests();

        debugPrint("✅ DASHBOARD: Approver setup completed successfully");

        if (mounted) {
          CustomSnackBar.successSnackBar("You are now set up as an overtime approver!");
        }

      } else {
        debugPrint("❌ User is NOT an overtime approver");

        if (widget.employeeId == 'scvCD591SEspd8jKuIGZ' && _userData?['pin'] == '1289') {
          debugPrint("🔧 FORCE SETUP: This user has PIN 1289, setting up as approver...");

          bool forceSetup = await OvertimeApproverService.forceSetupCurrentUserAsApprover(
            employeeId: widget.employeeId,
            employeeName: _userData?['name'] ?? 'Overtime Approver',
          );

          if (forceSetup) {
            debugPrint("✅ Force setup successful, rechecking...");
            await _checkOvertimeApproverStatus();
            return;
          }
        }

        if (mounted) {
          setState(() {
            _isOvertimeApprover = false;
            _approverInfo = null;
            _checkingApproverStatus = false;
          });
        }
      }

    } catch (e) {
      debugPrint("❌ Error checking approver status: $e");
      if (mounted) {
        setState(() {
          _isOvertimeApprover = false;
          _approverInfo = null;
          _checkingApproverStatus = false;
        });

        CustomSnackBar.errorSnackBar("Error checking overtime approver status: $e");
      }
    }
  }

  Future<void> _setupApproverNotifications() async {
    try {
      debugPrint("=== SETTING UP APPROVER NOTIFICATIONS ===");
      debugPrint("Setting up notifications for: ${widget.employeeId}");

      final fcmTokenService = getIt<FcmTokenService>();
      final notificationService = getIt<NotificationService>();

      await fcmTokenService.registerTokenForUser(widget.employeeId);

      if (widget.employeeId.startsWith('EMP')) {
        String altId = widget.employeeId.substring(3);
        await fcmTokenService.registerTokenForUser(altId);
        debugPrint("Also registered FCM for alt ID: $altId");
      }

      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');
      await notificationService.subscribeToTopic('all_overtime_approvers');

      if (widget.employeeId.startsWith('EMP')) {
        String altId = widget.employeeId.substring(3);
        await notificationService.subscribeToTopic('overtime_approver_$altId');
      }

      DocumentSnapshot tokenDoc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc(widget.employeeId)
          .get();

      if (tokenDoc.exists) {
        debugPrint("✅ FCM token verified in Firestore for ${widget.employeeId}");
        var tokenData = tokenDoc.data() as Map<String, dynamic>;
        debugPrint("Token: ${tokenData['token']?.substring(0, 20) ?? 'null'}...");
      } else {
        debugPrint("⚠️ FCM token NOT found in Firestore, forcing refresh...");
        await fcmTokenService.forceTokenRefresh(widget.employeeId);
      }

      debugPrint("✅ Approver notification setup completed");

    } catch (e) {
      debugPrint("❌ Error setting up approver notifications: $e");
    }
  }

  Future<void> _setupOvertimeApproverIfNeeded() async {
    try {
      debugPrint("=== CHECKING IF USER IS OVERTIME APPROVER ===");
      debugPrint("Current Employee: ${widget.employeeId}");

      bool shouldBeApprover = await _checkIfShouldBeOvertimeApprover();

      if (shouldBeApprover) {
        debugPrint("✅ User should be overtime approver, setting up...");

        final fcmTokenService = getIt<FcmTokenService>();
        await fcmTokenService.forceTokenRefresh(widget.employeeId);

        if (widget.employeeId.startsWith('EMP')) {
          await fcmTokenService.registerTokenForUser(widget.employeeId.substring(3));
        } else {
          await fcmTokenService.registerTokenForUser('EMP${widget.employeeId}');
        }

        await _setupAsOvertimeApprover();

        final notificationService = getIt<NotificationService>();
        await notificationService.subscribeToTopic('overtime_requests');
        await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');

        String altId = widget.employeeId.startsWith('EMP')
            ? widget.employeeId.substring(3)
            : 'EMP${widget.employeeId}';
        await notificationService.subscribeToTopic('overtime_approver_$altId');

        await notificationService.subscribeToTopic('all_employees');

        debugPrint("✅ Approver setup completed successfully");
      } else {
        debugPrint("ℹ️ User is not an overtime approver");
      }
    } catch (e) {
      debugPrint("Error in overtime approver setup: $e");
    }
  }

  Future<bool> _checkIfShouldBeOvertimeApprover() async {
    try {
      DocumentSnapshot approverDoc = await FirebaseFirestore.instance
          .collection('overtime_approvers')
          .doc(widget.employeeId)
          .get();

      if (approverDoc.exists) {
        Map<String, dynamic> data = approverDoc.data() as Map<String, dynamic>;
        if (data['isActive'] == true) {
          debugPrint("Found in overtime_approvers collection");
          return true;
        }
      }

      DocumentSnapshot empDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (empDoc.exists) {
        Map<String, dynamic> data = empDoc.data() as Map<String, dynamic>;
        if (data['hasOvertimeApprovalAccess'] == true) {
          debugPrint("Found hasOvertimeApprovalAccess in employees collection");
          return true;
        }
      }

      DocumentSnapshot masterDoc = await FirebaseFirestore.instance
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      if (masterDoc.exists) {
        Map<String, dynamic> data = masterDoc.data() as Map<String, dynamic>;
        if (data['hasOvertimeApprovalAccess'] == true) {
          debugPrint("Found hasOvertimeApprovalAccess in MasterSheet");
          return true;
        }
      }

      QuerySnapshot managerQuery = await FirebaseFirestore.instance
          .collection('line_managers')
          .where('managerId', isEqualTo: widget.employeeId)
          .where('canApproveOvertime', isEqualTo: true)
          .limit(1)
          .get();

      if (managerQuery.docs.isNotEmpty) {
        debugPrint("Found as line manager with overtime approval");
        return true;
      }

      if (widget.employeeId == 'EMP1289') {
        debugPrint("Default approver EMP1289 detected");
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Error checking overtime approver status: $e");
      return false;
    }
  }

  Future<void> _setupAsOvertimeApprover() async {
    try {
      debugPrint("Setting up ${widget.employeeId} as overtime approver");

      String employeeName = _userData?['name'] ?? _userData?['employeeName'] ?? 'Overtime Approver';

      final callable = FirebaseFunctions.instance.httpsCallable('setupOvertimeApprover');
      final result = await callable.call({
        'employeeId': widget.employeeId,
        'employeeName': employeeName,
      });

      if (result.data['success'] == true) {
        debugPrint("✅ Overtime approver setup successful");
        await _setupOvertimeNotifications();
        CustomSnackBar.successSnackBar(context, "You are now set up as an overtime approver!");
      } else {
        debugPrint("❌ Overtime approver setup failed");
        CustomSnackBar.errorSnackBar(context, "Failed to set up as overtime approver");
      }
    } catch (e) {
      debugPrint("Error setting up overtime approver: $e");
      CustomSnackBar.errorSnackBar(context, "Error setting up approver: $e");
    }
  }

  Future<void> _setupOvertimeNotifications() async {
    try {
      debugPrint("Setting up overtime notifications for ${widget.employeeId}");

      final notificationService = getIt<NotificationService>();
      final fcmTokenService = getIt<FcmTokenService>();

      await fcmTokenService.registerTokenForUser(widget.employeeId);

      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('overtime_approver_${widget.employeeId}');

      String altId = widget.employeeId.startsWith('EMP')
          ? widget.employeeId.substring(3)
          : 'EMP${widget.employeeId}';
      await notificationService.subscribeToTopic('overtime_approver_$altId');

      final callable = FirebaseFunctions.instance.httpsCallable('registerOvertimeApproverToken');

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcm_token');

      if (token != null) {
        await callable.call({
          'approverId': widget.employeeId,
          'token': token,
          'approverName': _userData?['name'] ?? _userData?['employeeName'] ?? 'Overtime Approver',
        });

        debugPrint("✅ Overtime notification setup completed");
      } else {
        debugPrint("⚠️ No FCM token available for registration");
      }
    } catch (e) {
      debugPrint("Error setting up overtime notifications: $e");
    }
  }

  Future<void> _loadPendingOvertimeRequests() async {
    if (!_isOvertimeApprover) return;

    try {
      debugPrint("=== LOADING PENDING OVERTIME REQUESTS ===");
      debugPrint("Loading for approver: ${widget.employeeId}");

      List<String> approverIds = [
        widget.employeeId,
        'EMP${widget.employeeId}',
        widget.employeeId.startsWith('EMP') ? widget.employeeId.substring(3) : widget.employeeId,
      ];

      debugPrint("Checking for approver IDs: $approverIds");

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      int matchingRequests = 0;
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String docApproverId = data['approverEmpId']?.toString() ?? '';

          debugPrint("Request ${doc.id}: approverEmpId = '$docApproverId'");

          for (String approverId in approverIds) {
            if (docApproverId == approverId) {
              matchingRequests++;
              debugPrint("✅ MATCH: Request ${doc.id} matches approver $approverId");
              break;
            }
          }
        } catch (e) {
          debugPrint("Error processing request ${doc.id}: $e");
        }
      }

      debugPrint("Found $matchingRequests pending overtime requests");

      if (mounted) {
        setState(() {
          _pendingOvertimeRequests = matchingRequests;
        });
      }

    } catch (e) {
      debugPrint("❌ Error loading pending overtime requests: $e");
      if (mounted) {
        setState(() {
          _pendingOvertimeRequests = 0;
        });
      }
    }
  }

  Future<void> _setupOvertimeApproverNotifications() async {
    if (widget.employeeId != 'EMP1289') return;

    try {
      print("=== SETTING UP OVERTIME APPROVER NOTIFICATIONS ===");

      final fcmTokenService = getIt<FcmTokenService>();
      await fcmTokenService.registerTokenForUser('EMP1289');
      await fcmTokenService.registerTokenForUser('1289');

      final notificationService = getIt<NotificationService>();
      await notificationService.subscribeToTopic('overtime_approver_EMP1289');
      await notificationService.subscribeToTopic('overtime_approver_1289');
      await notificationService.subscribeToTopic('overtime_requests');
      await notificationService.subscribeToTopic('all_overtime_approvers');

      final tokenDoc = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .doc('EMP1289')
          .get();

      if (tokenDoc.exists) {
        print("✅ EMP1289 FCM token verified: ${tokenDoc.data()}");
      } else {
        print("❌ EMP1289 FCM token not found, attempting force refresh");
        await fcmTokenService.forceTokenRefresh('EMP1289');
      }

      print("=== OVERTIME APPROVER SETUP COMPLETE ===");
    } catch (e) {
      print("Error setting up overtime approver notifications: $e");
    }
  }

  void _handleNotification(Map<String, dynamic> data) {
    final notificationType = data['type'];
    debugPrint("=== NOTIFICATION RECEIVED ===");
    debugPrint("Type: $notificationType");
    debugPrint("Data: $data");
    debugPrint("Current Employee: ${widget.employeeId}");

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
    else if (notificationType == 'overtime_request') {
      debugPrint("⚠️ OVERTIME REQUEST NOTIFICATION RECEIVED");

      if (_isOvertimeApprover) {
        final String projectName = data['projectName'] ?? 'Project';
        final String requesterName = data['requesterName'] ?? 'Someone';
        final String employeeCount = data['employeeCount'] ?? '0';

        CustomSnackBar.successSnackBar(
            "$requesterName requested overtime for $employeeCount employees in $projectName"
        );

        _loadPendingOvertimeRequests();
      }
    }
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

  // Settings Menu - Complete Implementation
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Increased height
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
                    'Settings & Tools',
                    style: TextStyle(
                      fontSize: (isLargeScreen ? 32 : (isTablet ? 28 : 24)) * responsiveFontSize,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Settings options with NEW DEBUG & SYNC OPTIONS
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
                        subtitle: 'View your attendance history and overtime records',
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

                    // ======= SYSTEM TOOLS (NEW SECTION) =======
                    _buildSettingsSection("System Tools", [
                      _buildModernSettingsOption(
                        icon: Icons.sync_rounded,
                        title: 'Force Attendance Sync',
                        subtitle: 'Sync attendance data across all devices',
                        iconColor: Colors.green,
                        onTap: () async {
                          Navigator.pop(context);
                          await _forceAttendanceSync();
                        },
                      ),

                      _buildModernSettingsOption(
                        icon: Icons.cloud_sync,
                        title: 'Manual Data Sync',
                        subtitle: 'Sync all pending data to cloud',
                        iconColor: Colors.orange,
                        isEnabled: _needsSync && _connectivityService.currentStatus == ConnectionStatus.online,
                        onTap: () async {
                          Navigator.pop(context);
                          await _manualSync();
                        },
                      ),

                      _buildModernSettingsOption(
                        icon: Icons.location_searching,
                        title: 'View All Locations',
                        subtitle: 'See available office locations and distances',
                        iconColor: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          _showLocationMenu(context);
                        },
                      ),

                      _buildModernSettingsOption(
                        icon: Icons.cloud_download,
                        title: 'Recover Face Data',
                        subtitle: 'Download face authentication data from cloud',
                        iconColor: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          _forceFaceDataRecovery();
                        },
                      ),
                    ]),

                    // ======= DEVELOPER TOOLS (NEW SECTION) =======
                    if (kDebugMode || widget.employeeId == 'EMP1289')
                      _buildSettingsSection("Developer Tools", [
                        _buildModernSettingsOption(
                          icon: Icons.bug_report,
                          title: 'Debug Local Data',
                          subtitle: 'View local database and cache information',
                          iconColor: Colors.red,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DebugDataScreen(employeeId: widget.employeeId),
                              ),
                            );
                          },
                        ),

                        _buildModernSettingsOption(
                          icon: Icons.refresh,
                          title: 'Force Dashboard Refresh',
                          subtitle: 'Reload all dashboard data from server',
                          iconColor: Colors.indigo,
                          onTap: () async {
                            Navigator.pop(context);
                            await _refreshDashboard();
                          },
                        ),

                        if (widget.employeeId == 'EMP1289')
                          _buildModernSettingsOption(
                            icon: Icons.science,
                            title: 'Offline Test Mode',
                            subtitle: 'Test offline functionality',
                            iconColor: Colors.teal,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OfflineTestView(
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

                      if (widget.employeeId == 'EMP1289')
                        _buildModernSettingsOption(
                          icon: Icons.admin_panel_settings,
                          title: 'Admin Panel',
                          subtitle: 'Administrative controls',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationAdminView(
                                  userId: widget.employeeId,
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
    bool isEnabled = true, // NEW PARAMETER
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

                    // Overtime section
                    if (_isOvertimeApprover && _approverInfo != null)
                      Container(
                        margin: EdgeInsets.only(bottom: containerSpacing),
                        padding: EdgeInsets.all(isLargeScreen ? 24 : (isTablet ? 20 : 16)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.withOpacity(0.8), Colors.red.withOpacity(0.8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(cardBorderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                                SizedBox(width: containerSpacing * 0.75),
                                Expanded(
                                  child: Text(
                                    "OVERTIME APPROVER",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: (isLargeScreen ? 20 : (isTablet ? 18 : 16)) * responsiveFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_pendingOvertimeRequests > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _pendingOvertimeRequests.toString(),
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: (isLargeScreen ? 16 : (isTablet ? 14 : 12)) * responsiveFontSize,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: containerSpacing),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PendingOvertimeView(
                                        approverId: widget.employeeId,
                                      ),
                                    ),
                                  ).then((_) => _loadPendingOvertimeRequests());
                                },
                                icon: const Icon(Icons.visibility),
                                label: Text("Review $_pendingOvertimeRequests Pending Requests"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.red,
                                  padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_userData != null &&
                        (_userData!['hasOvertimeAccess'] == true ||
                            _userData!['overtimeAccessGrantedAt'] != null))
                      _buildNotificationOption(
                        icon: Icons.access_time,
                        title: 'Request Overtime',
                        subtitle: 'Create new overtime request',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateOvertimeView(
                                requesterId: widget.employeeId,
                              ),
                            ),
                          );
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