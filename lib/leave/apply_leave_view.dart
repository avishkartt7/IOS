// lib/leave/apply_leave_view.dart - UPDATED WITH EMERGENCY LEAVE CONFIRMATION

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

class _ApplyLeaveViewState extends State<ApplyLeaveView>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _submitController;
  late AnimationController _eligibilityController;
  late AnimationController _emergencyController; // ✅ NEW: For emergency message animation
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _eligibilityFadeAnimation;
  late Animation<double> _emergencyFadeAnimation; // ✅ NEW: For emergency message

  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();

  // Form fields
  LeaveType _selectedLeaveType = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isAlreadyTaken = false;
  File? _certificateFile;
  String? _certificateFileName;

  // State management
  bool _isSubmitting = false;
  bool _isLoadingBalance = true;
  LeaveBalance? _leaveBalance;
  late LeaveApplicationService _leaveService;
  bool _hasAcknowledgedEligibility = false;
  bool _hasAcknowledgedEmergency = false; // ✅ NEW: Track emergency leave acknowledgment

  // Calculated values
  int _totalDays = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
    _loadLeaveBalance();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _submitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _eligibilityController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // ✅ NEW: Animation controller for emergency message
    _emergencyController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _submitController,
      curve: Curves.elasticOut,
    ));

    _eligibilityFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _eligibilityController,
      curve: Curves.easeInOut,
    ));

    // ✅ NEW: Animation for emergency message
    _emergencyFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _emergencyController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _submitController.dispose();
    _eligibilityController.dispose();
    _emergencyController.dispose(); // ✅ NEW: Dispose emergency controller
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Responsive design helpers with better calculations
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isTablet => screenWidth > 600;
  bool get isSmallScreen => screenWidth < 360;
  bool get isVerySmallScreen => screenWidth < 320;

  EdgeInsets get responsivePadding {
    if (isVerySmallScreen) return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0);
    if (isSmallScreen) return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0);
    if (isTablet) return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0);
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0);
  }

  double get responsiveFontMultiplier {
    if (isVerySmallScreen) return 0.85;
    if (isSmallScreen) return 0.9;
    if (isTablet) return 1.15;
    return 1.0;
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
      _submitController.forward().then((_) => _submitController.reverse());
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
              primary: const Color(0xFF6366F1),
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
              primary: const Color(0xFF6366F1),
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

  // ✅ UPDATED: Emergency leave doesn't require certificate
  bool _isCertificateRequired() {
    // Emergency leave never requires certificate
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

    // ✅ UPDATED: Validate annual leave eligibility acknowledgment
    if (_selectedLeaveType == LeaveType.annual && !_hasAcknowledgedEligibility) {
      CustomSnackBar.errorSnackBar("Please acknowledge the annual leave eligibility requirements");
      return false;
    }

    // ✅ NEW: Validate emergency leave acknowledgment
    if (_selectedLeaveType == LeaveType.emergency && !_hasAcknowledgedEmergency) {
      CustomSnackBar.errorSnackBar("Please acknowledge the emergency leave deduction policy");
      return false;
    }

    if (_isCertificateRequired() && _certificateFile == null) {
      String requiredFor = '';
      if (_selectedLeaveType == LeaveType.sick && _isAlreadyTaken) {
        requiredFor = 'sick leave that was already taken (medical certificate required)';
      } else if (_isAlreadyTaken) {
        requiredFor = 'already taken leave (supporting documents required)';
      }
      CustomSnackBar.errorSnackBar("Please upload certificate for $requiredFor");
      return false;
    }

    // ✅ UPDATED: Special balance check for emergency leave
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

  // ✅ NEW: Show emergency leave confirmation dialog
  Future<bool> _showEmergencyLeaveConfirmation() async {
    final emergencyRemaining = _leaveBalance?.getRemainingDays('emergency') ?? 0;
    final annualRemaining = _leaveBalance?.getRemainingDays('annual') ?? 0;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: isTablet ? 600 : double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.shade400,
                      Colors.orange.shade500,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Text(
                        'Emergency Leave Confirmation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (isTablet ? 22 : 20) * responsiveFontMultiplier,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main message
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.red.shade700,
                                  size: isTablet ? 24 : 20,
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Expanded(
                                  child: Text(
                                    'Double Deduction Policy',
                                    style: TextStyle(
                                      fontSize: (isTablet ? 18 : 16) * responsiveFontMultiplier,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 12 : 10),
                            Text(
                              'Emergency leave will be deducted from BOTH your Emergency Leave balance AND your Annual Leave balance.',
                              style: TextStyle(
                                fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Current balance display
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Current Balance:',
                              style: TextStyle(
                                fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1565C0), // blue-700 equivalent
                              ),
                            ),
                            SizedBox(height: isTablet ? 12 : 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBalanceItem(
                                    'Emergency Leave',
                                    '$emergencyRemaining days',
                                    Colors.orange,
                                  ),
                                ),
                                SizedBox(width: isTablet ? 16 : 12),
                                Expanded(
                                  child: _buildBalanceItem(
                                    'Annual Leave',
                                    '$annualRemaining days',
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Deduction explanation
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'After Approval ($_totalDays days):',
                              style: TextStyle(
                                fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB45309), // amber-800 equivalent
                              ),
                            ),
                            SizedBox(height: isTablet ? 12 : 8),
                            Text(
                              '• Emergency Leave: ${emergencyRemaining >= _totalDays ? (emergencyRemaining - _totalDays) : 0} days remaining\n'
                                  '• Annual Leave: ${annualRemaining >= _totalDays ? (annualRemaining - _totalDays) : annualRemaining} days remaining',
                              style: TextStyle(
                                fontSize: (isTablet ? 14 : 12) * responsiveFontMultiplier,
                                color: const Color(0xFFB45309), // amber-800 equivalent
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 20 : 16),

                      // Application details
                      Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Application Details:',
                              style: TextStyle(
                                fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF424242), // grey-700 equivalent
                              ),
                            ),
                            SizedBox(height: isTablet ? 12 : 8),
                            _buildDetailRow('Employee', widget.employeeName),
                            _buildDetailRow('Leave Type', 'Emergency Leave'),
                            _buildDetailRow('Dates', '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                            _buildDetailRow('Total Days', '$_totalDays days'),
                            if (_reasonController.text.isNotEmpty)
                              _buildDetailRow('Reason', _reasonController.text),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Do you want to proceed with this emergency leave application?',
                      style: TextStyle(
                        fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF424242), // grey-700 equivalent
                              side: const BorderSide(color: Color(0xFF9E9E9E)), // grey-300 equivalent
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier),
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F), // red-600 equivalent
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Confirm & Submit',
                              style: TextStyle(fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  Widget _buildBalanceItem(String title, String value, Color color) {
    // Create darker shades for text colors
    final Color darkColor = Color.fromRGBO(
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
      1.0,
    );
    final Color darkerColor = Color.fromRGBO(
      (color.red * 0.5).round(),
      (color.green * 0.5).round(),
      (color.blue * 0.5).round(),
      1.0,
    );

    return Container(
      padding: EdgeInsets.all(isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: (isTablet ? 12 : 10) * responsiveFontMultiplier,
              color: darkColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 4 : 2),
          Text(
            value,
            style: TextStyle(
              fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
              color: darkerColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 6 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 100 : 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF757575), // grey-600 equivalent
                fontSize: (isTablet ? 13 : 11) * responsiveFontMultiplier,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: (isTablet ? 13 : 11) * responsiveFontMultiplier,
                color: const Color(0xFF424242), // grey-800 equivalent
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitApplication() async {
    // ✅ NEW: Special handling for emergency leave
    if (_selectedLeaveType == LeaveType.emergency) {
      final confirmed = await _showEmergencyLeaveConfirmation();
      if (!confirmed) {
        return; // User cancelled
      }
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
    return Theme(
      data: _buildLightTheme(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildModernHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              SizedBox(height: responsivePadding.vertical / 2),
                              _buildBalanceCard(),
                              SizedBox(height: responsivePadding.vertical),
                              _buildLeaveTypeSection(),
                              SizedBox(height: responsivePadding.vertical),
                              // ✅ UPDATED: Show appropriate message based on leave type
                              if (_selectedLeaveType == LeaveType.annual) ...[
                                _buildAnnualLeaveEligibilityMessage(),
                                SizedBox(height: responsivePadding.vertical),
                              ],
                              if (_selectedLeaveType == LeaveType.emergency) ...[
                                _buildEmergencyLeaveMessage(),
                                SizedBox(height: responsivePadding.vertical),
                              ],
                              _buildAlreadyTakenSection(),
                              SizedBox(height: responsivePadding.vertical),
                              _buildDateSelectionSection(),
                              SizedBox(height: responsivePadding.vertical),
                              if (_totalDays > 0) ...[
                                _buildDaysCalculationCard(),
                                SizedBox(height: responsivePadding.vertical),
                              ],
                              _buildReasonSection(),
                              SizedBox(height: responsivePadding.vertical),
                              if (_isCertificateRequired()) ...[
                                _buildCertificateSection(),
                                SizedBox(height: responsivePadding.vertical),
                              ],
                              _buildSubmitButton(),
                              SizedBox(height: responsivePadding.vertical + 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Apply for Leave",
                  style: TextStyle(
                    fontSize: (isTablet ? 22 : (isSmallScreen ? 18 : 20)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Submit your leave application",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: (isTablet ? 14 : (isSmallScreen ? 12 : 13)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_available,
              color: Theme.of(context).colorScheme.primary,
              size: isSmallScreen ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            margin: responsivePadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF764BA2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 24 : (isSmallScreen ? 16 : 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Balance (${DateTime.now().year})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 20 : (isSmallScreen ? 16 : 18)) * responsiveFontMultiplier,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                    if (_isLoadingBalance)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_leaveBalance != null)
                      _buildBalanceGrid()
                    else
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Unable to load balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: (isTablet ? 16 : 14) * responsiveFontMultiplier,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceGrid() {
    final summary = _leaveBalance!.getSummary();
    final displayTypes = ['annual', 'sick', 'emergency', 'maternity', 'paternity', 'compensate'];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (isTablet) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 400) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isVerySmallScreen ? 1.5 : (isSmallScreen ? 1.8 : 2.0),
            crossAxisSpacing: isSmallScreen ? 8 : 12,
            mainAxisSpacing: isSmallScreen ? 8 : 12,
          ),
          itemCount: displayTypes.length,
          itemBuilder: (context, index) {
            final type = displayTypes[index];
            final balance = summary[type];
            final remaining = balance?['remaining'] ?? 0;
            final total = balance?['total'] ?? 0;
            final pending = balance?['pending'] ?? 0;

            return Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11)) * responsiveFontMultiplier,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$remaining/$total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16)) * responsiveFontMultiplier,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        pending > 0 ? '($pending pending)' : 'available',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: (isVerySmallScreen ? 8 : (isSmallScreen ? 9 : 10)) * responsiveFontMultiplier,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      margin: responsivePadding,
      padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 14 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildLeaveTypeSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leave Type',
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
          DropdownButtonFormField<LeaveType>(
            value: _selectedLeaveType,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : (isTablet ? 18 : 14),
                vertical: isSmallScreen ? 12 : (isTablet ? 18 : 14),
              ),
            ),
            items: LeaveType.values.map((type) {
              return DropdownMenuItem<LeaveType>(
                value: type,
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : (isSmallScreen ? 13 : 14)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                  _hasAcknowledgedEmergency = false; // ✅ NEW: Reset emergency acknowledgment
                });

                // ✅ UPDATED: Animate appropriate message in/out
                if (newValue == LeaveType.annual) {
                  _eligibilityController.forward();
                  _emergencyController.reverse();
                } else if (newValue == LeaveType.emergency) {
                  _emergencyController.forward();
                  _eligibilityController.reverse();
                } else {
                  _eligibilityController.reverse();
                  _emergencyController.reverse();
                }
              }
            },
            validator: (value) {
              if (value == null) return 'Please select leave type';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ✅ EXISTING: Annual Leave Eligibility Message Widget (keeping as is)
  Widget _buildAnnualLeaveEligibilityMessage() {
    return AnimatedBuilder(
      animation: _eligibilityFadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _eligibilityFadeAnimation,
          child: Container(
            margin: responsivePadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade400,
                  Colors.deepOrange.shade500,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 14 : 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: isSmallScreen ? 18 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Annual Leave Eligibility',
                            style: TextStyle(
                              fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10,
                            vertical: isSmallScreen ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'IMPORTANT',
                            style: TextStyle(
                              fontSize: (isTablet ? 11 : (isSmallScreen ? 9 : 10)) * responsiveFontMultiplier,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),

                    // Message content
                    Container(
                      padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Please check your annual leave eligibility before submitting this application.',
                            style: TextStyle(
                              fontSize: (isTablet ? 16 : (isSmallScreen ? 14 : 15)) * responsiveFontMultiplier,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: isTablet ? 12 : (isSmallScreen ? 8 : 10)),
                          Text(
                            '• Verify your remaining annual leave balance\n'
                                '• Ensure compliance with company leave policies\n'
                                '• Contact HR Department for eligibility confirmation\n'
                                '• Review your employment tenure requirements',
                            style: TextStyle(
                              fontSize: (isTablet ? 14 : (isSmallScreen ? 12 : 13)) * responsiveFontMultiplier,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                          Container(
                            padding: EdgeInsets.all(isTablet ? 12 : (isSmallScreen ? 10 : 11)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.support_agent,
                                  color: Colors.white,
                                  size: isSmallScreen ? 16 : 18,
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 10),
                                Expanded(
                                  child: Text(
                                    'For assistance, please contact the HR Department',
                                    style: TextStyle(
                                      fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),

                    // Acknowledgment checkbox
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _hasAcknowledgedEligibility = !_hasAcknowledgedEligibility;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 12 : (isSmallScreen ? 10 : 11)),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasAcknowledgedEligibility
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.3),
                              width: _hasAcknowledgedEligibility ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: isSmallScreen ? 1.0 : (isTablet ? 1.2 : 1.1),
                                child: Checkbox(
                                  value: _hasAcknowledgedEligibility,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _hasAcknowledgedEligibility = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.white,
                                  checkColor: const Color(0xFFFF5722), // orange-600 equivalent
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.8),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Text(
                                  'I acknowledge that I have verified my annual leave eligibility and contacted HR if needed',
                                  style: TextStyle(
                                    fontSize: (isTablet ? 14 : (isSmallScreen ? 12 : 13)) * responsiveFontMultiplier,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ NEW: Emergency Leave Message Widget
  Widget _buildEmergencyLeaveMessage() {
    return AnimatedBuilder(
      animation: _emergencyFadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _emergencyFadeAnimation,
          child: Container(
            margin: responsivePadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade400,
                  Colors.orange.shade500,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 14 : 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 18 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Emergency Leave Policy',
                            style: TextStyle(
                              fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10,
                            vertical: isSmallScreen ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NOTICE',
                            style: TextStyle(
                              fontSize: (isTablet ? 11 : (isSmallScreen ? 9 : 10)) * responsiveFontMultiplier,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),

                    // Message content
                    Container(
                      padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency leave will be deducted from BOTH your Emergency Leave and Annual Leave balances.',
                            style: TextStyle(
                              fontSize: (isTablet ? 16 : (isSmallScreen ? 14 : 15)) * responsiveFontMultiplier,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: isTablet ? 12 : (isSmallScreen ? 8 : 10)),
                          Text(
                            '• Double deduction policy applies to all emergency leaves\n'
                                '• No certificate or documentation required\n'
                                '• Immediate submission to line manager for approval\n'
                                '• Confirmation dialog will show exact deductions',
                            style: TextStyle(
                              fontSize: (isTablet ? 14 : (isSmallScreen ? 12 : 13)) * responsiveFontMultiplier,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
                          Container(
                            padding: EdgeInsets.all(isTablet ? 12 : (isSmallScreen ? 10 : 11)),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: isSmallScreen ? 16 : 18,
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 10),
                                Expanded(
                                  child: Text(
                                    'Confirmation required before final submission',
                                    style: TextStyle(
                                      fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),

                    // Acknowledgment checkbox
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _hasAcknowledgedEmergency = !_hasAcknowledgedEmergency;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 12 : (isSmallScreen ? 10 : 11)),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasAcknowledgedEmergency
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.3),
                              width: _hasAcknowledgedEmergency ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: isSmallScreen ? 1.0 : (isTablet ? 1.2 : 1.1),
                                child: Checkbox(
                                  value: _hasAcknowledgedEmergency,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _hasAcknowledgedEmergency = value ?? false;
                                    });
                                  },
                                  activeColor: Colors.white,
                                  checkColor: const Color(0xFFD32F2F), // red-600 equivalent
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.8),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Text(
                                  'I understand the double deduction policy for emergency leaves',
                                  style: TextStyle(
                                    fontSize: (isTablet ? 14 : (isSmallScreen ? 12 : 13)) * responsiveFontMultiplier,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlreadyTakenSection() {
    return _buildModernCard(
      child: InkWell(
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
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              Transform.scale(
                scale: isSmallScreen ? 1.0 : (isTablet ? 1.2 : 1.1),
                child: Checkbox(
                  value: _isAlreadyTaken,
                  onChanged: (bool? value) {
                    setState(() {
                      _isAlreadyTaken = value ?? false;
                      _startDate = null;
                      _endDate = null;
                      _totalDays = 0;
                      _certificateFile = null;
                      _certificateFileName = null;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This is for leave already taken',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: (isTablet ? 16 : (isSmallScreen ? 14 : 15)) * responsiveFontMultiplier,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Text(
                      'Check this if you\'re applying for leave that has already been taken',
                      style: TextStyle(
                        fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.date_range,
                  color: Theme.of(context).colorScheme.secondary,
                  size: isSmallScreen ? 18 :20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leave Dates',
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
          if (isTablet && screenWidth > 700)
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
                SizedBox(height: isSmallScreen ? 12 : 14),
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
            fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: isSmallScreen ? 16 : (isTablet ? 20 : 18),
                    color: date != null ? Theme.of(context).colorScheme.primary : Colors.grey.shade600,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : (isTablet ? 12 : 10)),
                  Expanded(
                    child: Text(
                      date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select date',
                      style: TextStyle(
                        color: date != null ? Colors.black87 : Colors.grey.shade600,
                        fontSize: (isTablet ? 15 : (isSmallScreen ? 13 : 14)) * responsiveFontMultiplier,
                        fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysCalculationCard() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: responsivePadding,
            padding: EdgeInsets.all(isTablet ? 20 : (isSmallScreen ? 14 : 16)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.indigo.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calculate_outlined,
                    color: Colors.white,
                    size: isSmallScreen ? 22 : (isTablet ? 28 : 24),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : (isTablet ? 16 : 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Days: $_totalDays',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: (isTablet ? 20 : (isSmallScreen ? 16 : 18)) * responsiveFontMultiplier,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_leaveBalance != null) ...[
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        // ✅ UPDATED: Show special message for emergency leave
                        if (_selectedLeaveType == LeaveType.emergency)
                          Text(
                            'Will deduct from both Emergency (${_leaveBalance!.getRemainingDays('emergency')}) and Annual (${_leaveBalance!.getRemainingDays('annual')}) leave',
                            style: TextStyle(
                              fontSize: (isTablet ? 11 : (isSmallScreen ? 9 : 10)) * responsiveFontMultiplier,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          )
                        else
                          Text(
                            'Remaining ${_selectedLeaveType.displayName}: ${_leaveBalance!.getRemainingDays(_selectedLeaveType.name)} days',
                            style: TextStyle(
                              fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReasonSection() {
    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: const Color(0xFFE65100), // orange-600 equivalent
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reason for Leave',
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: (isTablet ? 12 : (isSmallScreen ? 10 : 11)) * responsiveFontMultiplier,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
          TextFormField(
            controller: _reasonController,
            maxLines: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : (isTablet ? 5 : 4)),
            style: TextStyle(
              fontSize: (isTablet ? 15 : (isSmallScreen ? 13 : 14)) * responsiveFontMultiplier,
            ),
            decoration: InputDecoration(
              hintText: 'Please provide a reason for your leave (optional)...',
              hintStyle: TextStyle(
                fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                color: Colors.grey.shade500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.all(isTablet ? 18 : (isSmallScreen ? 12 : 14)),
              alignLabelWithHint: true,
            ),
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSection() {
    String requirement = '';
    if (_selectedLeaveType == LeaveType.sick && _isAlreadyTaken) {
      requirement = 'Medical certificate is required for sick leave that was already taken';
    } else if (_isAlreadyTaken) {
      requirement = 'Supporting documents are required for already taken leave';
    }

    return _buildModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attach_file,
                  color: const Color(0xFFD32F2F), // red-600 equivalent
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Certificate Upload',
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : (isSmallScreen ? 16 : 17)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : (isTablet ? 12 : 10),
                  vertical: isSmallScreen ? 3 : (isTablet ? 6 : 4),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350), // red-100 equivalent
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontSize: (isTablet ? 11 : (isSmallScreen ? 9 : 10)) * responsiveFontMultiplier,
                    color: const Color(0xFFB71C1C), // red-700 equivalent
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 12 : (isSmallScreen ? 8 : 10)),
          Text(
            requirement,
            style: TextStyle(
              fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isTablet ? 16 : (isSmallScreen ? 12 : 14)),
          if (_certificateFile == null)
            SizedBox(
              width: double.infinity,
              height: isSmallScreen ? 44 : (isTablet ? 56 : 48),
              child: OutlinedButton.icon(
                onPressed: _pickCertificate,
                icon: Icon(
                  Icons.cloud_upload_outlined,
                  size: isSmallScreen ? 18 : (isTablet ? 22 : 20),
                ),
                label: Text(
                  'Upload Certificate',
                  style: TextStyle(
                    fontSize: (isTablet ? 15 : (isSmallScreen ? 13 : 14)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : (isSmallScreen ? 12 : 14)),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E6C9), // green-100 equivalent
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: const Color(0xFF388E3C), // green-700 equivalent
                      size: isSmallScreen ? 20 : (isTablet ? 26 : 22),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : (isTablet ? 14 : 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _certificateFileName ?? 'Selected file',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF388E3C), // green-700 equivalent
                            fontSize: (isTablet ? 15 : (isSmallScreen ? 13 : 14)) * responsiveFontMultiplier,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Certificate uploaded successfully',
                          style: TextStyle(
                            fontSize: (isTablet ? 13 : (isSmallScreen ? 11 : 12)) * responsiveFontMultiplier,
                            color: const Color(0xFF4CAF50), // green-600 equivalent
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _removeCertificate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                        child: Icon(
                          Icons.close,
                          color: const Color(0xFFD32F2F), // red-600 equivalent
                          size: isSmallScreen ? 18 : (isTablet ? 22 : 20),
                        ),
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

  Widget _buildSubmitButton() {
    return Container(
      margin: responsivePadding,
      child: SizedBox(
        width: double.infinity,
        height: isSmallScreen ? 48 : (isTablet ? 60 : 52),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSubmitting
                ? Colors.grey.withOpacity(0.5)
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: _isSubmitting ? 0 : 6,
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          child: _isSubmitting
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: isSmallScreen ? 18 : (isTablet ? 22 : 20),
                height: isSmallScreen ? 18 : (isTablet ? 22 : 20),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : (isTablet ? 14 : 12)),
              Flexible(
                child: Text(
                  'Submitting Application...',
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : (isSmallScreen ? 14 : 15)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.send_rounded,
                size: isSmallScreen ? 18 : (isTablet ? 22 : 20),
              ),
              SizedBox(width: isSmallScreen ? 8 : (isTablet ? 12 : 10)),
              Flexible(
                child: Text(
                  'Submit Application',
                  style: TextStyle(
                    fontSize: (isTablet ? 17 : (isSmallScreen ? 15 : 16)) * responsiveFontMultiplier,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}