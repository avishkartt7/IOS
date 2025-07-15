import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/common/utils/custom_snackbar.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/dashboard/dashboard_view.dart';
import 'package:face_auth/pin_entry/user_profile_view.dart';
import 'package:face_auth/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:convert'; // ✅ ADD THIS IMPORT

class PinEntryView extends StatefulWidget {
  const PinEntryView({Key? key}) : super(key: key);

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView> 
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isPinEntered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set up listeners for PIN fields
    for (int i = 0; i < 4; i++) {
      _focusNodes[i].addListener(() {
        setState(() {});
      });

      _controllers[i].addListener(() {
        _handlePinInput(i);
      });
    }
  }

  void _handlePinInput(int index) {
    // Auto advance to next field
    if (_controllers[index].text.length == 1 && index < 3) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }

    // Check if all PIN fields are filled
    _checkPinCompletion();

    // Auto-verify when 4th digit is entered
    if (index == 3 && _controllers[index].text.length == 1) {
      _handleFourthDigitEntered();
    }
  }

  void _handleFourthDigitEntered() async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (_pin.length == 4 && !_isLoading) {
      debugPrint("🔐 4th digit entered, auto-verifying PIN: $_pin");
      
      // Hide keyboard
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      
      // Auto-verify PIN
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await _verifyPin();
      }
    }
  }

  void _checkPinCompletion() {
    bool allFilled = true;
    for (var controller in _controllers) {
      if (controller.text.isEmpty) {
        allFilled = false;
        break;
      }
    }

    if (allFilled != _isPinEntered) {
      setState(() {
        _isPinEntered = allFilled;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  String get _pin => _controllers.map((e) => e.text).join();

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _isPinEntered = false;
    });
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  Future<void> _verifyPin() async {
    if (_pin.length != 4) {
      _showError("Please enter a 4-digit PIN");
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      debugPrint("🔐 Verifying PIN: $_pin");

      // Find employee by PIN
      final querySnapshot = await FirebaseFirestore.instance
          .collection("employees")
          .where("pin", isEqualTo: _pin)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showError("Invalid PIN. Please try again.");
        _clearPin();
        return;
      }

      // Get employee data
      final employeeDoc = querySnapshot.docs.first;
      final employeeData = employeeDoc.data();
      final employeeId = employeeDoc.id;

      debugPrint("✅ Employee found: ${employeeData['name']} ($employeeId)");

      // Save authentication data
      await _saveAuthenticationData(employeeId, employeeData);

      // Create UserModel
      final employee = UserModel(
        id: employeeId,
        name: employeeData['name'] ?? 'Employee',
      );

      // Check if user is registered
      bool isRegistered = await _checkIfUserIsRegistered(employeeId, employeeData);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (isRegistered) {
          // User is fully registered, go to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardView(employeeId: employeeId),
            ),
          );
        } else {
          // User needs to complete registration
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserProfileView(
                employeePin: _pin,
                user: employee,
                isNewUser: true,
              ),
            ),
          );
        }
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint("❌ PIN verification error: $e");
      _showError("Error verifying PIN: $e");
      _clearPin();
    }
  }

  Future<bool> _checkIfUserIsRegistered(String employeeId, Map<String, dynamic> employeeData) async {
    try {
      // Check if user has completed all registration steps
      bool profileCompleted = employeeData['profileCompleted'] ?? false;
      bool faceRegistered = employeeData['faceRegistered'] ?? false;
      bool hasImage = employeeData.containsKey('image') && employeeData['image'] != null;
      
      // Also check local storage
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool localRegistrationComplete = prefs.getBool('registration_complete_$employeeId') ?? false;
      
      bool isFullyRegistered = profileCompleted && faceRegistered && hasImage;
      
      debugPrint("📋 Registration Status for $employeeId:");
      debugPrint("   - Profile Completed: $profileCompleted");
      debugPrint("   - Face Registered: $faceRegistered");
      debugPrint("   - Has Image: $hasImage");
      debugPrint("   - Local Registration Complete: $localRegistrationComplete");
      debugPrint("   - Fully Registered: $isFullyRegistered");
      
      return isFullyRegistered;
    } catch (e) {
      debugPrint("❌ Error checking registration status: $e");
      return false;
    }
  }

  Future<void> _saveAuthenticationData(String employeeId, Map<String, dynamic> employeeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('authenticated_user_id', employeeId);
      await prefs.setString('authenticated_employee_pin', _pin);
      await prefs.setBool('is_authenticated', true);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Save employee data for offline use
      Map<String, dynamic> dataToSave = Map<String, dynamic>.from(employeeData);
      dataToSave.forEach((key, value) {
        if (value is Timestamp) {
          dataToSave[key] = value.toDate().toIso8601String();
        }
      });

      await prefs.setString('user_data_$employeeId', jsonEncode(dataToSave));
      await prefs.setString('user_name_$employeeId', employeeData['name'] ?? 'User');
      await prefs.setBool('user_exists_$employeeId', true);

      debugPrint("💾 Authentication data saved for: $employeeId");
    } catch (e) {
      debugPrint("❌ Error saving authentication data: $e");
    }
  }

  void _showError(String message) {
    CustomSnackBar.errorSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // App logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 30),

              // Title
              const Text(
                "Employee Authentication",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Instruction text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _isLoading
                      ? "Verifying your PIN..."
                      : _isPinEntered
                          ? "PIN entered successfully!"
                          : "Enter your 4-digit PIN to continue",
                  style: TextStyle(
                    color: _isLoading ? Colors.yellow : Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // PIN input fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => _buildPinField(index),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Status indicator
              if (_isLoading) ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  "Processing...",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ] else if (_isPinEntered) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "PIN verified successfully!",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Enter your 4-digit PIN",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],

              const Spacer(),

              // Action buttons
              if (!_isLoading && _isPinEntered) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Clear button
                      GestureDetector(
                        onTap: _clearPin,
                        child: Container(
                          width: 120,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Center(
                            child: Text(
                              "Clear",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Continue button
                      GestureDetector(
                        onTapDown: (_) => _animationController.forward(),
                        onTapUp: (_) {
                          _animationController.reverse();
                          _verifyPin();
                        },
                        onTapCancel: () => _animationController.reverse(),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 120,
                            height: 50,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Continue",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (!_isLoading) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text(
                    "If you've forgotten your PIN, please contact your administrator",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _controllers[index].text.isNotEmpty
            ? Colors.white
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? accentColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        obscureText: true,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: TextStyle(
          color: _controllers[index].text.isNotEmpty
              ? accentColor
              : Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
      ),
    );
  }
}