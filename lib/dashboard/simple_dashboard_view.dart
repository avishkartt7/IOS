// lib/dashboard/simple_dashboard_view.dart - iOS SIMPLE DASHBOARD

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:face_auth/pin_entry/pin_entry_view.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  @override
  void initState() {
    super.initState();
    print("🏠 iOS Simple Dashboard initialized for: ${widget.employeeId}");
    _loadEmployeeData();
    _updateDateTime();
    _checkConnectivity();
    _checkFaceData();
    
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
      bool faceRegistered = prefs.getBool('face_registered_${widget.employeeId}') ?? false;
      
      setState(() {
        _hasFaceData = (faceImage != null && faceImage.isNotEmpty) || faceRegistered;
      });
      
      print("🔍 Face data check: $_hasFaceData");
    } catch (e) {
      print("❌ Error checking face data: $e");
    }
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
          "📱 iOS Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        actions: [
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
            title: "Connection",
            status: _isOfflineMode ? "📱 Offline" : "🌐 Online",
            color: _isOfflineMode ? Colors.orange : Colors.green,
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
              "🔄 Refresh Data",
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
          _buildInfoRow("Status", _isOfflineMode ? "Offline Mode" : "Online Mode"),
          _buildInfoRow("Face Data", _hasFaceData ? "Available" : "Not Available"),
          _buildInfoRow("Last Update", DateFormat('MMM dd, HH:mm').format(DateTime.now())),
        ],
      ),
    );
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

  // Action Methods
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
    
    _showMessage("🔄 Data refreshed");
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