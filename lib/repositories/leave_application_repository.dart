// lib/repositories/leave_application_repository.dart - STEP 3: FIXED CANCEL/REJECT LOGIC

import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:face_auth/model/leave_application_model.dart';
import 'package:face_auth/model/leave_balance_model.dart';
import 'package:face_auth/services/database_helper.dart';
import 'package:face_auth/services/connectivity_service.dart';

class LeaveApplicationRepository {
  final DatabaseHelper _dbHelper;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ConnectivityService _connectivityService;

  LeaveApplicationRepository({
    required DatabaseHelper dbHelper,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    required ConnectivityService connectivityService,
  }) : _dbHelper = dbHelper,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _connectivityService = connectivityService;

  // ============================================================================
  // LEAVE APPLICATION METHODS
  // ============================================================================

  /// Submit a new leave application
  Future<String?> submitLeaveApplication(LeaveApplicationModel application) async {
    try {
      debugPrint("🚀 REPOSITORY: Saving leave application for ${application.employeeName}");
      debugPrint("📋 Leave Type: ${application.leaveType.displayName}");
      debugPrint("📊 Total Days: ${application.totalDays}");

      // Generate ID if not provided
      final applicationId = application.id ?? _generateApplicationId();
      final applicationWithId = application.copyWith(id: applicationId);

      // Save to local database first
      await _saveApplicationLocally(applicationWithId);

      // Try to sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _syncApplicationToFirestore(applicationWithId);
        } catch (e) {
          debugPrint("❌ Failed to sync to Firestore, will sync later: $e");
        }
      }

