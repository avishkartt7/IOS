// lib/repositories/overtime_repository.dart - UPDATED FOR MANUAL APPROVER SELECTION

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:face_auth_compatible/model/overtime_request_model.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeRepository {
  final FirebaseFirestore _firestore;
  final DatabaseHelper _dbHelper;
  final ConnectivityService _connectivityService;
  final NotificationService _notificationService;

  OvertimeRepository({
    required FirebaseFirestore firestore,
    required DatabaseHelper dbHelper,
    required ConnectivityService connectivityService,
    required NotificationService notificationService,
  }) : _firestore = firestore,
        _dbHelper = dbHelper,
        _connectivityService = connectivityService,
        _notificationService = notificationService;

  // ✅ NEW: Get list of available overtime approvers for UI selection
  Future<List<Map<String, dynamic>>> getAvailableApprovers() async {
    try {
      debugPrint("=== FETCHING ALL AVAILABLE OVERTIME APPROVERS ===");

      List<Map<String, dynamic>> approvers = [];
      Set<String> addedApprovers = {}; // Prevent duplicates

      // Method 1: Check dedicated overtime_approvers collection
      try {
        QuerySnapshot approversSnapshot = await _firestore
            .collection('overtime_approvers')
            .where('isActive', isEqualTo: true)
            .get();

        for (var doc in approversSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String approverId = data['approverId'] ?? doc.id;

          if (!addedApprovers.contains(approverId)) {
            approvers.add({
              'id': approverId,
              'name': data['approverName'] ?? 'Unknown Approver',
              'designation': data['designation'] ?? 'Overtime Approver',
              'department': data['department'] ?? 'Management',
              'source': 'overtime_approvers',
              'priority': 1, // Highest priority
            });
            addedApprovers.add(approverId);
          }
        }
        debugPrint("Found ${approversSnapshot.docs.length} dedicated overtime approvers");
      } catch (e) {
        debugPrint("Error loading from overtime_approvers: $e");
      }

      // Method 2: Check MasterSheet for hasOvertimeApprovalAccess
      try {
        QuerySnapshot masterSheetSnapshot = await _firestore
            .collection('MasterSheet')
            .doc('Employee-Data')
            .collection('employees')
            .where('hasOvertimeApprovalAccess', isEqualTo: true)
            .get();

        for (var doc in masterSheetSnapshot.docs) {
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
        debugPrint("Found ${masterSheetSnapshot.docs.length} MasterSheet approvers");
      } catch (e) {
        debugPrint("Error loading from MasterSheet: $e");
      }

      // Method 3: Check employees collection
      try {
        QuerySnapshot employeesSnapshot = await _firestore
            .collection('employees')
            .where('hasOvertimeApprovalAccess', isEqualTo: true)
            .get();

        for (var doc in employeesSnapshot.docs) {
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
        debugPrint("Found ${employeesSnapshot.docs.length} employee approvers");
      } catch (e) {
        debugPrint("Error loading from employees: $e");
      }

      // Method 4: Check line_managers
      try {
        QuerySnapshot managersSnapshot = await _firestore
            .collection('line_managers')
            .where('canApproveOvertime', isEqualTo: true)
            .get();

        for (var doc in managersSnapshot.docs) {
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
        debugPrint("Found ${managersSnapshot.docs.length} line manager approvers");
      } catch (e) {
        debugPrint("Error loading from line_managers: $e");
      }

      // Sort by priority and name
      approvers.sort((a, b) {
        int priorityCompare = a['priority'].compareTo(b['priority']);
        if (priorityCompare != 0) return priorityCompare;
        return a['name'].compareTo(b['name']);
      });

      debugPrint("✅ Total unique approvers found: ${approvers.length}");

      // Add fallback if no approvers found
      if (approvers.isEmpty) {
        debugPrint("⚠️ No approvers found! Adding fallback EMP1289");
        approvers.add({
          'id': 'EMP1289',
          'name': 'Default Approver',
          'designation': 'System Approver',
          'department': 'Administration',
          'source': 'fallback',
          'priority': 999,
        });
      }

      return approvers;

    } catch (e) {
      debugPrint("❌ Error fetching available approvers: $e");
      // Return fallback approver
      return [{
        'id': 'EMP1289',
        'name': 'Default Approver',
        'designation': 'System Approver',
        'department': 'Administration',
        'source': 'fallback',
        'priority': 999,
      }];
    }
  }

  // ✅ UPDATED: Create request with manually selected approver (no automatic detection)
  Future<String?> createOvertimeRequestWithSelectedApprover({
    required String projectName,
    required String projectCode,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> employeeIds,
    required String requesterId,
    required String requesterName,
    required String selectedApproverId, // ✅ NEW: Manually selected approver
    required String selectedApproverName, // ✅ NEW: Manually selected approver name
    // Multi-project support
    List<OvertimeProjectEntry>? projects,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint("=== CREATING OVERTIME REQUEST WITH SELECTED APPROVER ===");
      debugPrint("Requester: $requesterName ($requesterId)");
      debugPrint("Selected Approver: $selectedApproverName ($selectedApproverId)");
      debugPrint("Project: $projectName");
      debugPrint("Employees: ${employeeIds.length}");

      // ✅ ENHANCED: Handle multi-project or single project
      List<OvertimeProjectEntry> projectList = projects ?? [
        OvertimeProjectEntry(
          projectName: projectName,
          projectCode: projectCode,
          startTime: startTime,
          endTime: endTime,
          employeeIds: employeeIds,
        )
      ];

      // Calculate totals
      int totalProjects = projectList.length;
      int totalEmployees = employeeIds.length;
      double totalHours = projectList.fold(0.0, (sum, p) => sum + p.durationInHours);

      // Create the enhanced overtime request
      final requestData = {
        // Multi-project structure
        'projects': projectList.map((p) => p.toMap()).toList(),

        // Basic fields
        'projectName': totalProjects == 1 ? projectName : "$totalProjects Projects",
        'projectCode': totalProjects == 1 ? projectCode : 'MULTI',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'employeeIds': employeeIds,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'approverEmpId': selectedApproverId, // ✅ Use selected approver
        'approverName': selectedApproverName, // ✅ Use selected approver
        'requestTime': FieldValue.serverTimestamp(),
        'status': 'pending',

        // Enhanced tracking fields
        'totalProjects': totalProjects,
        'totalEmployees': totalEmployees,
        'totalHours': totalHours,
        'isActive': true,
        'version': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Additional metadata
        'metadata': metadata ?? {},
        'approverSelectionSource': 'manual_ui_selection', // ✅ Track how approver was selected
      };

      // Save to Firestore
      DocumentReference docRef = await _firestore
          .collection('overtime_requests')
          .add(requestData);

      debugPrint("Enhanced overtime request created with ID: ${docRef.id}");

      // ✅ Send notifications to selected approver
      await _sendOvertimeNotifications(
        requestId: docRef.id,
        approverId: selectedApproverId,
        approverName: selectedApproverName,
        requesterId: requesterId,
        requesterName: requesterName,
        projectName: requestData['projectName'] as String,
        projectCode: requestData['projectCode'] as String,
        employeeCount: employeeIds.length,
        totalProjects: totalProjects,
        totalHours: totalHours,
      );

      return docRef.id;

    } catch (e) {
      debugPrint("Error creating overtime request: $e");
      rethrow;
    }
  }

  // ✅ DEPRECATED: Keep for backward compatibility, but use manual selection instead
  @Deprecated("Use createOvertimeRequestWithSelectedApprover instead")
  Future<String?> createOvertimeRequest({
    required String projectName,
    required String projectCode,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> employeeIds,
    required String requesterId,
    required String requesterName,
    List<OvertimeProjectEntry>? projects,
    Map<String, dynamic>? metadata,
  }) async {
    // Get first available approver as fallback
    final approvers = await getAvailableApprovers();
    if (approvers.isEmpty) {
      throw Exception("No overtime approvers available");
    }

    final fallbackApprover = approvers.first;

    return createOvertimeRequestWithSelectedApprover(
      projectName: projectName,
      projectCode: projectCode,
      startTime: startTime,
      endTime: endTime,
      employeeIds: employeeIds,
      requesterId: requesterId,
      requesterName: requesterName,
      selectedApproverId: fallbackApprover['id'],
      selectedApproverName: fallbackApprover['name'],
      projects: projects,
      metadata: metadata,
    );
  }

  // ✅ Keep this method but mark as deprecated (was used for automatic detection)
  @Deprecated("Approver selection is now done manually in UI")
  Future<Map<String, dynamic>?> getOvertimeApprover() async {
    final approvers = await getAvailableApprovers();
    if (approvers.isEmpty) return null;

    return {
      'approverId': approvers.first['id'],
      'approverName': approvers.first['name'],
      'source': 'deprecated_auto_selection'
    };
  }

  // ✅ Get requests created by a specific requester (for history)
  Future<List<OvertimeRequest>> getRequestsForRequester(String requesterId) async {
    try {
      debugPrint("Getting request history for requester: $requesterId");

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        QuerySnapshot snapshot = await _firestore
            .collection('overtime_requests')
            .where('requesterId', isEqualTo: requesterId)
            .orderBy('requestTime', descending: true)
            .limit(50)
            .get();

        List<OvertimeRequest> requests = [];
        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            requests.add(_mapToOvertimeRequest(doc.id, data));
          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
          }
        }

        debugPrint("Found ${requests.length} requests for requester $requesterId");
        return requests;
      } else {
        // Offline mode - get from local database
        debugPrint("Fetching requester history from local database");
        final db = await _dbHelper.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'overtime_requests',
          where: 'requester_id = ?',
          whereArgs: [requesterId],
          orderBy: 'request_time DESC',
          limit: 50,
        );

        return maps.map<OvertimeRequest>((map) => _mapLocalToOvertimeRequest(map)).toList();
      }
    } catch (e) {
      debugPrint("Error getting requester history: $e");
      return [];
    }
  }

  // ✅ Get requests by status with pagination
  Future<List<OvertimeRequest>> getRequestsByStatus(
      OvertimeRequestStatus status, {
        int? limit,
        DocumentSnapshot? startAfter,
      }) async {
    try {
      Query query = _firestore
          .collection('overtime_requests')
          .where('status', isEqualTo: status.value)
          .orderBy('requestTime', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      QuerySnapshot snapshot = await query.get();

      List<OvertimeRequest> requests = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          requests.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing request ${doc.id}: $e");
        }
      }

      return requests;
    } catch (e) {
      debugPrint("Error getting requests by status: $e");
      return [];
    }
  }

  // ✅ Get pending requests for approver
  Future<List<OvertimeRequest>> getPendingRequestsForApprover(String approverId) async {
    try {
      debugPrint("=== FETCHING PENDING REQUESTS FOR APPROVER ===");
      debugPrint("Approver ID: $approverId");

      List<OvertimeRequest> requests = [];

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        // Try exact match first
        QuerySnapshot exactSnapshot = await _firestore
            .collection('overtime_requests')
            .where('status', isEqualTo: 'pending')
            .where('approverEmpId', isEqualTo: approverId)
            .orderBy('requestTime', descending: true)
            .get();

        debugPrint("Exact match found ${exactSnapshot.docs.length} requests");

        // Try alternative ID format if no exact match
        if (exactSnapshot.docs.isEmpty) {
          String altId = approverId.startsWith('EMP')
              ? approverId.substring(3)
              : 'EMP$approverId';

          QuerySnapshot altSnapshot = await _firestore
              .collection('overtime_requests')
              .where('status', isEqualTo: 'pending')
              .where('approverEmpId', isEqualTo: altId)
              .orderBy('requestTime', descending: true)
              .get();

          debugPrint("Alternative ID ($altId) found ${altSnapshot.docs.length} requests");
          exactSnapshot = altSnapshot;
        }

        // Parse documents safely
        for (var doc in exactSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint("Processing request ${doc.id}: approverEmpId = ${data['approverEmpId']}");

            OvertimeRequest request = _mapToOvertimeRequest(doc.id, data);
            requests.add(request);

          } catch (e) {
            debugPrint("Error parsing request ${doc.id}: $e");
            continue;
          }
        }

        // Cache successful requests
        for (var request in requests) {
          await _cacheOvertimeRequest(request);
        }

        debugPrint("Successfully loaded ${requests.length} requests from Firestore");
        return requests;

      } else {
        // Offline mode - get from local database
        debugPrint("Fetching pending requests from local database");
        final db = await _dbHelper.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'overtime_requests',
          where: 'status = ? AND (approver_emp_id = ? OR approver_emp_id = ?)',
          whereArgs: [
            'pending',
            approverId,
            approverId.startsWith('EMP') ? approverId.substring(3) : 'EMP$approverId'
          ],
          orderBy: 'request_time DESC',
        );

        debugPrint("Found ${maps.length} pending requests locally");
        return maps.map<OvertimeRequest>((map) => _mapLocalToOvertimeRequest(map)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching pending requests: $e");
      return [];
    }
  }

  // ✅ Update request status
  Future<bool> updateRequestStatus(
      String requestId,
      OvertimeRequestStatus status,
      String? responseMessage,
      ) async {
    try {
      debugPrint("Updating request $requestId to status: ${status.displayName}");

      // Get the request first to gather details for notifications
      DocumentSnapshot requestDoc = await _firestore
          .collection('overtime_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        debugPrint("Request not found: $requestId");
        return false;
      }

      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;

      // Update the request status
      await _firestore.collection('overtime_requests').doc(requestId).update({
        'status': status.value,
        'responseMessage': responseMessage,
        'responseTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      // Send status update notification
      try {
        await _sendStatusUpdateNotification(
          requestId: requestId,
          requestData: requestData,
          newStatus: status,
          responseMessage: responseMessage,
        );
      } catch (notificationError) {
        debugPrint("Error sending status update notification: $notificationError");
      }

      debugPrint("Request status updated successfully");
      return true;
    } catch (e) {
      debugPrint("Error updating request status: $e");
      return false;
    }
  }

  // ✅ Get active overtime assignments for an employee
  Future<List<OvertimeRequest>> getActiveOvertimeForEmployee(String employeeId) async {
    try {
      debugPrint("=== GETTING ACTIVE OVERTIME FOR EMPLOYEE: $employeeId ===");

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime tomorrow = today.add(Duration(days: 1));

      // Get approved overtime requests for today where this employee is included
      QuerySnapshot snapshot = await _firestore
          .collection('overtime_requests')
          .where('status', isEqualTo: 'approved')
          .where('employeeIds', arrayContains: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('startTime', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      List<OvertimeRequest> activeOvertime = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          OvertimeRequest request = _mapToOvertimeRequest(doc.id, data);

          // Check if overtime is currently active (between start and end time)
          if (now.isAfter(request.startTime) && now.isBefore(request.endTime)) {
            activeOvertime.add(request);
          }
        } catch (e) {
          debugPrint("Error parsing active overtime ${doc.id}: $e");
        }
      }

      debugPrint("Found ${activeOvertime.length} active overtime assignments");
      return activeOvertime;
    } catch (e) {
      debugPrint("Error getting active overtime: $e");
      return [];
    }
  }

  // ✅ Get today's overtime schedule for an employee
  Future<List<OvertimeRequest>> getTodayOvertimeForEmployee(String employeeId) async {
    try {
      debugPrint("Getting today's overtime schedule for: $employeeId");

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime tomorrow = today.add(Duration(days: 1));

      QuerySnapshot snapshot = await _firestore
          .collection('overtime_requests')
          .where('status', isEqualTo: 'approved')
          .where('employeeIds', arrayContains: employeeId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('startTime', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      List<OvertimeRequest> todayOvertime = [];
      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          todayOvertime.add(_mapToOvertimeRequest(doc.id, data));
        } catch (e) {
          debugPrint("Error parsing today's overtime ${doc.id}: $e");
        }
      }

      debugPrint("Found ${todayOvertime.length} overtime assignments for today");
      return todayOvertime;
    } catch (e) {
      debugPrint("Error getting today's overtime: $e");
      return [];
    }
  }

  // ✅ Map Firestore data to OvertimeRequest object
  OvertimeRequest _mapToOvertimeRequest(String id, Map<String, dynamic> data) {
    // Handle projects (new multi-project format or legacy single project)
    List<OvertimeProjectEntry> projects = [];

    if (data['projects'] != null && data['projects'] is List) {
      // New multi-project format
      for (var projectData in data['projects']) {
        projects.add(OvertimeProjectEntry.fromMap(projectData));
      }
    } else {
      // Legacy single project format
      projects.add(OvertimeProjectEntry(
        projectName: data['projectName'] ?? '',
        projectCode: data['projectCode'] ?? '',
        startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        employeeIds: List<String>.from(data['employeeIds'] ?? []),
      ));
    }

    return OvertimeRequest(
      id: id,
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
      totalDurationHours: (data['totalHours'] ?? 0).toDouble(),
      projects: projects,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      version: data['version'] ?? 1,
      isActive: data['isActive'] ?? true,
      metadata: data['metadata'],
    );
  }

  // ✅ Map local database data to OvertimeRequest object
  OvertimeRequest _mapLocalToOvertimeRequest(Map<String, dynamic> map) {
    return OvertimeRequest(
      id: map['id'] ?? '',
      requesterId: map['requester_id'] ?? '',
      requesterName: map['requester_name'] ?? '',
      approverEmpId: map['approver_emp_id'] ?? '',
      approverName: map['approver_name'] ?? '',
      projectName: map['project_name'] ?? '',
      projectCode: map['project_code'] ?? '',
      startTime: DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['end_time'] ?? DateTime.now().toIso8601String()),
      employeeIds: (map['employee_ids'] as String?)?.split(',') ?? [],
      requestTime: DateTime.parse(map['request_time'] ?? DateTime.now().toIso8601String()),
      status: _parseStatus(map['status']),
      responseMessage: map['response_message'],
      responseTime: map['response_time'] != null ? DateTime.parse(map['response_time']) : null,
      totalProjects: map['total_projects'] ?? 1,
      totalEmployeeCount: map['total_employees'] ?? 0,
      totalDurationHours: (map['total_hours'] ?? 0).toDouble(),
      projects: [
        OvertimeProjectEntry(
          projectName: map['project_name'] ?? '',
          projectCode: map['project_code'] ?? '',
          startTime: DateTime.parse(map['start_time'] ?? DateTime.now().toIso8601String()),
          endTime: DateTime.parse(map['end_time'] ?? DateTime.now().toIso8601String()),
          employeeIds: (map['employee_ids'] as String?)?.split(',') ?? [],
        )
      ],
    );
  }

  // ✅ Helper method to parse status string to enum
  OvertimeRequestStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
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

  // ✅ Cache overtime request
  Future<void> _cacheOvertimeRequest(OvertimeRequest request) async {
    try {
      final requestMap = {
        'id': request.id,
        'projectName': request.projectName,
        'projectCode': request.projectCode,
        'startTime': request.startTime.toIso8601String(),
        'endTime': request.endTime.toIso8601String(),
        'employeeIds': request.employeeIds,
        'requesterId': request.requesterId,
        'requesterName': request.requesterName,
        'approverEmpId': request.approverEmpId,
        'approverName': request.approverName,
        'requestTime': request.requestTime.toIso8601String(),
        'status': request.status.value,
        'responseMessage': request.responseMessage,
        'responseTime': request.responseTime?.toIso8601String(),
        'totalProjects': request.totalProjects,
        'totalEmployees': request.totalEmployeeCount,
        'totalHours': request.totalDurationHours,
      };

      final prefs = await SharedPreferences.getInstance();
      final cachedRequests = prefs.getStringList('cached_overtime_requests') ?? [];
      cachedRequests.add(jsonEncode(requestMap));
      await prefs.setStringList('cached_overtime_requests', cachedRequests);
      debugPrint("Cached overtime request: ${request.id}");
    } catch (e) {
      debugPrint("Error caching overtime request: $e");
    }
  }

  // ✅ Send overtime notifications
  Future<void> _sendOvertimeNotifications({
    required String requestId,
    required String approverId,
    required String approverName,
    required String requesterId,
    required String requesterName,
    required String projectName,
    required String projectCode,
    required int employeeCount,
    int totalProjects = 1,
    double totalHours = 0,
  }) async {
    try {
      debugPrint("=== SENDING ENHANCED OVERTIME NOTIFICATIONS ===");
      debugPrint("Approver: $approverName ($approverId)");
      debugPrint("Requester: $requesterName ($requesterId)");
      debugPrint("Projects: $totalProjects, Hours: $totalHours");

      // Enhanced notification messages
      String approverTitle = totalProjects > 1
          ? "New Multi-Project Overtime Request"
          : "New Overtime Request";

      String approverBody = totalProjects > 1
          ? "$requesterName requested overtime for $employeeCount employees across $totalProjects projects (${totalHours.toStringAsFixed(1)}h total)"
          : "$requesterName requested overtime for $employeeCount employees in $projectName";

      String requesterTitle = totalProjects > 1
          ? "✅ Multi-Project Overtime Request Submitted"
          : "✅ Overtime Request Submitted";

      String requesterBody = totalProjects > 1
          ? "Your $totalProjects projects overtime request for $employeeCount employees has been submitted to $approverName for approval."
          : "Your overtime request for $employeeCount employees has been submitted to $approverName for approval.";

      // 1. Send notification to the approver
      await _sendNotificationToUser(
        userId: approverId,
        title: approverTitle,
        body: approverBody,
        data: {
          'type': 'overtime_request',
          'requestId': requestId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'projectName': projectName,
          'projectCode': projectCode,
          'employeeCount': employeeCount.toString(),
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'approverId': approverId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      // 2. Send confirmation to the requester
      await _sendNotificationToUser(
        userId: requesterId,
        title: requesterTitle,
        body: requesterBody,
        data: {
          'type': 'overtime_request_submitted',
          'requestId': requestId,
          'projectName': projectName,
          'projectCode': projectCode,
          'employeeCount': employeeCount.toString(),
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'approverId': approverId,
          'approverName': approverName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint("Enhanced overtime notifications sent successfully");

    } catch (e) {
      debugPrint("Error sending overtime notifications: $e");
    }
  }

  // ✅ Send status update notification
  Future<void> _sendStatusUpdateNotification({
    required String requestId,
    required Map<String, dynamic> requestData,
    required OvertimeRequestStatus newStatus,
    String? responseMessage,
  }) async {
    try {
      String requesterId = requestData['requesterId'] ?? '';
      String projectName = requestData['projectName'] ?? '';
      int totalProjects = requestData['totalProjects'] ?? 1;
      double totalHours = (requestData['totalHours'] ?? 0).toDouble();
      List<String> employeeIds = List<String>.from(requestData['employeeIds'] ?? []);

      String title = totalProjects > 1
          ? (newStatus == OvertimeRequestStatus.approved
          ? "Multi-Project Overtime Approved!"
          : "Multi-Project Overtime Rejected")
          : (newStatus == OvertimeRequestStatus.approved
          ? "Overtime Request Approved!"
          : "Overtime Request Rejected");

      String body = totalProjects > 1
          ? (newStatus == OvertimeRequestStatus.approved
          ? "Your $totalProjects projects overtime request (${totalHours.toStringAsFixed(1)}h) has been approved."
          : "Your $totalProjects projects overtime request has been rejected.${responseMessage != null ? ' Message: $responseMessage' : ''}")
          : (newStatus == OvertimeRequestStatus.approved
          ? "Your overtime request for $projectName has been approved."
          : "Your overtime request for $projectName has been rejected.${responseMessage != null ? ' Message: $responseMessage' : ''}");

      await _sendNotificationToUser(
        userId: requesterId,
        title: title,
        body: body,
        data: {
          'type': 'overtime_request_update',
          'requestId': requestId,
          'projectName': projectName,
          'status': newStatus.value,
          'message': responseMessage ?? '',
          'totalProjects': totalProjects.toString(),
          'totalHours': totalHours.toString(),
          'isMultiProject': (totalProjects > 1).toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      // If approved, notify each selected employee
      if (newStatus == OvertimeRequestStatus.approved && employeeIds.isNotEmpty) {
        String employeeTitle = totalProjects > 1
            ? "You're Approved for Multi-Project Overtime!"
            : "You're Approved for Overtime!";

        String employeeBody = totalProjects > 1
            ? "You have been approved for overtime work across $totalProjects projects (${totalHours.toStringAsFixed(1)}h total)."
            : "You have been approved for overtime work in $projectName.";

        for (String employeeId in employeeIds) {
          try {
            await _sendNotificationToUser(
              userId: employeeId,
              title: employeeTitle,
              body: employeeBody,
              data: {
                'type': 'overtime_approved',
                'requestId': requestId,
                'projectName': projectName,
                'totalProjects': totalProjects.toString(),
                'totalHours': totalHours.toString(),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          } catch (e) {
            debugPrint("Error notifying employee $employeeId: $e");
          }
        }
      }

    } catch (e) {
      debugPrint("Error sending status update notification: $e");
    }
  }

  // ✅ Send notification to user (Direct FCM + Topic + Firestore)
  Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint("Sending notification to user: $userId");

      // Method 1: Direct FCM token lookup and send
      bool directSuccess = await _sendDirectFCMNotification(userId, title, body, data);

      // Method 2: Topic-based notification for redundancy
      await _sendTopicNotification(userId, title, body, data);

      // Method 3: Firestore notification document (for app to poll if needed)
      await _createFirestoreNotification(userId, title, body, data);

      debugPrint("Notification sent to $userId via multiple methods. Direct FCM: ${directSuccess ? 'Success' : 'Failed'}");

    } catch (e) {
      debugPrint("Error in _sendNotificationToUser for $userId: $e");
    }
  }

  // ✅ Direct FCM notification
  Future<bool> _sendDirectFCMNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      // Try multiple user ID formats
      List<String> userIdVariants = [
        userId,
        userId.startsWith('EMP') ? userId.substring(3) : 'EMP$userId',
      ];

      for (String id in userIdVariants) {
        try {
          DocumentSnapshot tokenDoc = await _firestore
              .collection('fcm_tokens')
              .doc(id)
              .get();

          if (tokenDoc.exists) {
            Map<String, dynamic> tokenData = tokenDoc.data() as Map<String, dynamic>;
            String? token = tokenData['token'];

            if (token != null && token.isNotEmpty) {
              debugPrint("Found FCM token for $id: ${token.substring(0, 15)}...");

              // Create the message payload for Cloud Messaging
              await _firestore.collection('fcm_messages').add({
                'token': token,
                'notification': {
                  'title': title,
                  'body': body,
                },
                'data': data,
                'android': {
                  'priority': 'high',
                  'notification': {
                    'sound': 'default',
                    'priority': 'high',
                    'channel_id': 'overtime_requests_channel',
                  }
                },
                'apns': {
                  'payload': {
                    'aps': {
                      'sound': 'default',
                      'badge': 1,
                      'content_available': true,
                      'interruption_level': 'time_sensitive',
                    }
                  }
                },
                'timestamp': FieldValue.serverTimestamp(),
                'processed': false,
                'targetUserId': id,
              });

              debugPrint("FCM message queued for $id");
              return true;
            }
          }
        } catch (e) {
          debugPrint("Error checking token for $id: $e");
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error in direct FCM notification: $e");
      return false;
    }
  }

  // ✅ Topic-based notification fallback
  Future<void> _sendTopicNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      // Subscribe the user to their topic if not already subscribed
      await _notificationService.subscribeToEmployeeTopic(userId);

      // Send to user-specific topics
      List<String> topics = [
        'employee_$userId',
        userId.startsWith('EMP') ? 'employee_${userId.substring(3)}' : 'employee_EMP$userId',
        'overtime_approver_$userId',
        'overtime_requests', // General overtime topic
      ];

      for (String topic in topics) {
        await _firestore.collection('topic_messages').add({
          'topic': topic,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
          'timestamp': FieldValue.serverTimestamp(),
          'processed': false,
          'targetUserId': userId,
        });
      }

      debugPrint("Topic notifications queued for $userId");
    } catch (e) {
      debugPrint("Error sending topic notification: $e");
    }
  }

  // ✅ Firestore notification document creation
  Future<void> _createFirestoreNotification(
      String userId,
      String title,
      String body,
      Map<String, dynamic> data,
      ) async {
    try {
      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'overtime_notification',
      });

      debugPrint("Firestore notification created for $userId");
    } catch (e) {
      debugPrint("Error creating Firestore notification: $e");
    }
  }
}



