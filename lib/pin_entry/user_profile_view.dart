// lib/pin_entry/user_profile_view.dart - Complete Enhanced Implementation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/common/utils/custom_snackbar.dart';
import 'package:face_auth_compatible/common/views/custom_button.dart';
import 'package:face_auth_compatible/constants/theme.dart';
import 'package:face_auth_compatible/model/user_model.dart';
import 'package:face_auth_compatible/register_face/register_face_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Date Input Formatter for auto-formatting birthdate
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll('/', '');

    if (text.length > 8) {
      text = text.substring(0, 8);
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '/';
      }
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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

class UserProfileView extends StatefulWidget {
  final String employeePin;
  final UserModel user;
  final bool isNewUser;

  const UserProfileView({
    Key? key,
    required this.employeePin,
    required this.user,
    required this.isNewUser,
  }) : super(key: key);

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _birthdateController;
  late TextEditingController _emailController;
  late TextEditingController _otherCountryController;

  // Break time controllers
  late TextEditingController _breakStartTimeController;
  late TextEditingController _breakEndTimeController;
  late TextEditingController _jummaBreakStartController;
  late TextEditingController _jummaBreakEndController;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _hasJummaBreak = false;
  CountryData? _selectedCountry;
  bool _showOtherCountryField = false;

  // Animation controllers
  late AnimationController _breakSectionController;
  late AnimationController _jummaBreakController;
  late Animation<double> _breakSectionAnimation;
  late Animation<double> _jummaBreakAnimation;

