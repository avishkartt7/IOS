// lib/services/leave_application_service.dart - STEP 4: FIXED BALANCE MANAGEMENT

import 'dart:io';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:face_auth_compatible/model/leave_application_model.dart';
import 'package:face_auth_compatible/model/leave_balance_model.dart';
import 'package:face_auth_compatible/repositories/leave_application_repository.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/simple_firebase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

class LeaveApplicationService {
  final LeaveApplicationRepository _repository;
  final ConnectivityService _connectivityService;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LeaveApplicationService({
    required LeaveApplicationRepository repository,
    required ConnectivityService connectivityService,
  }) : _repository = repository,
        _connectivityService = connectivityService;

  // Certificate upload with proper authentication
  Future<Map<String, String>?> uploadCertificate(
      File certificateFile,
      String employeeId,
      String applicationId,
      ) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        throw Exception('Cannot upload files while offline. Please connect to internet.');
      }

      debugPrint("📤 Starting certificate upload for employee: $employeeId");

      // Ensure authentication
      final isAuthenticated = await SimpleFirebaseAuthService.ensureAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication failed. Please check your internet connection and try again.');
      }

      // Validate file
      if (!await certificateFile.exists()) {
        throw Exception('Selected file does not exist');
      }

      final fileSize = await certificateFile.length();
      if (fileSize == 0) {
        throw Exception('Selected file is empty');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('File size too large. Maximum 10MB allowed.');
      }

      // Get file extension and validate
      final fileName = path.basename(certificateFile.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final allowedExtensions = ['.pdf', '.jpg', '.jpeg', '.png', '.doc', '.docx'];

      if (!allowedExtensions.contains(fileExtension)) {
        throw Exception('Invalid file type. Allowed: PDF, JPG, PNG, DOC, DOCX');
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_${employeeId}_$fileName';

      // Create storage reference
      final storageRef = _storage
          .ref()
          .child('leave_certificates')
          .child(employeeId)
          .child(applicationId)
          .child(uniqueFileName);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: _getMimeType(fileExtension),
        customMetadata: {
          'employeeId': employeeId,
          'applicationId': applicationId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': fileName,
          'uploaderUID': SimpleFirebaseAuthService.currentUser?.uid ?? 'anonymous',
        },
      );

      // Upload with timeout
      final uploadTask = storageRef.putFile(certificateFile, metadata);
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Upload timeout. Please check your internet connection and try again.');
        },
      );

      // Verify upload
      if (snapshot.state != TaskState.success) {
        throw Exception('Upload failed with state: ${snapshot.state}');
      }

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL');
      }

      final result = {
        'url': downloadUrl,
        'fileName': uniqueFileName,
        'originalFileName': fileName,
        'fileSize': fileSize.toString(),
        'uploadTimestamp': timestamp.toString(),
        'storagePath': storageRef.fullPath,
      };

      debugPrint("✅ Certificate uploaded successfully!");
      return result;

    } catch (e) {
      debugPrint("❌ Certificate upload error: $e");

      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        throw Exception('Network error during upload. Please check your internet connection and try again.');
      } else if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
        throw Exception('Permission denied. Please restart the app and try again.');
      } else if (e.toString().contains('quota') || e.toString().contains('storage')) {
        throw Exception('Storage limit reached. Please contact administrator.');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  /// Get MIME type based on file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Submit leave application with proper balance handling
  // Addition to lib/services/leave_application_service.dart - Certificate Reminder Methods

// Add this method to the LeaveApplicationService class

  /// Submit leave application with certificate reminder setup
  Future<String?> submitLeaveApplication({
    required String employeeId,
    required String employeeName,
    required String employeePin,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required bool isAlreadyTaken,
    File? certificateFile,
  }) async {
    try {
      debugPrint("🚀 SERVICE: Starting leave application submission for $employeeName");
      debugPrint("📋 Leave type: ${leaveType.displayName}");

      // Ensure authentication
      final isAuthenticated = await SimpleFirebaseAuthService.ensureAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication failed. Please check your internet connection and try again.');
      }

      // Validate inputs
      if (startDate.isAfter(endDate)) {
        throw Exception('Start date cannot be after end date');
      }

      // Check certificate requirement
      if (isCertificateRequired(leaveType, isAlreadyTaken) && certificateFile == null) {
        String requiredFor = '';
        if (leaveType == LeaveType.sick && isAlreadyTaken) {
          requiredFor = 'sick leave that was already taken (medical certificate required)';
        } else if (isAlreadyTaken) {
          requiredFor = 'already taken leave';
        }
        throw Exception('Certificate is required for $requiredFor');
      }

      // Calculate total days
      final totalDays = calculateTotalDays(startDate, endDate);
      if (totalDays <= 0) {
        throw Exception('Invalid date range');
      }

      // Get line manager information
      final lineManagerInfo = await _repository.getLineManagerInfo(employeePin);
      if (lineManagerInfo == null) {
        throw Exception('Line manager information not found. Please contact HR.');
      }

      // Validate balance before proceeding
      final leaveBalance = await _repository.getLeaveBalance(employeeId);
      if (leaveBalance != null) {
        if (leaveType == LeaveType.emergency) {
          final emergencyRemaining = leaveBalance.getRemainingDays('emergency');
          final annualRemaining = leaveBalance.getRemainingDays('annual');

          if (emergencyRemaining < totalDays && annualRemaining < totalDays) {
            throw Exception(
                'Insufficient balance for emergency leave. Emergency: $emergencyRemaining days, Annual: $annualRemaining days, Requested: $totalDays days'
            );
          }
        } else {
          if (!leaveBalance.hasEnoughBalance(leaveType.name, totalDays)) {
            final remainingDays = leaveBalance.getRemainingDays(leaveType.name);
            throw Exception('Insufficient leave balance. Available: $remainingDays days, Requested: $totalDays days');
          }
        }
      }

      // Generate application ID
      final applicationId = 'LA_${DateTime.now().millisecondsSinceEpoch}';

      // Upload certificate if provided
      String? certificateUrl;
      String? certificateFileName;

      if (certificateFile != null && leaveType != LeaveType.emergency) {
        debugPrint("📎 Uploading certificate...");

        try {
          final uploadResult = await uploadCertificate(
            certificateFile,
            employeeId,
            applicationId,
          );

          if (uploadResult != null) {
            certificateUrl = uploadResult['url'];
            certificateFileName = uploadResult['originalFileName'];
            debugPrint("✅ Certificate uploaded successfully");
          } else {
            throw Exception('Certificate upload returned null result');
          }
        } catch (uploadError) {
          throw Exception('Failed to upload certificate: $uploadError');
        }
      } else if (leaveType == LeaveType.emergency) {
        debugPrint("ℹ️ Emergency leave - skipping certificate upload");
      }

      // 🆕 NEW: Check if certificate reminder is needed
      bool requiresCertificateReminder = false;
      DateTime? certificateReminderDate;

      if (leaveType == LeaveType.sick && !isAlreadyTaken && certificateFile == null) {
        // For future sick leave without certificate, set up reminder
        requiresCertificateReminder = true;
        // Set reminder for the day after leave ends
        certificateReminderDate = endDate.add(const Duration(days: 1));

        debugPrint("📅 Certificate reminder set for: ${DateFormat('dd/MM/yyyy').format(certificateReminderDate)}");
      }

      // Create leave application with reminder fields
      final application = LeaveApplicationModel(
        id: applicationId,
        employeeId: employeeId,
        employeeName: employeeName,
        employeePin: employeePin,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        totalDays: totalDays,
        reason: reason.isEmpty ? 'No specific reason provided' : reason,
        isAlreadyTaken: isAlreadyTaken,
        certificateUrl: certificateUrl,
        certificateFileName: certificateFileName,
        applicationDate: DateTime.now(),
        lineManagerId: lineManagerInfo['lineManagerId']!,
        lineManagerName: lineManagerInfo['lineManagerName']!,
        status: LeaveStatus.pending,
        isActive: true,
        createdAt: DateTime.now(),
        // 🆕 NEW: Certificate reminder fields
        requiresCertificateReminder: requiresCertificateReminder,
        certificateReminderDate: certificateReminderDate,
        certificateReminderSent: false,
        certificateReminderCount: 0,
      );

      debugPrint("💾 Saving application to database...");

      // Submit the application
      final savedApplicationId = await _repository.submitLeaveApplication(application);

      if (savedApplicationId == null) {
        // Clean up uploaded file if database save failed
        if (certificateUrl != null) {
          try {
            await _storage.refFromURL(certificateUrl).delete();
            debugPrint("🧹 Cleaned up uploaded file due to database save failure");
          } catch (cleanupError) {
            debugPrint("⚠️ Failed to cleanup uploaded file: $cleanupError");
          }
        }
        throw Exception('Failed to save leave application to database');
      }

      // Update balance after successful application save
      debugPrint("🔄 Updating leave balance...");
      await _repository.updateLeaveBalanceForApplication(
        employeeId,
        leaveType,
        totalDays,
        action: 'apply',
      );

      // Send notification to line manager
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _sendLeaveApplicationNotification(application);
      }

      // 🆕 NEW: Schedule certificate reminder if needed
      if (requiresCertificateReminder && certificateReminderDate != null) {
        await _scheduleCertificateReminder(application);
      }

      debugPrint("🎉 Leave application submitted successfully: $savedApplicationId");
      return savedApplicationId;

    } catch (e) {
      debugPrint("❌ Error submitting leave application: $e");
      rethrow;
    }
  }

