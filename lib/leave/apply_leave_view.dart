// lib/leave/apply_leave_view.dart - STEP 5: UPDATED FOR 4 LEAVE TYPES

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:face_auth/model/leave_application_model.dart';
import 'package:face_auth/model/leave_balance_model.dart';
import 'package:face_auth/services/leave_application_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/repositories/leave_application_repository.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';


class ApplyLeaveView extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final Map<String, dynamic> userData;

  const ApplyLeaveView({
    Key? key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.userData,
  }) : super(key: key);

  @override
  State<ApplyLeaveView> createState() => _ApplyLeaveViewState();
}

class _ApplyLeaveViewState extends State<ApplyLeaveView> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();

  // Form State
  LeaveType _selectedLeaveType = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isAlreadyTaken = false;
  File? _certificateFile;
  String? _certificateFileName;

  // App State
  bool _isSubmitting = false;
  bool _isLoadingBalance = true;
  LeaveBalance? _leaveBalance;
  late LeaveApplicationService _leaveService;
  bool _hasAcknowledgedEligibility = false;
  bool _hasAcknowledgedEmergency = false;

  // Calculated values
  int _totalDays = 0;

  // Responsive Design
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;
  bool get _isTablet => _screenWidth > 768;
  bool get _isMobile => _screenWidth <= 480;

  EdgeInsets get _padding => EdgeInsets.symmetric(
    horizontal: _isTablet ? 32 : (_isMobile ? 16 : 24),
    vertical: _isTablet ? 24 : (_isMobile ? 16 : 20),
  );

  double get _fontSize => _isTablet ? 1.2 : (_isMobile ? 0.9 : 1.0);

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadLeaveBalance();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeService() {
    final repository = getIt<LeaveApplicationRepository>();
    final connectivityService = getIt<ConnectivityService>();
    _leaveService = LeaveApplicationService(
      repository: repository,
      connectivityService: connectivityService,
    );
  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() => _isLoadingBalance = true);
      final balance = await _leaveService.getLeaveBalance(widget.employeeId);
      if (mounted) {
        setState(() {
          _leaveBalance = balance;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
      debugPrint("Error loading leave balance: $e");
    }
  }

  void _calculateTotalDays() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _totalDays = _leaveService.calculateTotalDays(_startDate!, _endDate!);
      });
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _isAlreadyTaken ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2030),
      helpText: _isAlreadyTaken ? 'Select past start date' : 'Select start date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _totalDays = 0;
        } else {
          _calculateTotalDays();
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? (_isAlreadyTaken ? DateTime(2020) : DateTime.now()),
      lastDate: DateTime(2030),
      helpText: _isAlreadyTaken ? 'Select past end date' : 'Select end date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        _calculateTotalDays();
      });
    }
  }

  Future<void> _pickCertificate() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && mounted) {
        setState(() {
          _certificateFile = File(result.files.single.path!);
          _certificateFileName = result.files.single.name;
        });
        CustomSnackBar.successSnackBar("Certificate selected: ${result.files.single.name}");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error selecting certificate: $e");
    }
  }

  void _removeCertificate() {
    setState(() {
      _certificateFile = null;
      _certificateFileName = null;
    });
  }

  bool _isCertificateRequired() {
    if (_selectedLeaveType == LeaveType.emergency) {
      return false;
    }
    return _leaveService.isCertificateRequired(_selectedLeaveType, _isAlreadyTaken);
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_startDate == null) {
      CustomSnackBar.errorSnackBar("Please select start date");
      return false;
    }

    if (_endDate == null) {
      CustomSnackBar.errorSnackBar("Please select end date");
      return false;
    }

    if (_startDate!.isAfter(_endDate!)) {
      CustomSnackBar.errorSnackBar("Start date cannot be after end date");
      return false;
    }

    if (!_isAlreadyTaken && !_leaveService.validateLeaveDates(_startDate!, _endDate!)) {
      CustomSnackBar.errorSnackBar("Leave dates cannot be in the past");
      return false;
    }

    if (_isAlreadyTaken && !_leaveService.areDatesInPast(_startDate!, _endDate!)) {
      CustomSnackBar.errorSnackBar("For already taken leave, dates must be in the past");
      return false;
    }

    if (_selectedLeaveType == LeaveType.annual && !_hasAcknowledgedEligibility) {
      CustomSnackBar.errorSnackBar("Please acknowledge the annual leave eligibility requirements");
      return false;
    }

    if (_selectedLeaveType == LeaveType.emergency && !_hasAcknowledgedEmergency) {
      CustomSnackBar.errorSnackBar("Please acknowledge the emergency leave deduction policy");
      return false;
    }

    if (_isCertificateRequired() && _certificateFile == null) {
      CustomSnackBar.errorSnackBar("Please upload required certificate");
      return false;
    }

    if (_leaveBalance != null) {
      if (_selectedLeaveType == LeaveType.emergency) {
        final emergencyRemaining = _leaveBalance!.getRemainingDays('emergency');
        final annualRemaining = _leaveBalance!.getRemainingDays('annual');

        if (emergencyRemaining < _totalDays && annualRemaining < _totalDays) {
          CustomSnackBar.errorSnackBar(
              "Insufficient balance for emergency leave. Emergency: $emergencyRemaining days, Annual: $annualRemaining days, Requested: $_totalDays days"
          );
          return false;
        }
      } else {
        if (!_leaveBalance!.hasEnoughBalance(_selectedLeaveType.name, _totalDays)) {
          final remaining = _leaveBalance!.getRemainingDays(_selectedLeaveType.name);
          CustomSnackBar.errorSnackBar("Insufficient leave balance. Available: $remaining days, Requested: $_totalDays days");
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> _showEmergencyLeaveConfirmation() async {
    final emergencyRemaining = _leaveBalance?.getRemainingDays('emergency') ?? 0;
    final annualRemaining = _leaveBalance?.getRemainingDays('annual') ?? 0;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Emergency Leave Confirmation')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Double Deduction Policy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Emergency leave will be deducted from BOTH your Emergency Leave balance AND your Annual Leave balance.',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Current Balance:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Emergency Leave: $emergencyRemaining days'),
            Text('• Annual Leave: $annualRemaining days'),
            const SizedBox(height: 12),
            Text('After Approval ($_totalDays days):', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Emergency Leave: ${emergencyRemaining >= _totalDays ? (emergencyRemaining - _totalDays) : 0} days'),
            Text('• Annual Leave: ${annualRemaining >= _totalDays ? (annualRemaining - _totalDays) : annualRemaining} days'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _submitApplication() async {
    if (_selectedLeaveType == LeaveType.emergency) {
      final confirmed = await _showEmergencyLeaveConfirmation();
      if (!confirmed) return;
    }

    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final applicationId = await _leaveService.submitLeaveApplication(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        employeePin: widget.employeePin,
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim().isEmpty
            ? 'No specific reason provided'
            : _reasonController.text.trim(),
        isAlreadyTaken: _isAlreadyTaken,
        certificateFile: _certificateFile,
      );

      if (mounted) {
        if (applicationId != null) {
          CustomSnackBar.successSnackBar("Leave application submitted successfully!");
          Navigator.of(context).pop(true);
        } else {
          CustomSnackBar.errorSnackBar("Failed to submit leave application");
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.errorSnackBar("Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildLeaveBalanceSection(),
                      _buildLeaveTypeSection(),
                      if (_selectedLeaveType == LeaveType.annual) _buildAnnualLeaveNotice(),
                      if (_selectedLeaveType == LeaveType.emergency) _buildEmergencyLeaveNotice(),
                      _buildAlreadyTakenSection(),
                      _buildDateSelectionSection(),
                      if (_totalDays > 0) _buildDaySummarySection(),
                      _buildReasonSection(),
                      if (_isCertificateRequired()) _buildCertificateSection(),
                      _buildSubmitSection(),
                      SizedBox(height: _padding.vertical * 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: _padding,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply for Leave',
                  style: TextStyle(
                    fontSize: 20 * _fontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Submit your leave application',
                  style: TextStyle(
                    fontSize: 14 * _fontSize,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceSection() {
    return Container(
      margin: _padding,
      padding: EdgeInsets.all(_isTablet ? 24 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Balance (${DateTime.now().year})',
            style: TextStyle(
              fontSize: 18 * _fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingBalance)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (_leaveBalance != null)
            _buildBalanceGrid()
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load balance',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceGrid() {
    final summary = _leaveBalance!.getSummary();
    // ✅ FIXED: Only show 4 leave types
    final displayTypes = ['annual', 'sick', 'local', 'emergency'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isTablet ? 2 : 2,
        childAspectRatio: _isTablet ? 2.5 : 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayTypes.length,
      itemBuilder: (context, index) {
        final type = displayTypes[index];
        final balance = summary[type];
        final remaining = balance?['remaining'] ?? 0;
        final total = balance?['total'] ?? 0;
        final pending = balance?['pending'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * _fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$remaining/$total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * _fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                pending > 0 ? '($pending pending)' : 'available',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9 * _fontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      margin: _padding,
      padding: EdgeInsets.all(_isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16 * _fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLeaveTypeSection() {
    return _buildSection(
      title: 'Leave Type',
      child: DropdownButtonFormField<LeaveType>(
        value: _selectedLeaveType,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: LeaveType.values.map((type) {
          return DropdownMenuItem<LeaveType>(
            value: type,
            child: Text(
              type.displayName,
              style: TextStyle(fontSize: 14 * _fontSize),
            ),
          );
        }).toList(),
        onChanged: (LeaveType? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedLeaveType = newValue;
              _certificateFile = null;
              _certificateFileName = null;
              _hasAcknowledgedEligibility = false;
              _hasAcknowledgedEmergency = false;
            });
          }
        },
        validator: (value) {
          if (value == null) return 'Please select leave type';
          return null;
        },
      ),
    );
  }

  Widget _buildAnnualLeaveNotice() {
    return Container(
      margin: _padding,
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Annual Leave Eligibility',
            style: TextStyle(
              fontSize: 16 * _fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please verify your annual leave eligibility before submitting. Contact HR Department if you need assistance with eligibility requirements.',
            style: TextStyle(
              fontSize: 14 * _fontSize,
              color: const Color(0xFF92400E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _hasAcknowledgedEligibility = !_hasAcknowledgedEligibility;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _hasAcknowledgedEligibility ? const Color(0xFF2563EB) : Colors.white,
                    border: Border.all(
                      color: _hasAcknowledgedEligibility ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _hasAcknowledgedEligibility
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I acknowledge that I have verified my annual leave eligibility',
                    style: TextStyle(
                      fontSize: 14 * _fontSize,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyLeaveNotice() {
    return Container(
      margin: _padding,
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Leave Policy',
            style: TextStyle(
              fontSize: 16 * _fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Emergency leave will be deducted from BOTH your Emergency Leave and Annual Leave balances. No certificate is required for emergency leave.',
            style: TextStyle(
              fontSize: 14 * _fontSize,
              color: const Color(0xFFDC2626),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _hasAcknowledgedEmergency = !_hasAcknowledgedEmergency;
              });
            },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _hasAcknowledgedEmergency ? const Color(0xFFDC2626) : Colors.white,
                    border: Border.all(
                      color: _hasAcknowledgedEmergency ? const Color(0xFFDC2626) : const Color(0xFFD1D5DB),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _hasAcknowledgedEmergency
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I understand the double deduction policy for emergency leaves',
                    style: TextStyle(
                      fontSize: 14 * _fontSize,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyTakenSection() {
    return Container(
      margin: _padding,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isAlreadyTaken = !_isAlreadyTaken;
            _startDate = null;
            _endDate = null;
            _totalDays = 0;
            _certificateFile = null;
            _certificateFileName = null;
          });
        },
        child: Container(
          padding: EdgeInsets.all(_isTablet ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isAlreadyTaken ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: _isAlreadyTaken ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _isAlreadyTaken ? const Color(0xFF2563EB) : Colors.white,
                  border: Border.all(
                    color: _isAlreadyTaken ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _isAlreadyTaken
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This is for leave already taken',
                      style: TextStyle(
                        fontSize: 15 * _fontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Check this if you\'re applying for leave that has already been taken',
                      style: TextStyle(
                        fontSize: 13 * _fontSize,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectionSection() {
    return _buildSection(
      title: 'Leave Dates',
      child: Column(
        children: [
          if (_isTablet)
            Row(
              children: [
                Expanded(child: _buildDateField('Start Date', _startDate, _selectStartDate)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateField('End Date', _endDate, _selectEndDate)),
              ],
            )
          else
            Column(
              children: [
                _buildDateField('Start Date', _startDate, _selectStartDate),
                const SizedBox(height: 16),
                _buildDateField('End Date', _endDate, _selectEndDate),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14 * _fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: date != null ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 12),
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select date',
                  style: TextStyle(
                    color: date != null ? const Color(0xFF1E293B) : const Color(0xFF6B7280),
                    fontSize: 14 * _fontSize,
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySummarySection() {
    return Container(
      margin: _padding,
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calculate, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Days: $_totalDays',
                  style: TextStyle(
                    fontSize: 18 * _fontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_leaveBalance != null)
                  Text(
                    _selectedLeaveType == LeaveType.emergency
                        ? 'Will deduct from both Emergency and Annual leave'
                        : 'Remaining ${_selectedLeaveType.displayName}: ${_leaveBalance!.getRemainingDays(_selectedLeaveType.name)} days',
                    style: TextStyle(
                      fontSize: 12 * _fontSize,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return _buildSection(
      title: 'Reason for Leave (Optional)',
      child: TextFormField(
        controller: _reasonController,
        maxLines: 4,
        style: TextStyle(fontSize: 14 * _fontSize),
        decoration: InputDecoration(
          hintText: 'Please provide a reason for your leave (optional)...',
          hintStyle: TextStyle(
            fontSize: 13 * _fontSize,
            color: const Color(0xFF9CA3AF),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCertificateSection() {
    return _buildSection(
      title: 'Certificate Upload (Required)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedLeaveType == LeaveType.sick && _isAlreadyTaken
                ? 'Medical certificate is required for sick leave that was already taken'
                : 'Supporting documents are required for already taken leave',
            style: TextStyle(
              fontSize: 13 * _fontSize,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          if (_certificateFile == null)
            GestureDetector(
              onTap: _pickCertificate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: const Color(0xFF2563EB),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload, size: 32, color: Color(0xFF2563EB)),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Certificate',
                      style: TextStyle(
                        fontSize: 14 * _fontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    Text(
                      'PDF, JPG, PNG, DOC (Max 10MB)',
                      style: TextStyle(
                        fontSize: 12 * _fontSize,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                border: Border.all(color: const Color(0xFF10B981)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _certificateFileName ?? 'Selected file',
                          style: TextStyle(
                            fontSize: 14 * _fontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                        Text(
                          'Certificate uploaded successfully',
                          style: TextStyle(
                            fontSize: 12 * _fontSize,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeCertificate,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Container(
      margin: _padding,
      child: SizedBox(
        width: double.infinity,
        height: _isTablet ? 56 : 48,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSubmitting ? const Color(0xFF9CA3AF) : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSubmitting
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Submitting Application...',
                style: TextStyle(
                  fontSize: 15 * _fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
              : Text(
            'Submit Application',
            style: TextStyle(
              fontSize: 16 * _fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}



