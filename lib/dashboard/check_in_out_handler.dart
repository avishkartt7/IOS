// lib/dashboard/check_in_out_handler.dart - UPDATED WITH LOCATION EXEMPTIONS

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:face_auth/checkout_request/create_request_view.dart';
import 'package:face_auth/checkout_request/request_history_view.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/repositories/check_out_request_repository.dart';
import 'package:face_auth/repositories/location_exemption_repository.dart';
import 'package:face_auth/model/check_out_request_model.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class CheckInOutHandler {
  // ✅ ENHANCED: Method to handle check-in/check-out with location exemption support
  static Future<bool> handleOffLocationAction({
    required BuildContext context,
    required String employeeId,
    required String employeeName,
    required bool isWithinGeofence,
    required Position? currentPosition,
    required VoidCallback onRegularAction,
    required bool isCheckIn,
  }) async {
    debugPrint("CheckInOutHandler: Starting handleOffLocationAction - isCheckIn=$isCheckIn");
    debugPrint("Employee ID: $employeeId");

    // ✅ STEP 1: Check if employee has location exemption FIRST
    try {
      final exemptionRepository = getIt<LocationExemptionRepository>();
      bool hasExemption = await exemptionRepository.hasLocationExemption(employeeId);

      if (hasExemption) {
        debugPrint("🆓 Employee $employeeId has location exemption - bypassing geofence check");

        // Show exemption notification
        CustomSnackBar.successSnackBar(
            "🆓 Location exemption active - proceeding with ${isCheckIn ? 'check-in' : 'check-out'}"
        );

        // Proceed with regular action regardless of location
        onRegularAction();
        return true;
      } else {
        debugPrint("❌ Employee $employeeId has NO location exemption - checking geofence");
      }
    } catch (e) {
      debugPrint("❌ Error checking location exemption: $e");
      // Continue with normal flow if exemption check fails
    }

    // ✅ STEP 2: If within geofence, proceed with normal action
    if (isWithinGeofence) {
      debugPrint("CheckInOutHandler: Within geofence, proceeding with regular action");
      onRegularAction();
      return true;
    }

    debugPrint("CheckInOutHandler: Outside geofence AND no exemption - handling as ${isCheckIn ? 'check-in' : 'check-out'} request");

    // ✅ STEP 3: Show location restriction dialog with exemption option
    return await _showLocationRestrictionDialog(
      context: context,
      employeeId: employeeId,
      employeeName: employeeName,
      currentPosition: currentPosition,
      isCheckIn: isCheckIn,
      onRegularAction: onRegularAction,
    );
  }

  // ✅ NEW: Show location restriction dialog with exemption request option
  static Future<bool> _showLocationRestrictionDialog({
    required BuildContext context,
    required String employeeId,
    required String employeeName,
    required Position? currentPosition,
    required bool isCheckIn,
    required VoidCallback onRegularAction,
  }) async {

    if (currentPosition == null) {
      CustomSnackBar.errorSnackBar("Unable to get your current location. Please try again.");
      return false;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_off, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location Required',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
              'You are currently outside the designated work location and do not have location exemption.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Options:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Move to designated work location\n'
                        '• Request manager approval for this location\n'
                        '• Contact HR for permanent location exemption',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              await _handleLocationRequest(
                context,
                employeeId,
                employeeName,
                currentPosition,
                isCheckIn,
              );
            },
            child: const Text(
              'Request Approval',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  // ✅ ENHANCED: Handle location-based requests (existing functionality)
  static Future<void> _handleLocationRequest(
      BuildContext context,
      String employeeId,
      String employeeName,
      Position currentPosition,
      bool isCheckIn,
      ) async {

    // Check if there's an approved request for today
    final repository = getIt<CheckOutRequestRepository>();
    final requests = await repository.getRequestsForEmployee(employeeId);

    debugPrint("CheckInOutHandler: Found ${requests.length} total requests for employee $employeeId");

    // Filter for today's approved requests of the specific type
    final today = DateTime.now();
    final String requestTypeToCheck = isCheckIn ? 'check-in' : 'check-out';

    final approvedRequests = requests.where((req) {
      bool isCorrectType = req.requestType == requestTypeToCheck;
      bool isApproved = req.status == CheckOutRequestStatus.approved;
      bool isSameDay = req.requestTime.year == today.year &&
          req.requestTime.month == today.month &&
          req.requestTime.day == today.day;

      bool isStillValid = true;
      if (req.responseTime != null) {
        final approvalTime = req.responseTime!;
        final validUntil = approvalTime.add(const Duration(hours: 1));
        isStillValid = today.isBefore(validUntil);
      }

      return isApproved && isCorrectType && isSameDay && isStillValid;
    }).toList();

    if (approvedRequests.isNotEmpty) {
      debugPrint("CheckInOutHandler: Found approved $requestTypeToCheck request");
      CustomSnackBar.successSnackBar("✅ You have approval to ${isCheckIn ? 'check in' : 'check out'} from this location");
      return;
    }

    // Check for pending requests
    final pendingRequests = requests.where((req) {
      bool isCorrectType = req.requestType == requestTypeToCheck;
      bool isPending = req.status == CheckOutRequestStatus.pending;
      bool isSameDay = req.requestTime.year == today.year &&
          req.requestTime.month == today.month &&
          req.requestTime.day == today.day;
      return isPending && isCorrectType && isSameDay;
    }).toList();

    if (pendingRequests.isNotEmpty) {
      final shouldCreateNew = await _showPendingRequestOptions(context, employeeId, isCheckIn);
      if (!shouldCreateNew) return;
    }

    // Create new request
    String? lineManagerId = await _getLineManagerId(employeeId);
    await _showCreateRequestForm(
      context,
      employeeId,
      employeeName,
      currentPosition,
      lineManagerId,
      isCheckIn,
    );
  }

  // Find line manager for the employee (existing method - no changes needed)
  static Future<String?> _getLineManagerId(String employeeId) async {
    try {
      debugPrint("Searching for line manager of employee: $employeeId");
      final prefs = await SharedPreferences.getInstance();
      String? cachedManagerId = prefs.getString('line_manager_id_$employeeId');

      if (cachedManagerId != null) {
        debugPrint("Found cached manager ID: $cachedManagerId");
        return cachedManagerId;
      }

      final employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .get();

      if (employeeDoc.exists) {
        Map<String, dynamic> data = employeeDoc.data() as Map<String, dynamic>;

        if (data.containsKey('lineManagerId') && data['lineManagerId'] != null) {
          String managerId = data['lineManagerId'];
          await prefs.setString('line_manager_id_$employeeId', managerId);
          debugPrint("Found manager ID in employee doc: $managerId");
          return managerId;
        }
      }

      debugPrint("Checking line_managers collection for employee: $employeeId");

      String employeePin = '';
      if (employeeDoc.exists) {
        Map<String, dynamic> data = employeeDoc.data() as Map<String, dynamic>;
        employeePin = data['pin'] ?? '';
      }

      final List<String> possibleEmployeeIds = [
        employeeId,
        employeeId.replaceFirst('EMP', ''),
        'EMP$employeeId',
        employeePin,
      ];

      final lineManagersSnapshot = await FirebaseFirestore.instance
          .collection('line_managers')
          .get();

      for (var doc in lineManagersSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        List<dynamic> teamMembers = data['teamMembers'] ?? [];

        for (String empId in possibleEmployeeIds) {
          if (teamMembers.contains(empId)) {
            String managerId = data['managerId'];
            await prefs.setString('line_manager_id_$employeeId', managerId);
            return managerId;
          }
        }
      }

      final managerQuery = await FirebaseFirestore.instance
          .collection('employees')
          .where('isManager', isEqualTo: true)
          .limit(1)
          .get();

      if (managerQuery.docs.isNotEmpty) {
        String fallbackManagerId = managerQuery.docs[0].id;
        await prefs.setString('line_manager_id_$employeeId', fallbackManagerId);
        return fallbackManagerId;
      }

      return "EMP1270"; // Default manager
    } catch (e) {
      debugPrint("Error looking up manager: $e");
      return "EMP1270";
    }
  }

  // Show pending request options (existing method - no changes needed)
  static Future<bool> _showPendingRequestOptions(
      BuildContext context,
      String employeeId,
      bool isCheckIn
      ) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pending ${isCheckIn ? 'Check-In' : 'Check-Out'} Request"),
        content: Text(
            "You already have a pending request to ${isCheckIn ? 'check in' : 'check out'} from your current location. "
                "Do you want to view the status of your request or create a new one?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckOutRequestHistoryView(
                    employeeId: employeeId,
                  ),
                ),
              );
            },
            child: const Text("View Requests"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Create New Request"),
          ),
        ],
      ),
    );

    return result == true;
  }

  // Show create request form (existing method - no changes needed)
  static Future<bool> _showCreateRequestForm(
      BuildContext context,
      String employeeId,
      String employeeName,
      Position currentPosition,
      String? lineManagerId,
      bool isCheckIn,
      ) async {
    debugPrint("Creating ${isCheckIn ? 'check-in' : 'check-out'} request form for $employeeId");

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CreateCheckOutRequestView(
            employeeId: employeeId,
            employeeName: employeeName,
            currentPosition: currentPosition,
            extra: {
              'lineManagerId': lineManagerId,
              'isCheckIn': isCheckIn,
            },
          ),
        ),
      );

      return result ?? false;
    } catch (e) {
      debugPrint("Error showing create request form: $e");
      return false;
    }
  }

  // ✅ NEW: Quick method to add test exemption for employee PIN 3576
  static Future<void> addTestExemption() async {
    try {
      debugPrint("🧪 Adding test location exemption for employee PIN 3576");

      // Add to Firestore manually
      await FirebaseFirestore.instance.collection('location_exemptions').add({
        'employeeId': 'EMP1244',
        'employeeName': 'Test Driver Employee',
        'employeePin': '1244',
        'reason': 'Driver - Mobile duty requires location flexibility',
        'grantedAt': DateTime.now().toIso8601String(),
        'grantedBy': 'System Admin',
        'isActive': true,
        'expiryDate': null, // No expiry
        'notes': 'Test exemption for development and testing purposes',
      });

      debugPrint("✅ Test exemption added successfully");
    } catch (e) {
      debugPrint("❌ Error adding test exemption: $e");
    }
  }

  // Existing methods (unchanged)
  static Future<bool> testCheckInRequest(
      BuildContext context,
      String employeeId,
      String employeeName,
      Position currentPosition,
      ) async {
    debugPrint("TEST: Creating a check-in request for testing");
    String? lineManagerId = await _getLineManagerId(employeeId);
    return await _showCreateRequestForm(
      context,
      employeeId,
      employeeName,
      currentPosition,
      lineManagerId,
      true,
    );
  }

  static Future<void> showRequestHistory(
      BuildContext context,
      String employeeId,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckOutRequestHistoryView(
          employeeId: employeeId,
        ),
      ),
    );
  }

  static Future<bool> createTestRequest(
      String employeeId,
      String employeeName,
      String lineManagerId,
      Position currentPosition,
      bool isCheckIn
      ) async {
    try {
      debugPrint("Creating TEST ${isCheckIn ? 'check-in' : 'check-out'} request");

      final repository = getIt<CheckOutRequestRepository>();

      CheckOutRequest request = CheckOutRequest.createNew(
        employeeId: employeeId,
        employeeName: employeeName,
        lineManagerId: lineManagerId,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        locationName: "Test Location (${currentPosition.latitude}, ${currentPosition.longitude})",
        reason: "This is a test request created for debugging",
        requestType: isCheckIn ? 'check-in' : 'check-out',
      );

      try {
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('check_out_requests')
            .add(request.toMap());
        debugPrint("Test request created successfully in Firestore: ${docRef.id}");
        return true;
      } catch (e) {
        debugPrint("Error saving test request to Firestore: $e");
        return await repository.createCheckOutRequest(request);
      }
    } catch (e) {
      debugPrint("Error creating test request: $e");
      return false;
    }
  }
}