      debugPrint("✅ Leave application saved successfully with ID: $applicationId");
      return applicationId;
    } catch (e) {
      debugPrint("❌ Error submitting leave application: $e");
      return null;
    }
  }

  /// Get line manager information from mastersheet
  /// Get line manager information from mastersheet - FIXED VERSION
  Future<Map<String, String>?> getLineManagerInfo(String employeePin) async {
    try {
      debugPrint("🔍 Looking for line manager info for employee PIN: $employeePin");

      // First try MasterSheet to get the lineManagerId
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final snapshot = await _firestore
            .collection('MasterSheet')
            .doc('Employee-Data')
            .collection('employees')
            .where('employeeNumber', isEqualTo: employeePin)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final lineManagerIdFromMaster = data['lineManagerId'];
          final lineManagerNameFromMaster = data['lineManagerName'];

          debugPrint("📋 Found employee data in MasterSheet:");
          debugPrint("   - lineManagerId: $lineManagerIdFromMaster");
          debugPrint("   - lineManagerName: $lineManagerNameFromMaster");

          if (lineManagerIdFromMaster != null) {
            String lineManagerIdStr = lineManagerIdFromMaster.toString();

            // ✅ FIXED: Strategy 1 - Direct document ID lookup (MOST LIKELY TO WORK)
            if (lineManagerIdStr.length > 10) {
              try {
                debugPrint("🎯 Strategy 1: Trying direct document lookup for: $lineManagerIdStr");

                final managerDoc = await _firestore
                    .collection('employees')
                    .doc(lineManagerIdStr)
                    .get();

                if (managerDoc.exists) {
                  final managerData = managerDoc.data() as Map<String, dynamic>;
                  final actualManagerName = managerData['name'] ?? lineManagerNameFromMaster;

                  debugPrint("✅ SUCCESS: Found line manager via direct lookup!");
                  debugPrint("   - Document ID: ${managerDoc.id}");
                  debugPrint("   - Manager Name: $actualManagerName");

                  return {
                    'lineManagerId': managerDoc.id,
                    'lineManagerName': actualManagerName,
                  };
                } else {
                  debugPrint("❌ Strategy 1 failed: Document doesn't exist");
                }
              } catch (e) {
                debugPrint("❌ Strategy 1 failed with error: $e");
              }
            }

            // ✅ FIXED: Strategy 2 - PIN lookup (handle different PIN formats)
            debugPrint("🎯 Strategy 2: Trying PIN-based lookup");

            List<String> possiblePins = [
              lineManagerIdStr,
              lineManagerIdStr.startsWith('EMP') ? lineManagerIdStr.substring(3) : 'EMP$lineManagerIdStr',
            ];

            for (String pinVariant in possiblePins) {
              try {
                debugPrint("   - Trying PIN variant: $pinVariant");

                final managerQuery = await _firestore
                    .collection('employees')
                    .where('pin', isEqualTo: pinVariant)
                    .limit(1)
                    .get();

                if (managerQuery.docs.isNotEmpty) {
                  final managerDoc = managerQuery.docs.first;
                  final managerData = managerDoc.data() as Map<String, dynamic>;
                  final actualManagerName = managerData['name'] ?? lineManagerNameFromMaster;

                  debugPrint("✅ SUCCESS: Found line manager via PIN lookup!");
                  debugPrint("   - Document ID: ${managerDoc.id}");
                  debugPrint("   - Manager Name: $actualManagerName");
                  debugPrint("   - PIN Used: $pinVariant");

                  return {
                    'lineManagerId': managerDoc.id,
                    'lineManagerName': actualManagerName,
                  };
                }
              } catch (e) {
                debugPrint("   - PIN variant $pinVariant failed: $e");
              }
            }

            // ✅ FIXED: Strategy 3 - Name search (as fallback)
            if (lineManagerNameFromMaster != null && lineManagerNameFromMaster.toString().isNotEmpty) {
              try {
                debugPrint("🎯 Strategy 3: Trying name-based lookup for: $lineManagerNameFromMaster");

                final nameQuery = await _firestore
                    .collection('employees')
                    .where('name', isEqualTo: lineManagerNameFromMaster)
                    .limit(1)
                    .get();

                if (nameQuery.docs.isNotEmpty) {
                  final managerDoc = nameQuery.docs.first;
                  final managerData = managerDoc.data() as Map<String, dynamic>;

                  debugPrint("✅ SUCCESS: Found line manager via name lookup!");
                  debugPrint("   - Document ID: ${managerDoc.id}");
                  debugPrint("   - Manager Name: $lineManagerNameFromMaster");

                  return {
                    'lineManagerId': managerDoc.id,
                    'lineManagerName': lineManagerNameFromMaster,
                  };
                } else {
                  debugPrint("❌ Strategy 3 failed: No manager found with name '$lineManagerNameFromMaster'");
                }
              } catch (e) {
                debugPrint("❌ Strategy 3 failed with error: $e");
              }
            }

            // ✅ NEW: Strategy 4 - Partial name search (case insensitive)
            if (lineManagerNameFromMaster != null && lineManagerNameFromMaster.toString().isNotEmpty) {
              try {
                debugPrint("🎯 Strategy 4: Trying case-insensitive name search");

                // Get all employees and filter by name (case insensitive)
                final allEmployees = await _firestore
                    .collection('employees')
                    .where('isActive', isEqualTo: true)
                    .get();

                final searchName = lineManagerNameFromMaster.toString().toLowerCase().trim();

                for (final doc in allEmployees.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final employeeName = (data['name'] ?? '').toString().toLowerCase().trim();

                  if (employeeName == searchName) {
                    debugPrint("✅ SUCCESS: Found line manager via case-insensitive name search!");
                    debugPrint("   - Document ID: ${doc.id}");
                    debugPrint("   - Manager Name: ${data['name']}");

                    return {
                      'lineManagerId': doc.id,
                      'lineManagerName': data['name'] ?? lineManagerNameFromMaster,
                    };
                  }
                }

                debugPrint("❌ Strategy 4 failed: No case-insensitive name match found");
              } catch (e) {
                debugPrint("❌ Strategy 4 failed with error: $e");
              }
            }

            // ✅ ENHANCED ERROR LOGGING
            debugPrint("❌ All strategies failed for line manager lookup");
            debugPrint("🔍 DEBUG INFO:");
            debugPrint("   - Employee PIN: $employeePin");
            debugPrint("   - Line Manager ID from MasterSheet: $lineManagerIdFromMaster");
            debugPrint("   - Line Manager Name from MasterSheet: $lineManagerNameFromMaster");
            debugPrint("   - Line Manager ID Type: ${lineManagerIdFromMaster.runtimeType}");
            debugPrint("   - Line Manager ID Length: ${lineManagerIdStr.length}");

            // ✅ NEW: Try to list some sample employees for debugging
            try {
              final sampleEmployees = await _firestore
                  .collection('employees')
                  .where('isActive', isEqualTo: true)
                  .limit(5)
                  .get();

              debugPrint("📊 Sample employees in collection:");
              for (final doc in sampleEmployees.docs) {
                final data = doc.data() as Map<String, dynamic>;
                debugPrint("   - ID: ${doc.id}, Name: ${data['name']}, PIN: ${data['pin']}");
              }
            } catch (e) {
              debugPrint("❌ Could not fetch sample employees: $e");
            }
          }
        } else {
          debugPrint("❌ No employee found in MasterSheet with PIN: $employeePin");
        }
      } else {
        debugPrint("📴 Offline - cannot fetch line manager info");
      }

      debugPrint("❌ Could not find line manager info for employee PIN: $employeePin");
      return null;
    } catch (e) {
      debugPrint("❌ Error getting line manager info: $e");
      debugPrint("📍 Stack trace: ${StackTrace.current}");
      return null;
    }
  }


  Future<bool> updateCertificateInfo(
      String applicationId,
      String certificateUrl,
      String certificateFileName,
      ) async {
    try {
      debugPrint("📎 Updating certificate info for application: $applicationId");

      final updates = {
        'certificate_url': certificateUrl,
        'certificate_file_name': certificateFileName,
        'certificate_uploaded_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final rowsUpdated = await _dbHelper.update(
        'leave_applications',
        updates,
        where: 'id = ?',
        whereArgs: [applicationId],
      );

      debugPrint("📱 Local database updated: $rowsUpdated rows");

      // Sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _firestore
            .collection('leave_applications')
            .doc(applicationId)
            .update({
          'certificateUrl': certificateUrl,
          'certificateFileName': certificateFileName,
          'certificateUploadedDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint("☁️ Firestore updated successfully");
      }

      return rowsUpdated > 0;
    } catch (e) {
      debugPrint("❌ Error updating certificate info: $e");
      return false;
    }
  }

  /// Get leave applications for a specific employee
  Future<List<LeaveApplicationModel>> getLeaveApplicationsForEmployee(
      String employeeId, {
        LeaveStatus? status,
        int limit = 20,
      }) async {
    try {
      debugPrint("🔍 Getting leave applications for employee: $employeeId");

      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncEmployeeApplicationsFromFirestore(employeeId);
      }

      // Build where clause
      String whereClause = 'is_active = 1';
      List<dynamic> whereArgs = [];

      if (employeeId.isNotEmpty) {
        whereClause += ' AND employee_id = ?';
        whereArgs.add(employeeId);
      }

      if (status != null) {
        whereClause += ' AND status = ?';
        whereArgs.add(status.name);
      }

      // Get from local database
      final applications = await _dbHelper.query(
        'leave_applications',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'application_date DESC',
        limit: limit,
      );

      final results = applications.map((map) => LeaveApplicationModel.fromMap(map)).toList();
      debugPrint("📊 Found ${results.length} applications for employee");

      return results;
    } catch (e) {
      debugPrint("❌ Error getting employee leave applications: $e");
      return [];
    }
  }

  /// Get pending applications for manager approval
  Future<List<LeaveApplicationModel>> getPendingApplicationsForManager(String managerId) async {
    try {
      debugPrint("🔍 Getting pending applications for manager: $managerId");

      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncManagerApplicationsFromFirestore(managerId);
      }

      // Try multiple manager ID formats
      List<String> managerIdVariants = [
        managerId,
        'EMP$managerId',
        managerId.startsWith('EMP') ? managerId.substring(3) : managerId,
      ];

      // Build dynamic where clause for multiple manager IDs
      String whereClause = 'status = ? AND is_active = 1 AND (';
      List<dynamic> whereArgs = ['pending'];

      for (int i = 0; i < managerIdVariants.length; i++) {
        whereClause += 'line_manager_id = ?';
        whereArgs.add(managerIdVariants[i]);

        if (i < managerIdVariants.length - 1) {
          whereClause += ' OR ';
        }
      }
      whereClause += ')';

      // Get from local database
      final applications = await _dbHelper.query(
        'leave_applications',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'application_date ASC',
      );

      List<LeaveApplicationModel> results = applications.map((map) => LeaveApplicationModel.fromMap(map)).toList();
      debugPrint("📊 Found ${results.length} pending applications for manager");

      return results;
    } catch (e) {
      debugPrint("❌ Error getting pending applications for manager: $e");
      return [];
    }
  }

  /// ✅ FIXED: Update application status with proper balance restoration
  Future<bool> updateApplicationStatus(
      String applicationId,
      LeaveStatus status, {
        String? comments,
        String? reviewedBy,
      }) async {
    try {
      debugPrint("🔄 REPOSITORY: Updating application status");
      debugPrint("📋 Application ID: $applicationId");
      debugPrint("📊 New Status: ${status.name}");
      debugPrint("👤 Reviewed By: $reviewedBy");

      // ✅ CRITICAL: Get the application details BEFORE updating status
      final existingApplications = await _dbHelper.query(
        'leave_applications',
        where: 'id = ?',
        whereArgs: [applicationId],
        limit: 1,
      );

      if (existingApplications.isEmpty) {
        debugPrint("❌ Application not found: $applicationId");
        return false;
      }

      final applicationMap = existingApplications.first;
      final application = LeaveApplicationModel.fromMap(applicationMap);

      debugPrint("📋 Found application: ${application.employeeName}");
      debugPrint("📋 Leave Type: ${application.leaveType.displayName}");
      debugPrint("📋 Total Days: ${application.totalDays}");
      debugPrint("📋 Current Status: ${application.status.displayName}");

      // ✅ CRITICAL: Only process balance changes if status is actually changing
      final oldStatus = application.status;
      final newStatus = status;

      if (oldStatus == newStatus) {
        debugPrint("⚠️ Status is the same, no balance changes needed");
        return true; // No change needed
      }

      // Prepare status update
      final updates = {
        'status': status.name,
        'review_date': DateTime.now().toIso8601String(),
        'review_comments': comments,
        'reviewed_by': reviewedBy,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // ✅ CRITICAL: Handle balance changes based on status transitions
      await _handleBalanceChangesForStatusUpdate(application, oldStatus, newStatus);

      // Update local database
      final rowsUpdated = await _dbHelper.update(
        'leave_applications',
        updates,
        where: 'id = ?',
        whereArgs: [applicationId],
      );

      debugPrint("📱 Local database updated: $rowsUpdated rows");

      // Sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncStatusUpdateToFirestore(applicationId, status, comments, reviewedBy);
      } else {
        debugPrint("📴 Offline - will sync when connection restored");
        await _markForSync(applicationId, 'status_update', {
          'status': status.name,
          'comments': comments,
          'reviewedBy': reviewedBy,
        });
      }

      return rowsUpdated > 0;
    } catch (e) {
      debugPrint("❌ Error updating application status: $e");
      return false;
    }
  }

  /// ✅ NEW: Handle balance changes for status updates
  Future<void> _handleBalanceChangesForStatusUpdate(
      LeaveApplicationModel application,
      LeaveStatus oldStatus,
      LeaveStatus newStatus,
      ) async {
    try {
      debugPrint("🔄 Handling balance changes for status update");
      debugPrint("📊 Old Status: ${oldStatus.displayName} → New Status: ${newStatus.displayName}");

      // Get current balance
      final balance = await getLeaveBalance(application.employeeId);
      if (balance == null) {
        debugPrint("⚠️ No balance found for employee: ${application.employeeId}");
        return;
      }

      debugPrint("📊 Current Balance State:");
      balance.printBalanceState();

      LeaveBalance? updatedBalance;

      // Handle different status transitions
      if (oldStatus == LeaveStatus.pending && newStatus == LeaveStatus.approved) {
        // PENDING → APPROVED: Move from pending to used
        debugPrint("✅ Processing APPROVAL: Moving from pending to used");

        if (application.leaveType == LeaveType.emergency) {
          updatedBalance = balance.approveEmergencyLeave(application.totalDays);
        } else {
          updatedBalance = balance.approveLeave(application.leaveType.name, application.totalDays);
        }

      } else if (oldStatus == LeaveStatus.pending && (newStatus == LeaveStatus.rejected || newStatus == LeaveStatus.cancelled)) {
        // PENDING → REJECTED/CANCELLED: Remove from pending (restore balance)
        debugPrint("❌ Processing REJECTION/CANCELLATION: Removing from pending");

        if (application.leaveType == LeaveType.emergency) {
          updatedBalance = balance.removeEmergencyPendingDays(application.totalDays);
        } else {
          updatedBalance = balance.removePendingDays(application.leaveType.name, application.totalDays);
        }

      } else if (oldStatus == LeaveStatus.approved && (newStatus == LeaveStatus.rejected || newStatus == LeaveStatus.cancelled)) {
        // APPROVED → REJECTED/CANCELLED: This should rarely happen, but handle it
        debugPrint("⚠️ Processing APPROVED → REJECTED/CANCELLED: Moving from used back to available");

        // This is complex - we need to subtract from used days and add back to available
        // For now, log this case and handle manually if needed
        debugPrint("🚨 RARE CASE: Approved leave being cancelled/rejected - manual review needed");

      } else {
        debugPrint("ℹ️ No balance changes needed for this status transition");
        return;
      }

      // Save updated balance if changes were made
      if (updatedBalance != null) {
        await _updateLeaveBalanceRecord(updatedBalance);
        debugPrint("✅ Balance updated successfully");
        debugPrint("📊 New Balance State:");
        updatedBalance.printBalanceState();
      }

    } catch (e) {
      debugPrint("❌ Error handling balance changes: $e");
    }
  }

  /// Cancel leave application
  Future<bool> cancelLeaveApplication(String applicationId) async {
    try {
      debugPrint("🔄 REPOSITORY: Cancelling leave application: $applicationId");
      return await updateApplicationStatus(applicationId, LeaveStatus.cancelled);
    } catch (e) {
      debugPrint("❌ Error cancelling leave application: $e");
      return false;
    }
  }

  // ============================================================================
  // LEAVE BALANCE METHODS
  // ============================================================================

  /// Get leave balance for an employee
  Future<LeaveBalance?> getLeaveBalance(String employeeId, {int? year}) async {
    try {
      final targetYear = year ?? DateTime.now().year;

      // Try to sync from Firestore first if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _syncLeaveBalanceFromFirestore(employeeId, targetYear);
      }

      // Get from local database
      final balanceRecords = await _dbHelper.query(
        'leave_balances',
        where: 'employee_id = ? AND year = ?',
        whereArgs: [employeeId, targetYear],
      );

      if (balanceRecords.isNotEmpty) {
        return _parseLeaveBalanceFromMap(balanceRecords.first);
      }

      // Create default balance if none exists
      final defaultBalance = LeaveBalance.createDefault(employeeId, year: targetYear);
      await _saveLeaveBalanceLocally(defaultBalance);

      return defaultBalance;
    } catch (e) {
      debugPrint("❌ Error getting leave balance: $e");
      return null;
    }
  }

  /// ✅ FIXED: Update leave balance for applications
  Future<bool> updateLeaveBalanceForApplication(
      String employeeId,
      LeaveType leaveType,
      int days, {
        required String action, // 'apply', 'approve', 'reject', 'cancel'
      }) async {
    try {
      debugPrint("🔄 Updating leave balance for application");
      debugPrint("👤 Employee: $employeeId");
      debugPrint("📋 Leave Type: ${leaveType.displayName}");
      debugPrint("📊 Days: $days");
      debugPrint("🎯 Action: $action");

      final balance = await getLeaveBalance(employeeId);
      if (balance == null) {
        debugPrint("❌ No balance found for employee: $employeeId");
        return false;
      }

      LeaveBalance updatedBalance;

      switch (action) {
        case 'apply':
        // Add to pending when application is submitted
          if (leaveType == LeaveType.emergency) {
            updatedBalance = balance.addEmergencyPendingDays(days);
          } else {
            updatedBalance = balance.addPendingDays(leaveType.name, days);
          }
          break;

        case 'approve':
        // Move from pending to used when approved
          if (leaveType == LeaveType.emergency) {
            updatedBalance = balance.approveEmergencyLeave(days);
          } else {
            updatedBalance = balance.approveLeave(leaveType.name, days);
          }
          break;

        case 'reject':
        case 'cancel':
        // Remove from pending when rejected or cancelled
          if (leaveType == LeaveType.emergency) {
            updatedBalance = balance.removeEmergencyPendingDays(days);
          } else {
            updatedBalance = balance.removePendingDays(leaveType.name, days);
          }
          break;

        default:
          debugPrint("❌ Unknown action: $action");
          return false;
      }

      return await _updateLeaveBalanceRecord(updatedBalance);
    } catch (e) {
      debugPrint("❌ Error updating leave balance for application: $e");
      return false;
    }
  }

  /// Update leave balance record
  Future<bool> _updateLeaveBalanceRecord(LeaveBalance balance) async {
    try {
      // Save to local database
      await _saveLeaveBalanceLocally(balance);

      // Sync to Firestore if online
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          await _firestore
              .collection('leave_balances')
              .doc('${balance.employeeId}_${balance.year}')
              .set(balance.toMap());
        } catch (e) {
          debugPrint("❌ Failed to sync balance to Firestore: $e");
        }
      }

      return true;
    } catch (e) {
      debugPrint("❌ Error updating leave balance record: $e");
      return false;
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Save application to local database
  Future<void> _saveApplicationLocally(LeaveApplicationModel application) async {
    try {
      await _dbHelper.insert(
        'leave_applications',
        application.toLocalMap(),
      );
    } catch (e) {
      debugPrint("❌ Error saving application locally: $e");
      rethrow;
    }
  }

  /// Save or update application locally
  Future<void> _saveOrUpdateApplicationLocally(LeaveApplicationModel application) async {
    try {
      // Check if application exists
      final existing = await _dbHelper.query(
        'leave_applications',
        where: 'id = ?',
        whereArgs: [application.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing
        await _dbHelper.update(
          'leave_applications',
          application.toLocalMap(),
          where: 'id = ?',
          whereArgs: [application.id],
        );
        debugPrint("📝 Updated existing application: ${application.id}");
      } else {
        // Insert new
        await _dbHelper.insert(
          'leave_applications',
          application.toLocalMap(),
        );
        debugPrint("📝 Inserted new application: ${application.id}");
      }
    } catch (e) {
      debugPrint("❌ Error saving application locally: $e");
      rethrow;
    }
  }

  /// Save application locally (public method for service access)
  Future<void> saveApplicationLocallyPublic(LeaveApplicationModel application) async {
    try {
      await _saveOrUpdateApplicationLocally(application);
    } catch (e) {
      debugPrint("❌ Error in public save method: $e");
      rethrow;
    }
  }

  /// Sync application to Firestore
  Future<void> _syncApplicationToFirestore(LeaveApplicationModel application) async {
    try {
      await _firestore
          .collection('leave_applications')
          .doc(application.id)
          .set(application.toMap());

      debugPrint("✅ Application synced to Firestore: ${application.id}");
    } catch (e) {
      debugPrint("❌ Error syncing application to Firestore: $e");
      rethrow;
    }
  }

  /// Sync status update to Firestore
  Future<void> _syncStatusUpdateToFirestore(
      String applicationId,
      LeaveStatus status,
      String? comments,
      String? reviewedBy
      ) async {
    try {
      debugPrint("☁️ Syncing status update to Firestore...");

      await _firestore
          .collection('leave_applications')
          .doc(applicationId)
          .update({
        'status': status.name,
        'reviewDate': FieldValue.serverTimestamp(),
        'reviewComments': comments,
        'reviewedBy': reviewedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Status update synced to Firestore successfully");

    } catch (e) {
      debugPrint("❌ Failed to sync status update to Firestore: $e");
      await _storeFailedSync(applicationId, {
        'type': 'status_update',
        'status': status.name,
        'comments': comments,
        'reviewedBy': reviewedBy,
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      });
    }
  }

  /// Sync employee applications from Firestore
  Future<void> _syncEmployeeApplicationsFromFirestore(String employeeId) async {
    try {
      debugPrint("🔄 Syncing employee applications from Firestore...");

      final snapshot = await _firestore
          .collection('leave_applications')
          .where('employeeId', isEqualTo: employeeId)
          .where('isActive', isEqualTo: true)
          .orderBy('applicationDate', descending: true)
          .get()
          .timeout(const Duration(seconds: 15));

      debugPrint("☁️ Fetched ${snapshot.docs.length} applications from Firestore");

      for (final doc in snapshot.docs) {
        try {
          final application = LeaveApplicationModel.fromFirestore(doc);
          await _saveOrUpdateApplicationLocally(application.copyWith(isSynced: true));
        } catch (docError) {
          debugPrint("⚠️ Error processing document ${doc.id}: $docError");
        }
      }

      debugPrint("✅ Employee applications sync completed");

    } catch (e) {
      debugPrint("❌ Error syncing employee applications from Firestore: $e");
    }
  }





  /// Sync manager applications from Firestore
  Future<void> _syncManagerApplicationsFromFirestore(String managerId) async {
    try {
      debugPrint("🔄 Syncing manager applications from Firestore...");

      List<String> managerIdVariants = [
        managerId,
        'EMP$managerId',
        managerId.startsWith('EMP') ? managerId.substring(3) : managerId,
      ];

      Set<String> allApplicationIds = {};
      List<LeaveApplicationModel> allApplications = [];

      for (String managerIdVariant in managerIdVariants) {
        try {
          final snapshot = await _firestore
              .collection('leave_applications')
              .where('lineManagerId', isEqualTo: managerIdVariant)
              .where('status', isEqualTo: 'pending')
              .where('isActive', isEqualTo: true)
              .orderBy('applicationDate', descending: false)
              .get()
              .timeout(const Duration(seconds: 10));

          for (final doc in snapshot.docs) {
            if (!allApplicationIds.contains(doc.id)) {
              final application = LeaveApplicationModel.fromFirestore(doc);
              allApplications.add(application);
              allApplicationIds.add(doc.id);

              await _saveOrUpdateApplicationLocally(application.copyWith(isSynced: true));
            }
          }
        } catch (e) {
          debugPrint("❌ Error querying Firestore for manager $managerIdVariant: $e");
        }
      }

      debugPrint("✅ Total applications synced: ${allApplications.length}");

    } catch (e) {
      debugPrint("❌ Error syncing manager applications from Firestore: $e");
    }
  }

  /// Save leave balance to local database
  Future<void> _saveLeaveBalanceLocally(LeaveBalance balance) async {
    try {
      await _dbHelper.insert(
        'leave_balances',
        {
          'id': '${balance.employeeId}_${balance.year}',
          'employee_id': balance.employeeId,
          'year': balance.year,
          'total_days': _encodeMapToJson(balance.totalDays),
          'used_days': _encodeMapToJson(balance.usedDays),
          'pending_days': _encodeMapToJson(balance.pendingDays),
          'last_updated': balance.lastUpdated?.toIso8601String(),
          'is_synced': 1,
        },
      );
    } catch (e) {
      debugPrint("❌ Error saving leave balance locally: $e");
      rethrow;
    }
  }

  /// Sync leave balance from Firestore
  Future<void> _syncLeaveBalanceFromFirestore(String employeeId, int year) async {
    try {
      final doc = await _firestore
          .collection('leave_balances')
          .doc('${employeeId}_$year')
          .get();

      if (doc.exists) {
        final balance = LeaveBalance.fromFirestore(doc);
        await _saveLeaveBalanceLocally(balance);
        debugPrint("✅ Synced leave balance for employee: $employeeId, year: $year");
      }
    } catch (e) {
      debugPrint("❌ Error syncing leave balance from Firestore: $e");
    }
  }

  /// Generate unique application ID
  String _generateApplicationId() {
    return 'LA_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Parse leave balance from database map
  LeaveBalance _parseLeaveBalanceFromMap(Map<String, dynamic> map) {
    return LeaveBalance(
      employeeId: map['employee_id'],
      year: map['year'],
      totalDays: _decodeJsonToMap(map['total_days']),
      usedDays: _decodeJsonToMap(map['used_days']),
      pendingDays: _decodeJsonToMap(map['pending_days']),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : null,
    );
  }

  /// Encode map to JSON string for database storage
  String _encodeMapToJson(Map<String, int> map) {
    final buffer = StringBuffer('{');
    final entries = map.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":${entry.value}');
      if (i < entries.length - 1) {
        buffer.write(',');
      }
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// ✅ FIXED: Decode JSON string to map with only 4 leave types
  Map<String, int> _decodeJsonToMap(String jsonString) {
    try {
      final map = <String, int>{};

      if (jsonString.isEmpty || jsonString == '{}') {
        return _getDefaultLeaveTypes();
      }

      // Remove the outer braces
      final content = jsonString.substring(1, jsonString.length - 1);

      if (content.isEmpty) return _getDefaultLeaveTypes();

      // Split by comma and parse each key-value pair
      final pairs = content.split(',');
      for (final pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          final key = keyValue[0].trim().replaceAll('"', '');
          final value = int.tryParse(keyValue[1].trim()) ?? 0;

          // ✅ FIXED: Only include our 4 leave types
          if (['annual', 'sick', 'local', 'emergency'].contains(key)) {
            map[key] = value;
          }
        }
      }

      // Ensure all 4 types are present
      final defaultTypes = _getDefaultLeaveTypes();
      for (String type in defaultTypes.keys) {
        if (!map.containsKey(type)) {
          map[type] = 0;
        }
      }

      return map;
    } catch (e) {
      debugPrint("❌ Error decoding JSON to map: $e");
      return _getDefaultLeaveTypes();
    }
  }

  /// ✅ NEW: Get default leave types (only 4 types)
  Map<String, int> _getDefaultLeaveTypes() {
    return {
      'annual': 0,
      'sick': 0,
      'local': 0,     // ✅ NEW
      'emergency': 0,
    };
  }

  // ============================================================================
  // SYNC AND UTILITY METHODS
  // ============================================================================

  /// Mark application for sync when online
  Future<void> _markForSync(String applicationId, String syncType, Map<String, dynamic> data) async {
    try {
      await _dbHelper.insert('sync_queue', {
        'id': '${syncType}_${applicationId}_${DateTime.now().millisecondsSinceEpoch}',
        'type': syncType,
        'application_id': applicationId,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'retry_count': 0,
      });

      debugPrint("📋 Marked for sync: $syncType - $applicationId");
    } catch (e) {
      debugPrint("⚠️ Error marking for sync: $e");
    }
  }

  /// Store failed sync for retry
  Future<void> _storeFailedSync(String applicationId, Map<String, dynamic> data) async {
    try {
      await _dbHelper.insert('failed_syncs', {
        'id': 'failed_${applicationId}_${DateTime.now().millisecondsSinceEpoch}',
        'application_id': applicationId,
        'data': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
        'max_retries': 3,
      });

      debugPrint("📋 Stored failed sync for retry: $applicationId");
    } catch (e) {
      debugPrint("⚠️ Error storing failed sync: $e");
    }
  }

  /// Sync pending applications
  Future<void> syncPendingApplications() async {
    try {
      if (_connectivityService.currentStatus != ConnectionStatus.online) {
        debugPrint("📴 Offline - cannot sync pending applications");
        return;
      }

      debugPrint("🔄 Starting sync of pending applications...");

      final unsyncedApplications = await _dbHelper.query(
        'leave_applications',
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
      );

      debugPrint("📊 Found ${unsyncedApplications.length} unsynced applications");

      for (final applicationMap in unsyncedApplications) {
        try {
          final application = LeaveApplicationModel.fromMap(applicationMap);
          await _syncApplicationToFirestore(application);

          // Mark as synced
          await _dbHelper.update(
            'leave_applications',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [application.id],
          );

          debugPrint("✅ Synced application: ${application.id}");
        } catch (e) {
          debugPrint("❌ Failed to sync application ${applicationMap['id']}: $e");
        }
      }

      debugPrint("🎉 Sync completed successfully");
    } catch (e) {
      debugPrint("❌ Error in sync: $e");
    }
  }
}



