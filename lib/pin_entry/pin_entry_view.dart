// lib/pin_entry/pin_entry_view.dart - COMPLETE FLEXIBLE PIN LENGTH SUPPORT (1-4 digits)

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

class PinEntryView extends StatefulWidget {
  const PinEntryView({Key? key}) : super(key: key);

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView>
    with SingleTickerProviderStateMixin {
  final List<String> _pinValues = ['', '', '', ''];
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    print("🔐 PIN Entry initialized with flexible PIN length support (1-4 digits)");

    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _pin => _pinValues.join();
  bool get _isPinComplete => _pinValues.every((value) => value.isNotEmpty);
  int get _enteredDigits => _pinValues.where((value) => value.isNotEmpty).length;

  void _onNumberPressed(String number) {
    if (_isLoading) return;

    HapticFeedback.lightImpact();

    if (_currentIndex < 4) {
      setState(() {
        _pinValues[_currentIndex] = number;
        _currentIndex++;
      });
    }
  }

  void _onBackspacePressed() {
    if (_isLoading) return;

    HapticFeedback.lightImpact();

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pinValues[_currentIndex] = '';
      });
    }
  }

  void _clearPin() {
    if (_isLoading) return;

    HapticFeedback.lightImpact();

    setState(() {
      _pinValues.fillRange(0, 4, '');
      _currentIndex = 0;
      _isLoading = false;
    });
  }

  // Manual verify function (called by Continue button)
  Future<void> _verifyPin() async {
    if (_enteredDigits == 0) {
      _showError("Please enter your PIN");
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      String enteredPin = _pin.replaceAll('', '').substring(0, _enteredDigits);
      debugPrint("🔐 Verifying entered PIN: '$enteredPin' (${_enteredDigits} digits)");

      // Try to find employee with exact PIN match first
      QuerySnapshot exactMatch = await FirebaseFirestore.instance
          .collection("employees")
          .where("pin", isEqualTo: enteredPin)
          .limit(1)
          .get();

      DocumentSnapshot? matchedDoc;
      String? actualPin;

      if (exactMatch.docs.isNotEmpty) {
        matchedDoc = exactMatch.docs.first;
        actualPin = enteredPin;
        debugPrint("✅ Found exact PIN match: '$actualPin'");
      } else {
        // Try flexible matching - compare normalized PINs
        debugPrint("🔍 Exact match not found, trying flexible PIN matching...");

        QuerySnapshot allEmployees = await FirebaseFirestore.instance
            .collection("employees")
            .get();

        for (var doc in allEmployees.docs) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          String? storedPin = data?['pin']?.toString();
          if (storedPin != null) {
            if (_pinsMatch(enteredPin, storedPin)) {
              matchedDoc = doc;
              actualPin = storedPin;
              debugPrint("✅ Found flexible PIN match: entered='$enteredPin', stored='$storedPin'");
              break;
            }
          }
        }
      }

      if (matchedDoc == null) {
        setState(() {
          _isLoading = false;
        });
        _showError("Invalid PIN. Please try again.");
        _clearPin();
        return;
      }

      // Get employee data
      final employeeData = matchedDoc.data() as Map<String, dynamic>;
      final employeeId = matchedDoc.id;

      debugPrint("✅ Employee found: ${employeeData['name']} ($employeeId)");

      // Save authentication data
      await _saveAuthenticationData(employeeId, employeeData, actualPin!);

      // Create UserModel
      final employee = UserModel(
        id: employeeId,
        name: employeeData['name'] ?? 'Employee',
      );

      // Check if user is fully registered
      bool isRegistered = await _checkIfUserIsRegistered(employeeId, employeeData);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (isRegistered) {
          debugPrint("✅ User is registered, navigating to Dashboard");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardView(employeeId: employeeId),
            ),
          );
        } else {
          debugPrint("⚠️ User needs to complete registration");
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserProfileView(
                employeePin: actualPin!,
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

  // Smart PIN matching function
  bool _pinsMatch(String enteredPin, String storedPin) {
    // Remove any whitespace
    enteredPin = enteredPin.trim();
    storedPin = storedPin.trim();

    // Direct match
    if (enteredPin == storedPin) {
      return true;
    }

    // Convert both to integers for numeric comparison
    try {
      int enteredNum = int.parse(enteredPin);
      int storedNum = int.parse(storedPin);

      // They match if they represent the same number
      // e.g., "0004" matches "4", "0018" matches "18"
      bool matches = enteredNum == storedNum;

      if (matches) {
        debugPrint("📋 PIN match found: '$enteredPin' (${enteredNum}) == '$storedPin' (${storedNum})");
      }

      return matches;
    } catch (e) {
      // If parsing fails, fall back to string comparison
      return enteredPin == storedPin;
    }
  }

  Future<bool> _checkIfUserIsRegistered(String employeeId, Map<String, dynamic> employeeData) async {
    try {
      bool profileCompleted = employeeData['profileCompleted'] ?? false;
      bool faceRegistered = employeeData['faceRegistered'] ?? false;
      bool enhancedRegistration = employeeData['enhancedRegistration'] ?? false;
      bool hasImage = employeeData.containsKey('image') && employeeData['image'] != null;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool localRegistrationComplete = prefs.getBool('registration_complete_$employeeId') ?? false;
      bool localFaceRegistered = prefs.getBool('face_registered_$employeeId') ?? false;

      bool isFullyRegistered = profileCompleted &&
          (faceRegistered || enhancedRegistration || localFaceRegistered) &&
          (hasImage || localRegistrationComplete);

      return isFullyRegistered;
    } catch (e) {
      debugPrint("❌ Error checking registration status: $e");
      return false;
    }
  }

  Future<void> _saveAuthenticationData(String employeeId, Map<String, dynamic> employeeData, String actualPin) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('authenticated_user_id', employeeId);
      await prefs.setString('authenticated_employee_pin', actualPin);
      await prefs.setBool('is_authenticated', true);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                // Header Section
                SizedBox(
                  height: screenHeight * 0.35,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 60.0 : 24.0,
                      vertical: isTablet ? 32.0 : 24.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Company Logo
                        Container(
                          width: isTablet ? 80 : 70,
                          height: isTablet ? 80 : 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D4B),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D4B).withOpacity(0.2),
                                spreadRadius: 0,
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "P",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 32 : 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 16 : 14),

                        // Company Name
                        Text(
                          "PHOENICIAN TECHNICAL SERVICES LLC",
                          style: TextStyle(
                            color: const Color(0xFF2E7D4B),
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: isTablet ? 8 : 6),

                        Text(
                          "",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: isTablet ? 20 : 16),

                        // Status Text
                        Text(
                          _isLoading
                              ? "Verifying your PIN..."
                              : _enteredDigits > 0
                              ? "${_enteredDigits} digit${_enteredDigits > 1 ? 's' : ''} entered"
                              : "Enter your PIN (1-4 digits)",
                          style: TextStyle(
                            color: _isLoading
                                ? const Color(0xFFFF8C00)
                                : _enteredDigits > 0
                                ? const Color(0xFF2E7D4B)
                                : Colors.grey[700],
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: isTablet ? 8 : 6),

                        // Helper text
                        Text(
                          "",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: isTablet ? 10 : 9,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // PIN Display Section
                Container(
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                          (index) => Container(
                        width: isTablet ? 50 : 45,
                        height: isTablet ? 50 : 45,
                        margin: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 8),
                        decoration: BoxDecoration(
                          color: _pinValues[index].isNotEmpty
                              ? const Color(0xFF2E7D4B)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _pinValues[index].isNotEmpty
                                ? const Color(0xFF2E7D4B)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: _pinValues[index].isNotEmpty
                              ? Container(
                            width: isTablet ? 12 : 10,
                            height: isTablet ? 12 : 10,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // Loading Indicator
                if (_isLoading) ...[
                  const CircularProgressIndicator(
                    color: Color(0xFF2E7D4B),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                ],

                // Number Pad Section
                SizedBox(
                  height: screenHeight * 0.45,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 60.0 : 24.0),
                    child: Column(
                      children: [
                        // Number Rows
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberRow(['1', '2', '3'], isTablet),
                              _buildNumberRow(['4', '5', '6'], isTablet),
                              _buildNumberRow(['7', '8', '9'], isTablet),
                              _buildBottomRow(isTablet),
                            ],
                          ),
                        ),

                        // Action Buttons
                        if (_enteredDigits > 0 && !_isLoading) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              top: isTablet ? 16 : 12,
                              bottom: isTablet ? 12 : 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Clear Button
                                GestureDetector(
                                  onTap: _clearPin,
                                  child: Container(
                                    width: isTablet ? 120 : 100,
                                    height: isTablet ? 44 : 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.grey[300]!, width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Clear",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: isTablet ? 14 : 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(width: isTablet ? 16 : 12),

                                // Continue Button
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
                                      width: isTablet ? 120 : 100,
                                      height: isTablet ? 44 : 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D4B),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2E7D4B).withOpacity(0.3),
                                            spreadRadius: 0,
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          "Continue",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: isTablet ? 14 : 12,
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
                          Padding(
                            padding: EdgeInsets.only(
                              top: isTablet ? 16 : 12,
                              bottom: isTablet ? 12 : 8,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D4B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    "PHOENICIAN",
                                    style: TextStyle(
                                      color: const Color(0xFF2E7D4B),
                                      fontSize: isTablet ? 10 : 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "DUBAI,UNITED ARAB EMIRATES",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: isTablet ? 10 : 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) => _buildNumberButton(number, isTablet)).toList(),
    );
  }

  Widget _buildBottomRow(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(width: isTablet ? 60 : 55), // Empty space
        _buildNumberButton('0', isTablet),
        _buildBackspaceButton(isTablet),
      ],
    );
  }

  Widget _buildNumberButton(String number, bool isTablet) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: isTablet ? 60 : 55,
        height: isTablet ? 60 : 55,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              color: const Color(0xFF2E7D4B),
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(bool isTablet) {
    return GestureDetector(
      onTap: _onBackspacePressed,
      child: Container(
        width: isTablet ? 60 : 55,
        height: isTablet ? 60 : 55,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Center(
          child: Text(
            "⌫",
            style: TextStyle(
              color: const Color(0xFF2E7D4B),
              fontSize: isTablet ? 18 : 16,
            ),
          ),
        ),
      ),
    );
  }
}



