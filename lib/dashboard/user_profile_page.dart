// lib/dashboard/user_profile_page.dart - FIXED OVERFLOW + NOTIFICATION SYSTEM + DATA PERSISTENCE

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Country model class with flag URL
class CountryData {
  final String name;
  final String code;
  final String flagUrl;
  final bool isOther;

  CountryData({
    required this.name,
    required this.code,
    required this.flagUrl,
    this.isOther = false,
  });
}

class UserProfilePage extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> userData;

  const UserProfilePage({
    Key? key,
    required this.employeeId,
    required this.userData,
  }) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _birthdateController;
  late TextEditingController _otherCountryController;

  // Break time controllers
  late TextEditingController _breakStartTimeController;
  late TextEditingController _breakEndTimeController;
  late TextEditingController _jummaBreakStartController;
  late TextEditingController _jummaBreakEndController;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isEditing = false;
  bool _isLoading = false;
  bool _hasJummaBreak = false;
  bool _isDarkMode = false;
  bool _showOtherCountryField = false;
  bool _showNotificationBanner = true;
  CountryData? _selectedCountry;

  // Document upload states
  Map<String, String?> _uploadedDocuments = {
    'degree_certificate': null,
    'passport': null,
    'visa': null,
    'emirates_id': null,
    'other_documents': null,
  };

  // Countries with real flag image URLs (top countries for UAE context)
  final List<CountryData> _countries = [
    CountryData(name: "United Arab Emirates", code: "AE", flagUrl: "https://flagcdn.com/w40/ae.png"),
    CountryData(name: "India", code: "IN", flagUrl: "https://flagcdn.com/w40/in.png"),
    CountryData(name: "Pakistan", code: "PK", flagUrl: "https://flagcdn.com/w40/pk.png"),
    CountryData(name: "Bangladesh", code: "BD", flagUrl: "https://flagcdn.com/w40/bd.png"),
    CountryData(name: "Philippines", code: "PH", flagUrl: "https://flagcdn.com/w40/ph.png"),
    CountryData(name: "Egypt", code: "EG", flagUrl: "https://flagcdn.com/w40/eg.png"),
    CountryData(name: "Jordan", code: "JO", flagUrl: "https://flagcdn.com/w40/jo.png"),
    CountryData(name: "Lebanon", code: "LB", flagUrl: "https://flagcdn.com/w40/lb.png"),
    CountryData(name: "Syria", code: "SY", flagUrl: "https://flagcdn.com/w40/sy.png"),
    CountryData(name: "Nepal", code: "NP", flagUrl: "https://flagcdn.com/w40/np.png"),
    CountryData(name: "Sri Lanka", code: "LK", flagUrl: "https://flagcdn.com/w40/lk.png"),
    CountryData(name: "Afghanistan", code: "AF", flagUrl: "https://flagcdn.com/w40/af.png"),
    CountryData(name: "Iran", code: "IR", flagUrl: "https://flagcdn.com/w40/ir.png"),
    CountryData(name: "Iraq", code: "IQ", flagUrl: "https://flagcdn.com/w40/iq.png"),
    CountryData(name: "Palestine", code: "PS", flagUrl: "https://flagcdn.com/w40/ps.png"),
    CountryData(name: "Yemen", code: "YE", flagUrl: "https://flagcdn.com/w40/ye.png"),
    CountryData(name: "Sudan", code: "SD", flagUrl: "https://flagcdn.com/w40/sd.png"),
    CountryData(name: "Morocco", code: "MA", flagUrl: "https://flagcdn.com/w40/ma.png"),
    CountryData(name: "Algeria", code: "DZ", flagUrl: "https://flagcdn.com/w40/dz.png"),
    CountryData(name: "Tunisia", code: "TN", flagUrl: "https://flagcdn.com/w40/tn.png"),
    CountryData(name: "Libya", code: "LY", flagUrl: "https://flagcdn.com/w40/ly.png"),
    CountryData(name: "Saudi Arabia", code: "SA", flagUrl: "https://flagcdn.com/w40/sa.png"),
    CountryData(name: "Kuwait", code: "KW", flagUrl: "https://flagcdn.com/w40/kw.png"),
    CountryData(name: "Qatar", code: "QA", flagUrl: "https://flagcdn.com/w40/qa.png"),
    CountryData(name: "Bahrain", code: "BH", flagUrl: "https://flagcdn.com/w40/bh.png"),
    CountryData(name: "Oman", code: "OM", flagUrl: "https://flagcdn.com/w40/om.png"),
    CountryData(name: "Ethiopia", code: "ET", flagUrl: "https://flagcdn.com/w40/et.png"),
    CountryData(name: "Somalia", code: "SO", flagUrl: "https://flagcdn.com/w40/so.png"),
    CountryData(name: "Eritrea", code: "ER", flagUrl: "https://flagcdn.com/w40/er.png"),
    CountryData(name: "Turkey", code: "TR", flagUrl: "https://flagcdn.com/w40/tr.png"),
    CountryData(name: "United Kingdom", code: "GB", flagUrl: "https://flagcdn.com/w40/gb.png"),
    CountryData(name: "United States", code: "US", flagUrl: "https://flagcdn.com/w40/us.png"),
    CountryData(name: "Canada", code: "CA", flagUrl: "https://flagcdn.com/w40/ca.png"),
    CountryData(name: "Australia", code: "AU", flagUrl: "https://flagcdn.com/w40/au.png"),
    CountryData(name: "Germany", code: "DE", flagUrl: "https://flagcdn.com/w40/de.png"),
    CountryData(name: "France", code: "FR", flagUrl: "https://flagcdn.com/w40/fr.png"),
    CountryData(name: "Italy", code: "IT", flagUrl: "https://flagcdn.com/w40/it.png"),
    CountryData(name: "Spain", code: "ES", flagUrl: "https://flagcdn.com/w40/es.png"),
    CountryData(name: "Netherlands", code: "NL", flagUrl: "https://flagcdn.com/w40/nl.png"),
    CountryData(name: "Russia", code: "RU", flagUrl: "https://flagcdn.com/w40/ru.png"),
    CountryData(name: "China", code: "CN", flagUrl: "https://flagcdn.com/w40/cn.png"),
    CountryData(name: "Japan", code: "JP", flagUrl: "https://flagcdn.com/w40/jp.png"),
    CountryData(name: "South Korea", code: "KR", flagUrl: "https://flagcdn.com/w40/kr.png"),
    CountryData(name: "Indonesia", code: "ID", flagUrl: "https://flagcdn.com/w40/id.png"),
    CountryData(name: "Malaysia", code: "MY", flagUrl: "https://flagcdn.com/w40/my.png"),
    CountryData(name: "Thailand", code: "TH", flagUrl: "https://flagcdn.com/w40/th.png"),
    CountryData(name: "Vietnam", code: "VN", flagUrl: "https://flagcdn.com/w40/vn.png"),
    CountryData(name: "Brazil", code: "BR", flagUrl: "https://flagcdn.com/w40/br.png"),
    CountryData(name: "Argentina", code: "AR", flagUrl: "https://flagcdn.com/w40/ar.png"),
    CountryData(name: "South Africa", code: "ZA", flagUrl: "https://flagcdn.com/w40/za.png"),
    // Other option at the end
    CountryData(
        name: "Other (Not Listed)",
        code: "OTHER",
        flagUrl: "https://flagcdn.com/w40/un.png",
        isOther: true
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDarkModePreference();
    _initializeAnimations();
    _initializeControllers();
    _loadUploadedDocuments();
    _checkProfileCompleteness();
  }

  void _checkProfileCompleteness() {
    // Check if phone or email is missing
    final phone = widget.userData['phone']?.toString().trim() ?? '';
    final email = widget.userData['email']?.toString().trim() ?? '';

    setState(() {
      _showNotificationBanner = phone.isEmpty || email.isEmpty;
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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

    _animationController.forward();
  }

  void _initializeControllers() {
    // Fix: Ensure proper null handling and string conversion
    _nameController = TextEditingController(text: widget.userData['name']?.toString() ?? '');
    _designationController = TextEditingController(text: widget.userData['designation']?.toString() ?? '');
    _departmentController = TextEditingController(text: widget.userData['department']?.toString() ?? '');

    // FIXED: Proper handling for phone and email
    _phoneController = TextEditingController(text: widget.userData['phone']?.toString() ?? '');
    _emailController = TextEditingController(text: widget.userData['email']?.toString() ?? '');

    _birthdateController = TextEditingController(text: widget.userData['birthdate']?.toString() ?? '');
    _otherCountryController = TextEditingController(text: '');

    // Initialize country selection
    String? countryName = widget.userData['country'];
    if (countryName != null && countryName.isNotEmpty) {
      _selectedCountry = _countries.firstWhere(
            (country) => country.name == countryName,
        orElse: () {
          _showOtherCountryField = true;
          _otherCountryController.text = countryName;
          return _countries.firstWhere((country) => country.isOther);
        },
      );
    }

    _breakStartTimeController = TextEditingController(text: widget.userData['breakStartTime'] ?? '');
    _breakEndTimeController = TextEditingController(text: widget.userData['breakEndTime'] ?? '');
    _hasJummaBreak = widget.userData['hasJummaBreak'] ?? false;
    _jummaBreakStartController = TextEditingController(text: widget.userData['jummaBreakStart'] ?? '');
    _jummaBreakEndController = TextEditingController(text: widget.userData['jummaBreakEnd'] ?? '');
  }

  void _loadUploadedDocuments() {
    // Load existing documents from userData
    setState(() {
      _uploadedDocuments = {
        'degree_certificate': widget.userData['degree_certificate'],
        'passport': widget.userData['passport'],
        'visa': widget.userData['visa'],
        'emirates_id': widget.userData['emirates_id'],
        'other_documents': widget.userData['other_documents'],
      };
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthdateController.dispose();
    _otherCountryController.dispose();
    _breakStartTimeController.dispose();
    _breakEndTimeController.dispose();
    _jummaBreakStartController.dispose();
    _jummaBreakEndController.dispose();
    super.dispose();
  }

  // Responsive design helper methods
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isTablet => screenWidth > 600;
  bool get isSmallScreen => screenWidth < 360;

  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
    horizontal: isTablet ? 24.0 : (isSmallScreen ? 12.0 : 16.0),
    vertical: isTablet ? 20.0 : (isSmallScreen ? 12.0 : 16.0),
  );

  double get responsiveFontSize {
    if (isTablet) return 1.2;
    if (isSmallScreen) return 0.9;
    return 1.0;
  }

  Future<void> _loadDarkModePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ),
    );
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _isDarkMode
                ? ColorScheme.dark(primary: const Color(0xFF6366F1))
                : ColorScheme.light(primary: const Color(0xFF6366F1)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  // Build flag image widget
  Widget _buildFlagImage(String flagUrl, {double size = 24}) {
    return Container(
      width: size,
      height: size * 0.75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.network(
          flagUrl,
          width: size,
          height: size * 0.75,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: Icon(
                Icons.flag_outlined,
                size: size * 0.6,
                color: Colors.grey[400],
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: SizedBox(
                width: size * 0.6,
                height: size * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: const Color(0xFF6366F1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _uploadDocument(String documentType) async {
    // TODO: Implement file picker and Firebase storage upload
    // For now, just show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Upload ${_getDocumentDisplayName(documentType)}",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Document upload functionality will be implemented with Firebase Storage.",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "OK",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _getDocumentDisplayName(String documentType) {
    switch (documentType) {
      case 'degree_certificate':
        return 'Degree Certificate';
      case 'passport':
        return 'Passport';
      case 'visa':
        return 'Visa';
      case 'emirates_id':
        return 'Emirates ID';
      case 'other_documents':
        return 'Other Documents';
      default:
        return 'Document';
    }
  }

  IconData _getDocumentIcon(String documentType) {
    switch (documentType) {
      case 'degree_certificate':
        return Icons.school;
      case 'passport':
        return Icons.card_travel;
      case 'visa':
        return Icons.card_membership;
      case 'emirates_id':
        return Icons.badge;
      case 'other_documents':
        return Icons.folder;
      default:
        return Icons.description;
    }
  }

  // FIXED SAVE PROFILE METHOD - THIS IS THE KEY FIX
  // FIXED SAVE PROFILE METHOD
  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackBar.errorSnackBar(context, "Name cannot be empty");
      return;
    }

    // Validate country selection
    if (_selectedCountry == null) {
      CustomSnackBar.errorSnackBar(context, "Please select a country");
      return;
    }

    // Validate "Other" country field
    if (_selectedCountry?.isOther == true && _otherCountryController.text.trim().isEmpty) {
      CustomSnackBar.errorSnackBar(context, "Please specify your country name");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine country name to save - THIS WAS MISSING!
      String countryToSave = _selectedCountry!.isOther
          ? _otherCountryController.text.trim()
          : _selectedCountry!.name;

      // Create updated data map with explicit string conversion
      Map<String, dynamic> updatedData = {
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),

        // FIXED: Ensure these are saved as strings, not null
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),

        'country': countryToSave,
        'countryCode': _selectedCountry!.isOther ? 'OTHER' : _selectedCountry!.code,
        'birthdate': _birthdateController.text.trim(),
        'breakStartTime': _breakStartTimeController.text.trim(),
        'breakEndTime': _breakEndTimeController.text.trim(),
        'hasJummaBreak': _hasJummaBreak,
        'jummaBreakStart': _jummaBreakStartController.text.trim(),
        'jummaBreakEnd': _jummaBreakEndController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .update(updatedData);

      // *** KEY FIX: Update the local userData map with new values ***
      // This ensures the data persists when reopening the profile
      widget.userData.addAll({
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'country': countryToSave,
        'countryCode': _selectedCountry!.isOther ? 'OTHER' : _selectedCountry!.code,
        'birthdate': _birthdateController.text.trim(),
        'breakStartTime': _breakStartTimeController.text.trim(),
        'breakEndTime': _breakEndTimeController.text.trim(),
        'hasJummaBreak': _hasJummaBreak,
        'jummaBreakStart': _jummaBreakStartController.text.trim(),
        'jummaBreakEnd': _jummaBreakEndController.text.trim(),
      });

      setState(() {
        _isLoading = false;
        _isEditing = false;
      });

      // Check if notification should be hidden now
      _checkProfileCompleteness();

      if (mounted) {
        CustomSnackBar.successSnackBar(context, "Profile updated successfully");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        CustomSnackBar.errorSnackBar(context, "Error updating profile: $e");
      }
    }
  }

  void _dismissNotificationBanner() {
    setState(() {
      _showNotificationBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
        body: _isLoading
            ? _buildLoadingScreen()
            : AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildFixedHeader(),
                  if (_showNotificationBanner) _buildNotificationBanner(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Column(
                              children: [
                                _buildProfileDetailsSection(),
                                const SizedBox(height: 100),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF0A0E1A), const Color(0xFF1E293B)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
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
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDarkMode ? Colors.white : Colors.white,
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Updating profile...',
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

  Widget _buildNotificationBanner() {
    final phone = widget.userData['phone']?.toString().trim() ?? '';
    final email = widget.userData['email']?.toString().trim() ?? '';

    List<String> missingFields = [];
    if (phone.isEmpty) missingFields.add('mobile number');
    if (email.isEmpty) missingFields.add('email address');

    if (missingFields.isEmpty) return const SizedBox.shrink();

    String message = "Please add your ${missingFields.join(' and ')} to complete your profile";

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: responsivePadding.horizontal,
        vertical: 8,
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.amber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange[700],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Complete Your Profile",
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isEditing)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[700],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "Edit",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _dismissNotificationBanner,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: Colors.orange[600],
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader() {
    String? imageBase64 = widget.userData['image'];

    return Container(
      height: isTablet ? 280 : 240,
      width: double.infinity,
      child: Stack(
        children: [
          // Simple Company Header Background
          Container(
            height: isTablet ? 140 : 120,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/company_banner.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsivePadding.horizontal,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (_isEditing) {
                            _showDiscardDialog();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),

                    const Spacer(), // This pushes the edit button to the right

                    // Edit Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isEditing ? Icons.save : Icons.edit,
                          color: Colors.white,
                        ),
                        onPressed: _isEditing ? _saveProfile : _toggleEditing,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Profile Section
          Positioned(
            top: isTablet ? 80 : 70,
            left: 0,
            right: 0,
            child: Container(
              padding: responsivePadding,
              child: Column(
                children: [
                  // Profile Picture
                  Hero(
                    tag: 'profile_${widget.employeeId}',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: isTablet ? 70 : 60,
                            backgroundColor: _isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            backgroundImage: imageBase64 != null
                                ? MemoryImage(base64Decode(imageBase64))
                                : null,
                            child: imageBase64 == null
                                ? Icon(
                              Icons.person,
                              color: _isDarkMode
                                  ? Colors.grey.shade300
                                  : Colors.grey,
                              size: isTablet ? 70 : 60,
                            )
                                : null,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.photo_camera,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Name and Designation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Name
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : "Employee Name",
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontSize: (isTablet ? 24 : 20) * responsiveFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Designation
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _designationController.text.isNotEmpty
                                ? _designationController.text
                                : "Employee",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsSection() {
    return Container(
      margin: responsivePadding,
      child: Column(
        children: [
          _buildModernSection(
            title: "Contact Information",
            icon: Icons.contact_phone,
            children: [
              _buildModernInfoField(
                label: "Phone",
                controller: _phoneController,
                icon: Icons.phone,
                isEditing: _isEditing,
                keyboardType: TextInputType.phone,
              ),
              _buildModernInfoField(
                label: "Email",
                controller: _emailController,
                icon: Icons.email,
                isEditing: _isEditing,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Work Information",
            icon: Icons.business_center,
            children: [
              _buildModernInfoField(
                label: "Department",
                controller: _departmentController,
                icon: Icons.business,
                isEditing: _isEditing,
              ),
              _buildModernInfoField(
                label: "Designation",
                controller: _designationController,
                icon: Icons.work,
                isEditing: _isEditing,
              ),
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Personal Information",
            icon: Icons.person,
            children: [
              _buildModernInfoField(
                label: "Birthdate",
                controller: _birthdateController,
                icon: Icons.cake,
                isEditing: _isEditing,
              ),
              // Country Dropdown
              _buildCountryDropdown(
                label: "Country",
                enabled: _isEditing,
                icon: Icons.location_on,
              ),
              // Other Country Text Field (shown when "Other" is selected)
              if (_showOtherCountryField)
                _buildModernInfoField(
                  label: "Please specify your country",
                  controller: _otherCountryController,
                  icon: Icons.edit_location_outlined,
                  isEditing: _isEditing,
                ),
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          _buildModernSection(
            title: "Break Time Information",
            icon: Icons.schedule,
            children: [
              _buildModernTimeField(
                label: "Daily Break Time",
                startController: _breakStartTimeController,
                endController: _breakEndTimeController,
                icon: Icons.coffee,
                isEditing: _isEditing,
              ),

              if (_isEditing) ...[
                const SizedBox(height: 16),
                _buildModernSwitchTile(
                  title: "Friday Prayer Break",
                  subtitle: "Enable if you take Friday prayer break",
                  value: _hasJummaBreak,
                  onChanged: (value) {
                    setState(() {
                      _hasJummaBreak = value;
                      if (!value) {
                        _jummaBreakStartController.clear();
                        _jummaBreakEndController.clear();
                      }
                    });
                  },
                ),
              ],

              if (_hasJummaBreak) ...[
                const SizedBox(height: 16),
                _buildModernTimeField(
                  label: "Friday Prayer Break",
                  startController: _jummaBreakStartController,
                  endController: _jummaBreakEndController,
                  icon: Icons.mosque,
                  isEditing: _isEditing,
                ),
              ],
            ],
          ),

          SizedBox(height: responsivePadding.vertical),

          // Documents Upload Section
          _buildModernSection(
            title: "Documents",
            icon: Icons.folder_open,
            children: [
              _buildDocumentUploadGrid(),
            ],
          ),

          if (_isEditing) ...[
            SizedBox(height: responsivePadding.vertical * 2),
            _buildModernSaveButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildCountryDropdown({
    required String label,
    bool enabled = false,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                label,
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          enabled
              ? DropdownButtonFormField<CountryData>(
            value: _selectedCountry,
            decoration: InputDecoration(
              hintText: "Select your country",
              hintStyle: TextStyle(
                color: _isDarkMode
                    ? Colors.grey.shade500
                    : Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            dropdownColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            isExpanded: true,
            menuMaxHeight: 300,
            items: _countries.map((CountryData country) {
              return DropdownMenuItem<CountryData>(
                value: country,
                child: Row(
                  children: [
                    _buildFlagImage(
                      country.flagUrl,
                      size: isTablet ? 28 : 24,
                    ),
                    SizedBox(width: isTablet ? 12 : 10),
                    Expanded(
                      child: Text(
                        country.name,
                        style: TextStyle(
                          color: country.isOther
                              ? Theme.of(context).colorScheme.primary
                              : (_isDarkMode ? Colors.white : Colors.black87),
                          fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                          fontWeight: country.isOther
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (CountryData? newCountry) {
              setState(() {
                _selectedCountry = newCountry;
                _showOtherCountryField = newCountry?.isOther ?? false;
                if (!_showOtherCountryField) {
                  _otherCountryController.clear();
                }
              });
            },
          )
              : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                if (_selectedCountry != null) ...[
                  _buildFlagImage(
                    _selectedCountry!.flagUrl,
                    size: isTablet ? 24 : 20,
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                ],
                Expanded(
                  child: Text(
                    _selectedCountry?.name ?? "Not selected",
                    style: TextStyle(
                      fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                      color: _selectedCountry != null
                          ? (_isDarkMode ? Colors.white : Colors.black87)
                          : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                      fontWeight: FontWeight.w500,
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

  Widget _buildDocumentUploadGrid() {
    return Column(
      children: [
        Text(
          "Upload your documents for verification",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTablet ? 1.2 : 1.0,
          children: _uploadedDocuments.keys.map((documentType) {
            bool isUploaded = _uploadedDocuments[documentType] != null;
            return GestureDetector(
              onTap: () => _uploadDocument(documentType),
              child: Container(
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUploaded
                        ? Colors.green.withOpacity(0.5)
                        : (_isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.2)),
                    width: isUploaded ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUploaded
                            ? Colors.green.withOpacity(0.1)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUploaded ? Icons.check_circle : _getDocumentIcon(documentType),
                        color: isUploaded
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                        size: isTablet ? 32 : 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDocumentDisplayName(documentType),
                      style: TextStyle(
                        fontSize: (isTablet ? 12 : 10) * responsiveFontSize,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUploaded ? "Uploaded" : "Tap to upload",
                      style: TextStyle(
                        fontSize: (isTablet ? 10 : 9) * responsiveFontSize,
                        color: isUploaded
                            ? Colors.green
                            : (_isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isTablet ? 20 : 18) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 1,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                isEditing
                    ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter $label",
                    hintStyle: TextStyle(
                      color: _isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    : Text(
                  controller.text.isNotEmpty
                      ? controller.text
                      : "Not provided",
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    color: controller.text.isNotEmpty
                        ? (_isDarkMode ? Colors.white : Colors.black87)
                        : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTimeField({
    required String label,
    required TextEditingController startController,
    required TextEditingController endController,
    required IconData icon,
    required bool isEditing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
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
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeSelector(
                  controller: startController,
                  hint: "Start time",
                  isEditing: isEditing,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "to",
                  style: TextStyle(
                    fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _buildTimeSelector(
                  controller: endController,
                  hint: "End time",
                  isEditing: isEditing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required TextEditingController controller,
    required String hint,
    required bool isEditing,
  }) {
    return GestureDetector(
      onTap: isEditing ? () => _selectTime(controller) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: _isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                controller.text.isNotEmpty ? controller.text : hint,
                style: TextStyle(
                  fontSize: (isTablet ? 14 : 12) * responsiveFontSize,
                  color: controller.text.isNotEmpty
                      ? (_isDarkMode ? Colors.white : Colors.black87)
                      : (_isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.mosque,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: (isTablet ? 16 : 14) * responsiveFontSize,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: (isTablet ? 12 : 11) * responsiveFontSize,
                    color: _isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSaveButton() {
    return Container(
      width: double.infinity,
      height: isTablet ? 60 : 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveProfile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "Save Changes",
                  style: TextStyle(
                    fontSize: (isTablet ? 18 : 16) * responsiveFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Discard Changes?",
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Any unsaved changes will be lost. Are you sure you want to continue?",
          style: TextStyle(
            color: _isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isEditing = false;
              });
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Discard"),
          ),
        ],
      ),
    );
  }
}



