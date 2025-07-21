// lib/dashboard/my_attendance_view.dart - FINAL FIXED VERSION WITH CROSS-DEVICE SYNC

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/model/overtime_request_model.dart';
import 'package:face_auth/model/attendance_model.dart';
import 'package:face_auth/repositories/attendance_repository.dart';
import 'package:face_auth/services/employee_overtime_service.dart';
import 'package:face_auth/services/service_locator.dart';

class MyAttendanceView extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> userData;

  const MyAttendanceView({
    Key? key,
    required this.employeeId,
    required this.userData,
  }) : super(key: key);

  @override
  State<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends State<MyAttendanceView> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // Services and repositories
  late EmployeeOvertimeService _overtimeService;
  late AttendanceRepository _attendanceRepository;

  // Attendance data
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoadingAttendance = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Overtime data
  List<OvertimeRequest> _overtimeHistory = [];
  List<OvertimeRequest> _filteredOvertimeHistory = [];
  List<OvertimeRequest> _todayOvertimeRequests = [];
  bool _isLoadingOvertime = true;
  bool _hasOvertimeAccess = false;
  Map<String, dynamic> _overtimeStatistics = {};

  // Filter and search for overtime
  String _overtimeSearchQuery = '';
  OvertimeRequestStatus? _selectedOvertimeStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _initializeEverything();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION METHODS =====
  Future<void> _initializeEverything() async {
    try {
      debugPrint("🚀 === INITIALIZING ATTENDANCE VIEW FOR ${widget.employeeId} ===");

      await _initializeServices();
      await _checkOvertimeAccess();
      await _fetchInitialData();

    } catch (e) {
      debugPrint("❌ Error during initialization: $e");
      _setupAttendanceOnlyView();
    }
  }

  Future<void> _initializeServices() async {
    try {
      debugPrint("🔧 Initializing services...");

      _attendanceRepository = getIt<AttendanceRepository>();
      debugPrint("✅ Successfully got AttendanceRepository from GetIt");

      try {
        _overtimeService = getIt<EmployeeOvertimeService>();
        debugPrint("✅ Successfully got EmployeeOvertimeService from GetIt");
      } catch (e) {
        debugPrint("❌ Error getting EmployeeOvertimeService from GetIt: $e");
        _overtimeService = EmployeeOvertimeService();
      }

    } catch (e) {
      debugPrint("❌ Error initializing services: $e");
      rethrow;
    }
  }

  Future<void> _checkOvertimeAccess() async {
    try {
      debugPrint("🔐 Checking overtime access for ${widget.employeeId}...");

      bool hasAccess = await _overtimeService.hasOvertimeAccess(widget.employeeId);
      debugPrint("📋 Overtime access result: $hasAccess");

      setState(() {
        _hasOvertimeAccess = hasAccess;
        _tabController.dispose();
        _tabController = TabController(length: _hasOvertimeAccess ? 2 : 1, vsync: this);
      });

      debugPrint("✅ Updated UI: ${_hasOvertimeAccess ? '2 tabs (Attendance + Overtime)' : '1 tab (Attendance only)'}");

    } catch (e) {
      debugPrint("❌ Error checking overtime access: $e");
      _setupAttendanceOnlyView();
    }
  }

  Future<void> _fetchInitialData() async {
    // ✅ IMPROVED: Always force refresh on initial load to get latest data
    await _fetchAttendanceRecords(forceRefresh: true);
    
    if (_hasOvertimeAccess) {
      debugPrint("📊 Fetching overtime data...");
      _fetchOvertimeData();
    } else {
      debugPrint("⏭️ Skipping overtime data (no access)");
    }
  }

  void _setupAttendanceOnlyView() {
    setState(() {
      _hasOvertimeAccess = false;
      _tabController.dispose();
      _tabController = TabController(length: 1, vsync: this);
    });
    _fetchAttendanceRecords();
  }

  // ===== FIXED ATTENDANCE METHODS FOR CROSS-DEVICE SYNC =====
  Future<void> _fetchAttendanceRecords({bool forceRefresh = false}) async {
    setState(() => _isLoadingAttendance = true);

    try {
      debugPrint("📅 Fetching attendance records for ${widget.employeeId} in month $_selectedMonth (force: $forceRefresh)");

      // Parse the selected month to get start and end dates
      DateTime selectedDate = DateFormat('yyyy-MM').parse(_selectedMonth);
      int year = selectedDate.year;
      int month = selectedDate.month;

      debugPrint("📅 Fetching for year: $year, month: $month");

      // ✅ FIXED: Use repository method with force refresh capability
      List<AttendanceRecord> existingRecords = await _attendanceRepository.getAttendanceRecordsForMonth(
        employeeId: widget.employeeId,
        year: year,
        month: month,
        forceRefresh: forceRefresh, // ✅ Use force refresh parameter
      );

      debugPrint("📅 Found ${existingRecords.length} attendance records from repository");

      // Generate complete month view with all days
      List<AttendanceRecord> completeRecords = await _generateCompleteMonthView(year, month, existingRecords);

      setState(() {
        _attendanceRecords = completeRecords;
        _isLoadingAttendance = false;
      });

      debugPrint("✅ Generated complete month view: ${completeRecords.length} days total");
      debugPrint("📊 Days with records: ${existingRecords.length}");
      debugPrint("📊 Absent days: ${completeRecords.length - existingRecords.length}");

    } catch (e) {
      debugPrint("❌ Error fetching attendance records: $e");
      setState(() => _isLoadingAttendance = false);

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading attendance records: $e");
      }
    }
  }

  // ✅ NEW: Generate complete month view with all days
  Future<List<AttendanceRecord>> _generateCompleteMonthView(int year, int month, List<AttendanceRecord> existingRecords) async {
    try {
      // Create a map of existing records by date
      Map<String, AttendanceRecord> existingRecordsMap = {};
      for (var record in existingRecords) {
        existingRecordsMap[record.date] = record;
      }

      // Generate ALL days of the month
      List<AttendanceRecord> completeRecords = [];
      DateTime startOfMonth = DateTime(year, month, 1);
      DateTime endOfMonth = DateTime(year, month + 1, 0);
      DateTime currentDay = startOfMonth;

      while (currentDay.isBefore(endOfMonth) || currentDay.isAtSameMomentAs(endOfMonth)) {
        String currentDateStr = DateFormat('yyyy-MM-dd').format(currentDay);

        if (existingRecordsMap.containsKey(currentDateStr)) {
          // Day has attendance record
          completeRecords.add(existingRecordsMap[currentDateStr]!);
        } else {
          // Day is absent - create empty attendance record
          completeRecords.add(AttendanceRecord(
            date: currentDateStr,
            checkIn: null,
            checkOut: null,
            location: 'No Location',
            workStatus: 'Absent',
            totalHours: 0.0,
            regularHours: 0.0,
            overtimeHours: 0.0,
            isWithinGeofence: false,
            rawData: {'hasRecord': false},
          ));
        }

        currentDay = currentDay.add(const Duration(days: 1));
      }

      // Sort by date (newest first)
      completeRecords.sort((a, b) => b.date.compareTo(a.date));

      return completeRecords;
    } catch (e) {
      debugPrint("❌ Error generating complete month view: $e");
      return [];
    }
  }

  // ✅ NEW: Force refresh with user feedback
  Future<void> _forceRefreshAttendance() async {
    try {
      debugPrint("🔄 Force refreshing attendance data from Firestore...");

      // Show loading state
      if (mounted) {
        CustomSnackBar.infoSnackBar("🔄 Syncing latest data from server...");
      }

      // Force refresh the data
      await _fetchAttendanceRecords(forceRefresh: true);

      if (mounted) {
        CustomSnackBar.successSnackBar("✅ Data synced successfully!");
      }
    } catch (e) {
      debugPrint("❌ Error during force refresh: $e");
      if (mounted) {
        CustomSnackBar.errorSnackBar("❌ Error syncing data: $e");
      }
    }
  }

  // ✅ NEW: Force refresh today's data specifically (for same-day cross-device sync)
  Future<void> _forceRefreshToday() async {
    try {
      debugPrint("🔄 Force refreshing today's data from Firestore...");

      // Show loading feedback
      if (mounted) {
        CustomSnackBar.infoSnackBar("🔄 Getting today's latest data...");
      }

      // Force refresh today's data
      await _attendanceRepository.forceRefreshTodayFromFirestore(widget.employeeId);

      // Refresh the current view
      await _fetchAttendanceRecords(forceRefresh: true);

      if (mounted) {
        CustomSnackBar.successSnackBar("✅ Today's data updated!");
      }
    } catch (e) {
      debugPrint("❌ Error refreshing today's data: $e");
      if (mounted) {
        CustomSnackBar.errorSnackBar("❌ Error updating today's data: $e");
      }
    }
  }

  // ===== OVERTIME METHODS (keeping existing) =====
  Future<void> _fetchOvertimeData() async {
    if (!_hasOvertimeAccess) return;

    setState(() => _isLoadingOvertime = true);

    try {
      debugPrint("📊 === FETCHING ALL OVERTIME DATA ===");

      final futures = await Future.wait([
        _overtimeService.getOvertimeHistoryForEmployee(widget.employeeId),
        _overtimeService.getTodayOvertimeForEmployee(widget.employeeId),
        _overtimeService.getOvertimeStatistics(widget.employeeId),
      ]);

      final List<OvertimeRequest> history = futures[0] as List<OvertimeRequest>;
      final List<OvertimeRequest> todayRequests = futures[1] as List<OvertimeRequest>;
      final Map<String, dynamic> statistics = futures[2] as Map<String, dynamic>;

      setState(() {
        _overtimeHistory = history;
        _filteredOvertimeHistory = history;
        _todayOvertimeRequests = todayRequests;
        _overtimeStatistics = statistics;
        _isLoadingOvertime = false;
      });

      debugPrint("✅ Successfully loaded overtime data:");
      debugPrint("  - History: ${history.length} requests");
      debugPrint("  - Today: ${todayRequests.length} requests");
      debugPrint("  - Statistics: $statistics");

    } catch (e) {
      debugPrint("❌ Error fetching overtime data: $e");
      setState(() => _isLoadingOvertime = false);

      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading overtime data: $e");
      }
    }
  }

  // ===== OVERTIME FILTER METHODS =====
  void _filterOvertimeHistory() {
    List<OvertimeRequest> filtered = _overtimeHistory;

    if (_selectedOvertimeStatus != null) {
      filtered = filtered.where((request) => request.status == _selectedOvertimeStatus).toList();
    }

    if (_overtimeSearchQuery.isNotEmpty) {
      String query = _overtimeSearchQuery.toLowerCase();
      filtered = filtered.where((request) {
        return request.projectName.toLowerCase().contains(query) ||
            request.projectCode.toLowerCase().contains(query) ||
            request.requesterName.toLowerCase().contains(query) ||
            request.approverName.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredOvertimeHistory = filtered;
    });
  }

  void _clearOvertimeFilters() {
    setState(() {
      _overtimeSearchQuery = '';
      _selectedOvertimeStatus = null;
      _filteredOvertimeHistory = _overtimeHistory;
    });
  }

  // ===== UI BUILD METHODS =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My ${_hasOvertimeAccess ? 'Attendance & Overtime' : 'Attendance'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ IMPROVED: Enhanced sync options with better UX
          PopupMenuButton<String>(
            icon: const Icon(Icons.sync_rounded, size: 22),
            tooltip: 'Sync Options',
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  await _fetchAttendanceRecords();
                  if (_hasOvertimeAccess) {
                    await _fetchOvertimeData();
                  }
                  break;
                case 'force_refresh':
                  await _forceRefreshAttendance();
                  break;
                case 'refresh_today':
                  await _forceRefreshToday();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Refresh'),
                        Text('Normal data refresh', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'force_refresh',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Force Sync'),
                        Text('Sync from server', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh_today',
                child: Row(
                  children: [
                    Icon(Icons.today_rounded, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Today'),
                        Text('Get today\'s latest data', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _hasOvertimeAccess
            ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Attendance', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Overtime', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        )
            : null,
      ),
      body: _hasOvertimeAccess
          ? TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildOvertimeTab(),
        ],
      )
          : _buildAttendanceTab(),
    );
  }

  // ===== ATTENDANCE TAB =====
  Widget _buildAttendanceTab() {
    return Column(
      children: [
        // Month selector
        _buildMonthSelector(),

        // ✅ NEW: Enhanced sync status indicator
        if (_isLoadingAttendance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade600),
                ),
                const SizedBox(width: 12),
                Text(
                  'Syncing attendance data from server...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(Icons.cloud_sync_rounded, size: 16, color: Colors.blue.shade600),
              ],
            ),
          ),

        // Summary cards
        if (!_isLoadingAttendance && _attendanceRecords.isNotEmpty)
          _buildSummaryCards(),

        // Attendance table
        Expanded(
          child: _isLoadingAttendance
              ? const Center(
            child: CircularProgressIndicator(color: accentColor),
          )
              : _attendanceRecords.isEmpty
              ? _buildEmptyState()
              : _buildAttendanceTable(),
        ),
      ],
    );
  }

  // ===== KEEPING ALL EXISTING UI METHODS =====
  Widget _buildSummaryCards() {
    int totalDaysInMonth = _attendanceRecords.length;
    double totalWorkHours = 0;
    double totalOvertimeHours = 0;
    int absentDays = 0;
    int presentDays = 0;

    for (var record in _attendanceRecords) {
      bool hasRecord = record.rawData['hasRecord'] ?? true;

      if (!hasRecord || (!record.hasCheckIn && !record.hasCheckOut)) {
        absentDays++;
      } else {
        presentDays++;
      }

      totalWorkHours += record.totalHours;
      totalOvertimeHours += record.overtimeHours;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary for ${DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(_selectedMonth))}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Days',
                  totalDaysInMonth.toString(),
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Present Days',
                  presentDays.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Absent Days',
                  absentDays.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Hours',
                  '${totalWorkHours.toStringAsFixed(1)}h',
                  Icons.access_time,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTable() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Attendance Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                // ✅ NEW: Quick sync button for table
                TextButton.icon(
                  onPressed: () => _forceRefreshToday(),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync Today', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                  columns: [
                    const DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Check In',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Check Out',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Total Hours',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_hasOvertimeAccess)
                      const DataColumn(
                        label: Text(
                          'Overtime',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    const DataColumn(
                      label: Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Attendance',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _attendanceRecords.map((record) => _buildDataRow(record)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(AttendanceRecord record) {
    bool hasRecord = record.rawData['hasRecord'] ?? true;

    // Determine attendance status
    String attendanceStatus = 'Present';
    Color attendanceColor = Colors.green;
    IconData attendanceIcon = Icons.check_circle;

    if (!hasRecord || (!record.hasCheckIn && !record.hasCheckOut)) {
      attendanceStatus = 'Absent';
      attendanceColor = Colors.red;
      attendanceIcon = Icons.cancel;
    } else if (!record.hasCheckIn || !record.hasCheckOut) {
      attendanceStatus = 'Incomplete';
      attendanceColor = Colors.orange;
      attendanceIcon = Icons.warning;
    }

    // Format date
    String formattedDate = '';
    String dayOfWeek = '';
    try {
      DateTime dateTime = DateFormat('yyyy-MM-dd').parse(record.date);
      formattedDate = DateFormat('MMM dd').format(dateTime);
      dayOfWeek = DateFormat('EEE').format(dateTime);
    } catch (e) {
      formattedDate = record.date;
    }

    return DataRow(
      color: attendanceStatus == 'Absent'
          ? MaterialStateProperty.all(Colors.red.withOpacity(0.05))
          : attendanceStatus == 'Incomplete'
          ? MaterialStateProperty.all(Colors.orange.withOpacity(0.05))
          : null,
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: attendanceStatus == 'Absent' ? Colors.red.shade700 : Colors.black,
                ),
              ),
              if (dayOfWeek.isNotEmpty)
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 12,
                    color: attendanceStatus == 'Absent'
                        ? Colors.red.shade500
                        : Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Text(
            record.formattedCheckIn,
            style: TextStyle(
              color: record.hasCheckIn ? Colors.green.shade700 : Colors.grey,
              fontWeight: record.hasCheckIn ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        DataCell(
          Text(
            record.formattedCheckOut,
            style: TextStyle(
              color: record.hasCheckOut ? Colors.red.shade700 : Colors.grey,
              fontWeight: record.hasCheckOut ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        DataCell(
          Text(
            record.formattedTotalHours,
            style: TextStyle(
              color: record.totalHours > 0 ? Colors.blue.shade700 : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_hasOvertimeAccess)
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: record.hasOvertime ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.formattedOvertimeHours,
                style: TextStyle(
                  color: record.hasOvertime ? Colors.orange.shade800 : Colors.grey,
                  fontWeight: record.hasOvertime ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                record.location,
                style: TextStyle(
                  fontSize: 12,
                  color: attendanceStatus == 'Absent' ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (attendanceStatus != 'Absent' && hasRecord)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      record.isWithinGeofence ? Icons.location_on : Icons.location_off,
                      size: 12,
                      color: record.isWithinGeofence ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.isWithinGeofence ? 'Inside' : 'Outside',
                      style: TextStyle(
                        fontSize: 10,
                        color: record.isWithinGeofence ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(record.workStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.workStatus,
              style: TextStyle(
                color: _getStatusColor(record.workStatus),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: attendanceColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  attendanceIcon,
                  size: 14,
                  color: attendanceColor,
                ),
                const SizedBox(width: 4),
                Text(
                  attendanceStatus,
                  style: TextStyle(
                    color: attendanceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== KEEPING ALL OTHER EXISTING METHODS (overtime tab, helper methods, etc.) =====
  Widget _buildOvertimeTab() {
    return Column(
      children: [
        if (_todayOvertimeRequests.isNotEmpty) _buildTodayOvertimeCompact(),
        if (!_isLoadingOvertime && _overtimeHistory.isNotEmpty)
          _buildOvertimeSummary(),
        Expanded(
          child: _isLoadingOvertime
              ? const Center(
            child: CircularProgressIndicator(color: accentColor),
          )
              : _overtimeHistory.isEmpty
              ? _buildEmptyOvertimeState()
              : _buildOvertimeHistoryList(),
        ),
      ],
    );
  }

  // [All other existing overtime methods remain the same - _buildTodayOvertimeCompact, _buildOvertimeSummary, etc.]

  Widget _buildTodayOvertimeCompact() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.today_rounded, color: Colors.blue.shade600, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Today's Overtime",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_todayOvertimeRequests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _todayOvertimeRequests.map((request) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.projectName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Code: ${request.projectCode}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${request.totalDurationHours.toStringAsFixed(1)}h",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeSummary() {
    int totalRequests = _overtimeStatistics['totalRequests'] ?? 0;
    int approvedRequests = _overtimeStatistics['approvedRequests'] ?? 0;
    int pendingRequests = _overtimeStatistics['pendingRequests'] ?? 0;
    double totalOvertimeHours = _overtimeStatistics['totalApprovedHours'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overtime Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactSummaryCard(
                  'Total',
                  totalRequests.toString(),
                  Icons.assignment_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Approved',
                  approvedRequests.toString(),
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Pending',
                  pendingRequests.toString(),
                  Icons.pending_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactSummaryCard(
                  'Hours',
                  '${totalOvertimeHours.toStringAsFixed(1)}h',
                  Icons.timer_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeHistoryList() {
    return Column(
      children: [
        _buildOvertimeSearchAndFilter(),
        Expanded(
          child: _filteredOvertimeHistory.isEmpty
              ? _buildNoResultsState()
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filteredOvertimeHistory.length,
            itemBuilder: (context, index) {
              final request = _filteredOvertimeHistory[index];
              return _buildCompactOvertimeCard(request);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOvertimeCard(OvertimeRequest request) {
    Color statusColor = _getOvertimeStatusColor(request.status);
    IconData statusIcon = _getOvertimeStatusIcon(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.projectName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        request.projectCode,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.displayName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${DateFormat('MMM dd').format(request.startTime)} • ${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${request.totalDurationHours.toStringAsFixed(1)}h",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "By: ${request.requesterName}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      "${request.totalEmployeeCount} ${request.totalEmployeeCount == 1 ? 'person' : 'people'}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (request.responseMessage != null && request.responseMessage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message_rounded, size: 12, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.responseMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
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
        ],
      ),
    );
  }

  Widget _buildOvertimeSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Overtime History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null)
                TextButton.icon(
                  onPressed: _clearOvertimeFilters,
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _overtimeSearchQuery = value;
                });
                _filterOvertimeHistory();
              },
              decoration: InputDecoration(
                hintText: 'Search projects, codes...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _overtimeSearchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    setState(() {
                      _overtimeSearchQuery = '';
                    });
                    _filterOvertimeHistory();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: accentColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactFilterChip(
                  label: 'All',
                  isSelected: _selectedOvertimeStatus == null,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = null;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Pending',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.pending,
                  color: Colors.orange,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.pending;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Approved',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.approved,
                  color: Colors.green,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.approved;
                    });
                    _filterOvertimeHistory();
                  },
                ),
                const SizedBox(width: 6),
                _buildCompactFilterChip(
                  label: 'Rejected',
                  isSelected: _selectedOvertimeStatus == OvertimeRequestStatus.rejected,
                  color: Colors.red,
                  onTap: () {
                    setState(() {
                      _selectedOvertimeStatus = OvertimeRequestStatus.rejected;
                    });
                    _filterOvertimeHistory();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? accentColor) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? (color ?? accentColor) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : (color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No overtime requests found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Try adjusting your filters'
                : 'Your overtime requests will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null) {
                _clearOvertimeFilters();
              } else {
                _fetchOvertimeData();
              }
            },
            icon: Icon(_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? Icons.clear_rounded
                : Icons.refresh_rounded, size: 16),
            label: Text(_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Clear Filters'
                : 'Refresh', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOvertimeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No overtime history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your overtime requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOvertimeData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getOvertimeStatusColor(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Colors.orange;
      case OvertimeRequestStatus.approved:
        return Colors.green;
      case OvertimeRequestStatus.rejected:
        return Colors.red;
      case OvertimeRequestStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getOvertimeStatusIcon(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Icons.pending_rounded;
      case OvertimeRequestStatus.approved:
        return Icons.check_circle_rounded;
      case OvertimeRequestStatus.rejected:
        return Icons.cancel_rounded;
      case OvertimeRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: accentColor),
          const SizedBox(width: 12),
          const Text(
            'Select Month:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: _generateMonthOptions(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue != _selectedMonth) {
                      setState(() {
                        _selectedMonth = newValue;
                      });
                      // ✅ Force refresh when changing months to get latest data
                      _fetchAttendanceRecords(forceRefresh: true);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _generateMonthOptions() {
    List<DropdownMenuItem<String>> items = [];
    DateTime now = DateTime.now();

    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String monthKey = DateFormat('yyyy-MM').format(month);
      String monthDisplay = DateFormat('MMMM yyyy').format(month);

      items.add(
        DropdownMenuItem<String>(
          value: monthKey,
          child: Text(monthDisplay),
        ),
      );
    }

    return items;
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_month,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(_selectedMonth))}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _fetchAttendanceRecords(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _forceRefreshAttendance(),
                icon: const Icon(Icons.cloud_sync_rounded),
                label: const Text('Force Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}