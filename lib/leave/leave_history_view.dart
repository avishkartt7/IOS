// lib/leave/leave_history_view.dart - COMPLETE FIXED IMPLEMENTATION

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_auth/model/leave_application_model.dart';
import 'package:face_auth/model/leave_balance_model.dart';
import 'package:face_auth/services/leave_application_service.dart';
import 'package:face_auth/services/service_locator.dart';
import 'package:face_auth/repositories/leave_application_repository.dart';
import 'package:face_auth/services/connectivity_service.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/leave/apply_leave_view.dart';

class LeaveHistoryView extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String employeePin;
  final Map<String, dynamic> userData;

  const LeaveHistoryView({
    Key? key,
    required this.employeeId,
    required this.employeeName,
    required this.employeePin,
    required this.userData,
  }) : super(key: key);

  @override
  State<LeaveHistoryView> createState() => _LeaveHistoryViewState();
}

class _LeaveHistoryViewState extends State<LeaveHistoryView>
    with TickerProviderStateMixin {

  // Animation Controllers
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Tab Controller
  late TabController _tabController;

  // Service and State
  late LeaveApplicationService _leaveService;
  List<LeaveApplicationModel> _allApplications = [];
  List<LeaveApplicationModel> _pendingApplications = [];
  List<LeaveApplicationModel> _approvedApplications = [];
  List<LeaveApplicationModel> _rejectedApplications = [];
  LeaveBalance? _leaveBalance;
  Map<String, dynamic> _statistics = {};

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
    _tabController = TabController(length: 4, vsync: this);
    _initializeAnimations();
    _loadDarkModePreference();
    _initializeService();
    _loadData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
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
    _pulseController.dispose();
    _tabController.dispose();
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

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load all data in parallel
      final futures = await Future.wait([
        _leaveService.getEmployeeLeaveApplications(widget.employeeId),
        _leaveService.getLeaveBalance(widget.employeeId),
        _leaveService.getLeaveStatistics(widget.employeeId),
      ]);

      final applications = futures[0] as List<LeaveApplicationModel>;
      final balance = futures[1] as LeaveBalance?;
      final statistics = futures[2] as Map<String, dynamic>;

      setState(() {
        _allApplications = applications;
        _pendingApplications = applications
            .where((app) => app.status == LeaveStatus.pending)
            .toList();
        _approvedApplications = applications
            .where((app) => app.status == LeaveStatus.approved)
            .toList();
        _rejectedApplications = applications
            .where((app) => app.status == LeaveStatus.rejected)
            .toList();
        _leaveBalance = balance;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.errorSnackBar("Error loading data: $e");
    }
  }

  Future<void> _refreshData() async {
    try {
      setState(() => _isRefreshing = true);
      await _loadData();
      setState(() => _isRefreshing = false);
      CustomSnackBar.successSnackBar("Data refreshed");
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
              'Loading leave history...',
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
                    'Leave History',
                    style: TextStyle(
                      fontSize: 20 * responsiveFontSize,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Track your leave applications',
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
                onTap: _isRefreshing ? null : _refreshData,
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

  // Quick Stats Section - More Compact
  Widget _buildQuickStats() {
    int totalApplications = _statistics['totalApplications'] ?? 0;
    int totalDaysApproved = _statistics['totalDaysApproved'] ?? 0;

    return Container(
      margin: responsivePadding,
      padding: const EdgeInsets.all(12), // Reduced from 16
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
                icon: Icons.description,
                value: totalApplications.toString(),
                label: "Total",
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.check_circle,
                value: totalDaysApproved.toString(),
                label: "Approved",
              ),
            ),
            Container(
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.pending,
                value: _pendingApplications.length.toString(),
                label: "Pending",
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2), // Reduced padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16), // Reduced from 18
          const SizedBox(height: 4), // Reduced from 6
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * responsiveFontSize, // Reduced from 16
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9 * responsiveFontSize, // Reduced from 10
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Leave Balance Card - Fixed Grid Overflow
  Widget _buildLeaveBalanceCard() {
    if (_leaveBalance == null) {
      return Container(
        margin: responsivePadding,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            'Unable to load leave balance',
            style: TextStyle(
              color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 14 * responsiveFontSize,
            ),
          ),
        ),
      );
    }

    final summary = _leaveBalance!.getSummary();
    // Show only 4 leave types as per your requirement
    final displayTypes = ['annual', 'sick', 'local', 'emergency'];

    return Container(
      margin: responsivePadding,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Leave Balance (${DateTime.now().year})',
              style: TextStyle(
                fontSize: 16 * responsiveFontSize,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: isSmallScreen ? 2.8 : 2.5, // Increased aspect ratio
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
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Changed to spaceEvenly
                    children: [
                      Flexible(
                        flex: 1,
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: (isSmallScreen ? 8 : 9) * responsiveFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$remaining/$total',
                            style: TextStyle(
                              color: _isDarkMode ? Colors.white : Colors.black87,
                              fontSize: (isSmallScreen ? 14 : 16) * responsiveFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 1,
                        child: Text(
                          pending > 0 ? '($pending pending)' : 'available',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                            fontSize: (isSmallScreen ? 7 : 8) * responsiveFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tab Bar - Fixed Overflow Issues
  Widget _buildTabBar() {
    return Container(
      margin: responsivePadding,
      height: 50, // Fixed height to prevent overflow
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        labelStyle: TextStyle(
          fontSize: (isSmallScreen ? 9 : 10) * responsiveFontSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: (isSmallScreen ? 9 : 10) * responsiveFontSize,
          fontWeight: FontWeight.w500,
        ),
        isScrollable: false,
        dividerColor: Colors.transparent,
        tabs: [
          // Overview Tab
          Tab(
            child: Container(
              constraints: const BoxConstraints(minWidth: 0), // Allow flexible width
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard, size: isSmallScreen ? 14 : 16),
                  if (screenWidth > 380) ...[
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        'Overview',
                        style: TextStyle(fontSize: 8 * responsiveFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Pending Tab
          Tab(
            child: Container(
              constraints: const BoxConstraints(minWidth: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: isSmallScreen ? 14 : 16),
                      const SizedBox(width: 2),
                      Text(
                        '${_pendingApplications.length}',
                        style: TextStyle(fontSize: (isSmallScreen ? 9 : 10) * responsiveFontSize),
                      ),
                    ],
                  ),
                  if (screenWidth > 380) ...[
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        'Pending',
                        style: TextStyle(fontSize: 8 * responsiveFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Approved Tab
          Tab(
            child: Container(
              constraints: const BoxConstraints(minWidth: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: isSmallScreen ? 14 : 16),
                      const SizedBox(width: 2),
                      Text(
                        '${_approvedApplications.length}',
                        style: TextStyle(fontSize: (isSmallScreen ? 9 : 10) * responsiveFontSize),
                      ),
                    ],
                  ),
                  if (screenWidth > 380) ...[
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        'Approved',
                        style: TextStyle(fontSize: 8 * responsiveFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Rejected Tab
          Tab(
            child: Container(
              constraints: const BoxConstraints(minWidth: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel, size: isSmallScreen ? 14 : 16),
                      const SizedBox(width: 2),
                      Text(
                        '${_rejectedApplications.length}',
                        style: TextStyle(fontSize: (isSmallScreen ? 9 : 10) * responsiveFontSize),
                      ),
                    ],
                  ),
                  if (screenWidth > 380) ...[
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        'Rejected',
                        style: TextStyle(fontSize: 8 * responsiveFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Compact Application Card - Much Smaller Version
  Widget _buildApplicationCard(LeaveApplicationModel application, bool canCancel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Reduced from 12
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8), // Reduced from 12
        border: Border.all(
          color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12), // Reduced from 16
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - More Compact
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Reduced from 8
                  decoration: BoxDecoration(
                    color: _getStatusColor(application.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6), // Reduced from 8
                  ),
                  child: Icon(
                    _getStatusIcon(application.status),
                    color: _getStatusColor(application.status),
                    size: 14, // Reduced from 16
                  ),
                ),
                const SizedBox(width: 8), // Reduced from 12
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.leaveType.displayName,
                        style: TextStyle(
                          fontSize: 14 * responsiveFontSize, // Reduced from 16
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        application.dateRange,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 10 * responsiveFontSize, // Reduced from 12
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Reduced
                    decoration: BoxDecoration(
                      color: _getStatusColor(application.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      application.status.displayName.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(application.status),
                        fontSize: 8 * responsiveFontSize, // Reduced from 9
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8), // Reduced from 12

            // Details Row - More Compact
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12, // Reduced from 14
                  color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 6), // Reduced from 8
                Expanded(
                  child: Text(
                    '${application.totalDays} days',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 12 * responsiveFontSize, // Reduced from 14
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (application.certificateUrl != null) ...[
                  Icon(
                    Icons.attachment,
                    size: 12, // Reduced from 14
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Cert',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 8 * responsiveFontSize, // Reduced from 10
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6), // Reduced from 8

            // Reason - More Compact
            Text(
              'Reason: ${application.reason}',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 10 * responsiveFontSize, // Reduced from 12
              ),
              maxLines: 1, // Reduced from 2
              overflow: TextOverflow.ellipsis,
            ),

            // Manager Comments - More Compact
            if (application.reviewComments != null && application.reviewComments!.isNotEmpty) ...[
              const SizedBox(height: 6), // Reduced from 8
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6), // Reduced from 8
                decoration: BoxDecoration(
                  color: application.status == LeaveStatus.approved
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // Reduced from 8
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.comment,
                      size: 12, // Reduced from 14
                      color: application.status == LeaveStatus.approved
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 6), // Reduced from 8
                    Expanded(
                      child: Text(
                        application.reviewComments!,
                        style: TextStyle(
                          fontSize: 9 * responsiveFontSize, // Reduced from 11
                          color: application.status == LeaveStatus.approved
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                        maxLines: 1, // Reduced from 2
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancel button for pending applications - More Compact
            if (canCancel && application.status == LeaveStatus.pending) ...[
              const SizedBox(height: 8), // Reduced from 12
              SizedBox(
                width: double.infinity,
                height: 32, // Reduced from 36
                child: OutlinedButton.icon(
                  onPressed: () => _showCancelDialog(application),
                  icon: const Icon(Icons.cancel, size: 14), // Reduced from 16
                  label: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 10 * responsiveFontSize), // Reduced from 12
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6), // Reduced from 8
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Applications List
  Widget _buildApplicationsList(List<LeaveApplicationModel> applications, bool canCancel) {
    if (applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Applications Found',
              style: TextStyle(
                fontSize: 18 * responsiveFontSize,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your leave applications will appear here',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14 * responsiveFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          responsivePadding.horizontal,
          8,
          responsivePadding.horizontal,
          100, // Extra padding for FAB
        ),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final application = applications[index];
          return _buildApplicationCard(application, canCancel);
        },
      ),
    );
  }

  // Overview Tab - More Compact and Better Organized
  Widget _buildOverviewTab() {
    final recentApplications = _allApplications.take(3).toList(); // Show only 3 instead of 5

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF2563EB),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4), // Reduced from 8

            // Quick Stats - More Compact
            _buildQuickStats(),

            const SizedBox(height: 8), // Reduced spacing

            // Leave Balance Card - More Compact
            _buildLeaveBalanceCard(),

            const SizedBox(height: 8), // Reduced spacing

            // Recent Applications Section
            if (recentApplications.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsivePadding.horizontal,
                  vertical: 4, // Reduced from default
                ),
                child: Row(
                  children: [
                    Text(
                      'Recent Applications',
                      style: TextStyle(
                        fontSize: 16 * responsiveFontSize, // Reduced from 18
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${recentApplications.length} of ${_allApplications.length}',
                      style: TextStyle(
                        fontSize: 12 * responsiveFontSize,
                        color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Recent Applications List - More Compact
              Padding(
                padding: EdgeInsets.symmetric(horizontal: responsivePadding.horizontal),
                child: Column(
                  children: recentApplications.map((app) =>
                      _buildApplicationCard(app, app.status == LeaveStatus.pending)
                  ).toList(),
                ),
              ),
            ] else ...[
              // Empty State - More Compact
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: responsivePadding.horizontal,
                  vertical: 8,
                ),
                padding: const EdgeInsets.all(24), // Reduced from 32
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 48, // Reduced from 64
                        color: _isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12), // Reduced from 16
                      Text(
                        'No leave applications yet',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 14 * responsiveFontSize, // Reduced from 16
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the + button to apply for leave',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                          fontSize: 12 * responsiveFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 80), // Space for FAB - Reduced from 100
          ],
        ),
      ),
    );
  }

  // Navigation and dialogs
  Future<void> _navigateToApplyLeave() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyLeaveView(
          employeeId: widget.employeeId,
          employeeName: widget.employeeName,
          employeePin: widget.employeePin,
          userData: widget.userData,
        ),
      ),
    );

    if (result == true) {
      await _refreshData();
    }
  }

  Future<void> _showCancelDialog(LeaveApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Application',
                style: TextStyle(
                  fontSize: 18 * responsiveFontSize,
                  color: _isDarkMode ? Colors.white : Colors.black87,
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
              'Are you sure you want to cancel this leave application?',
              style: TextStyle(
                fontSize: 14 * responsiveFontSize,
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Type: ${application.leaveType.displayName}',
                    style: TextStyle(
                      fontSize: 12 * responsiveFontSize,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Dates: ${application.dateRange}',
                    style: TextStyle(
                      fontSize: 12 * responsiveFontSize,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Days: ${application.totalDays}',
                    style: TextStyle(
                      fontSize: 12 * responsiveFontSize,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelApplication(application);
    }
  }

  Future<void> _cancelApplication(LeaveApplicationModel application) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
              const SizedBox(height: 16),
              Text(
                'Cancelling application...',
                style: TextStyle(
                  fontSize: 14 * responsiveFontSize,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );

      final success = await _leaveService.cancelLeaveApplication(application.id!);

      Navigator.pop(context); // Close loading dialog

      if (success) {
        CustomSnackBar.successSnackBar("Leave application cancelled successfully");
        await _refreshData();
      } else {
        CustomSnackBar.errorSnackBar("Failed to cancel application");
      }
    } catch (e) {
      Navigator.pop(context);
      CustomSnackBar.errorSnackBar("Error: $e");
    }
  }

  // Helper methods
  Color _getStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
      case LeaveStatus.cancelled:
        return Colors.grey;
      case LeaveStatus.pending:
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return Icons.check_circle;
      case LeaveStatus.rejected:
        return Icons.cancel;
      case LeaveStatus.cancelled:
        return Icons.block;
      case LeaveStatus.pending:
      default:
        return Icons.schedule;
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

                  // Tab Bar
                  _buildTabBar(),

                  const SizedBox(height: 8),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildApplicationsList(_pendingApplications, true),
                        _buildApplicationsList(_approvedApplications, false),
                        _buildApplicationsList(_rejectedApplications, false),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: FloatingActionButton.extended(
                onPressed: _navigateToApplyLeave,
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Apply Leave',
                  style: TextStyle(
                    fontSize: 14 * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



