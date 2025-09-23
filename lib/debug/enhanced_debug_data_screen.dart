import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/service_locator.dart';
import 'package:face_auth_compatible/repositories/attendance_repository.dart';
import 'package:face_auth_compatible/model/local_attendance_model.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DebugDataScreen extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> userData;

  const DebugDataScreen({
    Key? key,
    required this.employeeId,
    required this.userData,
  }) : super(key: key);

  @override
  State<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _debugData = {};
  late AttendanceRepository _attendanceRepository;
  late ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _attendanceRepository = getIt<AttendanceRepository>();
    _connectivityService = getIt<ConnectivityService>();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    setState(() => _isLoading = true);

    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      Map<String, dynamic> debugData = {
        'timestamp': DateTime.now().toIso8601String(),
        'employeeId': widget.employeeId,
        'today': today,
        'connectivity': _connectivityService.currentStatus.toString(),
        'localData': {},
        'firebaseData': {},
        'comparison': {},
        'recommendations': [],
      };

      // Get Local Data
      await _loadLocalData(debugData, today);

      // Get Firebase Data (if online)
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _loadFirebaseData(debugData, today);
      } else {
        debugData['firebaseData'] = {'status': 'offline', 'message': 'Cannot fetch - device is offline'};
      }

      // Perform Comparison
      _performComparison(debugData);

      setState(() {
        _debugData = debugData;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _debugData = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalData(Map<String, dynamic> debugData, String today) async {
    Map<String, dynamic> localData = {};

    try {
      // SQLite Database Info
      final dbHelper = getIt<DatabaseHelper>();
      final db = await dbHelper.database;

      localData['database'] = {
        'path': db.path,
        'version': await db.getVersion(),
        'isOpen': db.isOpen,
      };

      // Today's Attendance Record
      final localRecord = await _attendanceRepository.getTodaysAttendance(widget.employeeId);
      if (localRecord != null) {
        localData['attendance'] = {
          'exists': true,
          'checkIn': localRecord.checkIn,
          'checkOut': localRecord.checkOut,
          'hasCheckIn': localRecord.hasCheckIn,
          'hasCheckOut': localRecord.hasCheckOut,
          'isSynced': localRecord.isSynced,
          'locationSummary': localRecord.locationSummary,
          'rawDataKeys': localRecord.rawData.keys.toList(),
          'rawData': localRecord.rawData,
        };
      } else {
        localData['attendance'] = {
          'exists': false,
          'message': 'No local attendance record found for today',
        };
      }

      // All Local Records (last 7 days)
      final recentRecords = await _attendanceRepository.getAttendanceRecords(
        employeeId: widget.employeeId,
        startDate: DateTime.now().subtract(Duration(days: 7)),
        endDate: DateTime.now(),
      );

      localData['recentRecords'] = {
        'count': recentRecords.length,
        'records': recentRecords.map((record) => {
          'date': record.date,
          'hasCheckIn': record.hasCheckIn,
          'hasCheckOut': record.hasCheckOut,
          'isSynced': record.isSynced,
        }).toList(),
      };

      // Pending Records
      final pendingRecords = await _attendanceRepository.getPendingRecords();
      localData['pendingSync'] = {
        'count': pendingRecords.length,
        'records': pendingRecords.map((record) => {
          'date': record.date,
          'employeeId': record.employeeId,
          'hasCheckIn': record.hasCheckIn,
          'hasCheckOut': record.hasCheckOut,
        }).toList(),
      };

      // SharedPreferences Data
      final prefs = await SharedPreferences.getInstance();
      localData['sharedPreferences'] = {
        'userDataExists': prefs.getString('user_data_${widget.employeeId}') != null,
        'userNameExists': prefs.getString('user_name_${widget.employeeId}') != null,
        'attendanceCache': prefs.getString('attendance_${widget.employeeId}_$today') != null,
        'allKeys': prefs.getKeys().where((key) => key.contains(widget.employeeId)).toList(),
      };

      // Try to get cached attendance
      String? cachedAttendance = prefs.getString('attendance_${widget.employeeId}_$today');
      if (cachedAttendance != null) {
        try {
          Map<String, dynamic> parsed = jsonDecode(cachedAttendance);
          localData['sharedPreferences']['cachedAttendanceData'] = parsed;
        } catch (e) {
          localData['sharedPreferences']['cachedAttendanceError'] = e.toString();
        }
      }

    } catch (e) {
      localData['error'] = e.toString();
    }

    debugData['localData'] = localData;
  }

  Future<void> _loadFirebaseData(Map<String, dynamic> debugData, String today) async {
    Map<String, dynamic> firebaseData = {};

    try {
      // Today's Attendance from Firebase
      DocumentSnapshot attendanceDoc = await FirebaseFirestore.instance
          .collection('Attendance_Records')
          .doc('PTSEmployees')
          .collection('Records')
          .doc('${widget.employeeId}-$today')
          .get()
          .timeout(const Duration(seconds: 10));

      if (attendanceDoc.exists) {
        Map<String, dynamic> data = attendanceDoc.data() as Map<String, dynamic>;

        firebaseData['attendance'] = {
          'exists': true,
          'documentId': attendanceDoc.id,
          'rawData': data,
          'checkInRaw': data['checkIn'],
          'checkOutRaw': data['checkOut'],
          'checkInType': data['checkIn']?.runtimeType.toString(),
          'checkOutType': data['checkOut']?.runtimeType.toString(),
        };

        // Parse timestamps
        DateTime? checkIn, checkOut;
        try {
          if (data['checkIn'] is Timestamp) {
            checkIn = (data['checkIn'] as Timestamp).toDate();
          } else if (data['checkIn'] is String) {
            checkIn = DateTime.parse(data['checkIn']);
          }

          if (data['checkOut'] is Timestamp) {
            checkOut = (data['checkOut'] as Timestamp).toDate();
          } else if (data['checkOut'] is String) {
            checkOut = DateTime.parse(data['checkOut']);
          }
        } catch (e) {
          firebaseData['attendance']['parseError'] = e.toString();
        }

        firebaseData['attendance']['parsed'] = {
          'checkIn': checkIn?.toIso8601String(),
          'checkOut': checkOut?.toIso8601String(),
          'hasCheckIn': checkIn != null,
          'hasCheckOut': checkOut != null,
          'expectedState': checkIn != null && checkOut == null ? 'CHECKED_IN' : 'CHECKED_OUT',
        };

      } else {
        firebaseData['attendance'] = {
          'exists': false,
          'message': 'No Firebase attendance record found for today',
        };
      }

      // Recent Firebase Records
      QuerySnapshot recentDocs = await FirebaseFirestore.instance
          .collection('Attendance_Records')
          .doc('PTSEmployees')
          .collection('Records')
          .where('employeeId', isEqualTo: widget.employeeId)
          .orderBy('date', descending: true)
          .limit(7)
          .get()
          .timeout(const Duration(seconds: 10));

      firebaseData['recentRecords'] = {
        'count': recentDocs.docs.length,
        'records': recentDocs.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return {
            'documentId': doc.id,
            'date': data['date'],
            'hasCheckIn': data['checkIn'] != null,
            'hasCheckOut': data['checkOut'] != null,
          };
        }).toList(),
      };

      // User Document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get()
          .timeout(const Duration(seconds: 5));

      firebaseData['userDocument'] = {
        'exists': userDoc.exists,
        'lastUpdated': userDoc.exists ?
        (userDoc.data() as Map<String, dynamic>?)?.containsKey('lastUpdated') == true ?
        (userDoc.data() as Map<String, dynamic>)['lastUpdated'].toString() : 'Not available'
            : null,
      };

    } catch (e) {
      firebaseData['error'] = e.toString();
    }

    debugData['firebaseData'] = firebaseData;
  }

  void _performComparison(Map<String, dynamic> debugData) {
    Map<String, dynamic> comparison = {};
    List<String> recommendations = [];

    try {
      // Compare attendance states
      bool? localState;
      bool? firebaseState;

      if (debugData['localData']['attendance']['exists'] == true) {
        localState = debugData['localData']['attendance']['hasCheckIn'] == true &&
            debugData['localData']['attendance']['hasCheckOut'] != true;
      }

      if (debugData['firebaseData']['attendance']?['exists'] == true) {
        firebaseState = debugData['firebaseData']['attendance']['parsed']['hasCheckIn'] == true &&
            debugData['firebaseData']['attendance']['parsed']['hasCheckOut'] != true;
      }

      comparison['states'] = {
        'local': localState != null ? (localState ? 'CHECKED_IN' : 'CHECKED_OUT') : 'NO_DATA',
        'firebase': firebaseState != null ? (firebaseState ? 'CHECKED_IN' : 'CHECKED_OUT') : 'NO_DATA',
        'match': localState == firebaseState,
        'conflict': localState != null && firebaseState != null && localState != firebaseState,
      };

      // Sync status analysis
      bool isLocalSynced = debugData['localData']['attendance']?['isSynced'] == true;
      bool hasPendingRecords = (debugData['localData']['pendingSync']?['count'] ?? 0) > 0;

      comparison['sync'] = {
        'localSynced': isLocalSynced,
        'hasPendingRecords': hasPendingRecords,
        'needsSync': !isLocalSynced || hasPendingRecords,
      };

      // Generate recommendations
      if (comparison['states']['conflict'] == true) {
        if (!isLocalSynced) {
          recommendations.add("🔥 CRITICAL: Local unsynced data conflicts with Firebase. Local data should take priority.");
        } else {
          recommendations.add("⚠️ WARNING: Synced local data conflicts with Firebase. Manual investigation needed.");
        }
      }

      if (hasPendingRecords) {
        recommendations.add("📤 Action needed: ${debugData['localData']['pendingSync']['count']} records waiting to sync.");
      }

      if (debugData['connectivity'] == 'ConnectionStatus.offline') {
        recommendations.add("📱 Offline mode: Using local data only. Will sync when online.");
      }

      if (localState == null && firebaseState != null) {
        recommendations.add("📥 Suggestion: Download Firebase data to local storage.");
      }

      if (localState != null && firebaseState == null) {
        recommendations.add("📤 Suggestion: Upload local data to Firebase.");
      }

      if (comparison['states']['match'] == true && isLocalSynced) {
        recommendations.add("✅ All good: Local and Firebase data are synchronized.");
      }

    } catch (e) {
      comparison['error'] = e.toString();
    }

    debugData['comparison'] = comparison;
    debugData['recommendations'] = recommendations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Data Screen'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDebugData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _debugData.isEmpty
          ? Center(child: Text('No data available'))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            SizedBox(height: 16),
            _buildRecommendationsCard(),
            SizedBox(height: 16),
            _buildComparisonCard(),
            SizedBox(height: 16),
            _buildLocalDataCard(),
            SizedBox(height: 16),
            _buildFirebaseDataCard(),
            SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summary, color: Colors.blue),
                SizedBox(width: 8),
                Text('Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('Employee ID', widget.employeeId),
            _buildInfoRow('Date', _debugData['today'] ?? 'Unknown'),
            _buildInfoRow('Connectivity', _debugData['connectivity'] ?? 'Unknown'),
            _buildInfoRow('Last Updated', DateFormat('HH:mm:ss').format(DateTime.parse(_debugData['timestamp'] ?? DateTime.now().toIso8601String()))),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    List<String> recommendations = List<String>.from(_debugData['recommendations'] ?? []);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange),
                SizedBox(width: 8),
                Text('Recommendations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            if (recommendations.isEmpty)
              Text('No specific recommendations', style: TextStyle(color: Colors.grey))
            else
              ...recommendations.map((rec) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(rec)),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    Map<String, dynamic> comparison = _debugData['comparison'] ?? {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare, color: Colors.green),
                SizedBox(width: 8),
                Text('Comparison', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            if (comparison['states'] != null) ...[
              _buildComparisonRow('Local State', comparison['states']['local']),
              _buildComparisonRow('Firebase State', comparison['states']['firebase']),
              _buildComparisonRow('States Match', comparison['states']['match']?.toString() ?? 'Unknown'),
              _buildComparisonRow('Has Conflict', comparison['states']['conflict']?.toString() ?? 'Unknown'),
            ],
            if (comparison['sync'] != null) ...[
              Divider(),
              _buildComparisonRow('Local Synced', comparison['sync']['localSynced']?.toString() ?? 'Unknown'),
              _buildComparisonRow('Has Pending', comparison['sync']['hasPendingRecords']?.toString() ?? 'Unknown'),
              _buildComparisonRow('Needs Sync', comparison['sync']['needsSync']?.toString() ?? 'Unknown'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocalDataCard() {
    Map<String, dynamic> localData = _debugData['localData'] ?? {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue),
                SizedBox(width: 8),
                Text('Local Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            if (localData['attendance'] != null) ...[
              Text('Attendance Record:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildDataSection(localData['attendance']),
              SizedBox(height: 16),
            ],
            if (localData['pendingSync'] != null) ...[
              Text('Pending Sync:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildDataSection(localData['pendingSync']),
              SizedBox(height: 16),
            ],
            if (localData['database'] != null) ...[
              Text('Database Info:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildDataSection(localData['database']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseDataCard() {
    Map<String, dynamic> firebaseData = _debugData['firebaseData'] ?? {};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Colors.orange),
                SizedBox(width: 8),
                Text('Firebase Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            if (firebaseData['status'] == 'offline') ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Device is offline - Cannot fetch Firebase data'),
                  ],
                ),
              ),
            ] else ...[
              if (firebaseData['attendance'] != null) ...[
                Text('Attendance Record:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildDataSection(firebaseData['attendance']),
                SizedBox(height: 16),
              ],
              if (firebaseData['recentRecords'] != null) ...[
                Text('Recent Records:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _buildDataSection(firebaseData['recentRecords']),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.red),
                SizedBox(width: 8),
                Text('Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _forceSync,
                  icon: Icon(Icons.sync),
                  label: Text('Force Sync'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: _clearLocalData,
                  icon: Icon(Icons.delete),
                  label: Text('Clear Local'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: _exportDebugData,
                  icon: Icon(Icons.download),
                  label: Text('Export Data'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label + ':', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value) {
    Color? valueColor;
    if (value == 'true') valueColor = Colors.green;
    if (value == 'false') valueColor = Colors.red;
    if (value == 'CHECKED_IN') valueColor = Colors.blue;
    if (value == 'CHECKED_OUT') valueColor = Colors.orange;

    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label + ':', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key + ':',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _forceSync() async {
    // Implement force sync logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Force sync initiated')),
    );
    _loadDebugData();
  }

  Future<void> _clearLocalData() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Local Data'),
        content: Text('This will delete all local attendance data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // Implement clear local data logic
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Local data cleared')),
      );
      _loadDebugData();
    }
  }

  Future<void> _exportDebugData() async {
    // Implement export logic (could save to file or copy to clipboard)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Debug data exported to console')),
    );
    print('DEBUG DATA EXPORT: ${jsonEncode(_debugData)}');
  }
}