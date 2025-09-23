// lib/leave/manager_leave_approval_view.dart - COMPACT UI DESIGN

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth/model/leave_application_model.dart';
import 'package:face_auth/services/leave_application_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/repositories/leave_application_repository.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';

class ManagerLeaveApprovalView extends StatefulWidget {
  final String managerId;
  final String managerName;

  const ManagerLeaveApprovalView({
    Key? key,
    required this.managerId,
    required this.managerName,
  }) : super(key: key);

  @override
  State<ManagerLeaveApprovalView> createState() => _ManagerLeaveApprovalViewState();
}

class _ManagerLeaveApprovalViewState extends State<ManagerLeaveApprovalView>
    with SingleTickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Service and State
  late LeaveApplicationService _leaveService;
  List<LeaveApplicationModel> _pendingApplications = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDarkMode = false;

  // Responsive design helpers
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isTablet => screenWidth > 600;
  bool get isSmallScreen => screenWidth < 360;

  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
    horizontal: isTablet ? 20.0 : 16.0,
    vertical: isTablet ? 16.0 : 12.0,
  );

  double get responsiveFontSize {
    if (isTablet) return 1.1;
    if (isSmallScreen) return 0.9;
    return 1.0;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDarkModePreference();
    _initializeService();
    _loadPendingApplications();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  Future<void> _loadPendingApplications() async {
    try {
      setState(() => _isLoading = true);

      final applications = await _leaveService.getPendingApplicationsForManager(widget.managerId);

      setState(() {
        _pendingApplications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading applications: $e");
    }
  }

  Future<void> _refreshApplications() async {
    try {
      setState(() => _isRefreshing = true);

      final applications = await _leaveService.getPendingApplicationsForManager(widget.managerId);

      setState(() {
        _pendingApplications = applications;
        _isRefreshing = false;
      });

      CustomSnackBar.successSnackBar("Applications refreshed");
    } catch (e) {
      setState(() => _isRefreshing = false);
      CustomSnackBar.errorSnackBar("Error refreshing: $e");
    }
  }

  // Modern Theme Builders
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Loading Screen
  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading leave applications...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * responsiveFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Clean Header Section
  Widget _buildHeader() {
    return Container(
      padding: responsivePadding,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Approvals',
                    style: TextStyle(
                      fontSize: 20 * responsiveFontSize,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${_pendingApplications.length} pending applications',
                    style: TextStyle(
                      fontSize: 14 * responsiveFontSize,
                      color: _isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isRefreshing ? null : _refreshApplications,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isRefreshing
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  )
                      : Icon(
                    Icons.refresh,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Stats Section
  Widget _buildQuickStats() {
    int totalDays = _pendingApplications.fold<int>(0, (sum, app) => sum + app.totalDays);
    int withCertificates = _pendingApplications.where((app) => app.certificateUrl != null).length;

    return Container(
      margin: responsivePadding,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.pending_actions,
                value: _pendingApplications.length.toString(),
                label: "Pending",
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.calendar_today,
                value: totalDays.toString(),
                label: "Total Days",
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.attachment,
                value: withCertificates.toString(),
                label: "Certificates",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * responsiveFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9 * responsiveFontSize,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Compact Application Card
  Widget _buildApplicationCard(LeaveApplicationModel application) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showApprovalDialog(application),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Compact
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getLeaveTypeColor(application.leaveType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getLeaveTypeIcon(application.leaveType),
                        color: _getLeaveTypeColor(application.leaveType),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.employeeName,
                            style: TextStyle(
                              fontSize: 14 * responsiveFontSize,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            application.leaveType.displayName,
                            style: TextStyle(
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 10 * responsiveFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 8 * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // ✅ FIXED: Show certificate status properly
                        if (application.certificateUrl != null && application.certificateUrl!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attachment,
                                  size: 10,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Cert',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 7 * responsiveFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ✅ FIXED: Details Row with proper date formatting
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        application.dateRange, // This now shows properly formatted dates
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 12 * responsiveFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${application.totalDays} days',
                        style: TextStyle(
                          color: const Color(0xFF2563EB),
                          fontSize: 10 * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ✅ FIXED: Reason display
                Text(
                  'Reason: ${application.reason.isNotEmpty ? application.reason : "No specific reason provided"}',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 10 * responsiveFontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // ✅ FIXED: Already taken indicator
                if (application.isAlreadyTaken) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Already taken leave',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 9 * responsiveFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _processDecision(application, false, ''),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Reject',
                          style: TextStyle(fontSize: 10 * responsiveFontSize),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _processDecision(application, true, ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Approve',
                          style: TextStyle(fontSize: 10 * responsiveFontSize),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showApprovalDialog(application),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Review',
                          style: TextStyle(fontSize: 10 * responsiveFontSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced approval dialog - Compact
  Future<void> _showApprovalDialog(LeaveApplicationModel application) async {
    final TextEditingController commentsController = TextEditingController();
    bool? approved;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: isTablet ? 500 : double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              // Header - Compact
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.approval,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Review Leave Application',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * responsiveFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content - Compact
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee info - Compact
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Employee', application.employeeName),
                            _buildDetailRow('Leave Type', application.leaveType.displayName),
                            _buildDetailRow('Dates', application.dateRange),
                            _buildDetailRow('Total Days', '${application.totalDays} days'),
                            _buildDetailRow('Applied On', DateFormat('dd/MM/yyyy').format(application.applicationDate)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Reason section - Compact
                      Text(
                        'Reason:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14 * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          application.reason,
                          style: TextStyle(
                            fontSize: 12 * responsiveFontSize,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // Certificate section - Compact
                      if (application.certificateUrl != null) ...[
                        const SizedBox(height: 12),
                        _buildCertificateSection(application),
                      ],

                      // Already taken notice - Compact
                      if (application.isAlreadyTaken) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This is for leave already taken',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12 * responsiveFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Comments section - Compact
                      Text(
                        'Comments (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14 * responsiveFontSize,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          controller: commentsController,
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: 12 * responsiveFontSize,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add any comments about your decision...',
                            hintStyle: TextStyle(
                              fontSize: 11 * responsiveFontSize,
                              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons - Compact
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          side: BorderSide(
                            color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: 12 * responsiveFontSize),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          approved = false;
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Reject',
                          style: TextStyle(fontSize: 12 * responsiveFontSize),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          approved = true;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Approve',
                          style: TextStyle(fontSize: 12 * responsiveFontSize),
                        ),
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

    if (approved != null) {
      await _processDecision(application, approved!, commentsController.text);
    }
  }

  // Certificate section - Compact
  Widget _buildCertificateSection(LeaveApplicationModel application) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.attachment,
                  size: 16,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate Attached',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12 * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // ✅ FIXED: Show certificate filename if available
                    if (application.certificateFileName != null && application.certificateFileName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        application.certificateFileName!,
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 10 * responsiveFontSize,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        'Certificate file available',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 10 * responsiveFontSize,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewCertificate(application.certificateUrl!),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: Text(
                    'View Certificate',
                    style: TextStyle(fontSize: 10 * responsiveFontSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                    minimumSize: Size.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadCertificate(application.certificateUrl!, application.certificateFileName),
                  icon: const Icon(Icons.download, size: 14),
                  label: Text(
                    'Download',
                    style: TextStyle(fontSize: 10 * responsiveFontSize),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: 10 * responsiveFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10 * responsiveFontSize,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Applications List
  Widget _buildApplicationsList() {
    if (_pendingApplications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshApplications,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          responsivePadding.horizontal,
          8,
          responsivePadding.horizontal,
          20,
        ),
        itemCount: _pendingApplications.length,
        itemBuilder: (context, index) {
          final application = _pendingApplications[index];
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  // Empty state - Compact
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 48,
              color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18 * responsiveFontSize,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending leave applications to review',
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 14 * responsiveFontSize,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refreshApplications,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'Refresh',
              style: TextStyle(fontSize: 12 * responsiveFontSize),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _viewCertificate(String certificateUrl) async {
    try {
      final Uri url = Uri.parse(certificateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        CustomSnackBar.errorSnackBar("Cannot open certificate. URL may be invalid.");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error opening certificate: $e");
    }
  }

  Future<void> _downloadCertificate(String certificateUrl, String? fileName) async {
    try {
      final Uri url = Uri.parse(certificateUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        CustomSnackBar.successSnackBar("Certificate download started");
      } else {
        CustomSnackBar.errorSnackBar("Cannot download certificate. URL may be invalid.");
      }
    } catch (e) {
      CustomSnackBar.errorSnackBar("Error downloading certificate: $e");
    }
  }

  Future<void> _processDecision(
      LeaveApplicationModel application,
      bool isApproved,
      String comments,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing decision...',
                  style: TextStyle(
                    fontSize: 14 * responsiveFontSize,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      bool success;
      if (isApproved) {
        success = await _leaveService.approveLeaveApplication(
          application.id!,
          widget.managerId,
          comments: comments.isNotEmpty ? comments : null,
        );
      } else {
        success = await _leaveService.rejectLeaveApplication(
          application.id!,
          widget.managerId,
          comments: comments.isNotEmpty ? comments : null,
        );
      }

      Navigator.pop(context); // Close loading dialog

      if (success) {
        CustomSnackBar.successSnackBar(
            'Application ${isApproved ? 'approved' : 'rejected'} successfully'
        );

        setState(() {
          _pendingApplications.removeWhere((app) => app.id == application.id);
        });
      } else {
        CustomSnackBar.errorSnackBar('Failed to process decision');
      }
    } catch (e) {
      Navigator.pop(context);
      CustomSnackBar.errorSnackBar('Error: $e');
    }
  }

  // Leave type color mapping for 4 types
  Color _getLeaveTypeColor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return Colors.blue;
      case LeaveType.sick:
        return Colors.red;
      case LeaveType.local:
        return Colors.green;
      case LeaveType.emergency:
        return Colors.orange;
    }
  }

  // Leave type icon mapping for 4 types
  IconData _getLeaveTypeIcon(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return Icons.beach_access;
      case LeaveType.sick:
        return Icons.local_hospital;
      case LeaveType.local:
        return Icons.location_on;
      case LeaveType.emergency:
        return Icons.emergency;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set context for snackbar
    if (CustomSnackBar.context == null) {
      CustomSnackBar.context = context;
    }

    return Theme(
      data: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: _isLoading
            ? _buildLoadingScreen()
            : AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Quick Stats (only show if there are applications)
                  if (_pendingApplications.isNotEmpty) ...[
                    _buildQuickStats(),
                    const SizedBox(height: 8),
                  ],

                  // Applications list
                  Expanded(
                    child: _buildApplicationsList(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}



