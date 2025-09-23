// lib/dashboard/my_attendance_view.dart - MOBILE-OPTIMIZED WITH WEEKLY VIEW

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/model/overtime_request_model.dart';
import 'package:face_auth/model/attendance_model.dart';
import 'package:face_auth/repositories/attendance_repository.dart';
import 'package:face_auth/services/employee_overtime_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/model/local_attendance_model.dart';

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
  final PageController _weekPageController = PageController();

  // Services and repositories
  late EmployeeOvertimeService _overtimeService;
  late AttendanceRepository _attendanceRepository;

  // Attendance data
  List<AttendanceRecord> _attendanceRecords = [];
  List<List<AttendanceRecord>> _weeklyRecords = [];
  bool _isLoadingAttendance = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  int _currentWeekIndex = 0;

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
    _weekPageController.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION METHODS =====
  Future<void> _initializeEverything() async {
    try {
      debugPrint("🚀 === INITIALIZING MOBILE ATTENDANCE VIEW FOR ${widget.employeeId} ===");

      await _initializeServices();
      await _checkOvertimeAccess();
      await _fetchInitialData();
      await _resolveExistingLocationNames();

    } catch (e) {
      debugPrint("❌ Error during initialization: $e");
      _setupAttendanceOnlyView();
    }
  }

  Future<void> _initializeServices() async {
    try {
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
      bool hasAccess = await _overtimeService.hasOvertimeAccess(widget.employeeId);
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
    await _fetchAttendanceRecords(forceRefresh: true);
    if (_hasOvertimeAccess) {
      _fetchOvertimeData();
    }
  }

  Future<void> _resolveExistingLocationNames() async {
    try {
      _attendanceRepository.bulkResolveLocationNames(widget.employeeId);
    } catch (e) {
      debugPrint("❌ Error starting location name resolution: $e");
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

  // ===== ATTENDANCE METHODS =====
  Future<void> _fetchAttendanceRecords({bool forceRefresh = false}) async {
    setState(() => _isLoadingAttendance = true);

    try {
      DateTime selectedDate = DateFormat('yyyy-MM').parse(_selectedMonth);
      int year = selectedDate.year;
      int month = selectedDate.month;

      List<AttendanceRecord> existingRecords = await _attendanceRepository.getAttendanceRecordsForMonth(
        employeeId: widget.employeeId,
        year: year,
        month: month,
        forceRefresh: forceRefresh,
      );

      List<AttendanceRecord> completeRecords = await _generateCompleteMonthView(year, month, existingRecords);
      List<List<AttendanceRecord>> weeklyData = _generateWeeklyView(completeRecords);

      setState(() {
        _attendanceRecords = completeRecords;
        _weeklyRecords = weeklyData;
        _currentWeekIndex = _findCurrentWeekIndex(weeklyData);
        _isLoadingAttendance = false;
      });

      debugPrint("✅ Generated weekly view: ${weeklyData.length} weeks");
    } catch (e) {
      debugPrint("❌ Error fetching attendance records: $e");
      setState(() => _isLoadingAttendance = false);
      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading attendance records: $e");
      }
    }
  }

  Future<List<AttendanceRecord>> _generateCompleteMonthView(int year, int month, List<AttendanceRecord> existingRecords) async {
    Map<String, AttendanceRecord> existingRecordsMap = {};
    for (var record in existingRecords) {
      existingRecordsMap[record.date] = record;
    }

    List<AttendanceRecord> completeRecords = [];
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth = DateTime(year, month + 1, 0);
    DateTime currentDay = startOfMonth;

    while (currentDay.isBefore(endOfMonth) || currentDay.isAtSameMomentAs(endOfMonth)) {
      String currentDateStr = DateFormat('yyyy-MM-dd').format(currentDay);

      if (existingRecordsMap.containsKey(currentDateStr)) {
        completeRecords.add(existingRecordsMap[currentDateStr]!);
      } else {
        completeRecords.add(AttendanceRecord(
          date: currentDateStr,
          checkIn: null,
          checkOut: null,
          checkInLocation: null,
          checkOutLocation: null,
          checkInLocationName: null,
          checkOutLocationName: null,
          workStatus: 'Absent',
          totalHours: 0.0,
          regularHours: 0.0,
          overtimeHours: 0.0,
          isWithinGeofence: false,
          rawData: {
            'hasRecord': false,
            'dayType': currentDay.weekday == DateTime.sunday ? 'sunday' : 'working',
            'isDayOff': currentDay.weekday == DateTime.sunday,
            'shouldCountAsPresent': currentDay.weekday == DateTime.sunday,
            'reason': currentDay.weekday == DateTime.sunday ? 'Sunday Holiday' : 'Absent',
            'date': currentDateStr,
          },
        ));
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    completeRecords.sort((a, b) => a.date.compareTo(b.date));
    return completeRecords;
  }

  List<List<AttendanceRecord>> _generateWeeklyView(List<AttendanceRecord> records) {
    if (records.isEmpty) return [];

    List<List<AttendanceRecord>> weeks = [];
    List<AttendanceRecord> currentWeek = [];

    for (var record in records) {
      DateTime date = DateFormat('yyyy-MM-dd').parse(record.date);

      if (currentWeek.isEmpty) {
        currentWeek.add(record);
      } else {
        DateTime lastDate = DateFormat('yyyy-MM-dd').parse(currentWeek.last.date);

        if (date.weekday < lastDate.weekday ||
            date.difference(lastDate).inDays > 1) {
          weeks.add(List.from(currentWeek));
          currentWeek = [record];
        } else {
          currentWeek.add(record);
        }
      }
    }

    if (currentWeek.isNotEmpty) {
      weeks.add(currentWeek);
    }

    return weeks;
  }

  int _findCurrentWeekIndex(List<List<AttendanceRecord>> weeks) {
    DateTime now = DateTime.now();
    String today = DateFormat('yyyy-MM-dd').format(now);

    for (int i = 0; i < weeks.length; i++) {
      for (var record in weeks[i]) {
        if (record.date == today) {
          return i;
        }
      }
    }
    return weeks.isNotEmpty ? weeks.length - 1 : 0;
  }

  // ===== OVERTIME METHODS =====
  Future<void> _fetchOvertimeData() async {
    if (!_hasOvertimeAccess) return;

    setState(() => _isLoadingOvertime = true);

    try {
      final futures = await Future.wait([
        _overtimeService.getOvertimeHistoryForEmployee(widget.employeeId),
        _overtimeService.getTodayOvertimeForEmployee(widget.employeeId),
        _overtimeService.getOvertimeStatistics(widget.employeeId),
      ]);

      setState(() {
        _overtimeHistory = futures[0] as List<OvertimeRequest>;
        _filteredOvertimeHistory = futures[0] as List<OvertimeRequest>;
        _todayOvertimeRequests = futures[1] as List<OvertimeRequest>;
        _overtimeStatistics = futures[2] as Map<String, dynamic>;
        _isLoadingOvertime = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching overtime data: $e");
      setState(() => _isLoadingOvertime = false);
      if (mounted) {
        CustomSnackBar.errorSnackBar("Error loading overtime data: $e");
      }
    }
  }

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
          'My ${_hasOvertimeAccess ? 'Work Records' : 'Attendance'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 22),
            tooltip: 'Sync Data',
            onPressed: () => _showSyncOptions(context),
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

  void _showSyncOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sync Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Colors.blue),
              title: const Text('Refresh'),
              subtitle: const Text('Normal data refresh'),
              onTap: () {
                Navigator.pop(context);
                _fetchAttendanceRecords();
                if (_hasOvertimeAccess) _fetchOvertimeData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_rounded, color: Colors.orange),
              title: const Text('Force Sync'),
              subtitle: const Text('Sync from server'),
              onTap: () {
                Navigator.pop(context);
                _fetchAttendanceRecords(forceRefresh: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_rounded, color: Colors.purple),
              title: const Text('Fix Locations'),
              subtitle: const Text('Resolve location names'),
              onTap: () {
                Navigator.pop(context);
                _resolveLocationNames();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveLocationNames() async {
    try {
      CustomSnackBar.infoSnackBar("Resolving location names...");
      await _attendanceRepository.bulkResolveLocationNames(widget.employeeId);
      await _fetchAttendanceRecords(forceRefresh: true);
      CustomSnackBar.successSnackBar("Location names resolved!");
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error resolving locations: $e");
    }
  }

  // ===== ATTENDANCE TAB =====
  Widget _buildAttendanceTab() {
    return Column(
      children: [
        _buildMonthSelector(),
        if (_isLoadingAttendance) _buildLoadingIndicator(),
        Expanded(
          child: _isLoadingAttendance
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : _weeklyRecords.isEmpty
              ? _buildEmptyState()
              : _buildWeeklyView(),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
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
            'Syncing attendance data...',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Icon(Icons.location_on_rounded, size: 16, color: Colors.blue.shade600),
        ],
      ),
    );
  }

  Widget _buildWeeklyView() {
    return Column(
      children: [
        // Week navigation header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _currentWeekIndex > 0 ? () => _previousWeek() : null,
                icon: const Icon(Icons.chevron_left),
                color: _currentWeekIndex > 0 ? accentColor : Colors.grey,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Week ${_currentWeekIndex + 1} of ${_weeklyRecords.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_weeklyRecords.isNotEmpty && _currentWeekIndex < _weeklyRecords.length)
                      Text(
                        _getWeekDateRange(_weeklyRecords[_currentWeekIndex]),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _currentWeekIndex < _weeklyRecords.length - 1 ? () => _nextWeek() : null,
                icon: const Icon(Icons.chevron_right),
                color: _currentWeekIndex < _weeklyRecords.length - 1 ? accentColor : Colors.grey,
              ),
            ],
          ),
        ),

        // Week cards
        Expanded(
          child: PageView.builder(
            controller: _weekPageController,
            onPageChanged: (index) => setState(() => _currentWeekIndex = index),
            itemCount: _weeklyRecords.length,
            itemBuilder: (context, index) => _buildWeekCard(_weeklyRecords[index]),
          ),
        ),
      ],
    );
  }

  void _previousWeek() {
    if (_currentWeekIndex > 0) {
      _weekPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextWeek() {
    if (_currentWeekIndex < _weeklyRecords.length - 1) {
      _weekPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getWeekDateRange(List<AttendanceRecord> weekRecords) {
    if (weekRecords.isEmpty) return '';

    DateTime startDate = DateFormat('yyyy-MM-dd').parse(weekRecords.first.date);
    DateTime endDate = DateFormat('yyyy-MM-dd').parse(weekRecords.last.date);

    return '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd').format(endDate)}';
  }

  Widget _buildWeekCard(List<AttendanceRecord> weekRecords) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weekRecords.length,
      itemBuilder: (context, index) => _buildDayCard(weekRecords[index]),
    );
  }

  Widget _buildDayCard(AttendanceRecord record) {
    DateTime date = DateFormat('yyyy-MM-dd').parse(record.date);
    String dayName = DateFormat('EEEE').format(date);
    String dayDate = DateFormat('MMM dd').format(date);
    bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == record.date;

    String dayType = record.rawData['dayType'] ?? 'working';
    bool hasRecord = record.rawData['hasRecord'] ?? true;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    IconData statusIcon = Icons.check_circle;
    Color statusColor = Colors.green;
    String statusText = 'Present';

    if (isToday) {
      borderColor = accentColor;
    }

    if (dayType == 'sunday') {
      cardColor = record.hasCheckIn ? Colors.orange.shade50 : Colors.green.shade50;
      statusIcon = record.hasCheckIn ? Icons.work_history : Icons.weekend;
      statusColor = record.hasCheckIn ? Colors.orange : Colors.green;
      statusText = record.hasCheckIn ? 'Sunday Work' : 'Holiday';
    } else if (!hasRecord || (!record.hasCheckIn && !record.hasCheckOut)) {
      cardColor = Colors.red.shade50;
      statusIcon = Icons.cancel;
      statusColor = Colors.red;
      statusText = 'Absent';
    } else if (!record.hasCheckIn || !record.hasCheckOut) {
      cardColor = Colors.orange.shade50;
      statusIcon = Icons.warning;
      statusColor = Colors.orange;
      statusText = 'Incomplete';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isToday ? accentColor : Colors.black87,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        dayDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time and location info
            if (record.hasCheckIn || record.hasCheckOut) ...[
              Row(
                children: [
                  // Check-in
                  Expanded(
                    child: _buildTimeCard(
                      'Check In',
                      record.formattedCheckIn,
                      record.checkInLocationName ?? record.checkInLocation,
                      Icons.login,
                      Colors.green,
                      record.hasCheckIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Check-out
                  Expanded(
                    child: _buildTimeCard(
                      'Check Out',
                      record.formattedCheckOut,
                      record.checkOutLocationName ?? record.checkOutLocation,
                      Icons.logout,
                      Colors.red,
                      record.hasCheckOut,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Summary row
              Row(
                children: [
                  _buildSummaryChip(
                    'Total Hours',
                    record.formattedTotalHours,
                    Icons.schedule,
                    Colors.blue,
                  ),
                  if (_hasOvertimeAccess && record.hasOvertime) ...[
                    const SizedBox(width: 8),
                    _buildSummaryChip(
                      'Overtime',
                      record.formattedOvertimeHours,
                      Icons.access_time_filled,
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ] else ...[
              // No attendance data
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      dayType == 'sunday' ? 'Sunday Holiday' : 'No attendance recorded',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
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

  Widget _buildTimeCard(String label, String time, String? location, IconData icon, Color color, bool hasData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasData ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData ? color.withOpacity(0.3) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: hasData ? color : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: hasData ? color : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: hasData ? Colors.black87 : Colors.grey,
            ),
          ),
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _truncateLocationName(location),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (hasData) ...[
            const SizedBox(height: 2),
            Text(
              'No location',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateLocationName(String name) {
    if (name.length <= 20) return name;
    if (name.contains('-') && name.length > 30) {
      return 'Location ${name.substring(0, 8)}...';
    }
    return '${name.substring(0, 17)}...';
  }

  // ===== OVERTIME TAB =====
  Widget _buildOvertimeTab() {
    return Column(
      children: [
        // Today's overtime section
        _buildTodayOvertimeSection(),

        // Search and filter
        _buildOvertimeSearchAndFilter(),

        // Overtime history
        Expanded(
          child: _isLoadingOvertime
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : _buildOvertimeList(),
        ),
      ],
    );
  }

  Widget _buildTodayOvertimeSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Today\'s Overtime',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _fetchOvertimeData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_todayOvertimeRequests.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Colors.grey.shade500, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Overtime Assigned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'You have no overtime requests for today',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show today's overtime requests
            ...(_todayOvertimeRequests.map((request) => _buildTodayOvertimeCard(request)).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayOvertimeCard(OvertimeRequest request) {
    Color statusColor = _getOvertimeStatusColor(request.status);
    IconData statusIcon = _getOvertimeStatusIcon(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.projectName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      request.status.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${request.totalDurationHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (request.responseMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.message, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.responseMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOvertimeSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const Icon(Icons.filter_list_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filter Overtime History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

          // Search field
          SizedBox(
            height: 36,
            child: TextField(
              onChanged: (value) {
                setState(() => _overtimeSearchQuery = value);
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
                    setState(() => _overtimeSearchQuery = '');
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

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', _selectedOvertimeStatus == null, null, () {
                  setState(() => _selectedOvertimeStatus = null);
                  _filterOvertimeHistory();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Pending', _selectedOvertimeStatus == OvertimeRequestStatus.pending, Colors.orange, () {
                  setState(() => _selectedOvertimeStatus = OvertimeRequestStatus.pending);
                  _filterOvertimeHistory();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Approved', _selectedOvertimeStatus == OvertimeRequestStatus.approved, Colors.green, () {
                  setState(() => _selectedOvertimeStatus = OvertimeRequestStatus.approved);
                  _filterOvertimeHistory();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Rejected', _selectedOvertimeStatus == OvertimeRequestStatus.rejected, Colors.red, () {
                  setState(() => _selectedOvertimeStatus = OvertimeRequestStatus.rejected);
                  _filterOvertimeHistory();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Color? color, VoidCallback onTap) {
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

  Widget _buildOvertimeList() {
    if (_filteredOvertimeHistory.isEmpty) {
      return _buildEmptyOvertimeState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOvertimeHistory.length,
      itemBuilder: (context, index) => _buildOvertimeHistoryCard(_filteredOvertimeHistory[index]),
    );
  }

  Widget _buildOvertimeHistoryCard(OvertimeRequest request) {
    Color statusColor = _getOvertimeStatusColor(request.status);
    IconData statusIcon = _getOvertimeStatusIcon(request.status);

    String formattedDate = DateFormat('MMM dd, yyyy').format(request.startTime);
    String dayOfWeek = DateFormat('EEE').format(request.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.projectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Date and time info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '$formattedDate ($dayOfWeek)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('h:mm a').format(request.startTime)} - ${DateFormat('h:mm a').format(request.endTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${request.totalDurationHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Requester and approver info
            Row(
              children: [
                Expanded(
                  child: _buildPersonInfo('Requested by', request.requesterName, Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPersonInfo('Approved by', request.approverName, Icons.person_outline),
                ),
              ],
            ),

            // Response message
            if (request.responseMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.message_outlined, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Response:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.responseMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
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

  Widget _buildPersonInfo(String label, String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
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
            'No overtime records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Try adjusting your filters'
                : 'Your overtime requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
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
                : Icons.refresh_rounded),
            label: Text(_overtimeSearchQuery.isNotEmpty || _selectedOvertimeStatus != null
                ? 'Clear Filters'
                : 'Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ===== HELPER METHODS =====
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: accentColor),
          const SizedBox(width: 12),
          const Text(
            'Month:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      setState(() => _selectedMonth = newValue);
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

      items.add(DropdownMenuItem<String>(
        value: monthKey,
        child: Text(monthDisplay),
      ));
    }

    return items;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_view_week,
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
          ElevatedButton.icon(
            onPressed: () => _fetchAttendanceRecords(forceRefresh: true),
            icon: const Icon(Icons.refresh),
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
}



