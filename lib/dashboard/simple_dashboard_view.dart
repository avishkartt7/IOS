// lib/dashboard/simple_dashboard_view.dart - COMPLETE ENHANCED WITH COMPREHENSIVE DEBUG INFO

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

class SimpleDashboardView extends StatefulWidget {
  final String employeeId;

  const SimpleDashboardView({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<SimpleDashboardView> createState() => _SimpleDashboardViewState();
}

class _SimpleDashboardViewState extends State<SimpleDashboardView> {
  Map<String, dynamic>? employeeData;
  bool _isLoading = true;
  bool _isOfflineMode = false;
  String _currentTime = "";
  String _currentDate = "";
  bool _hasFaceData = false;

  // ✅ DEBUG INFORMATION
  Map<String, dynamic> _debugInfo = {};
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    print("🏠 iOS Enhanced Dashboard initialized for: ${widget.employeeId}");
    _loadEmployeeData();
    _updateDateTime();
    _checkConnectivity();
    _checkFaceData();
    _loadDebugInformation();
    
    // Update time every second
    Stream.periodic(const Duration(seconds: 1), (i) => i)
        .listen((value) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
        _currentDate = DateFormat('EEEE, MMMM dd, yyyy').format(now);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      print("📶 Dashboard connectivity: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
    }
  }

  Future<void> _checkFaceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? faceImage = prefs.getString('employee_image_${widget.employeeId}');
      String? faceFeatures = prefs.getString('employee_face_features_${widget.employeeId}');
      bool faceRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;
      
      setState(() {
        _hasFaceData = (faceImage != null && faceImage.isNotEmpty) || 
                      (faceFeatures != null && faceFeatures.isNotEmpty) || 
                      faceRegistered;
      });
      
      print("🔍 Face data check:");
      print("   - Face Image: ${faceImage != null ? 'EXISTS (${faceImage.length} chars)' : 'NULL'}");
      print("   - Face Features: ${faceFeatures != null ? 'EXISTS (${faceFeatures.length} chars)' : 'NULL'}");
      print("   - Face Registered: $faceRegistered");
      print("   - Has Face Data: $_hasFaceData");
    } catch (e) {
      print("❌ Error checking face data: $e");
    }
  }

  // ✅ COMPREHENSIVE DEBUG INFORMATION LOADER
  Future<void> _loadDebugInformation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      Map<String, dynamic> debugData = {
        'employeeId': widget.employeeId,
        'timestamp': DateTime.now().toIso8601String(),
        'totalStoredKeys': allKeys.length,
        'faceData': {},
        'userData': {},
        'authenticationData': {},
        'registrationFlags': {},
        'allStoredKeys': [],
        'systemInfo': {},
        'sdkInformation': {},
      };

      // ✅ FACE DATA ANALYSIS
      debugData['faceData'] = {
        'employee_image': _getStorageInfo(prefs, 'employee_image_${widget.employeeId}'),
        'employee_face_features': _getStorageInfo(prefs, 'employee_face_features_${widget.employeeId}'),
        'secure_face_image': _getStorageInfo(prefs, 'secure_face_image_${widget.employeeId}'),
        'secure_face_features': _getStorageInfo(prefs, 'secure_face_features_${widget.employeeId}'),
        'secure_enhanced_face_features': _getStorageInfo(prefs, 'secure_enhanced_face_features_${widget.employeeId}'),
      };

      // ✅ USER DATA ANALYSIS
      debugData['userData'] = {
        'user_data': _getStorageInfo(prefs, 'user_data_${widget.employeeId}'),
        'user_name': _getStorageInfo(prefs, 'user_name_${widget.employeeId}'),
        'user_exists': prefs.getBool('user_exists_${widget.employeeId}') ?? false,
      };

