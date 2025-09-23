// lib/views/certificate_reminder_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:face_auth/model/leave_application_model.dart';
import 'package:face_auth/services/leave_application_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/repositories/leave_application_repository.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';

class CertificateReminderView extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const CertificateReminderView({
    Key? key,
    required this.employeeId,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<CertificateReminderView> createState() => _CertificateReminderViewState();
}

class _CertificateReminderViewState extends State<CertificateReminderView> {
  late LeaveApplicationService _leaveService;
  List<LeaveApplicationModel> _pendingApplications = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadPendingApplications();
  }

  void _initializeService() {
    final repository = getIt<LeaveApplicationRepository>();
    final connectivityService = getIt<ConnectivityService>();
    _leaveService = LeaveApplicationService(
      repository: repository,
      connectivityService: connectivityService,
    );
  }

  Future<void> _loadPendingApplications() async {
    try {
      setState(() => _isLoading = true);

      final applications = await _leaveService.getApplicationsNeedingCertificate(widget.employeeId);

      setState(() {
        _pendingApplications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading applications: $e");
    }
  }

  Future<void> _uploadCertificate(LeaveApplicationModel application) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      setState(() => _isUploading = true);

      final certificateFile = File(result.files.single.path!);

      final success = await _leaveService.uploadCertificateAfterLeave(
        applicationId: application.id!,
        certificateFile: certificateFile,
        employeeId: widget.employeeId,
      );

      if (success) {
        CustomSnackBar.successSnackBar("Certificate uploaded successfully!");
        await _loadPendingApplications(); // Refresh the list
      } else {
        CustomSnackBar.errorSnackBar("Failed to upload certificate");
      }

    } catch (e) {
      CustomSnackBar.errorSnackBar("Error uploading certificate: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Certificate Upload Required',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading applications...'),
          ],
        ),
      )
          : _pendingApplications.isEmpty
          ? _buildEmptyState()
          : _buildApplicationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Set!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No pending certificate uploads required',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medical certificates are required for the following completed sick leaves:',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pendingApplications.length,
            itemBuilder: (context, index) {
              final application = _pendingApplications[index];
              return _buildApplicationCard(application);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationCard(LeaveApplicationModel application) {
    final daysSinceLeave = DateTime.now().difference(application.endDate).inDays;
    final isOverdue = daysSinceLeave > 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? Colors.red.shade300 : Colors.orange.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: isOverdue ? Colors.red.shade700 : Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sick Leave Certificate Required',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? Colors.red.shade800 : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        application.dateRange,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Leave details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Duration:', '${application.totalDays} days'),
                  _buildDetailRow('Leave ended:', DateFormat('dd/MM/yyyy').format(application.endDate)),
                  _buildDetailRow('Days since:', '$daysSinceLeave days ago'),
                  if (application.reason.isNotEmpty)
                    _buildDetailRow('Reason:', application.reason),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Upload button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _uploadCertificate(application),
                icon: _isUploading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.cloud_upload, size: 20),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Upload Medical Certificate',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOverdue ? Colors.red.shade600 : Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Helper text
            Text(
              'Supported formats: PDF, JPG, PNG, DOC, DOCX (Max 10MB)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



