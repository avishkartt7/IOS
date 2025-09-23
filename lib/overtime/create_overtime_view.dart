// lib/overtime/create_overtime_view.dart - ENHANCED MOBILE-OPTIMIZED VERSION

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/overtime_request_model.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/services/notification_service.dart';
import 'package:face_auth/repositories/overtime_repository.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/overtime/employee_list_management_view.dart';
import 'package:flutter/foundation.dart';

class CreateOvertimeView extends StatefulWidget {
  final String requesterId;

  const CreateOvertimeView({
    Key? key,
    required this.requesterId,
  }) : super(key: key);

  @override
  State<CreateOvertimeView> createState() => _CreateOvertimeViewState();
}

class _CreateOvertimeViewState extends State<CreateOvertimeView> {
  // Form Controllers
  final _projectNameController = TextEditingController();
  final _projectCodeController = TextEditingController();
  final _searchController = TextEditingController();

  // State Variables
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));

  // Employee data
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<String> _selectedEmployeeIds = [];
  List<Map<String, dynamic>> _myEmployeeList = [];

  // Approver data
  List<Map<String, dynamic>> _availableApprovers = [];
  Map<String, dynamic>? _selectedApprover;

  // Request history
  List<OvertimeRequest> _requestHistory = [];

  // UI States
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasCustomList = false;
  bool _showEmployeeSelection = false;
  bool _showApproverSelection = false;
  bool _showHistory = false;
  bool _isLoadingApprovers = false;

  @override
  void initState() {

    super.initState();
    _initializeData();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectCodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION =====
  Future<void> _initializeData() async {
    await Future.wait([
      _loadEligibleEmployees(),
      _loadMyEmployeeList(),
      _loadAvailableApprovers(),
      _loadRequestHistory(),
    ]);
  }

  // ===== DATA LOADING METHODS =====
  Future<void> _loadEligibleEmployees() async {
    try {
      QuerySnapshot masterSheetSnapshot = await FirebaseFirestore.instance
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .where('hasOvertime', isEqualTo: true)
          .get();

      QuerySnapshot employeesSnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('hasOvertime', isEqualTo: true)
          .get();

      Set<Map<String, dynamic>> uniqueEmployees = {};

      for (var doc in masterSheetSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        uniqueEmployees.add({
          'id': doc.id,
          'name': data['employeeName'] ?? 'Unknown',
          'designation': data['designation'] ?? 'No designation',
          'department': data['department'] ?? 'No department',
          'employeeNumber': data['employeeNumber'] ?? '',
        });
      }

      for (var doc in employeesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        uniqueEmployees.add({
          'id': doc.id,
          'name': data['name'] ?? data['employeeName'] ?? 'Unknown',
          'designation': data['designation'] ?? 'No designation',
          'department': data['department'] ?? 'No department',
          'employeeNumber': data['employeeNumber'] ?? '',
        });
      }

      setState(() {
        _allEmployees = uniqueEmployees.toList();
        _allEmployees.sort((a, b) => a['name'].compareTo(b['name']));
        _filteredEmployees = List.from(_allEmployees);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Error loading employees: $e");
    }
  }

  Future<void> _loadMyEmployeeList() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employee_lists')
          .doc(widget.requesterId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<String> employeeIds = List<String>.from(data['employeeIds'] ?? []);

        List<Map<String, dynamic>> customList = [];
        for (String empId in employeeIds) {
          var employee = _allEmployees.firstWhere(
                (emp) => emp['id'] == empId,
            orElse: () => {},
          );
          if (employee.isNotEmpty) {
            customList.add(employee);
          }
        }

        setState(() {
          _myEmployeeList = customList;
          _hasCustomList = customList.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error loading custom employee list: $e");
    }
  }

  Future<void> _loadAvailableApprovers() async {
    setState(() => _isLoadingApprovers = true);

    try {
      List<Map<String, dynamic>> approvers = [];
      Set<String> addedApprovers = {};

      // Load from multiple sources
      await Future.wait([
        _loadApproversFromCollection('overtime_approvers', approvers, addedApprovers),
        _loadApproversFromMasterSheet(approvers, addedApprovers),
        _loadApproversFromEmployees(approvers, addedApprovers),
        _loadApproversFromLineManagers(approvers, addedApprovers),
      ]);

      // Sort by priority and name
      approvers.sort((a, b) {
        int priorityCompare = a['priority'].compareTo(b['priority']);
        if (priorityCompare != 0) return priorityCompare;
        return a['name'].compareTo(b['name']);
      });

      setState(() {
        _availableApprovers = approvers;
        _isLoadingApprovers = false;

        // Auto-select first approver if only one available
        if (approvers.length == 1) {
          _selectedApprover = approvers.first;
        }
      });

      // Fallback if no approvers found
      if (approvers.isEmpty) {
        _setFallbackApprover();
      }

    } catch (e) {
      debugPrint("Error loading approvers: $e");
      setState(() => _isLoadingApprovers = false);
      _setFallbackApprover();
    }
  }

  Future<void> _loadApproversFromCollection(String collection, List<Map<String, dynamic>> approvers, Set<String> addedApprovers) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String approverId = data['approverId'] ?? doc.id;

        if (!addedApprovers.contains(approverId)) {
          approvers.add({
            'id': approverId,
            'name': data['approverName'] ?? 'Unknown Approver',
            'designation': data['designation'] ?? 'Overtime Approver',
            'department': data['department'] ?? 'Management',
            'source': collection,
            'priority': 1,
          });
          addedApprovers.add(approverId);
        }
      }
    } catch (e) {
      debugPrint("Error loading from $collection: $e");
    }
  }

  Future<void> _loadApproversFromMasterSheet(List<Map<String, dynamic>> approvers, Set<String> addedApprovers) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('MasterSheet')
          .doc('Employee-Data')
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String approverId = doc.id;

        if (!addedApprovers.contains(approverId)) {
          approvers.add({
            'id': approverId,
            'name': data['employeeName'] ?? data['name'] ?? 'Unknown',
            'designation': data['designation'] ?? 'Manager',
            'department': data['department'] ?? 'Unknown Department',
            'source': 'mastersheet',
            'priority': 2,
          });
          addedApprovers.add(approverId);
        }
      }
    } catch (e) {
      debugPrint("Error loading from MasterSheet: $e");
    }
  }

  Future<void> _loadApproversFromEmployees(List<Map<String, dynamic>> approvers, Set<String> addedApprovers) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('hasOvertimeApprovalAccess', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String approverId = doc.id;

        if (!addedApprovers.contains(approverId)) {
          approvers.add({
            'id': approverId,
            'name': data['name'] ?? data['employeeName'] ?? 'Unknown',
            'designation': data['designation'] ?? 'Manager',
            'department': data['department'] ?? 'Unknown Department',
            'source': 'employees',
            'priority': 3,
          });
          addedApprovers.add(approverId);
        }
      }
    } catch (e) {
      debugPrint("Error loading from employees: $e");
    }
  }

  Future<void> _loadApproversFromLineManagers(List<Map<String, dynamic>> approvers, Set<String> addedApprovers) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('line_managers')
          .where('canApproveOvertime', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String approverId = data['managerId'] ?? doc.id;

        if (!addedApprovers.contains(approverId)) {
          approvers.add({
            'id': approverId,
            'name': data['managerName'] ?? 'Unknown Manager',
            'designation': data['designation'] ?? 'Line Manager',
            'department': data['department'] ?? 'Management',
            'source': 'line_managers',
            'priority': 4,
          });
          addedApprovers.add(approverId);
        }
      }
    } catch (e) {
      debugPrint("Error loading from line_managers: $e");
    }
  }

  void _setFallbackApprover() {
    setState(() {
      _availableApprovers = [{
        'id': 'EMP1289',
        'name': 'Default Approver',
        'designation': 'System Approver',
        'department': 'Administration',
        'source': 'fallback',
        'priority': 999,
      }];
      _selectedApprover = _availableApprovers.first;
    });
  }

  Future<void> _loadRequestHistory() async {
    try {
      FirebaseFirestore.instance
          .collection('overtime_requests')
          .where('requesterId', isEqualTo: widget.requesterId)
          .orderBy('requestTime', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        List<OvertimeRequest> requests = [];
        for (var doc in snapshot.docs) {
          try {
            requests.add(_parseOvertimeRequest(doc));
          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
          }
        }

        if (mounted) {
          setState(() => _requestHistory = requests);
        }
      });
    } catch (e) {
      debugPrint("Error loading request history: $e");
    }
  }

  OvertimeRequest _parseOvertimeRequest(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<OvertimeProjectEntry> projects = [];
    if (data['projects'] != null && data['projects'] is List) {
      for (var projectData in data['projects']) {
        projects.add(OvertimeProjectEntry.fromMap(projectData));
      }
    } else {
      projects.add(OvertimeProjectEntry(
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        employeeIds: List<String>.from(data['employeeIds'] ?? []),
      ));
    }

    return OvertimeRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      approverEmpId: data['approverEmpId'] ?? '',
      approverName: data['approverName'] ?? '',
      projectName: data['projectName'] ?? '',
      projectCode: data['projectCode'] ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeIds: List<String>.from(data['employeeIds'] ?? []),
      requestTime: (data['requestTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status']),
      responseMessage: data['responseMessage'],
      responseTime: (data['responseTime'] as Timestamp?)?.toDate(),
      totalProjects: data['totalProjects'] ?? 1,
      totalEmployeeCount: data['totalEmployees'] ?? (data['employeeIds'] as List?)?.length ?? 0,
      totalDurationHours: data['totalHours']?.toDouble() ?? 0.0,
      projects: projects,
    );
  }

  OvertimeRequestStatus _parseStatus(dynamic status) {
    if (status == null) return OvertimeRequestStatus.pending;
    switch (status.toString().toLowerCase()) {
      case 'approved':
        return OvertimeRequestStatus.approved;
      case 'rejected':
        return OvertimeRequestStatus.rejected;
      case 'cancelled':
        return OvertimeRequestStatus.cancelled;
      case 'pending':
      default:
        return OvertimeRequestStatus.pending;
    }
  }

  // ===== EMPLOYEE MANAGEMENT =====
  void _filterEmployees() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(_allEmployees);
      } else {
        _filteredEmployees = _allEmployees.where((employee) {
          String name = employee['name'].toString().toLowerCase();
          String designation = employee['designation'].toString().toLowerCase();
          String department = employee['department'].toString().toLowerCase();
          String empId = employee['id'].toString().toLowerCase();
          return name.contains(query) ||
              designation.contains(query) ||
              department.contains(query) ||
              empId.contains(query);
        }).toList();
      }
    });
  }

  void _toggleEmployeeSelection(String employeeId) {
    setState(() {
      if (_selectedEmployeeIds.contains(employeeId)) {
        _selectedEmployeeIds.remove(employeeId);
      } else {
        _selectedEmployeeIds.add(employeeId);
      }
    });
  }

  void _selectAllEmployees() {
    setState(() {
      _selectedEmployeeIds = _filteredEmployees.map((emp) => emp['id'] as String).toList();
    });
  }

  void _clearAllEmployees() {
    setState(() {
      _selectedEmployeeIds.clear();
    });
  }

  void _loadMyEmployees() {
    setState(() {
      _selectedEmployeeIds = _myEmployeeList.map((emp) => emp['id'] as String).toList();
    });
  }

  // ===== TIME SELECTION =====
  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );

    if (picked != null) {
      final now = DateTime.now();
      final newStartTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

      setState(() {
        _startTime = newStartTime;
        // Ensure end time is after start time
        if (_endTime.isBefore(newStartTime) || _endTime.difference(newStartTime).inMinutes < 60) {
          _endTime = newStartTime.add(const Duration(hours: 2));
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );

    if (picked != null) {
      final now = DateTime.now();
      final newEndTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

      if (newEndTime.isAfter(_startTime)) {
        setState(() {
          _endTime = newEndTime;
        });
      } else {
        _showErrorSnackBar("End time must be after start time");
      }
    }
  }

  // ===== VALIDATION =====
  bool _isFormValid() {
    return _projectNameController.text.trim().isNotEmpty &&
        _projectCodeController.text.trim().isNotEmpty &&
        _selectedEmployeeIds.isNotEmpty &&
        _selectedApprover != null;
  }

  double get _durationInHours {
    return _endTime.difference(_startTime).inMinutes / 60.0;
  }

  // ===== SUBMISSION =====
  Future<void> _submitRequest() async {
    if (!_isFormValid()) {
      _showErrorSnackBar("Please fill all required fields");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get requester info
      DocumentSnapshot requesterDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.requesterId)
          .get();

      String requesterName = '';
      if (requesterDoc.exists) {
        Map<String, dynamic> data = requesterDoc.data() as Map<String, dynamic>;
        requesterName = data['employeeName'] ?? data['name'] ?? 'Unknown Requester';
      }

      // Create project entry
      final projectEntry = OvertimeProjectEntry(
        projectName: _projectNameController.text.trim(),
        projectCode: _projectCodeController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        employeeIds: _selectedEmployeeIds,
      );

      // Submit to Firestore
      DocumentReference requestRef = await FirebaseFirestore.instance
          .collection('overtime_requests')
          .add({
        'projects': [projectEntry.toMap()],
        'requesterId': widget.requesterId,
        'requesterName': requesterName,
        'approverEmpId': _selectedApprover!['id'],
        'approverName': _selectedApprover!['name'],
        'requestTime': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdBy': widget.requesterId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'version': 1,
        'projectName': projectEntry.projectName,
        'projectCode': projectEntry.projectCode,
        'startTime': Timestamp.fromDate(projectEntry.startTime),
        'endTime': Timestamp.fromDate(projectEntry.endTime),
        'employeeIds': _selectedEmployeeIds,
        'totalProjects': 1,
        'totalEmployees': _selectedEmployeeIds.length,
        'totalHours': projectEntry.durationInHours,
        'employeeDetails': await _getEmployeeDetails(_selectedEmployeeIds),
      });

      // Send notifications
      await _sendNotifications(requestRef.id, projectEntry, requesterName);

      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorSnackBar("Error submitting request: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getEmployeeDetails(List<String> employeeIds) async {
    List<Map<String, dynamic>> details = [];
    for (String empId in employeeIds) {
      var employee = _allEmployees.firstWhere(
            (emp) => emp['id'] == empId,
        orElse: () => {},
      );
      if (employee.isNotEmpty) {
        details.add({
          'id': empId,
          'name': employee['name'],
          'designation': employee['designation'],
          'department': employee['department'],
          'employeeNumber': employee['employeeNumber'],
        });
      }
    }
    return details;
  }

  Future<void> _sendNotifications(String requestId, OvertimeProjectEntry project, String requesterName) async {
    try {
      // Notification to requester
      final requesterCallable = FirebaseFunctions.instance.httpsCallable('sendNotificationToUser');
      await requesterCallable.call({
        'userId': widget.requesterId,
        'title': '✅ Overtime Request Submitted!',
        'body': 'Your overtime request for ${project.projectName} has been sent to ${_selectedApprover!['name']} for approval.',
        'data': {
          'type': 'overtime_request_submitted',
          'requestId': requestId,
          'projectName': project.projectName,
          'employeeCount': _selectedEmployeeIds.length.toString(),
          'approverName': _selectedApprover!['name'],
        }
      });

      // Notification to approver
      final approverCallable = FirebaseFunctions.instance.httpsCallable('sendOvertimeRequestNotification');
      await approverCallable.call({
        'requestId': requestId,
        'projectName': project.projectName,
        'requesterName': requesterName,
        'requesterId': widget.requesterId,
        'employeeCount': _selectedEmployeeIds.length,
        'totalProjects': 1,
        'totalHours': project.durationInHours.round(),
        'approverId': _selectedApprover!['id'],
        'approverName': _selectedApprover!['name'],
      });
    } catch (e) {
      debugPrint("Notification error: $e");
    }
  }

  // ===== UI HELPERS =====
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text("Request Submitted!", style: TextStyle(color: Colors.green))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your overtime request has been successfully submitted and sent for approval."),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Project: ${_projectNameController.text}"),
                  Text("Approver: ${_selectedApprover!['name']}"),
                  Text("Employees: ${_selectedEmployeeIds.length}"),
                  Text("Duration: ${_durationInHours.toStringAsFixed(1)} hours"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text("Create Overtime Request"),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            _buildProgressIndicator(),
            SizedBox(height: 24),

            // Project Details Card
            _buildProjectDetailsCard(),
            SizedBox(height: 16),

            // Employee Selection Card
            _buildEmployeeSelectionCard(),
            SizedBox(height: 16),

            // Approver Selection Card
            if (_selectedEmployeeIds.isNotEmpty) ...[
              _buildApproverSelectionCard(),
              SizedBox(height: 16),
            ],

            // Preview Card
            if (_isFormValid()) ...[
              _buildPreviewCard(),
              SizedBox(height: 16),
            ],

            // History Toggle
            _buildHistoryToggle(),

            // History Cards
            if (_showHistory) ...[
              SizedBox(height: 16),
              _buildHistorySection(),
            ],

            SizedBox(height: 100), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: _isFormValid()
          ? FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _submitRequest,
        backgroundColor: _isSubmitting ? Colors.grey : Colors.green,
        icon: _isSubmitting
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(Icons.send, color: Colors.white),
        label: Text(
          _isSubmitting ? "Submitting..." : "Submit Request",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
          : null,
    );
  }

  Widget _buildProgressIndicator() {
    int completedSteps = 0;
    if (_projectNameController.text.trim().isNotEmpty && _projectCodeController.text.trim().isNotEmpty) completedSteps++;
    if (_selectedEmployeeIds.isNotEmpty) completedSteps++;
    if (_selectedApprover != null) completedSteps++;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Progress: $completedSteps/3 Steps Complete",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: completedSteps / 3,
            backgroundColor: Colors.blue.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetailsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.work, color: Colors.blue),
                ),
                SizedBox(width: 12),
                Text(
                  "Project Details",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Project Name
            TextFormField(
              controller: _projectNameController,
              decoration: InputDecoration(
                labelText: "Project Name *",
                hintText: "Enter project name",
                prefixIcon: Icon(Icons.business_center),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),

            // Project Code
            TextFormField(
              controller: _projectCodeController,
              decoration: InputDecoration(
                labelText: "Project Code *",
                hintText: "Enter project code",
                prefixIcon: Icon(Icons.code),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 16),

            // Time Selection
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    label: "Start Time",
                    time: _startTime,
                    onTap: _selectStartTime,
                    icon: Icons.schedule,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelector(
                    label: "End Time",
                    time: _endTime,
                    onTap: _selectEndTime,
                    icon: Icons.schedule_send,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Duration Display
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    "Duration: ${_durationInHours.toStringAsFixed(1)} hours",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required DateTime time,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(time),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSelectionCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.people, color: Colors.green),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Select Employees",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showEmployeeSelection = !_showEmployeeSelection),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedEmployeeIds.isNotEmpty ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${_selectedEmployeeIds.length} selected",
                          style: TextStyle(
                            color: _selectedEmployeeIds.isNotEmpty ? Colors.green : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          _showEmployeeSelection ? Icons.expand_less : Icons.expand_more,
                          color: _selectedEmployeeIds.isNotEmpty ? Colors.green : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedEmployeeIds.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildSelectedEmployeesChips(),
            ],

            if (_showEmployeeSelection) ...[
              SizedBox(height: 16),
              _buildEmployeeSelectionSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedEmployeesChips() {
    return Container(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _selectedEmployeeIds.take(10).map((empId) {
          final employee = _allEmployees.firstWhere((emp) => emp['id'] == empId, orElse: () => {});
          if (employee.isEmpty) return SizedBox.shrink();

          return Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                employee['name'][0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            label: Text(
              employee['name'],
              style: TextStyle(fontSize: 12),
            ),
            deleteIcon: Icon(Icons.close, size: 16),
            onDeleted: () => _toggleEmployeeSelection(empId),
            backgroundColor: Colors.green.withOpacity(0.1),
            deleteIconColor: Colors.green,
          );
        }).toList()
          ..addAll(_selectedEmployeeIds.length > 10 ? [
            Chip(
              label: Text("+${_selectedEmployeeIds.length - 10} more"),
              backgroundColor: Colors.grey.withOpacity(0.2),
            )
          ] : []),
      ),
    );
  }

  Widget _buildEmployeeSelectionSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Actions
        if (_hasCustomList) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "My Saved List (${_myEmployeeList.length} employees)",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton(
                  onPressed: _loadMyEmployees,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text("Load", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectAllEmployees,
                icon: Icon(Icons.select_all, size: 16),
                label: Text("Select All"),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearAllEmployees,
                icon: Icon(Icons.clear, size: 16),
                label: Text("Clear"),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),

        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search employees...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
          ),
        ),
        SizedBox(height: 12),

        // Employee List
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: _filteredEmployees.length,
            itemBuilder: (context, index) {
              final employee = _filteredEmployees[index];
              final empId = employee['id'];
              final isSelected = _selectedEmployeeIds.contains(empId);

              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected ? Colors.green : Colors.grey[400],
                  child: Text(
                    employee['name'][0].toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(
                  employee['name'],
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  "${employee['designation']} • ${employee['department']}",
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleEmployeeSelection(empId),
                  activeColor: Colors.green,
                ),
                onTap: () => _toggleEmployeeSelection(empId),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildApproverSelectionCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.purple),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Select Approver",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showApproverSelection = !_showApproverSelection),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedApprover != null ? Colors.purple.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedApprover != null ? "Selected" : "Choose",
                          style: TextStyle(
                            color: _selectedApprover != null ? Colors.purple : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          _showApproverSelection ? Icons.expand_less : Icons.expand_more,
                          color: _selectedApprover != null ? Colors.purple : Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedApprover != null) ...[
              SizedBox(height: 16),
              _buildSelectedApproverChip(),
            ],

            if (_showApproverSelection || _selectedApprover == null) ...[
              SizedBox(height: 16),
              _buildApproverSelectionSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedApproverChip() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.purple,
            child: Text(
              _selectedApprover!['name'][0].toUpperCase(),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedApprover!['name'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_selectedApprover!['designation']} • ${_selectedApprover!['department']}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedApprover = null),
            icon: Icon(Icons.close, color: Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildApproverSelectionSection() {
    if (_isLoadingApprovers) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    if (_availableApprovers.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(height: 8),
            Text(
              "No approvers available",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Please contact your administrator",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _availableApprovers.length,
        itemBuilder: (context, index) {
          final approver = _availableApprovers[index];
          final isSelected = _selectedApprover?['id'] == approver['id'];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.purple : Colors.grey[400],
              child: Text(
                approver['name'][0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              approver['name'],
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "${approver['designation']} • ${approver['department']}",
              style: TextStyle(fontSize: 12),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.purple)
                : Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
            onTap: () => setState(() => _selectedApprover = approver),
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.preview, color: Colors.orange),
                ),
                SizedBox(width: 12),
                Text(
                  "Request Preview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Summary Grid
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem("Project", _projectNameController.text, Icons.work)),
                      SizedBox(width: 16),
                      Expanded(child: _buildSummaryItem("Code", _projectCodeController.text, Icons.code)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem("Employees", "${_selectedEmployeeIds.length}", Icons.people)),
                      SizedBox(width: 16),
                      Expanded(child: _buildSummaryItem("Duration", "${_durationInHours.toStringAsFixed(1)}h", Icons.timer)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryItem("Start", DateFormat('h:mm a').format(_startTime), Icons.schedule)),
                      SizedBox(width: 16),
                      Expanded(child: _buildSummaryItem("End", DateFormat('h:mm a').format(_endTime), Icons.schedule_send)),
                    ],
                  ),
                  if (_selectedApprover != null) ...[
                    SizedBox(height: 12),
                    _buildSummaryItem("Approver", _selectedApprover!['name'], Icons.admin_panel_settings),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.orange),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showHistory = !_showHistory),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.grey[600]),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Request History (${_requestHistory.length})",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Icon(
              _showHistory ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_requestHistory.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "No request history",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _requestHistory.take(5).map((request) => _buildHistoryCard(request)).toList(),
    );
  }

  Widget _buildHistoryCard(OvertimeRequest request) {
    Color statusColor = _getStatusColor(request.status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getStatusIcon(request.status), color: statusColor, size: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.projectName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • h:mm a').format(request.requestTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(request.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  "${request.totalEmployeeCount} employees",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 16),
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  "${request.totalDurationHours.toStringAsFixed(1)}h",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 16),
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.approverName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for status
  Color _getStatusColor(OvertimeRequestStatus status) {
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

  IconData _getStatusIcon(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return Icons.pending;
      case OvertimeRequestStatus.approved:
        return Icons.check_circle;
      case OvertimeRequestStatus.rejected:
        return Icons.cancel;
      case OvertimeRequestStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusText(OvertimeRequestStatus status) {
    switch (status) {
      case OvertimeRequestStatus.pending:
        return "Pending";
      case OvertimeRequestStatus.approved:
        return "Approved";
      case OvertimeRequestStatus.rejected:
        return "Rejected";
      case OvertimeRequestStatus.cancelled:
        return "Cancelled";
    }
  }
}



