// lib/debug/debug_dashboard_view.dart - COMPREHENSIVE DEBUGGING DASHBOARD

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth/constants/theme.dart';
import 'package:face_auth/authenticate_face/authenticate_face_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:face_auth/model/user_model.dart';

class DebugDashboardView extends StatefulWidget {
  final String employeeId;

  const DebugDashboardView({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<DebugDashboardView> createState() => _DebugDashboardViewState();
}

class _DebugDashboardViewState extends State<DebugDashboardView> {
  bool _isLoading = true;
  bool _isOfflineMode = false;
  Map<String, dynamic> _debugData = {};
  Map<String, dynamic> _firestoreData = {};
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeDebugDashboard();
  }

  Future<void> _initializeDebugDashboard() async {
    await _checkConnectivity();
    await _loadDebugData();
    await _loadFirestoreData();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      setState(() {
        _isOfflineMode = connectivityResult == ConnectivityResult.none;
      });
      _addLog("📶 Connectivity: ${_isOfflineMode ? 'Offline' : 'Online'}");
    } catch (e) {
      setState(() {
        _isOfflineMode = true;
      });
      _addLog("⚠️ Connectivity check failed: $e");
    }
  }

  Future<void> _loadDebugData() async {
    try {
      _addLog("🔍 Loading comprehensive debug data...");
      
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      Map<String, dynamic> debugInfo = {
        'timestamp': DateTime.now().toIso8601String(),
        'employeeId': widget.employeeId,
        'platform': 'iOS',
        'totalKeys': allKeys.length,
        'connectivity': _isOfflineMode ? 'Offline' : 'Online',
        'faceImageData': {},
        'faceFeatureData': {},
        'registrationFlags': {},
        'authenticationData': {},
        'employeeKeys': [],
        'allKeys': [],
      };

      // ✅ FACE IMAGE DATA ANALYSIS
      debugInfo['faceImageData'] = {
        'employee_image': _analyzeStorageKey(prefs, 'employee_image_${widget.employeeId}'),
        'secure_face_image': _analyzeStorageKey(prefs, 'secure_face_image_${widget.employeeId}'),
        'backup_locations': [],
      };

      // ✅ FACE FEATURE DATA ANALYSIS
      debugInfo['faceFeatureData'] = {
        'employee_face_features': _analyzeStorageKey(prefs, 'employee_face_features_${widget.employeeId}'),
        'secure_face_features': _analyzeStorageKey(prefs, 'secure_face_features_${widget.employeeId}'),
        'secure_enhanced_face_features': _analyzeStorageKey(prefs, 'secure_enhanced_face_features_${widget.employeeId}'),
        'parsed_features': await _analyzeFaceFeatures(prefs),
      };

      // ✅ REGISTRATION FLAGS ANALYSIS
      debugInfo['registrationFlags'] = {
        'face_registered': prefs.getBool('face_registered_${widget.employeeId}') ?? false,
        'enhanced_face_registered': prefs.getBool('enhanced_face_registered_${widget.employeeId}') ?? false,
        'registration_complete': prefs.getBool('registration_complete_${widget.employeeId}') ?? false,
        'face_registration_date': prefs.getString('face_registration_date_${widget.employeeId}'),
        'face_registration_platform': prefs.getString('face_registration_platform_${widget.employeeId}'),
        'registration_timestamp': prefs.getInt('face_registration_timestamp_${widget.employeeId}'),
      };

      // ✅ AUTHENTICATION DATA ANALYSIS
      debugInfo['authenticationData'] = {
        'authenticated_user_id': prefs.getString('authenticated_user_id'),
        'is_authenticated': prefs.getBool('is_authenticated') ?? false,
        'authentication_timestamp': prefs.getInt('authentication_timestamp'),
        'last_auth_date': _formatTimestamp(prefs.getInt('authentication_timestamp')),
      };

      // ✅ EMPLOYEE-SPECIFIC KEYS
      List<String> employeeKeys = allKeys
          .where((key) => key.contains(widget.employeeId))
          .toList();
      
      debugInfo['employeeKeys'] = employeeKeys.map((key) => {
        'key': key,
        'type': prefs.get(key).runtimeType.toString(),
        'hasValue': prefs.get(key) != null,
        'valuePreview': _getValuePreview(prefs.get(key)),
      }).toList();

      setState(() {
        _debugData = debugInfo;
      });

      _addLog("✅ Debug data loaded: ${debugInfo['totalKeys']} total keys, ${employeeKeys.length} employee keys");

    } catch (e) {
      _addLog("❌ Error loading debug data: $e");
    }
  }

