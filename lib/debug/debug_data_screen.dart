// lib/debug/debug_data_screen.dart - ENHANCED DEBUG SCREEN WITH ATTENDANCE STATE ANALYSIS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/service_locator.dart';
import 'package:face_auth_compatible/repositories/attendance_repository.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/common/utils/custom_snackbar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class DebugDataScreen extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic>? userData;

  const DebugDataScreen({
    Key? key,
    required this.employeeId,
    this.userData,
  }) : super(key: key);

  @override
  State<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _debugData = {};
  List<Map<String, dynamic>> _attendanceAnalysis = [];
  Map<String, dynamic>? _stateComparison;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    setState(() => _isLoading = true);

    try {
      // Gather comprehensive debug information
      Map<String, dynamic> debugData = {};

      // 1. Database statistics
      final dbHelper = getIt<DatabaseHelper>();
      debugData['database'] = await dbHelper.getDatabaseStats();

      // 2. Connectivity status
      final connectivityService = getIt<ConnectivityService>();
      debugData['connectivity'] = {
        'status': connectivityService.currentStatus.toString(),
        'isOnline': connectivityService.currentStatus == ConnectionStatus.online,
      };

      // 3. Today's attendance analysis
      await _analyzeAttendanceState();

      // 4. Recent attendance records
      final attendanceRepo = getIt<AttendanceRepository>();
      final recentRecords = await attendanceRepo.getRecentAttendance(widget.employeeId, 7);

      debugData['recentAttendance'] = recentRecords.map((record) => {
        'date': record.date,
        'hasCheckIn': record.hasCheckIn,
        'hasCheckOut': record.hasCheckOut,
        'checkInTime': record.checkIn,
        'checkOutTime': record.checkOut,
        'isSynced': record.isSynced,
        'locationSummary': record.locationSummary,
      }).toList();

      // 5. Pending sync records
      final pendingRecords = await attendanceRepo.getPendingRecords();
      debugData['pendingSync'] = pendingRecords.where((record) =>
      record.employeeId == widget.employeeId).map((record) => {
        'date': record.date,
        'hasCheckIn': record.hasCheckIn,
        'hasCheckOut': record.hasCheckOut,
        'syncError': record.syncError,
      }).toList();

      setState(() {
        _debugData = debugData;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading debug data: $e");
    }
  }

  // ✅ NEW: Analyze attendance state discrepancies
  Future<void> _analyzeAttendanceState() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      Map<String, dynamic> analysis = {
        'date': today,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Get local data
      final attendanceRepo = getIt<AttendanceRepository>();
      final localRecord = await attendanceRepo.getTodaysAttendance(widget.employeeId);

      analysis['local'] = {
        'exists': localRecord != null,
        'hasCheckIn': localRecord?.hasCheckIn ?? false,
        'hasCheckOut': localRecord?.hasCheckOut ?? false,
        'checkInTime': localRecord?.checkIn,
        'checkOutTime': localRecord?.checkOut,
        'locationSummary': localRecord?.locationSummary ?? 'No location data',
        'isSynced': localRecord?.isSynced ?? false,
        'syncError': localRecord?.syncError,
      };

      // Get Firestore data
      Map<String, dynamic>? firestoreData;
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('Attendance_Records')
            .doc('PTSEmployees')
            .collection('Records')
            .doc('${widget.employeeId}-$today')
            .get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          firestoreData = doc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        analysis['firestoreError'] = e.toString();
      }

      if (firestoreData != null) {
        // Parse Firestore timestamps
        DateTime? firestoreCheckIn;
        DateTime? firestoreCheckOut;

        if (firestoreData['checkIn'] != null) {
          if (firestoreData['checkIn'] is Timestamp) {
            firestoreCheckIn = (firestoreData['checkIn'] as Timestamp).toDate();
          } else if (firestoreData['checkIn'] is String) {
            try {
              firestoreCheckIn = DateTime.parse(firestoreData['checkIn']);
            } catch (e) {
              analysis['firestoreParseError'] = 'checkIn: $e';
            }
          }
        }

        if (firestoreData['checkOut'] != null) {
          if (firestoreData['checkOut'] is Timestamp) {
            firestoreCheckOut = (firestoreData['checkOut'] as Timestamp).toDate();
          } else if (firestoreData['checkOut'] is String) {
            try {
              firestoreCheckOut = DateTime.parse(firestoreData['checkOut']);
            } catch (e) {
              analysis['firestoreParseError'] = 'checkOut: $e';
            }
          }
        }

        analysis['firestore'] = {
          'exists': true,
          'hasCheckIn': firestoreCheckIn != null,
          'hasCheckOut': firestoreCheckOut != null,
          'checkInTime': firestoreCheckIn?.toIso8601String(),
          'checkOutTime': firestoreCheckOut?.toIso8601String(),
          'rawCheckIn': firestoreData['checkIn']?.toString(),
          'rawCheckOut': firestoreData['checkOut']?.toString(),
          'locationName': firestoreData['locationName'] ?? firestoreData['checkInLocationName'],
          'workStatus': firestoreData['workStatus'],
        };

        // Determine expected states
        bool localExpectedState = localRecord?.hasCheckIn == true && localRecord?.hasCheckOut != true;
        bool firestoreExpectedState = firestoreCheckIn != null && firestoreCheckOut == null;

        analysis['stateComparison'] = {
          'localShouldBeCheckedIn': localExpectedState,
          'firestoreShouldBeCheckedIn': firestoreExpectedState,
          'statesMatch': localExpectedState == firestoreExpectedState,
          'discrepancy': localExpectedState != firestoreExpectedState,
        };

      } else {
        analysis['firestore'] = {
          'exists': false,
          'message': 'No Firestore record found for today',
        };
      }

      setState(() {
        _stateComparison = analysis;
        _attendanceAnalysis = [analysis];
      });

    } catch (e) {
      print("Error analyzing attendance state: $e");
    }
  }

  // ✅ NEW: Force sync specific record
  Future<void> _forceSyncRecord(String date) async {
    try {
      setState(() => _isLoading = true);

      final attendanceRepo = getIt<AttendanceRepository>();
      final record = await attendanceRepo.getAttendanceForDate(widget.employeeId, date);

      if (record != null) {
        // Mark as unsynced and trigger sync
        final dbHelper = getIt<DatabaseHelper>();
        await dbHelper.update(
          'attendance',
          {'is_synced': 0, 'sync_error': null},
          where: 'employee_id = ? AND date = ?',
          whereArgs: [widget.employeeId, date],
        );

        // Trigger sync
        bool success = await attendanceRepo.syncPendingRecords();

        CustomSnackBar.successSnackBar(success
            ? "Record synced successfully"
            : "Sync attempted - check for errors");
      } else {
        CustomSnackBar.errorSnackBar("No record found for $date");
      }

      // Refresh data
      await _loadDebugData();

    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error syncing record: $e");
    }
  }

  // ✅ NEW: Fix attendance state discrepancy
  Future<void> _fixAttendanceState() async {
    try {
      setState(() => _isLoading = true);

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get fresh data from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Attendance_Records')
          .doc('PTSEmployees')
          .collection('Records')
          .doc('${widget.employeeId}-$today')
          .get();

      if (doc.exists) {
        Map<String, dynamic> firestoreData = doc.data() as Map<String, dynamic>;

        // Update local database with Firestore data
        final attendanceRepo = getIt<AttendanceRepository>();
        await attendanceRepo.forceRefreshTodayFromFirestore(widget.employeeId);

        CustomSnackBar.successSnackBar("Attendance state synchronized with server");
      } else {
        CustomSnackBar.infoSnackBar("No server record found - local state is authoritative");
      }

      // Refresh debug data
      await _loadDebugData();

    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error fixing attendance state: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Debug Data & State Analysis'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDebugData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Attendance State Analysis (Priority)
            _buildAttendanceStateCard(),
            const SizedBox(height: 16),

            // Quick Actions
            _buildQuickActionsCard(),
            const SizedBox(height: 16),

            // System Status
            _buildSystemStatusCard(),
            const SizedBox(height: 16),

            // Recent Attendance
            _buildRecentAttendanceCard(),
            const SizedBox(height: 16),

            // Database Stats
            _buildDatabaseStatsCard(),
            const SizedBox(height: 16),

            // Raw Debug Data
            _buildRawDebugDataCard(),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Priority card for attendance state analysis
  Widget _buildAttendanceStateCard() {
    if (_stateComparison == null) return Container();

    bool hasDiscrepancy = _stateComparison!['stateComparison']?['discrepancy'] ?? false;
    Color cardColor = hasDiscrepancy ? Colors.red : Colors.green;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cardColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(hasDiscrepancy ? Icons.warning : Icons.check_circle,
                      color: cardColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasDiscrepancy ? 'ATTENDANCE STATE DISCREPANCY DETECTED' : 'Attendance State: Synchronized',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Local vs Firestore comparison
              Row(
                children: [
                  Expanded(child: _buildStateColumn('Local Database', _stateComparison!['local'])),
                  Container(width: 1, height: 60, color: Colors.grey[300]),
                  Expanded(child: _buildStateColumn('Firestore', _stateComparison!['firestore'])),
                ],
              ),

              if (hasDiscrepancy) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended Action:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Local and server states don\'t match. This can cause the check-in/check-out button to show incorrectly.'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('Fix State Discrepancy'),
                        onPressed: _fixAttendanceState,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
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
    );
  }

  Widget _buildStateColumn(String title, Map<String, dynamic> data) {
    bool exists = data['exists'] ?? false;
    bool hasCheckIn = data['hasCheckIn'] ?? false;
    bool hasCheckOut = data['hasCheckOut'] ?? false;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (exists) ...[
            _buildStatusRow('Check-in', hasCheckIn),
            _buildStatusRow('Check-out', hasCheckOut),
            Text(
              'Expected State: ${hasCheckIn && !hasCheckOut ? "CHECKED IN" : "CHECKED OUT"}',
              style: TextStyle(
                fontSize: 12,
                color: hasCheckIn && !hasCheckOut ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const Text('No record found', style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(status ? Icons.check : Icons.close,
              color: status ? Colors.green : Colors.red, size: 16),
          const SizedBox(width: 4),
          Text('$label: ${status ? "Yes" : "No"}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Force Sync Today'),
                  onPressed: () => _forceSyncRecord(DateFormat('yyyy-MM-dd').format(DateTime.now())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Data'),
                  onPressed: _loadDebugData,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('Clear Cache'),
                  onPressed: _clearLocalCache,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text('Run Diagnostics'),
                  onPressed: _runDiagnostics,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600], foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_debugData['connectivity'] != null) ...[
              _buildStatusItem(
                'Connectivity',
                _debugData['connectivity']['isOnline'] ? 'Online' : 'Offline',
                _debugData['connectivity']['isOnline'] ? Colors.green : Colors.red,
              ),
            ],

            if (_debugData['database'] != null) ...[
              _buildStatusItem(
                'Database Version',
                _debugData['database']['version']?.toString() ?? 'Unknown',
                Colors.blue,
              ),
              _buildStatusItem(
                'Total Tables',
                _debugData['database']['totalTables']?.toString() ?? '0',
                Colors.blue,
              ),
            ],

            _buildStatusItem(
              'Employee ID',
              widget.employeeId,
              Colors.grey[600]!,
            ),

            if (widget.userData != null) ...[
              _buildStatusItem(
                'Employee Name',
                widget.userData!['name'] ?? 'Unknown',
                Colors.grey[600]!,
              ),
              _buildStatusItem(
                'Employee PIN',
                widget.userData!['pin']?.toString() ?? 'Not set',
                Colors.grey[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttendanceCard() {
    List<dynamic> recentAttendance = _debugData['recentAttendance'] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Attendance (7 days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${recentAttendance.length} records',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),

            if (recentAttendance.isEmpty) ...[
              const Text('No recent attendance records found',
                  style: TextStyle(color: Colors.grey)),
            ] else ...[
              ...recentAttendance.map<Widget>((record) => _buildAttendanceRow(record)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRow(Map<String, dynamic> record) {
    bool hasCheckIn = record['hasCheckIn'] ?? false;
    bool hasCheckOut = record['hasCheckOut'] ?? false;
    bool isSynced = record['isSynced'] ?? false;
    String date = record['date'] ?? '';

    Color statusColor = hasCheckIn
        ? (hasCheckOut ? Colors.green : Colors.orange)
        : Colors.red;

    String status = hasCheckIn
        ? (hasCheckOut ? 'Complete' : 'In Progress')
        : 'Absent';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                  if (record['locationSummary'] != null) ...[
                    Text(
                      record['locationSummary'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  isSynced ? Icons.cloud_done : Icons.cloud_off,
                  color: isSynced ? Colors.green : Colors.orange,
                  size: 16,
                ),
                Text(
                  isSynced ? 'Synced' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSynced ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16),
              onSelected: (value) {
                if (value == 'sync') {
                  _forceSyncRecord(date);
                } else if (value == 'copy') {
                  _copyRecordData(record);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'sync', child: Text('Force Sync')),
                const PopupMenuItem(value: 'copy', child: Text('Copy Data')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatsCard() {
    Map<String, dynamic>? dbStats = _debugData['database'];
    if (dbStats == null) return Container();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Database Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (dbStats['tableStats'] != null) ...[
              ...dbStats['tableStats'].entries.map<Widget>((entry) =>
                  _buildStatusItem(entry.key, '${entry.value} records', Colors.grey[600]!)
              ).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRawDebugDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Raw Debug Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy All'),
                  onPressed: _copyAllDebugData,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(_debugData),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Additional action methods
  Future<void> _clearLocalCache() async {
    try {
      final attendanceRepo = getIt<AttendanceRepository>();
      await attendanceRepo.clearAttendanceData(employeeId: widget.employeeId);

      CustomSnackBar.successSnackBar("Local cache cleared");
      await _loadDebugData();
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error clearing cache: $e");
    }
  }

  Future<void> _runDiagnostics() async {
    try {
      setState(() => _isLoading = true);

      final dbHelper = getIt<DatabaseHelper>();
      await dbHelper.runDiagnostics();

      CustomSnackBar.successSnackBar("Diagnostics completed - check console logs");
      await _loadDebugData();
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error running diagnostics: $e");
    }
  }

  void _copyRecordData(Map<String, dynamic> record) {
    String data = const JsonEncoder.withIndent('  ').convert(record);
    Clipboard.setData(ClipboardData(text: data));
    CustomSnackBar.successSnackBar("Record data copied to clipboard");
  }

  void _copyAllDebugData() {
    String data = const JsonEncoder.withIndent('  ').convert(_debugData);
    Clipboard.setData(ClipboardData(text: data));
    CustomSnackBar.successSnackBar("All debug data copied to clipboard");
  }
}


