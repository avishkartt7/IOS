import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/common/views/custom_button.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:face_auth/register_face/register_face_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // ✅ ADD THIS IMPORT
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
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? '');
    _designationController = TextEditingController(text: '');
    _departmentController = TextEditingController(text: '');
    _emailController = TextEditingController(text: '');
    _phoneController = TextEditingController(text: '');

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
          _nameController.text = data['name'] ?? '';
          _designationController.text = data['designation'] ?? '';
          _departmentController.text = data['department'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: Text(widget.isNewUser ? "Complete Your Profile" : "Your Profile"),
        elevation: 0,
        actions: [
          if (!widget.isNewUser)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldTopGradientClr,
              scaffoldBottomGradientClr,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: accentColor),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: primaryWhite.withOpacity(0.2),
                        child: const Icon(
                          Icons.person,
                          size: 80,
                          color: primaryWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    _buildProfileField(
                      label: "Full Name",
                      controller: _nameController,
                      enabled: _isEditing,
                      isRequired: true,
                    ),

                    // Designation Field
                    _buildProfileField(
                      label: "Designation",
                      controller: _designationController,
                      enabled: _isEditing,
                      isRequired: true,
                    ),

                    // Department Field
                    _buildProfileField(
                      label: "Department",
                      controller: _departmentController,
                      enabled: _isEditing,
                      isRequired: true,
                    ),

                    // Email Field
                    _buildProfileField(
                      label: "Email",
                      controller: _emailController,
                      enabled: _isEditing,
                      isRequired: false,
                      hint: "your.email@company.com",
                    ),

                    // Phone Field
                    _buildProfileField(
                      label: "Phone Number",
                      controller: _phoneController,
                      enabled: _isEditing,
                      isRequired: false,
                      hint: "+1 234 567 8900",
                    ),

                    const SizedBox(height: 32),

                    // Save/Continue Button
                    if (widget.isNewUser || _isEditing)
                      Center(
                        child: CustomButton(
                          text: widget.isNewUser ? "Save & Continue" : "Save Changes",
                          onTap: _saveProfile,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    bool enabled = false,
    bool isRequired = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label${isRequired ? ' *' : ''}",
            style: TextStyle(
              color: primaryWhite.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            style: const TextStyle(
              color: primaryWhite,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: primaryWhite.withOpacity(0.4),
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(enabled ? 0.1 : 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: primaryWhite.withOpacity(0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: primaryWhite.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: accentColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty ||
        _designationController.text.trim().isEmpty ||
        _departmentController.text.trim().isEmpty) {
      CustomSnackBar.errorSnackBar("Please fill in all required fields");
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
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profileCompleted': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Save to local storage
      await _saveToLocalStorage();

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
        CustomSnackBar.successSnackBar("Profile updated successfully");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error saving profile: $e");
      CustomSnackBar.errorSnackBar("Error saving profile. Please try again.");
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profileCompleted': true,
        'pin': widget.employeePin,
      };

      await prefs.setString('user_data_${widget.user.id}', 
          jsonEncode(userData));
      await prefs.setString('user_name_${widget.user.id}', 
          _nameController.text.trim());
      await prefs.setBool('profile_completed_${widget.user.id}', true);

      debugPrint("💾 Profile data saved to local storage");
    } catch (e) {
      debugPrint("❌ Error saving to local storage: $e");
    }
  }
}