  Future<void> _loadFirestoreData() async {
    if (_isOfflineMode) {
      _addLog("📱 Skipping Firestore data (offline mode)");
      return;
    }

    try {
      _addLog("🌐 Loading Firestore data...");
      
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get()
          .timeout(Duration(seconds: 10));

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          _firestoreData = {
            'exists': true,
            'hasImage': data.containsKey('image') && data['image'] != null,
            'imageLength': data['image']?.length ?? 0,
            'hasFaceFeatures': data.containsKey('faceFeatures') && data['faceFeatures'] != null,
            'hasEnhancedFeatures': data.containsKey('enhancedFaceFeatures') && data['enhancedFaceFeatures'] != null,
            'faceRegistered': data['faceRegistered'] ?? false,
            'platform': data['platform'] ?? 'Unknown',
            'registeredOn': data['registeredOn']?.toString() ?? 'Unknown',
            'faceQualityScore': data['faceQualityScore'],
            'registrationMethod': data['registrationMethod'],
            'allFields': data.keys.toList(),
          };
        });

        _addLog("✅ Firestore data loaded successfully");
        _addLog("📊 Firestore has face data: ${_firestoreData['hasImage']}");
        
      } else {
        setState(() {
          _firestoreData = {'exists': false};
        });
        _addLog("❌ Employee document not found in Firestore");
      }

    } catch (e) {
      _addLog("❌ Error loading Firestore data: $e");
      setState(() {
        _firestoreData = {'error': e.toString()};
      });
    }
  }

  Future<Map<String, dynamic>> _analyzeFaceFeatures(SharedPreferences prefs) async {
    Map<String, dynamic> analysis = {
      'canParse': false,
      'featureCount': 0,
      'essentialFeatures': [],
      'missingFeatures': [],
      'qualityScore': 0.0,
    };

    try {
      String? featuresJson = prefs.getString('employee_face_features_${widget.employeeId}');
      
      if (featuresJson != null && featuresJson.isNotEmpty) {
        Map<String, dynamic> featuresMap = jsonDecode(featuresJson);
        FaceFeatures features = FaceFeatures.fromJson(featuresMap);
        
        analysis['canParse'] = true;
        
        List<String> essential = [];
        List<String> missing = [];
        
        if (features.leftEye != null) essential.add('leftEye'); else missing.add('leftEye');
        if (features.rightEye != null) essential.add('rightEye'); else missing.add('rightEye');
        if (features.noseBase != null) essential.add('noseBase'); else missing.add('noseBase');
        if (features.leftMouth != null) essential.add('leftMouth'); else missing.add('leftMouth');
        if (features.rightMouth != null) essential.add('rightMouth'); else missing.add('rightMouth');
        
        analysis['featureCount'] = essential.length;
        analysis['essentialFeatures'] = essential;
        analysis['missingFeatures'] = missing;
        analysis['qualityScore'] = essential.length / 5.0; // Basic quality score
        
        _addLog("📊 Face features analysis: ${essential.length}/5 essential features");
      } else {
        _addLog("❌ No face features found for analysis");
      }
      
    } catch (e) {
      _addLog("❌ Error analyzing face features: $e");
      analysis['error'] = e.toString();
    }

    return analysis;
  }

  Map<String, dynamic> _analyzeStorageKey(SharedPreferences prefs, String key) {
    var value = prefs.get(key);
    return {
      'exists': value != null,
      'type': value?.runtimeType.toString() ?? 'null',
      'length': value is String ? value.length : null,
      'hasContent': value != null && (value is! String || value.isNotEmpty),
      'preview': _getValuePreview(value),
    };
  }

  String _getValuePreview(dynamic value) {
    if (value == null) return 'null';
    if (value is bool || value is int) return value.toString();
    if (value is String) {
      if (value.length > 50) return '${value.substring(0, 50)}...';
      return value;
    }
    return value.toString();
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) return 'Never';
    try {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return date.toString();
    } catch (e) {
      return 'Invalid timestamp';
    }
  }

  void _addLog(String message) {
    String timestampedMessage = "${DateTime.now().toIso8601String().substring(11, 19)} - $message";
    setState(() {
      _debugLogs.add(timestampedMessage);
    });
    print(timestampedMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          "🐛 Debug Dashboard - ${widget.employeeId}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF16213E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshDebugData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusOverview(),
                  const SizedBox(height: 16),
                  _buildFaceDataAnalysis(),
                  const SizedBox(height: 16),
                  _buildRegistrationAnalysis(),
                  const SizedBox(height: 16),
                  _buildFirestoreAnalysis(),
                  const SizedBox(height: 16),
                  _buildTestActions(),
                  const SizedBox(height: 16),
                  _buildDebugLogs(),
                  const SizedBox(height: 16),
                  _buildRawDataSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusOverview() {
    return _buildSection(
      title: "📊 Status Overview",
      child: Column(
        children: [
          _buildStatusRow("Platform", "iOS", Colors.blue),
          _buildStatusRow("Connectivity", _isOfflineMode ? "Offline" : "Online", 
              _isOfflineMode ? Colors.orange : Colors.green),
          _buildStatusRow("Local Face Data", 
              _debugData['faceImageData']?['employee_image']?['exists'] == true ? "Available" : "Missing",
              _debugData['faceImageData']?['employee_image']?['exists'] == true ? Colors.green : Colors.red),
          _buildStatusRow("Face Registered", 
              _debugData['registrationFlags']?['face_registered'] == true ? "Yes" : "No",
              _debugData['registrationFlags']?['face_registered'] == true ? Colors.green : Colors.red),
          _buildStatusRow("Cloud Data", 
              _firestoreData['exists'] == true ? "Available" : "Missing",
              _firestoreData['exists'] == true ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceDataAnalysis() {
    var faceData = _debugData['faceFeatureData']?['parsed_features'] ?? {};
    var imageData = _debugData['faceImageData'] ?? {};
    
    return _buildSection(
      title: "🔍 Face Data Analysis",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubSection("Image Storage", [
            "Primary: ${imageData['employee_image']?['exists'] == true ? '✅' : '❌'} (${imageData['employee_image']?['length'] ?? 0} chars)",
            "Secure: ${imageData['secure_face_image']?['exists'] == true ? '✅' : '❌'} (${imageData['secure_face_image']?['length'] ?? 0} chars)",
          ]),
          const SizedBox(height: 12),
          _buildSubSection("Feature Analysis", [
            "Can Parse: ${faceData['canParse'] == true ? '✅' : '❌'}",
            "Quality Score: ${((faceData['qualityScore'] ?? 0.0) * 100).toStringAsFixed(1)}%",
            "Essential Features: ${faceData['essentialFeatures']?.join(', ') ?? 'None'}",
            "Missing Features: ${faceData['missingFeatures']?.join(', ') ?? 'None'}",
          ]),
        ],
      ),
    );
  }

  Widget _buildRegistrationAnalysis() {
    var regData = _debugData['registrationFlags'] ?? {};
    
    return _buildSection(
      title: "📝 Registration Analysis",
      child: _buildSubSection("Registration Status", [
        "Face Registered: ${regData['face_registered'] == true ? '✅ Yes' : '❌ No'}",
        "Enhanced Registered: ${regData['enhanced_face_registered'] == true ? '✅ Yes' : '❌ No'}",
        "Registration Complete: ${regData['registration_complete'] == true ? '✅ Yes' : '❌ No'}",
        "Registration Date: ${regData['face_registration_date'] ?? 'Not set'}",
        "Platform: ${regData['face_registration_platform'] ?? 'Not set'}",
      ]),
    );
  }

  Widget _buildFirestoreAnalysis() {
    if (_isOfflineMode) {
      return _buildSection(
        title: "☁️ Firestore Analysis",
        child: const Text("Offline mode - Firestore data not available", 
            style: TextStyle(color: Colors.orange)),
      );
    }

    return _buildSection(
      title: "☁️ Firestore Analysis",
      child: _buildSubSection("Cloud Data Status", [
        "Document Exists: ${_firestoreData['exists'] == true ? '✅ Yes' : '❌ No'}",
        if (_firestoreData['exists'] == true) ...[
          "Has Image: ${_firestoreData['hasImage'] == true ? '✅ Yes' : '❌ No'} (${_firestoreData['imageLength']} chars)",
          "Has Face Features: ${_firestoreData['hasFaceFeatures'] == true ? '✅ Yes' : '❌ No'}",
          "Face Registered: ${_firestoreData['faceRegistered'] == true ? '✅ Yes' : '❌ No'}",
          "Platform: ${_firestoreData['platform'] ?? 'Unknown'}",
          "Quality Score: ${_firestoreData['faceQualityScore']?.toString() ?? 'Not set'}",
        ],
        if (_firestoreData['error'] != null) "Error: ${_firestoreData['error']}",
      ]),
    );
  }

  Widget _buildTestActions() {
    return _buildSection(
      title: "🧪 Test Actions",
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testAuthentication,
                  icon: const Icon(Icons.face, color: Colors.white),
                  label: const Text("Test Authentication", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyDebugData,
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text("Copy Debug Data", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clearAllData,
                  icon: const Icon(Icons.clear, color: Colors.white),
                  label: const Text("Clear All Data", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshDebugData,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text("Refresh Data", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogs() {
    return _buildSection(
      title: "📋 Debug Logs (${_debugLogs.length})",
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _debugLogs.length,
          itemBuilder: (context, index) {
            return Text(
              _debugLogs[index],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRawDataSection() {
    return _buildSection(
      title: "🗂️ Raw Data",
      child: Column(
        children: [
          ExpansionTile(
            title: const Text("Employee Keys", style: TextStyle(color: Colors.white)),
            children: [
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _debugData['employeeKeys']?.length ?? 0,
                  itemBuilder: (context, index) {
                    var keyData = _debugData['employeeKeys'][index];
                    return Text(
                      "${keyData['key']} (${keyData['type']}) ${keyData['hasValue'] ? '✅' : '❌'}",
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
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
          Text(title, style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text("• $item", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        )).toList(),
      ],
    );
  }

  void _testAuthentication() {
    _addLog("🧪 Starting authentication test...");
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthenticateFaceView(
          employeeId: widget.employeeId,
          onAuthenticationComplete: (success) {
            _addLog("🧪 Authentication test result: ${success ? 'SUCCESS' : 'FAILED'}");
          },
        ),
      ),
    );
  }

  void _copyDebugData() {
    String debugText = jsonEncode(_debugData);
    Clipboard.setData(ClipboardData(text: debugText));
    _addLog("📋 Debug data copied to clipboard");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Debug data copied to clipboard")),
    );
  }

  Future<void> _clearAllData() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2E2E2E),
        title: const Text("Clear All Data", style: TextStyle(color: Colors.white)),
        content: const Text("This will remove all stored face data. Continue?", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().where((key) => key.contains(widget.employeeId)).toList();
        
        for (String key in keys) {
          await prefs.remove(key);
        }
        
        _addLog("🧹 Cleared ${keys.length} employee data keys");
        await _refreshDebugData();
        
      } catch (e) {
        _addLog("❌ Error clearing data: $e");
      }
    }
  }

  Future<void> _refreshDebugData() async {
    setState(() {
      _isLoading = true;
      _debugLogs.clear();
    });
    
    _addLog("🔄 Refreshing debug dashboard...");
    await _initializeDebugDashboard();
    _addLog("✅ Debug dashboard refreshed");
  }
}