      // ✅ AUTHENTICATION DATA ANALYSIS
      debugData['authenticationData'] = {
        'authenticated_user_id': prefs.getString('authenticated_user_id'),
        'authenticated_employee_pin': prefs.getString('authenticated_employee_pin'),
        'is_authenticated': prefs.getBool('is_authenticated') ?? false,
        'authentication_timestamp': prefs.getInt('authentication_timestamp'),
        'auth_date': prefs.getInt('authentication_timestamp') != null 
            ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt('authentication_timestamp')!).toString()
            : 'Not set',
      };

      // ✅ REGISTRATION FLAGS ANALYSIS
      debugData['registrationFlags'] = {
        'face_registered': prefs.getBool('face_registered_${widget.employeeId}') ?? false,
        'enhanced_face_registered': prefs.getBool('enhanced_face_registered_${widget.employeeId}') ?? false,
        'registration_complete': prefs.getBool('registration_complete_${widget.employeeId}') ?? false,
        'profile_completed': prefs.getBool('profile_completed_${widget.employeeId}') ?? false,
        'face_registration_date': prefs.getString('face_registration_date_${widget.employeeId}'),
        'face_registration_platform': prefs.getString('face_registration_platform_${widget.employeeId}'),
      };

      // ✅ ALL STORED KEYS (filtered for this employee + auth data)
      List<String> employeeKeys = allKeys.where((key) => 
          key.contains(widget.employeeId) || 
          key.contains('authenticated') ||
          key.contains('is_authenticated') ||
          key.contains('face_') ||
          key.contains('secure_')).toList();
      
      debugData['allStoredKeys'] = employeeKeys.map((key) {
        var value = prefs.get(key);
        return {
          'key': key,
          'type': value.runtimeType.toString(),
          'hasValue': value != null,
          'valueLength': value is String ? value.length : null,
          'preview': _getValuePreview(value),
        };
      }).toList();

      // ✅ SDK INFORMATION
      debugData['sdkInformation'] = {
        'regula_sdk_status': _isOfflineMode ? 'DISABLED (Offline)' : 'ENABLED (Online)',
        'ml_kit_status': 'ALWAYS AVAILABLE',
        'current_sdk': _isOfflineMode ? 'ML Kit (iOS Native)' : 'Regula SDK (Cloud)',
        'offline_mode_active': _isOfflineMode,
        'regula_can_work_offline': false, // ❌ IMPORTANT: Regula SDK CANNOT work offline
        'ml_kit_accuracy': 'Good (75% threshold)',
        'regula_accuracy': 'High (85% threshold)',
      };

      // ✅ SYSTEM INFORMATION
      debugData['systemInfo'] = {
        'platform': 'iOS',
        'connectivity': _isOfflineMode ? 'Offline' : 'Online',
        'has_face_data': _hasFaceData,
        'current_time': DateTime.now().toIso8601String(),
        'dashboard_version': 'Enhanced Debug v1.0',
      };

      setState(() {
        _debugInfo = debugData;
      });

      print("🔍 Debug information loaded:");
      print("   - Total keys: ${_debugInfo['totalStoredKeys']}");
      print("   - Employee keys: ${employeeKeys.length}");
      print("   - Face data available: $_hasFaceData");
      print("   - SDK mode: ${_isOfflineMode ? 'ML Kit' : 'Regula'}");
      
    } catch (e) {
      print("❌ Error loading debug information: $e");
    }
  }

  // ✅ HELPER TO GET STORAGE INFORMATION
  Map<String, dynamic> _getStorageInfo(SharedPreferences prefs, String key) {
    var value = prefs.get(key);
    return {
      'exists': value != null,
      'type': value?.runtimeType.toString() ?? 'null',
      'length': value is String ? value.length : null,
      'preview': _getValuePreview(value),
    };
  }

  String _getValuePreview(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is int) return value.toString();
    if (value is String) {
      if (value.length > 100) {
        return '${value.substring(0, 100)}...';
      }
      return value;
    }
    return value.toString();
  }

  Future<void> _loadEmployeeData() async {
    try {
      print("📊 Loading employee data...");
      
      // Try local storage first
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString('user_data_${widget.employeeId}');
      
      if (localData != null) {
        Map<String, dynamic> data = jsonDecode(localData);
        setState(() {
          employeeData = data;
          _isLoading = false;
        });
        print("✅ Employee data loaded from local storage");
      } else {
        // Create basic employee data if none exists
        setState(() {
          employeeData = {
            'id': widget.employeeId,
            'name': 'User ${widget.employeeId}',
            'platform': 'iOS',
          };
          _isLoading = false;
        });
        print("ℹ️ Using basic employee data");
      }

      // Try to get fresh data from Firestore if online
      if (!_isOfflineMode) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(widget.employeeId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            // Save to local storage
            await prefs.setString('user_data_${widget.employeeId}', jsonEncode(data));
            
            setState(() {
              employeeData = data;
            });
            print("✅ Employee data updated from Firestore");
          }
        } catch (e) {
          print("⚠️ Firestore fetch failed, using local data: $e");
        }
      }
    } catch (e) {
      debugPrint("❌ Error loading employee data: $e");
      setState(() {
        _isLoading = false;
        employeeData = {
          'id': widget.employeeId,
          'name': 'User ${widget.employeeId}',
          'platform': 'iOS',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          "📱 iOS Enhanced Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        actions: [
          // Debug toggle button
          IconButton(
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugInfo ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
          // Connectivity indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOfflineMode ? Colors.orange : Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isOfflineMode ? "Offline" : "Online",
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Time Card
                  _buildTimeCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Status Cards
                  _buildStatusCards(),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  _buildActionButtons(),
                  
                  const SizedBox(height: 16),
                  
                  // System Info
                  _buildSystemInfo(),

                  // ✅ DEBUG INFORMATION SECTION
                  if (_showDebugInfo) ...[
                    const SizedBox(height: 16),
                    _buildDebugSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Welcome back! 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            employeeData?['name'] ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "ID: ${widget.employeeId}",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentDate,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            title: "Face Data",
            status: _hasFaceData ? "✅ Available" : "❌ Missing",
            color: _hasFaceData ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            title: "SDK Mode",
            status: _isOfflineMode ? "📱 ML Kit" : "🌐 Regula",
            color: _isOfflineMode ? Colors.orange : Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Face Authentication Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasFaceData ? _authenticateFace : null,
            icon: const Icon(Icons.fingerprint, color: Colors.white),
            label: Text(
              _hasFaceData 
                ? "🔐 Face Authentication" 
                : "❌ No Face Data",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasFaceData ? const Color(0xFF667eea) : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Refresh Data Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              "🔄 Refresh All Data",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Debug Toggle Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
              color: Colors.white,
            ),
            label: Text(
              _showDebugInfo ? "🐛 Hide Debug Info" : "🐛 Show Debug Info",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showDebugInfo ? Colors.orange : const Color(0xFF9C27B0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 System Information",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow("Platform", "iOS"),
          _buildInfoRow("Employee ID", widget.employeeId),
          _buildInfoRow("Connection", _isOfflineMode ? "Offline Mode" : "Online Mode"),
          _buildInfoRow("Face SDK", _isOfflineMode ? "ML Kit (iOS Native)" : "Regula SDK (Cloud)"),
          _buildInfoRow("Face Data", _hasFaceData ? "Available" : "Not Available"),
          _buildInfoRow("Regula Offline", "❌ NOT SUPPORTED"),
          _buildInfoRow("Last Update", DateFormat('MMM dd, HH:mm').format(DateTime.now())),
        ],
      ),
    );
  }

  // ✅ COMPREHENSIVE DEBUG SECTION
  Widget _buildDebugSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.yellow, size: 20),
              const SizedBox(width: 8),
              const Text(
                "🐛 Complete Debug Information",
                style: TextStyle(
                  color: Colors.yellow,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                onPressed: _copyDebugInfo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Face Data Debug
          _buildDebugCategory("📱 Face Data Storage", _debugInfo['faceData']),
          const SizedBox(height: 12),
          
          // User Data Debug
          _buildDebugCategory("👤 User Profile Data", _debugInfo['userData']),
          const SizedBox(height: 12),
          
          // Authentication Debug
          _buildDebugCategory("🔐 Authentication Data", _debugInfo['authenticationData']),
          const SizedBox(height: 12),
          
          // Registration Flags Debug
          _buildDebugCategory("✅ Registration Flags", _debugInfo['registrationFlags']),
          const SizedBox(height: 12),
          
          // SDK Information Debug
          _buildDebugCategory("⚙️ SDK Information", _debugInfo['sdkInformation']),
          const SizedBox(height: 12),
          
          // System Info Debug
          _buildDebugCategory("📊 System Information", _debugInfo['systemInfo']),
          const SizedBox(height: 12),
          
          // All Stored Keys
          _buildStoredKeysSection(),
        ],
      ),
    );
  }

  Widget _buildDebugCategory(String title, Map<String, dynamic>? data) {
    if (data == null) return Container();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...data.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key + ":",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDebugValue(entry.value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildStoredKeysSection() {
    List<dynamic> keys = _debugInfo['allStoredKeys'] ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🗂️ All Stored Keys (${keys.length} total)",
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...keys.map((keyData) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              "${keyData['key']} (${keyData['type']}) ${keyData['hasValue'] ? '✅' : '❌'} ${keyData['valueLength'] != null ? '[${keyData['valueLength']} chars]' : ''}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  String _formatDebugValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.toString();
    } else if (value is String && value.length > 100) {
      return '${value.substring(0, 100)}...';
    } else {
      return value.toString();
    }
  }

  void _copyDebugInfo() {
    String debugText = jsonEncode(_debugInfo);
    Clipboard.setData(ClipboardData(text: debugText));
    _showMessage("🐛 Debug info copied to clipboard");
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ACTION METHODS
  void _authenticateFace() {
    if (!_hasFaceData) {
      _showMessage("No face data available for authentication");
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthenticateFaceView(
          employeeId: widget.employeeId,
          onAuthenticationComplete: (success) {
            if (success) {
              _showMessage("✅ Authentication successful!");
            } else {
              _showMessage("❌ Authentication failed");
            }
          },
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    await _checkConnectivity();
    await _loadEmployeeData();
    await _checkFaceData();
    await _loadDebugInformation();
    
    _showMessage("🔄 All data refreshed (Debug info updated)");
  }

  Future<void> _logout() async {
    bool shouldLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldLogout) {
      // Clear authentication data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('authenticated_user_id');
      await prefs.setBool('is_authenticated', false);
      await prefs.remove('authentication_timestamp');

      // Navigate to PIN entry
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const PinEntryView(),
          ),
          (route) => false,
        );
      }
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}