  // Countries with real flag image URLs
  final List<CountryData> _countries = [
    CountryData(name: "Afghanistan", code: "AF", flagUrl: "https://flagcdn.com/w40/af.png"),
    CountryData(name: "Albania", code: "AL", flagUrl: "https://flagcdn.com/w40/al.png"),
    CountryData(name: "Algeria", code: "DZ", flagUrl: "https://flagcdn.com/w40/dz.png"),
    CountryData(name: "United Arab Emirates", code: "AE", flagUrl: "https://flagcdn.com/w40/ae.png"),
    CountryData(name: "United Kingdom", code: "GB", flagUrl: "https://flagcdn.com/w40/gb.png"),
    CountryData(name: "United States", code: "US", flagUrl: "https://flagcdn.com/w40/us.png"),
    CountryData(name: "India", code: "IN", flagUrl: "https://flagcdn.com/w40/in.png"),
    CountryData(name: "Pakistan", code: "PK", flagUrl: "https://flagcdn.com/w40/pk.png"),
    CountryData(name: "Bangladesh", code: "BD", flagUrl: "https://flagcdn.com/w40/bd.png"),
    CountryData(name: "Philippines", code: "PH", flagUrl: "https://flagcdn.com/w40/ph.png"),
    CountryData(name: "Egypt", code: "EG", flagUrl: "https://flagcdn.com/w40/eg.png"),
    CountryData(name: "Saudi Arabia", code: "SA", flagUrl: "https://flagcdn.com/w40/sa.png"),
    CountryData(name: "Qatar", code: "QA", flagUrl: "https://flagcdn.com/w40/qa.png"),
    CountryData(name: "Kuwait", code: "KW", flagUrl: "https://flagcdn.com/w40/kw.png"),
    CountryData(name: "Oman", code: "OM", flagUrl: "https://flagcdn.com/w40/om.png"),
    CountryData(name: "Bahrain", code: "BH", flagUrl: "https://flagcdn.com/w40/bh.png"),
    CountryData(name: "Jordan", code: "JO", flagUrl: "https://flagcdn.com/w40/jo.png"),
    CountryData(name: "Lebanon", code: "LB", flagUrl: "https://flagcdn.com/w40/lb.png"),
    CountryData(name: "Syria", code: "SY", flagUrl: "https://flagcdn.com/w40/sy.png"),
    CountryData(name: "Iraq", code: "IQ", flagUrl: "https://flagcdn.com/w40/iq.png"),
    CountryData(name: "Iran", code: "IR", flagUrl: "https://flagcdn.com/w40/ir.png"),
    CountryData(name: "Turkey", code: "TR", flagUrl: "https://flagcdn.com/w40/tr.png"),
    CountryData(name: "Canada", code: "CA", flagUrl: "https://flagcdn.com/w40/ca.png"),
    CountryData(name: "Australia", code: "AU", flagUrl: "https://flagcdn.com/w40/au.png"),
    CountryData(name: "Germany", code: "DE", flagUrl: "https://flagcdn.com/w40/de.png"),
    CountryData(name: "France", code: "FR", flagUrl: "https://flagcdn.com/w40/fr.png"),
    CountryData(name: "Italy", code: "IT", flagUrl: "https://flagcdn.com/w40/it.png"),
    CountryData(name: "Spain", code: "ES", flagUrl: "https://flagcdn.com/w40/es.png"),
    CountryData(name: "Netherlands", code: "NL", flagUrl: "https://flagcdn.com/w40/nl.png"),
    CountryData(name: "Singapore", code: "SG", flagUrl: "https://flagcdn.com/w40/sg.png"),
    CountryData(name: "Malaysia", code: "MY", flagUrl: "https://flagcdn.com/w40/my.png"),
    CountryData(name: "Indonesia", code: "ID", flagUrl: "https://flagcdn.com/w40/id.png"),
    CountryData(name: "Thailand", code: "TH", flagUrl: "https://flagcdn.com/w40/th.png"),
    CountryData(name: "Sri Lanka", code: "LK", flagUrl: "https://flagcdn.com/w40/lk.png"),
    CountryData(name: "Nepal", code: "NP", flagUrl: "https://flagcdn.com/w40/np.png"),
    CountryData(name: "China", code: "CN", flagUrl: "https://flagcdn.com/w40/cn.png"),
    CountryData(name: "Japan", code: "JP", flagUrl: "https://flagcdn.com/w40/jp.png"),
    CountryData(name: "South Korea", code: "KR", flagUrl: "https://flagcdn.com/w40/kr.png"),
    CountryData(name: "Vietnam", code: "VN", flagUrl: "https://flagcdn.com/w40/vn.png"),
    CountryData(name: "South Africa", code: "ZA", flagUrl: "https://flagcdn.com/w40/za.png"),
    CountryData(name: "Nigeria", code: "NG", flagUrl: "https://flagcdn.com/w40/ng.png"),
    CountryData(name: "Kenya", code: "KE", flagUrl: "https://flagcdn.com/w40/ke.png"),
    CountryData(name: "Ethiopia", code: "ET", flagUrl: "https://flagcdn.com/w40/et.png"),
    CountryData(name: "Morocco", code: "MA", flagUrl: "https://flagcdn.com/w40/ma.png"),
    CountryData(name: "Brazil", code: "BR", flagUrl: "https://flagcdn.com/w40/br.png"),
    CountryData(name: "Mexico", code: "MX", flagUrl: "https://flagcdn.com/w40/mx.png"),
    CountryData(name: "Argentina", code: "AR", flagUrl: "https://flagcdn.com/w40/ar.png"),
    CountryData(name: "Russia", code: "RU", flagUrl: "https://flagcdn.com/w40/ru.png"),
    CountryData(name: "Ukraine", code: "UA", flagUrl: "https://flagcdn.com/w40/ua.png"),
    CountryData(name: "Poland", code: "PL", flagUrl: "https://flagcdn.com/w40/pl.png"),
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

    // Set clean status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _initializeControllers();
    _initializeAnimations();
    _loadUserData();

    // If new user, enable editing by default
    _isEditing = widget.isNewUser;

    // Start break section animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _breakSectionController.forward();
      }
    });
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _designationController = TextEditingController();
    _departmentController = TextEditingController();
    _birthdateController = TextEditingController();
    _emailController = TextEditingController();
    _otherCountryController = TextEditingController();
    _breakStartTimeController = TextEditingController();
    _breakEndTimeController = TextEditingController();
    _jummaBreakStartController = TextEditingController();
    _jummaBreakEndController = TextEditingController();
  }

  void _initializeAnimations() {
    _breakSectionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _jummaBreakController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _breakSectionAnimation = CurvedAnimation(
      parent: _breakSectionController,
      curve: Curves.easeInOutCubic,
    );
    _jummaBreakAnimation = CurvedAnimation(
      parent: _jummaBreakController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _loadUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.user.id)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _designationController.text = data['designation'] ?? '';
          _departmentController.text = data['department'] ?? '';
          _birthdateController.text = data['birthdate'] ?? '';
          _emailController.text = data['email'] ?? '';

          // Handle country selection
          String? countryName = data['country'];
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

          // Load break time data
          _breakStartTimeController.text = data['breakStartTime'] ?? '';
          _breakEndTimeController.text = data['breakEndTime'] ?? '';
          _hasJummaBreak = data['hasJummaBreak'] ?? false;
          _jummaBreakStartController.text = data['jummaBreakStart'] ?? '';
          _jummaBreakEndController.text = data['jummaBreakEnd'] ?? '';

          if (_hasJummaBreak) {
            _jummaBreakController.forward();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Error loading profile: $e");
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _birthdateController.dispose();
    _emailController.dispose();
    _otherCountryController.dispose();
    _breakStartTimeController.dispose();
    _breakEndTimeController.dispose();
    _jummaBreakStartController.dispose();
    _jummaBreakEndController.dispose();
    _breakSectionController.dispose();
    _jummaBreakController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D4B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: const Color(0xFF2E7D4B).withOpacity(0.2)),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

  Widget _buildFlagImage(String flagUrl, {double size = 24}) {
    return Container(
      width: size,
      height: size * 0.75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
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
              child: Center(
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: const Color(0xFF2E7D4B),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Responsive helper
  bool get _isTablet => MediaQuery.of(context).size.width > 600;
  double get _screenWidth => MediaQuery.of(context).size.width;
  EdgeInsets get _screenPadding => EdgeInsets.symmetric(
    horizontal: _isTablet ? 40.0 : 20.0,
    vertical: _isTablet ? 32.0 : 20.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingView() : _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D4B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Color(0xFF2E7D4B),
            size: 20,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.isNewUser ? "Complete Your Profile" : "Your Profile",
        style: TextStyle(
          color: const Color(0xFF2E7D4B),
          fontSize: _isTablet ? 20 : 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        if (!widget.isNewUser) _buildEditButton(),
      ],
    );
  }

  Widget _buildEditButton() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isEditing
                ? const Color(0xFF2E7D4B)
                : const Color(0xFF2E7D4B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isEditing ? Icons.check : Icons.edit,
            color: _isEditing ? Colors.white : const Color(0xFF2E7D4B),
            size: 20,
          ),
        ),
        onPressed: () {
          setState(() {
            if (_isEditing) {
              _saveProfile();
            } else {
              _isEditing = true;
            }
          });
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(_isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: const Color(0xFF2E7D4B),
                  strokeWidth: 3,
                ),
                SizedBox(height: _isTablet ? 20 : 16),
                Text(
                  "Saving your profile...",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: _isTablet ? 16 : 14,
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

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: _screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          SizedBox(height: _isTablet ? 32 : 24),
          _buildBasicInformationSection(),
          SizedBox(height: _isTablet ? 32 : 24),
          _buildBreakTimeSection(),
          SizedBox(height: _isTablet ? 40 : 32),
          if (widget.isNewUser || _isEditing) _buildActionButton(),
          SizedBox(height: _isTablet ? 24 : 16),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isTablet ? 28.0 : 20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E7D4B).withOpacity(0.08),
            const Color(0xFF2E7D4B).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E7D4B).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: _isTablet ? 100 : 80,
            height: _isTablet ? 100 : 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2E7D4B).withOpacity(0.2),
                  const Color(0xFF2E7D4B).withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2E7D4B).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D4B).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: _isTablet ? 45 : 35,
              color: const Color(0xFF2E7D4B),
            ),
          ),
          SizedBox(height: _isTablet ? 20 : 16),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isTablet ? 20 : 16,
              vertical: _isTablet ? 10 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E7D4B).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  "PHOENICIAN TECHNICAL SERVICES",
                  style: TextStyle(
                    color: const Color(0xFF2E7D4B),
                    fontSize: _isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  "Employee Profile Setup",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: _isTablet ? 12 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Basic Information", Icons.person_outline),
        SizedBox(height: _isTablet ? 20 : 16),
        Container(
          padding: EdgeInsets.all(_isTablet ? 20.0 : 16.0),
          decoration: _buildCardDecoration(),
          child: Column(
            children: [
              _buildProfileField(
                label: "Full Name",
                controller: _nameController,
                icon: Icons.person_outline,
                isRequired: true,
              ),
              _buildProfileField(
                label: "Designation",
                controller: _designationController,
                icon: Icons.work_outline,
                isRequired: true,
              ),
              _buildProfileField(
                label: "Department",
                controller: _departmentController,
                icon: Icons.business_outlined,
                isRequired: true,
              ),
              _buildBirthdateField(),
              _buildCountryDropdown(),
              if (_showOtherCountryField) _buildOtherCountryField(),
              _buildProfileField(
                label: "Email (Optional)",
                controller: _emailController,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                hint: "your.email@example.com",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Break Time Settings", Icons.schedule_outlined),
        SizedBox(height: _isTablet ? 20 : 16),
        FadeTransition(
          opacity: _breakSectionAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(_breakSectionAnimation),
            child: Container(
              padding: EdgeInsets.all(_isTablet ? 20.0 : 16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2E7D4B).withOpacity(0.08),
                    const Color(0xFF2E7D4B).withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E7D4B).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreakSectionTitle(),
                  SizedBox(height: _isTablet ? 20 : 16),
                  _buildDailyBreakTimeContainer(),
                  SizedBox(height: _isTablet ? 20 : 16),
                  _buildJummaBreakToggle(),
                  _buildJummaBreakTimeContainer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 16 : 12,
        vertical: _isTablet ? 12 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF2E7D4B).withOpacity(0.1),
            const Color(0xFF2E7D4B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E7D4B).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D4B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: _isTablet ? 18 : 16,
            ),
          ),
          SizedBox(width: _isTablet ? 12 : 10),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF2E7D4B),
              fontSize: _isTablet ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.grey[200]!,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: _isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: _isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRequired) ...[
                SizedBox(width: 4),
                Text(
                  "*",
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: _isTablet ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: _isTablet ? 8 : 6),
          Container(
            constraints: BoxConstraints(
              minHeight: _isTablet ? 56 : 48,
            ),
            decoration: BoxDecoration(
              color: _isEditing ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEditing
                    ? (controller.text.isNotEmpty
                    ? const Color(0xFF2E7D4B).withOpacity(0.4)
                    : const Color(0xFF2E7D4B).withOpacity(0.3))
                    : Colors.grey[300]!,
                width: _isEditing ? 1.5 : 1,
              ),
              boxShadow: _isEditing ? [
                BoxShadow(
                  color: const Color(0xFF2E7D4B).withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: TextField(
              controller: controller,
              enabled: _isEditing,
              keyboardType: keyboardType,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: _isTablet ? 15 : 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint ?? "Enter $label",
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: _isTablet ? 13 : 11,
                ),
                prefixIcon: Container(
                  margin: EdgeInsets.all(_isTablet ? 10 : 8),
                  padding: EdgeInsets.all(_isTablet ? 6 : 5),
                  decoration: BoxDecoration(
                    color: _isEditing
                        ? const Color(0xFF2E7D4B).withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: _isEditing
                        ? const Color(0xFF2E7D4B)
                        : Colors.grey[500],
                    size: _isTablet ? 18 : 16,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 16 : 14,
                  vertical: _isTablet ? 16 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdateField() {
    return Padding(
      padding: EdgeInsets.only(bottom: _isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Birthdate",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: _isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Text(
                "*",
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: _isTablet ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D4B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "DD/MM/YYYY",
                  style: TextStyle(
                    color: const Color(0xFF2E7D4B),
                    fontSize: _isTablet ? 10 : 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _isTablet ? 8 : 6),
          Container(
            constraints: BoxConstraints(
              minHeight: _isTablet ? 56 : 48,
            ),
            decoration: BoxDecoration(
              color: _isEditing ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEditing
                    ? (_birthdateController.text.isNotEmpty
                    ? const Color(0xFF2E7D4B).withOpacity(0.4)
                    : const Color(0xFF2E7D4B).withOpacity(0.3))
                    : Colors.grey[300]!,
                width: _isEditing ? 1.5 : 1,
              ),
              boxShadow: _isEditing ? [
                BoxShadow(
                  color: const Color(0xFF2E7D4B).withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: TextField(
              controller: _birthdateController,
              enabled: _isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                DateInputFormatter(),
              ],
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: _isTablet ? 15 : 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
              decoration: InputDecoration(
                hintText: "DD/MM/YYYY",
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: _isTablet ? 13 : 11,
                  letterSpacing: 0.8,
                ),
                prefixIcon: Container(
                  margin: EdgeInsets.all(_isTablet ? 10 : 8),
                  padding: EdgeInsets.all(_isTablet ? 6 : 5),
                  decoration: BoxDecoration(
                    color: _isEditing
                        ? const Color(0xFF2E7D4B).withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cake_outlined,
                    color: _isEditing
                        ? const Color(0xFF2E7D4B)
                        : Colors.grey[500],
                    size: _isTablet ? 18 : 16,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 16 : 14,
                  vertical: _isTablet ? 16 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: _isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Country",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: _isTablet ? 14 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Text(
                "*",
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: _isTablet ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: _isTablet ? 8 : 6),
          Container(
            constraints: BoxConstraints(
              minHeight: _isTablet ? 56 : 48,
            ),
            decoration: BoxDecoration(
              color: _isEditing ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEditing
                    ? (_selectedCountry != null
                    ? const Color(0xFF2E7D4B).withOpacity(0.4)
                    : const Color(0xFF2E7D4B).withOpacity(0.3))
                    : Colors.grey[300]!,
                width: _isEditing ? 1.5 : 1,
              ),
              boxShadow: _isEditing ? [
                BoxShadow(
                  color: const Color(0xFF2E7D4B).withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: DropdownButtonFormField<CountryData>(
              value: _selectedCountry,
              decoration: InputDecoration(
                hintText: "Select your country",
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: _isTablet ? 13 : 11,
                ),
                prefixIcon: Container(
                  margin: EdgeInsets.all(_isTablet ? 10 : 8),
                  padding: EdgeInsets.all(_isTablet ? 6 : 5),
                  decoration: BoxDecoration(
                    color: _isEditing
                        ? const Color(0xFF2E7D4B).withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.public_outlined,
                    color: _isEditing
                        ? const Color(0xFF2E7D4B)
                        : Colors.grey[500],
                    size: _isTablet ? 18 : 16,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 16 : 14,
                  vertical: _isTablet ? 16 : 14,
                ),
              ),
              icon: Container(
                margin: EdgeInsets.only(right: _isTablet ? 10 : 8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _isEditing ? const Color(0xFF2E7D4B) : Colors.grey[400],
                  size: _isTablet ? 20 : 18,
                ),
              ),
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: _isTablet ? 15 : 13,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              isExpanded: true,
              menuMaxHeight: 300,
              items: _isEditing
                  ? _countries.map((CountryData country) {
                return DropdownMenuItem<CountryData>(
                  value: country,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: _isTablet ? 6 : 4),
                    child: Row(
                      children: [
                        _buildFlagImage(
                          country.flagUrl,
                          size: _isTablet ? 24 : 20,
                        ),
                        SizedBox(width: _isTablet ? 10 : 8),
                        Expanded(
                          child: Text(
                            country.name,
                            style: TextStyle(
                              color: country.isOther
                                  ? const Color(0xFF2E7D4B)
                                  : Colors.grey[800],
                              fontSize: _isTablet ? 14 : 12,
                              fontWeight: country.isOther
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList()
                  : null,
              selectedItemBuilder: _isEditing
                  ? (BuildContext context) {
                return _countries.map<Widget>((CountryData country) {
                  return Row(
                    children: [
                      _buildFlagImage(
                        country.flagUrl,
                        size: _isTablet ? 20 : 16,
                      ),
                      SizedBox(width: _isTablet ? 10 : 8),
                      Expanded(
                        child: Text(
                          country.name,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: _isTablet ? 15 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList();
              }
                  : null,
              onChanged: _isEditing
                  ? (CountryData? newCountry) {
                setState(() {
                  _selectedCountry = newCountry;
                  _showOtherCountryField = newCountry?.isOther ?? false;
                  if (!_showOtherCountryField) {
                    _otherCountryController.clear();
                  }
                });
              }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherCountryField() {
    return _buildProfileField(
      label: "Please specify your country",
      controller: _otherCountryController,
      icon: Icons.edit_location_outlined,
      isRequired: true,
      hint: "Enter your country name",
    );
  }

  Widget _buildBreakSectionTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D4B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.coffee_outlined,
            color: const Color(0xFF2E7D4B),
            size: _isTablet ? 20 : 18,
          ),
        ),
        SizedBox(width: _isTablet ? 12 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Daily Break Schedule",
                style: TextStyle(
                  color: const Color(0xFF2E7D4B),
                  fontSize: _isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Set your regular break timings",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: _isTablet ? 12 : 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBreakTimeContainer() {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 16.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTimeField(
            label: "Break Start Time",
            controller: _breakStartTimeController,
            timeIcon: Icons.play_circle_outline,
            isRequired: true,
          ),
          SizedBox(height: _isTablet ? 12 : 10),
          _buildTimeField(
            label: "Break End Time",
            controller: _breakEndTimeController,
            timeIcon: Icons.pause_circle_outline,
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildJummaBreakToggle() {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 16.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasJummaBreak
              ? const Color(0xFF2E7D4B).withOpacity(0.3)
              : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasJummaBreak
                ? const Color(0xFF2E7D4B).withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: _hasJummaBreak
                  ? const Color(0xFF2E7D4B).withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.mosque_outlined,
              color: _hasJummaBreak
                  ? const Color(0xFF2E7D4B)
                  : Colors.grey[600],
              size: _isTablet ? 18 : 16,
            ),
          ),
          SizedBox(width: _isTablet ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Friday Prayer Break",
                  style: TextStyle(
                    color: _hasJummaBreak
                        ? const Color(0xFF2E7D4B)
                        : Colors.grey[800],
                    fontSize: _isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Enable if you take Friday prayer break",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: _isTablet ? 11 : 10,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: _isTablet ? 1.0 : 0.8,
            child: Switch(
              value: _hasJummaBreak,
              onChanged: _isEditing
                  ? (value) {
                setState(() {
                  _hasJummaBreak = value;
                  if (value) {
                    _jummaBreakController.forward();
                  } else {
                    _jummaBreakController.reverse();
                    _jummaBreakStartController.clear();
                    _jummaBreakEndController.clear();
                  }
                });
              }
                  : null,
              activeColor: const Color(0xFF2E7D4B),
              activeTrackColor: const Color(0xFF2E7D4B).withOpacity(0.3),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJummaBreakTimeContainer() {
    return SizeTransition(
      sizeFactor: _jummaBreakAnimation,
      child: FadeTransition(
        opacity: _jummaBreakAnimation,
        child: Container(
          margin: EdgeInsets.only(top: _isTablet ? 16 : 12),
          padding: EdgeInsets.all(_isTablet ? 16.0 : 12.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E7D4B).withOpacity(0.05),
                const Color(0xFF2E7D4B).withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E7D4B).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mosque_outlined,
                    color: const Color(0xFF2E7D4B),
                    size: _isTablet ? 16 : 14,
                  ),
                  SizedBox(width: _isTablet ? 8 : 6),
                  Text(
                    "Friday Prayer Schedule",
                    style: TextStyle(
                      color: const Color(0xFF2E7D4B),
                      fontSize: _isTablet ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: _isTablet ? 12 : 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      label: "Prayer Start",
                      controller: _jummaBreakStartController,
                      timeIcon: Icons.access_time,
                      isRequired: true,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: _isTablet ? 12 : 8),
                    height: 24,
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2E7D4B).withOpacity(0.1),
                          const Color(0xFF2E7D4B).withOpacity(0.3),
                          const Color(0xFF2E7D4B).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: _buildTimeField(
                      label: "Prayer End",
                      controller: _jummaBreakEndController,
                      timeIcon: Icons.access_time,
                      isRequired: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    IconData? timeIcon,
  }) {
    return GestureDetector(
      onTap: _isEditing ? () => _selectTime(controller) : null,
      child: Container(
        constraints: BoxConstraints(
          minHeight: _isTablet ? 64 : 56,
        ),
        decoration: BoxDecoration(
          color: _isEditing ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isEditing
                ? (controller.text.isNotEmpty
                ? const Color(0xFF2E7D4B).withOpacity(0.4)
                : const Color(0xFF2E7D4B).withOpacity(0.2))
                : Colors.grey[300]!,
            width: _isEditing ? 1.2 : 1,
          ),
          boxShadow: _isEditing ? [
            BoxShadow(
              color: const Color(0xFF2E7D4B).withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        padding: EdgeInsets.all(_isTablet ? 12.0 : 10.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_isTablet ? 5 : 4),
              decoration: BoxDecoration(
                color: controller.text.isNotEmpty
                    ? const Color(0xFF2E7D4B).withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                timeIcon ?? Icons.access_time,
                color: controller.text.isNotEmpty
                    ? const Color(0xFF2E7D4B)
                    : Colors.grey[500],
                size: _isTablet ? 16 : 14,
              ),
            ),
            SizedBox(width: _isTablet ? 8 : 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: _isTablet ? 11 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRequired) ...[
                        SizedBox(width: 2),
                        Text(
                          "*",
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: _isTablet ? 11 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.text.isNotEmpty ? controller.text : "Tap to select",
                          style: TextStyle(
                            color: controller.text.isNotEmpty
                                ? Colors.grey[800]
                                : Colors.grey[500],
                            fontSize: _isTablet ? 13 : 12,
                            fontWeight: controller.text.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isEditing)
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[500],
                          size: _isTablet ? 16 : 14,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Center(
      child: GestureDetector(
        onTap: _saveProfile,
        child: Container(
          width: _isTablet ? 200 : 160,
          height: _isTablet ? 56 : 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E7D4B),
                const Color(0xFF2E7D4B).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D4B).withOpacity(0.4),
                spreadRadius: 0,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isNewUser ? Icons.arrow_forward : Icons.save,
                  color: Colors.white,
                  size: _isTablet ? 20 : 18,
                ),
                SizedBox(width: _isTablet ? 10 : 8),
                Text(
                  widget.isNewUser ? "Continue" : "Save Changes",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: _isTablet ? 16 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _saveProfile() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty ||
        _designationController.text.trim().isEmpty ||
        _departmentController.text.trim().isEmpty ||
        _birthdateController.text.trim().isEmpty ||
        _selectedCountry == null ||
        _breakStartTimeController.text.trim().isEmpty ||
        _breakEndTimeController.text.trim().isEmpty) {
      _showErrorSnackBar("Please fill in all required fields");
      return;
    }

    // Validate birthdate format
    if (_birthdateController.text.trim().length != 10 ||
        !RegExp(r'^\d{2}/\d{2}/\d{4}'
        ).hasMatch(_birthdateController.text.trim())) {
      _showErrorSnackBar("Please enter a valid birthdate (DD/MM/YYYY)");
      return;
    }

    // Validate "Other" country field
    if (_selectedCountry?.isOther == true && _otherCountryController.text.trim().isEmpty) {
      _showErrorSnackBar("Please specify your country name");
      return;
    }

    // Validate Friday Prayer break times if enabled
    if (_hasJummaBreak &&
        (_jummaBreakStartController.text.trim().isEmpty ||
            _jummaBreakEndController.text.trim().isEmpty)) {
      _showErrorSnackBar("Please fill in Friday Prayer break times");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Determine country name to save
      String countryToSave = _selectedCountry!.isOther
          ? _otherCountryController.text.trim()
          : _selectedCountry!.name;

      // Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.user.id)
          .update({
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'birthdate': _birthdateController.text.trim(),
        'country': countryToSave,
        'countryCode': _selectedCountry!.isOther ? 'OTHER' : _selectedCountry!.code,
        'email': _emailController.text.trim(),
        'breakStartTime': _breakStartTimeController.text.trim(),
        'breakEndTime': _breakEndTimeController.text.trim(),
        'hasJummaBreak': _hasJummaBreak,
        'jummaBreakStart': _jummaBreakStartController.text.trim(),
        'jummaBreakEnd': _jummaBreakEndController.text.trim(),
        'profileCompleted': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() => _isLoading = false);

      if (widget.isNewUser) {
        // If new user, proceed to face registration
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RegisterFaceView(
                employeeId: widget.user.id!,
                employeePin: widget.employeePin,
              ),
            ),
          );
        }
      } else {
        // If existing user, just exit edit mode
        setState(() => _isEditing = false);
        if (mounted) {
          _showSuccessSnackBar("Profile updated successfully");
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar("Error saving profile: $e");
      }
    }
  }
}