// 🆕 NEW: Schedule certificate reminder in Firebase
  Future<void> _scheduleCertificateReminder(LeaveApplicationModel application) async {
    try {
      debugPrint("🔔 Scheduling certificate reminder for ${application.employeeName}");

      await _firestore.collection('certificate_reminders').add({
        'applicationId': application.id,
        'employeeId': application.employeeId,
        'employeeName': application.employeeName,
        'employeePin': application.employeePin,
        'leaveType': application.leaveType.name,
        'startDate': Timestamp.fromDate(application.startDate),
        'endDate': Timestamp.fromDate(application.endDate),
        'reminderDate': Timestamp.fromDate(application.certificateReminderDate!),
        'reminderSent': false,
        'reminderCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'scheduled',
      });

      debugPrint("✅ Certificate reminder scheduled successfully");
    } catch (e) {
      debugPrint("❌ Error scheduling certificate reminder: $e");
    }
  }

// 🆕 NEW: Upload certificate after leave completion
  Future<bool> uploadCertificateAfterLeave({
    required String applicationId,
    required File certificateFile,
    required String employeeId,
  }) async {
    try {
      debugPrint("📎 Uploading post-leave certificate for application: $applicationId");

      // Upload certificate
      final uploadResult = await uploadCertificate(
        certificateFile,
        employeeId,
        applicationId,
      );

      if (uploadResult == null) {
        throw Exception('Certificate upload failed');
      }

      final certificateUrl = uploadResult['url'];
      final certificateFileName = uploadResult['originalFileName'];

      // Update application in local database
      await _repository.updateCertificateInfo(
        applicationId,
        certificateUrl!,
        certificateFileName!,
      );

      // Update in Firestore
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _firestore.collection('leave_applications').doc(applicationId).update({
          'certificateUrl': certificateUrl,
          'certificateFileName': certificateFileName,
          'certificateUploadedDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Mark reminder as completed
        await _markReminderAsCompleted(applicationId);
      }

      // Send confirmation notification
      await _sendCertificateUploadConfirmation(applicationId, employeeId);

      debugPrint("✅ Post-leave certificate uploaded successfully");
      return true;

    } catch (e) {
      debugPrint("❌ Error uploading post-leave certificate: $e");
      return false;
    }
  }

// 🆕 NEW: Mark certificate reminder as completed
  Future<void> _markReminderAsCompleted(String applicationId) async {
    try {
      final reminderQuery = await _firestore
          .collection('certificate_reminders')
          .where('applicationId', isEqualTo: applicationId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in reminderQuery.docs) {
        await doc.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'isActive': false,
        });
      }

      debugPrint("✅ Certificate reminder marked as completed");
    } catch (e) {
      debugPrint("❌ Error marking reminder as completed: $e");
    }
  }

