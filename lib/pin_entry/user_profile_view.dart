
// lib/pin_entry/user_profile_view.dart - CLEAN WHITE DESIGN

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/register_face/register_face_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _UserProfileViewState extends State<UserProfileView> {
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _birthdateController;
  late TextEditingController _countryController;
  late TextEditingController _emailController;

  // Add break time controllers
  late TextEditingController _breakStartTimeController;
  late TextEditingController _breakEndTimeController;
  late TextEditingController _jummaBreakStartController;
  late TextEditingController _jummaBreakEndController;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _hasJummaBreak = false;

  @override
  void initState() {
    super.initState();

    // Set clean white status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _nameController = TextEditingController(text: widget.user.name ?? '');
    _designationController = TextEditingController(text: '');
    _departmentController = TextEditingController(text: '');
    _birthdateController = TextEditingController(text: '');
    _countryController = TextEditingController(text: '');
    _emailController = TextEditingController(text: '');

    // Initialize break time controllers
    _breakStartTimeController = TextEditingController(text: '');
    _breakEndTimeController = TextEditingController(text: '');
    _jummaBreakStartController = TextEditingController(text: '');
    _jummaBreakEndController = TextEditingController(text: '');

    // If new user, enable editing by default
    _isEditing = widget.isNewUser;

    // Load existing data if available
    _loadUserData();
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
          _countryController.text = data['country'] ?? '';
          _emailController.text = data['email'] ?? '';

          // Load break time data
          _breakStartTimeController.text = data['breakStartTime'] ?? '';
          _breakEndTimeController.text = data['breakEndTime'] ?? '';
          _hasJummaBreak = data['hasJummaBreak'] ?? false;
          _jummaBreakStartController.text = data['jummaBreakStart'] ?? '';
          _jummaBreakEndController.text = data['jummaBreakEnd'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading profile: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _birthdateController.dispose();
    _countryController.dispose();
    _emailController.dispose();
    _breakStartTimeController.dispose();
    _breakEndTimeController.dispose();
    _jummaBreakStartController.dispose();
    _jummaBreakEndController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E7D4B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isNewUser ? "Complete Your Profile" : "Your Profile",
          style: TextStyle(
            color: const Color(0xFF2E7D4B),
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isNewUser)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check : Icons.edit,
                color: const Color(0xFF2E7D4B),
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
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D4B),
                strokeWidth: 3,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40.0 : 24.0,
                vertical: isTablet ? 32.0 : 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        // Profile Avatar
                        Container(
                          width: isTablet ? 120 : 100,
                          height: isTablet ? 120 : 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D4B).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2E7D4B).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            size: isTablet ? 60 : 50,
                            color: const Color(0xFF2E7D4B),
                          ),
                        ),
                        
                        SizedBox(height: isTablet ? 24 : 20),

                        // Company Info
                        Text(
                          "PHOENICIAN TECHNICAL SERVICES",
                          style: TextStyle(
                            color: const Color(0xFF2E7D4B),
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: isTablet ? 6 : 4),

                        Text(
                          "Employee Profile Setup",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 32),

                  // Basic Information Section
                  _buildSectionHeader("Basic Information", isTablet),
                  SizedBox(height: isTablet ? 20 : 16),

                  _buildProfileField(
                    label: "Full Name",
                    controller: _nameController,
                    enabled: _isEditing,
                    isTablet: isTablet,
                    icon: Icons.person_outline,
                  ),

                  _buildProfileField(
                    label: "Designation",
                    controller: _designationController,
                    enabled: _isEditing,
                    isTablet: isTablet,
                    icon: Icons.work_outline,
                  ),

                  _buildProfileField(
                    label: "Department",
                    controller: _departmentController,
                    enabled: _isEditing,
                    isTablet: isTablet,
                    icon: Icons.business_outlined,
                  ),

                  _buildProfileField(
                    label: "Birthdate",
                    controller: _birthdateController,
                    enabled: _isEditing,
                    hint: "DD/MM/YYYY",
                    isTablet: isTablet,
                    icon: Icons.cake_outlined,
                  ),

                  _buildProfileField(
                    label: "Country",
                    controller: _countryController,
                    enabled: _isEditing,
                    isTablet: isTablet,
                    icon: Icons.public_outlined,
                  ),

                  _buildProfileField(
                    label: "Email (Optional)",
                    controller: _emailController,
                    enabled: _isEditing,
                    hint: "your.email@example.com",
                    isTablet: isTablet,
                    icon: Icons.email_outlined,
                  ),

                  SizedBox(height: isTablet ? 32 : 24),

                  // Break Time Settings Section
                  _buildSectionHeader("Break Time Settings", isTablet),
                  SizedBox(height: isTablet ? 20 : 16),

                  Container(
                    padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D4B).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2E7D4B).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily break time
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                label: "Break Start Time",
                                controller: _breakStartTimeController,
                                enabled: _isEditing,
                                isRequired: true,
                                isTablet: isTablet,
                              ),
                            ),
                            SizedBox(width: isTablet ? 20 : 16),
                            Expanded(
                              child: _buildTimeField(
                                label: "Break End Time",
                                controller: _breakEndTimeController,
                                enabled: _isEditing,
                                isRequired: true,
                                isTablet: isTablet,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: isTablet ? 24 : 20),

                        // Friday Prayer Break Toggle
                        Container(
                          padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mosque_outlined,
                                color: const Color(0xFF2E7D4B),
                                size: isTablet ? 24 : 20,
                              ),
                              SizedBox(width: isTablet ? 16 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Friday Prayer Break",
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: isTablet ? 4 : 2),
                                    Text(
                                      "Enable if you take Friday prayer break",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: isTablet ? 12 : 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _hasJummaBreak,
                                onChanged: _isEditing ? (value) {
                                  setState(() {
                                    _hasJummaBreak = value;
                                    if (!value) {
                                      _jummaBreakStartController.clear();
                                      _jummaBreakEndController.clear();
                                    }
                                  });
                                } : null,
                                activeColor: const Color(0xFF2E7D4B),
                              ),
                            ],
                          ),
                        ),

                        // Friday Prayer Break Times
                        if (_hasJummaBreak) ...[
                          SizedBox(height: isTablet ? 20 : 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimeField(
                                  label: "Friday Prayer Start",
                                  controller: _jummaBreakStartController,
                                  enabled: _isEditing,
                                  isRequired: true,
                                  isTablet: isTablet,
                                ),
                              ),
                              SizedBox(width: isTablet ? 20 : 16),
                              Expanded(
                                child: _buildTimeField(
                                  label: "Friday Prayer End",
                                  controller: _jummaBreakEndController,
                                  enabled: _isEditing,
                                  isRequired: true,
                                  isTablet: isTablet,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 32),

                  // Action Button
                  if (widget.isNewUser || _isEditing)
                    Center(
                      child: GestureDetector(
                        onTap: _saveProfile,
                        child: Container(
                          width: isTablet ? 200 : 160,
                          height: isTablet ? 56 : 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D4B),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D4B).withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.isNewUser ? "Continue" : "Save Changes",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isTablet ? 16 : 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: isTablet ? 24 : 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isTablet) {
    return Text(
      title,
      style: TextStyle(
        color: const Color(0xFF2E7D4B),
        fontSize: isTablet ? 20 : 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    bool enabled = false,
    String? hint,
    required bool isTablet,
    IconData? icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Container(
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled 
                    ? const Color(0xFF2E7D4B).withOpacity(0.3)
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: isTablet ? 16 : 14,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: isTablet ? 14 : 12,
                ),
                prefixIcon: icon != null 
                    ? Icon(
                        icon,
                        color: const Color(0xFF2E7D4B).withOpacity(0.7),
                        size: isTablet ? 22 : 20,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: icon != null ? 16 : 16,
                  vertical: isTablet ? 16 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    bool enabled = false,
    bool isRequired = false,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: enabled ? () => _selectTime(controller) : null,
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled 
                ? const Color(0xFF2E7D4B).withOpacity(0.3)
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: const Color(0xFF2E7D4B).withOpacity(0.7),
              size: isTablet ? 22 : 20,
            ),
            SizedBox(width: isTablet ? 12 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$label${isRequired ? ' *' : ''}",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isTablet ? 6 : 4),
                  Text(
                    controller.text.isNotEmpty ? controller.text : "Tap to select",
                    style: TextStyle(
                      color: controller.text.isNotEmpty
                          ? Colors.grey[800]
                          : Colors.grey[500],
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: controller.text.isNotEmpty 
                          ? FontWeight.w500 
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    // Validate fields
    if (_nameController.text.trim().isEmpty ||
        _designationController.text.trim().isEmpty ||
        _departmentController.text.trim().isEmpty ||
        _breakStartTimeController.text.trim().isEmpty ||
        _breakEndTimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate Friday Prayer break times if enabled
    if (_hasJummaBreak &&
        (_jummaBreakStartController.text.trim().isEmpty ||
            _jummaBreakEndController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in Friday Prayer break times"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.user.id)
          .update({
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'birthdate': _birthdateController.text.trim(),
        'country': _countryController.text.trim(),
        'email': _emailController.text.trim(),
        'breakStartTime': _breakStartTimeController.text.trim(),
        'breakEndTime': _breakEndTimeController.text.trim(),
        'hasJummaBreak': _hasJummaBreak,
        'jummaBreakStart': _jummaBreakStartController.text.trim(),
        'jummaBreakEnd': _jummaBreakEndController.text.trim(),
        'profileCompleted': true,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile updated successfully"),
              backgroundColor: Color(0xFF2E7D4B),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving profile: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}