// 🆕 NEW: Send certificate upload confirmation
  Future<void> _sendCertificateUploadConfirmation(String applicationId, String employeeId) async {
    try {
      await _firestore.collection('employee_notifications').add({
        'type': 'certificate_uploaded',
        'employeeId': employeeId,
        'applicationId': applicationId,
        'title': 'Certificate Uploaded Successfully',
        'message': 'Your medical certificate has been uploaded and submitted to HR.',
        'isRead': false,
        'priority': 'normal',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Certificate upload confirmation sent");
    } catch (e) {
      debugPrint("❌ Error sending upload confirmation: $e");
    }
  }

// 🆕 NEW: Get applications needing certificate upload
  Future<List<LeaveApplicationModel>> getApplicationsNeedingCertificate(String employeeId) async {
    try {
      final applications = await _repository.getLeaveApplicationsForEmployee(employeeId);

      return applications.where((app) =>
      app.leaveType == LeaveType.sick &&
          app.status == LeaveStatus.approved &&
          !app.isAlreadyTaken &&
          app.certificateUrl == null &&
          DateTime.now().isAfter(app.endDate)
      ).toList();

    } catch (e) {
      debugPrint("❌ Error getting applications needing certificate: $e");
      return [];
    }
  }

// 🆕 NEW: Check and send certificate reminders (call this daily)
  Future<void> checkAndSendCertificateReminders() async {
    try {
      debugPrint("🔔 Checking for certificate reminders...");

      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        debugPrint("📴 Offline - skipping reminder check");
        return;
      }

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      // Query reminders for today
      final reminderQuery = await _firestore
          .collection('certificate_reminders')
          .where('isActive', isEqualTo: true)
          .where('reminderSent', isEqualTo: false)
          .where('reminderDate', isLessThanOrEqualTo: Timestamp.fromDate(todayStart.add(const Duration(days: 1))))
          .get();

      debugPrint("📊 Found ${reminderQuery.docs.length} reminders to process");

      for (final reminderDoc in reminderQuery.docs) {
        final reminderData = reminderDoc.data();
        final applicationId = reminderData['applicationId'];
        final employeeId = reminderData['employeeId'];
        final employeeName = reminderData['employeeName'];

        try {
          // Send reminder notification
          await _sendCertificateReminderNotification(
            employeeId: employeeId,
            employeeName: employeeName,
            applicationId: applicationId,
            reminderCount: reminderData['reminderCount'] ?? 0,
          );

          // Update reminder document
          await reminderDoc.reference.update({
            'reminderSent': true,
            'reminderCount': FieldValue.increment(1),
            'lastReminderSent': FieldValue.serverTimestamp(),
          });

          debugPrint("✅ Reminder sent to $employeeName for application $applicationId");

        } catch (e) {
          debugPrint("❌ Error sending reminder for $applicationId: $e");
        }
      }

      debugPrint("🎉 Certificate reminder check completed");

    } catch (e) {
      debugPrint("❌ Error checking certificate reminders: $e");
    }
  }

// 🆕 NEW: Send certificate reminder notification
  Future<void> _sendCertificateReminderNotification({
    required String employeeId,
    required String employeeName,
    required String applicationId,
    required int reminderCount,
  }) async {
    try {
      final title = reminderCount == 0
          ? 'Medical Certificate Required'
          : 'Reminder: Medical Certificate Required';

      final body = reminderCount == 0
          ? 'Please upload your medical certificate for your completed sick leave.'
          : 'This is reminder #${reminderCount + 1}: Please upload your medical certificate for your completed sick leave.';

      // Send to employee notifications collection
      await _firestore.collection('employee_notifications').add({
        'type': 'certificate_reminder',
        'employeeId': employeeId,
        'employeeName': employeeName,
        'applicationId': applicationId,
        'title': title,
        'message': body,
        'reminderCount': reminderCount + 1,
        'isRead': false,
        'priority': reminderCount >= 2 ? 'high' : 'normal',
        'timestamp': FieldValue.serverTimestamp(),
        'actionRequired': true,
        'actionType': 'upload_certificate',
      });

      // Also create FCM notification trigger
      await _firestore.collection('notification_triggers').add({
        'type': 'certificate_reminder',
        'targetUserId': employeeId,
        'title': title,
        'body': body,
        'data': {
          'type': 'certificate_reminder',
          'applicationId': applicationId,
          'reminderCount': (reminderCount + 1).toString(),
          'actionRequired': 'true',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("📨 Certificate reminder notification sent to $employeeName");

    } catch (e) {
      debugPrint("❌ Error sending certificate reminder notification: $e");
    }
  }

  /// Send notification to line manager with properly formatted data
  Future<void> _sendLeaveApplicationNotification(LeaveApplicationModel application) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        return;
      }

      debugPrint("📧 Sending notification to line manager: ${application.lineManagerId}");

      // Format dates properly for Firebase
      final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

      final notificationData = {
        'type': 'new_leave_application',
        'applicationId': application.id,
        'employeeId': application.employeeId,
        'employeeName': application.employeeName,
        'employeePin': application.employeePin,
        'leaveType': application.leaveType.name,
        'leaveTypeDisplay': application.leaveType.displayName,

        // Send formatted date strings
        'startDate': dateFormatter.format(application.startDate),
        'endDate': dateFormatter.format(application.endDate),
        'dateRange': '${dateFormatter.format(application.startDate)} - ${dateFormatter.format(application.endDate)}',

        'totalDays': application.totalDays,
        'reason': application.reason,
        'managerId': application.lineManagerId,
        'managerName': application.lineManagerName,
        'isAlreadyTaken': application.isAlreadyTaken,
        'applicationDate': Timestamp.fromDate(application.applicationDate),
        'status': application.status.name,

        // Certificate information
        'hasAttachment': application.certificateUrl != null,
        'hasCertificate': application.certificateUrl != null,
        'certificateUrl': application.certificateUrl,
        'certificateFileName': application.certificateFileName,
        'attachmentStatus': application.certificateUrl != null ? 'attached' : 'none',
        'attachmentInfo': application.certificateUrl != null
            ? 'Certificate attached: ${application.certificateFileName ?? "Unknown"}'
            : 'No certificate attached',

        'isEmergencyLeave': application.leaveType == LeaveType.emergency,
        'requiresDoubleDeduction': application.leaveType == LeaveType.emergency,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': application.leaveType == LeaveType.emergency ? 'high' : 'normal',

        // Enhanced display information
        'displaySummary': '${application.employeeName} - ${application.leaveType.displayName} - ${application.totalDays} days',
        'certificateRequired': isCertificateRequired(application.leaveType, application.isAlreadyTaken),
        'certificateUploaded': application.certificateUrl != null,
      };

      // Send to manager's notification queue
      await _firestore
          .collection('manager_notifications')
          .doc(application.lineManagerId)
          .collection('notifications')
          .add(notificationData);

      // Send to global HR dashboard notifications
      await _firestore.collection('hr_notifications').add({
        ...notificationData,
        'type': 'new_leave_application_hr',
        'message': application.leaveType == LeaveType.emergency
            ? '🚨 EMERGENCY: ${application.employeeName} submitted an emergency leave application'
            : '${application.employeeName} submitted a leave application',
        'category': 'leave_management',
        'requiresAction': true,
        'isUrgent': application.leaveType == LeaveType.emergency,
      });

      debugPrint("✅ Notifications sent successfully");

    } catch (e) {
      debugPrint("❌ Error sending notifications: $e");
    }
  }

  /// Approve leave application with proper balance handling
  Future<bool> approveLeaveApplication(
      String applicationId,
      String managerId, {
        String? comments,
      }) async {
    try {
      debugPrint("✅ SERVICE: Approving leave application: $applicationId");

      // Get the application details first
      final applications = await _repository.getLeaveApplicationsForEmployee('');
      final application = applications.firstWhere((app) => app.id == applicationId);

      debugPrint("📋 Application found: ${application.employeeName} - ${application.leaveType.displayName}");

      // Call cloud function for employee notification (if online)
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('updateLeaveApplicationStatus');
          final result = await callable.call({
            'applicationId': applicationId,
            'status': 'approved',
            'comments': comments,
            'reviewedBy': managerId,
          });

          debugPrint("☁️ Cloud function result: ${result.data}");
        } catch (cloudError) {
          debugPrint("❌ Cloud function failed: $cloudError");
        }
      }

      // Update application status (this will handle balance changes)
      final localSuccess = await _repository.updateApplicationStatus(
        applicationId,
        LeaveStatus.approved,
        comments: comments,
        reviewedBy: managerId,
      );

      if (localSuccess) {
        debugPrint("✅ Leave application approved successfully");

        // Send HR notification
        await _sendApprovalNotificationToHR(application, true, comments);

        // Force refresh employee data if possible
        await _forceRefreshEmployeeApplication(application.employeeId, applicationId);

        return true;
      } else {
        debugPrint("❌ Local update failed");
        return false;
      }

    } catch (e) {
      debugPrint("❌ Error approving leave application: $e");
      return false;
    }
  }

  /// Reject leave application with proper balance handling
  Future<bool> rejectLeaveApplication(
      String applicationId,
      String managerId, {
        String? comments,
      }) async {
    try {
      debugPrint("❌ SERVICE: Rejecting leave application: $applicationId");

      // Get the application details first
      final applications = await _repository.getLeaveApplicationsForEmployee('');
      final application = applications.firstWhere((app) => app.id == applicationId);

      debugPrint("📋 Application found: ${application.employeeName} - ${application.leaveType.displayName}");

      // Call cloud function for employee notification (if online)
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('updateLeaveApplicationStatus');
          final result = await callable.call({
            'applicationId': applicationId,
            'status': 'rejected',
            'comments': comments,
            'reviewedBy': managerId,
          });

          debugPrint("☁️ Cloud function result: ${result.data}");
        } catch (cloudError) {
          debugPrint("❌ Cloud function failed: $cloudError");
        }
      }

      // Update application status (this will handle balance restoration)
      final localSuccess = await _repository.updateApplicationStatus(
        applicationId,
        LeaveStatus.rejected,
        comments: comments,
        reviewedBy: managerId,
      );

      if (localSuccess) {
        debugPrint("✅ Leave application rejected successfully");

        // Send HR notification
        await _sendApprovalNotificationToHR(application, false, comments);

        // Force refresh employee data if possible
        await _forceRefreshEmployeeApplication(application.employeeId, applicationId);

        return true;
      } else {
        debugPrint("❌ Local update failed");
        return false;
      }

    } catch (e) {
      debugPrint("❌ Error rejecting leave application: $e");
      return false;
    }
  }

  /// Force refresh employee application data
  Future<void> _forceRefreshEmployeeApplication(String employeeId, String applicationId) async {
    try {
      debugPrint("🔄 Force refreshing employee application data...");

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final doc = await _firestore
            .collection('leave_applications')
            .doc(applicationId)
            .get();

        if (doc.exists) {
          final application = LeaveApplicationModel.fromFirestore(doc);
          await _repository.saveApplicationLocallyPublic(application.copyWith(isSynced: true));
          debugPrint("✅ Employee application data refreshed");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error refreshing employee data: $e");
    }
  }

  /// Send HR notification
  Future<void> _sendApprovalNotificationToHR(
      LeaveApplicationModel application,
      bool isApproved,
      String? comments,
      ) async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.offline) {
        debugPrint("📴 Offline - HR notification will be sent when online");
        return;
      }

      final action = isApproved ? 'approved' : 'rejected';
      final priority = isApproved ? 'normal' : 'high';
      final isEmergency = application.leaveType == LeaveType.emergency;

      debugPrint("📨 Sending HR notification: $action");

      await _firestore.collection('hr_live_notifications').add({
        'type': 'leave_$action',
        'action': action,
        'message': isEmergency
            ? '🚨 EMERGENCY LEAVE ${action.toUpperCase()}: ${application.lineManagerName} $action emergency leave application from ${application.employeeName}'
            : '${application.lineManagerName} $action leave application from ${application.employeeName}',

        // Application Details
        'applicationId': application.id,
        'employeeId': application.employeeId,
        'employeeName': application.employeeName,
        'employeePin': application.employeePin,

        // Leave Details
        'leaveType': application.leaveType.name,
        'leaveTypeDisplay': application.leaveType.displayName,
        'startDate': Timestamp.fromDate(application.startDate),
        'endDate': Timestamp.fromDate(application.endDate),
        'totalDays': application.totalDays,
        'reason': application.reason,
        'isAlreadyTaken': application.isAlreadyTaken,
        'dateRange': application.dateRange,

        // Manager Details
        'managerId': application.lineManagerId,
        'managerName': application.lineManagerName,

        // Decision Details
        'isApproved': isApproved,
        'comments': comments ?? '',
        'decisionTimestamp': FieldValue.serverTimestamp(),

        // Emergency Leave Flags
        'isEmergencyLeave': isEmergency,
        'hasDoubleDeduction': isEmergency,

        // Metadata
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': isEmergency ? 'urgent' : priority,
        'category': 'leave_management',
        'source': 'manager_app_decision',
        'month': DateTime.now().month,
        'year': DateTime.now().year,

        'notificationId': 'hr_${application.id}_${action}_${DateTime.now().millisecondsSinceEpoch}',
        'processed': false,
      });

      debugPrint("📊 HR live notification sent successfully");

    } catch (e) {
      debugPrint("❌ Error sending HR notification: $e");
    }
  }

  // Calculate business days between two dates (excluding weekends)
  int calculateBusinessDays(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 0;
    }

    int businessDays = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (current.weekday >= 1 && current.weekday <= 5) {
        businessDays++;
      }
      current = current.add(const Duration(days: 1));
    }

    return businessDays;
  }

  // Calculate total days between two dates (including weekends)
  int calculateTotalDays(DateTime startDate, DateTime endDate) {
    if (startDate.isAfter(endDate)) {
      return 0;
    }
    return endDate.difference(startDate).inDays + 1;
  }

  // Check if certificate is required for leave type
  bool isCertificateRequired(LeaveType leaveType, bool isAlreadyTaken) {
    // Emergency leave NEVER requires certificate
    if (leaveType == LeaveType.emergency) {
      return false;
    }

    // Sick leave: only required if already taken
    if (leaveType == LeaveType.sick && isAlreadyTaken) {
      return true;
    }

    // Other leave types: only required if already taken
    if (isAlreadyTaken && (leaveType == LeaveType.annual || leaveType == LeaveType.local)) {
      return true;
    }

    return false;
  }

  // Get leave applications for employee
  Future<List<LeaveApplicationModel>> getEmployeeLeaveApplications(
      String employeeId, {
        LeaveStatus? status,
        int limit = 20,
      }) async {
    return await _repository.getLeaveApplicationsForEmployee(
      employeeId,
      status: status,
      limit: limit,
    );
  }

  // Get pending applications for manager
  Future<List<LeaveApplicationModel>> getPendingApplicationsForManager(String managerId) async {
    return await _repository.getPendingApplicationsForManager(managerId);
  }

  // Get leave balance for employee
  Future<LeaveBalance?> getLeaveBalance(String employeeId, {int? year}) async {
    return await _repository.getLeaveBalance(employeeId, year: year);
  }

  // Validate leave dates
  bool validateLeaveDates(DateTime startDate, DateTime endDate) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);

    return !startDate.isAfter(endDate) && !startDateOnly.isBefore(todayOnly);
  }

  // Check if dates are in the past (for already taken leave)
  bool areDatesInPast(DateTime startDate, DateTime endDate) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    return endDateOnly.isBefore(todayOnly);
  }

  // Get leave statistics for employee
  Future<Map<String, dynamic>> getLeaveStatistics(String employeeId) async {
    try {
      final applications = await getEmployeeLeaveApplications(employeeId);
      final balance = await getLeaveBalance(employeeId);

      final stats = <String, dynamic>{
        'totalApplications': applications.length,
        'approvedApplications': applications.where((app) => app.status == LeaveStatus.approved).length,
        'pendingApplications': applications.where((app) => app.status == LeaveStatus.pending).length,
        'rejectedApplications': applications.where((app) => app.status == LeaveStatus.rejected).length,
        'emergencyApplications': applications.where((app) => app.leaveType == LeaveType.emergency).length,
        'totalDaysRequested': applications.fold<int>(0, (sum, app) => sum + app.totalDays),
        'totalDaysApproved': applications
            .where((app) => app.status == LeaveStatus.approved)
            .fold<int>(0, (sum, app) => sum + app.totalDays),
        'emergencyDaysUsed': applications
            .where((app) => app.leaveType == LeaveType.emergency && app.status == LeaveStatus.approved)
            .fold<int>(0, (sum, app) => sum + app.totalDays),
        'leaveBalance': balance?.getSummary(),
      };

      return stats;
    } catch (e) {
      debugPrint("❌ Error getting leave statistics: $e");
      return {};
    }
  }

  // Cancel leave application with proper balance restoration
  Future<bool> cancelLeaveApplication(String applicationId) async {
    try {
      debugPrint("🔄 SERVICE: Cancelling leave application: $applicationId");

      // The repository will handle the balance restoration
      return await _repository.cancelLeaveApplication(applicationId);
    } catch (e) {
      debugPrint("❌ Error cancelling leave application: $e");
      return false;
    }
  }

  // Sync pending operations when coming online
  Future<void> syncPendingOperations() async {
    try {
      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        await _repository.syncPendingApplications();
        debugPrint("✅ Leave applications synced successfully");
      }
    } catch (e) {
      debugPrint("❌ Error syncing leave applications: $e");
    }
  }

  // Force refresh application status
  Future<void> forceRefreshApplicationStatus(String applicationId, String employeeId) async {
    try {
      debugPrint("🔄 Force refreshing application status...");

      if (_connectivityService.currentStatus == ConnectionStatus.online) {
        final doc = await _firestore
            .collection('leave_applications')
            .doc(applicationId)
            .get();

        if (doc.exists) {
          final application = LeaveApplicationModel.fromFirestore(doc);
          await _repository.saveApplicationLocallyPublic(application.copyWith(isSynced: true));

          debugPrint("✅ Application status force refreshed");
          debugPrint("📊 New Status: ${application.status.displayName}");
          return;
        }
      }

      debugPrint("❌ Could not refresh - offline or not found");
    } catch (e) {
      debugPrint("❌ Error force refreshing: $e");
    }
  }
}



