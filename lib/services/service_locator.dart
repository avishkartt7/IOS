// lib/services/service_locator.dart - UPDATED WITH PDF SERVICE

import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_auth_compatible/repositories/location_repository.dart';
import 'package:face_auth_compatible/repositories/polygon_location_repository.dart';
import 'package:face_auth_compatible/repositories/attendance_repository.dart';
import 'package:face_auth_compatible/repositories/check_out_request_repository.dart';
import 'package:face_auth_compatible/repositories/overtime_repository.dart';
import 'package:face_auth_compatible/repositories/leave_application_repository.dart';
import 'package:face_auth_compatible/services/database_helper.dart';
import 'package:face_auth_compatible/services/connectivity_service.dart';
import 'package:face_auth_compatible/services/notification_service.dart';
import 'package:face_auth_compatible/services/fcm_token_service.dart';
import 'package:face_auth_compatible/services/sync_service.dart';
import 'package:face_auth_compatible/services/secure_face_storage_service.dart';
import 'package:face_auth_compatible/services/overtime_approver_service.dart';
import 'package:face_auth_compatible/services/employee_overtime_service.dart';
import 'package:face_auth_compatible/services/leave_application_service.dart';
import 'package:face_auth_compatible/services/firebase_auth_service.dart';

import 'package:face_auth_compatible/repositories/location_exemption_repository.dart';
import 'package:face_auth_compatible/services/geofence_exit_monitoring_service.dart';

// ✅ NEW: Import the PDF service
import 'package:face_auth_compatible/services/attendance_pdf_service.dart';

final GetIt getIt = GetIt.instance;

/// Initialize all services and repositories - UPDATED WITH PDF SERVICE
Future<void> setupServiceLocator() async {
  print("=== INITIALIZING SERVICE LOCATOR (WITH PDF SERVICE) ===");

  try {
    // ================================
    // CORE SERVICES
    // ================================

    // Register database helper (FIRST - needed by everything)
    if (!getIt.isRegistered<DatabaseHelper>()) {
      getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
      print("✅ DatabaseHelper registered");
    }

    // Register connectivity service (SECOND - needed by repositories)
    if (!getIt.isRegistered<ConnectivityService>()) {
      getIt.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
      print("✅ ConnectivityService registered");
    }

    // Register secure storage service
    if (!getIt.isRegistered<SecureFaceStorageService>()) {
      getIt.registerLazySingleton<SecureFaceStorageService>(() => SecureFaceStorageService());
      print("✅ SecureFaceStorageService registered");
    }

    // Register Firebase Auth Service
    if (!getIt.isRegistered<FirebaseAuthService>()) {
      getIt.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());
      print("✅ FirebaseAuthService registered");
    }

    if (!getIt.isRegistered<GeofenceExitMonitoringService>()) {
      getIt.registerLazySingleton<GeofenceExitMonitoringService>(
            () => GeofenceExitMonitoringService(
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
          notificationService: getIt<NotificationService>(),
        ),
      );
      print("✅ GeofenceExitMonitoringService registered");
    }

    // ✅ NEW: Register PDF Service
    if (!getIt.isRegistered<AttendancePdfService>()) {
      getIt.registerLazySingleton<AttendancePdfService>(() => AttendancePdfService());
      print("✅ AttendancePdfService registered");
    }

    // ================================
    // NOTIFICATION SERVICES
    // ================================

    // Register notification services
    if (!getIt.isRegistered<NotificationService>()) {
      getIt.registerLazySingleton<NotificationService>(() => NotificationService());
      print("✅ NotificationService registered");
    }

    // Register FCM token service
    if (!getIt.isRegistered<FcmTokenService>()) {
      getIt.registerLazySingleton<FcmTokenService>(() => FcmTokenService());
      print("✅ FcmTokenService registered");
    }

    // ================================
    // REPOSITORIES
    // ================================

    // Register location repository
    if (!getIt.isRegistered<LocationRepository>()) {
      getIt.registerLazySingleton<LocationRepository>(
            () => LocationRepository(
          firestore: FirebaseFirestore.instance,
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ LocationRepository registered");
    }



    // Register polygon location repository
    if (!getIt.isRegistered<PolygonLocationRepository>()) {
      getIt.registerLazySingleton<PolygonLocationRepository>(
            () => PolygonLocationRepository(
          firestore: FirebaseFirestore.instance,
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ PolygonLocationRepository registered");
    }

    // Register attendance repository
    if (!getIt.isRegistered<AttendanceRepository>()) {
      getIt.registerLazySingleton<AttendanceRepository>(
            () => AttendanceRepository(
          firestore: FirebaseFirestore.instance,
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ AttendanceRepository registered");
    }

    getIt.registerLazySingleton<LocationExemptionRepository>(
          () => LocationExemptionRepository(
        dbHelper: getIt<DatabaseHelper>(),
        connectivityService: getIt<ConnectivityService>(),
      ),
    );

    // Register check-out request repository
    if (!getIt.isRegistered<CheckOutRequestRepository>()) {
      getIt.registerLazySingleton<CheckOutRequestRepository>(
            () => CheckOutRequestRepository(
          firestore: FirebaseFirestore.instance,
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ CheckOutRequestRepository registered");
    }

    // Register overtime repository
    if (!getIt.isRegistered<OvertimeRepository>()) {
      getIt.registerLazySingleton<OvertimeRepository>(
            () => OvertimeRepository(
          firestore: FirebaseFirestore.instance,
          dbHelper: getIt<DatabaseHelper>(),
          connectivityService: getIt<ConnectivityService>(),
          notificationService: getIt<NotificationService>(),
        ),
      );
      print("✅ OvertimeRepository registered");
    }

    // Register leave application repository
    if (!getIt.isRegistered<LeaveApplicationRepository>()) {
      getIt.registerLazySingleton<LeaveApplicationRepository>(
            () => LeaveApplicationRepository(
          dbHelper: getIt<DatabaseHelper>(),
          firestore: FirebaseFirestore.instance,
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ LeaveApplicationRepository registered");
    }

    // ================================
    // APPLICATION SERVICES
    // ================================

    // Register sync service (depends on repositories)
    if (!getIt.isRegistered<SyncService>()) {
      getIt.registerLazySingleton<SyncService>(
            () => SyncService(
          attendanceRepository: getIt<AttendanceRepository>(),
          checkOutRequestRepository: getIt<CheckOutRequestRepository>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ SyncService registered");
    }

    // Register overtime services
    if (!getIt.isRegistered<OvertimeApproverService>()) {
      getIt.registerLazySingleton<OvertimeApproverService>(() => OvertimeApproverService());
      print("✅ OvertimeApproverService registered");
    }

    if (!getIt.isRegistered<EmployeeOvertimeService>()) {
      getIt.registerLazySingleton<EmployeeOvertimeService>(() => EmployeeOvertimeService());
      print("✅ EmployeeOvertimeService registered");
    }

    // Register leave application service
    if (!getIt.isRegistered<LeaveApplicationService>()) {
      getIt.registerLazySingleton<LeaveApplicationService>(
            () => LeaveApplicationService(
          repository: getIt<LeaveApplicationRepository>(),
          connectivityService: getIt<ConnectivityService>(),
        ),
      );
      print("✅ LeaveApplicationService registered");
    }

    print("✅ Service Locator setup completed successfully (With PDF Service)");
    print("📊 Total registered services: ${_getRegisteredServicesCount()}");

    // Validate critical services
    _validateCriticalServices();

  } catch (e) {
    print("❌ Error setting up Service Locator: $e");
    print("📍 Stack trace: ${StackTrace.current}");
    rethrow;
  }
}

/// Validate that critical services are properly registered
void _validateCriticalServices() {
  print("🔍 Validating critical services...");

  final criticalServices = [
    'FirebaseAuthService',
    'DatabaseHelper',
    'ConnectivityService',
    'AttendanceRepository',
    'AttendancePdfService', // ✅ ADDED
    'NotificationService'
  ];

  bool allValid = true;

  for (String serviceName in criticalServices) {
    bool isValid = false;

    switch (serviceName) {
      case 'FirebaseAuthService':
        isValid = isServiceRegistered<FirebaseAuthService>();
        break;
      case 'DatabaseHelper':
        isValid = isServiceRegistered<DatabaseHelper>();
        break;
      case 'ConnectivityService':
        isValid = isServiceRegistered<ConnectivityService>();
        break;
      case 'GeofenceExitMonitoringService':
        isValid = isServiceRegistered<GeofenceExitMonitoringService>();
        break;
      case 'AttendanceRepository':
        isValid = isServiceRegistered<AttendanceRepository>();
        break;
      case 'AttendancePdfService': // ✅ ADDED
        isValid = isServiceRegistered<AttendancePdfService>();
        break;
      case 'NotificationService':
        isValid = isServiceRegistered<NotificationService>();
        break;
    }

    if (!isValid) {
      print("❌ CRITICAL SERVICE MISSING: $serviceName");
      allValid = false;
    } else {
      print("✅ Critical service validated: $serviceName");
    }
  }

  if (allValid) {
    print("🎉 All critical services are properly registered");
  } else {
    print("⚠️ CRITICAL SERVICES MISSING - App may not function properly");
  }
}

/// Get count of registered services
int _getRegisteredServicesCount() {
  int count = 0;

  // Core services
  if (getIt.isRegistered<DatabaseHelper>()) count++;
  if (getIt.isRegistered<ConnectivityService>()) count++;
  if (getIt.isRegistered<SecureFaceStorageService>()) count++;
  if (getIt.isRegistered<FirebaseAuthService>()) count++;
  if (getIt.isRegistered<AttendancePdfService>()) count++; // ✅ ADDED
  if (getIt.isRegistered<GeofenceExitMonitoringService>()) count++;

  // Notification services
  if (getIt.isRegistered<NotificationService>()) count++;
  if (getIt.isRegistered<FcmTokenService>()) count++;

  // Repositories
  if (getIt.isRegistered<LocationRepository>()) count++;
  if (getIt.isRegistered<PolygonLocationRepository>()) count++;
  if (getIt.isRegistered<AttendanceRepository>()) count++;
  if (getIt.isRegistered<CheckOutRequestRepository>()) count++;
  if (getIt.isRegistered<OvertimeRepository>()) count++;
  if (getIt.isRegistered<LeaveApplicationRepository>()) count++;

  // Application services
  if (getIt.isRegistered<SyncService>()) count++;
  if (getIt.isRegistered<OvertimeApproverService>()) count++;
  if (getIt.isRegistered<EmployeeOvertimeService>()) count++;
  if (getIt.isRegistered<LeaveApplicationService>()) count++;

  return count;
}

/// Reset the service locator (useful for testing)
Future<void> resetServiceLocator() async {
  print("=== RESETTING SERVICE LOCATOR ===");

  try {
    // Dispose services that need cleanup
    if (getIt.isRegistered<ConnectivityService>()) {
      getIt<ConnectivityService>().dispose();
      print("✅ ConnectivityService disposed");
    }

    // Reset GetIt
    await getIt.reset();

    print("✅ Service Locator reset completed");
  } catch (e) {
    print("❌ Error resetting Service Locator: $e");
    rethrow;
  }
}

/// Get a service from the locator with enhanced error handling
T getService<T extends Object>({String? debugName}) {
  try {
    if (!getIt.isRegistered<T>()) {
      throw Exception('Service ${T.toString()} is not registered. Did you call setupServiceLocator()?');
    }

    final service = getIt<T>();
    if (debugName != null) {
      print("🔧 Retrieved service: $debugName (${T.toString()})");
    }

    return service;
  } catch (e) {
    print("❌ Error getting service ${T.toString()}: $e");
    print("💡 Available services: ${_getAvailableServices()}");
    rethrow;
  }
}

/// Check if a service is registered
bool isServiceRegistered<T extends Object>() {
  return getIt.isRegistered<T>();
}

/// Get list of all available services
List<String> _getAvailableServices() {
  final services = <String>[];

  // Check all possible services
  if (isServiceRegistered<DatabaseHelper>()) services.add('DatabaseHelper');
  if (isServiceRegistered<ConnectivityService>()) services.add('ConnectivityService');
  if (isServiceRegistered<SecureFaceStorageService>()) services.add('SecureFaceStorageService');
  if (isServiceRegistered<FirebaseAuthService>()) services.add('FirebaseAuthService');
  if (isServiceRegistered<AttendancePdfService>()) services.add('AttendancePdfService'); // ✅ ADDED
  if (isServiceRegistered<NotificationService>()) services.add('NotificationService');
  if (isServiceRegistered<FcmTokenService>()) services.add('FcmTokenService');
  if (isServiceRegistered<LocationRepository>()) services.add('LocationRepository');
  if (isServiceRegistered<PolygonLocationRepository>()) services.add('PolygonLocationRepository');
  if (isServiceRegistered<AttendanceRepository>()) services.add('AttendanceRepository');
  if (isServiceRegistered<CheckOutRequestRepository>()) services.add('CheckOutRequestRepository');
  if (isServiceRegistered<OvertimeRepository>()) services.add('OvertimeRepository');
  if (isServiceRegistered<LeaveApplicationRepository>()) services.add('LeaveApplicationRepository');
  if (isServiceRegistered<SyncService>()) services.add('SyncService');
  if (isServiceRegistered<OvertimeApproverService>()) services.add('OvertimeApproverService');
  if (isServiceRegistered<EmployeeOvertimeService>()) services.add('EmployeeOvertimeService');
  if (isServiceRegistered<LeaveApplicationService>()) services.add('LeaveApplicationService');
  if (isServiceRegistered<GeofenceExitMonitoringService>()) services.add('GeofenceExitMonitoringService');
  return services;
}

/// Enhanced debug method to list all registered services with details
void listRegisteredServices({bool showDetails = false}) {
  print("=== REGISTERED SERVICES REPORT ===");

  final services = _getAvailableServices();

  print("📊 Total Services: ${services.length}");
  print("");

  // Core Services
  print("🔧 CORE SERVICES:");
  _printServiceStatus('DatabaseHelper', isServiceRegistered<DatabaseHelper>());
  _printServiceStatus('ConnectivityService', isServiceRegistered<ConnectivityService>());
  _printServiceStatus('SecureFaceStorageService', isServiceRegistered<SecureFaceStorageService>());
  _printServiceStatus('FirebaseAuthService', isServiceRegistered<FirebaseAuthService>());
  _printServiceStatus('AttendancePdfService', isServiceRegistered<AttendancePdfService>()); // ✅ ADDED
  print("");

  // Notification Services
  print("📱 NOTIFICATION SERVICES:");
  _printServiceStatus('NotificationService', isServiceRegistered<NotificationService>());
  _printServiceStatus('FcmTokenService', isServiceRegistered<FcmTokenService>());
  print("");

  // Repositories
  print("🗃️ REPOSITORIES:");
  _printServiceStatus('LocationRepository', isServiceRegistered<LocationRepository>());
  _printServiceStatus('PolygonLocationRepository', isServiceRegistered<PolygonLocationRepository>());
  _printServiceStatus('AttendanceRepository', isServiceRegistered<AttendanceRepository>());
  _printServiceStatus('CheckOutRequestRepository', isServiceRegistered<CheckOutRequestRepository>());
  _printServiceStatus('OvertimeRepository', isServiceRegistered<OvertimeRepository>());
  _printServiceStatus('LeaveApplicationRepository', isServiceRegistered<LeaveApplicationRepository>());
  print("");

  // Application Services
  print("⚙️ APPLICATION SERVICES:");
  _printServiceStatus('SyncService', isServiceRegistered<SyncService>());
  _printServiceStatus('OvertimeApproverService', isServiceRegistered<OvertimeApproverService>());
  _printServiceStatus('EmployeeOvertimeService', isServiceRegistered<EmployeeOvertimeService>());
  _printServiceStatus('LeaveApplicationService', isServiceRegistered<LeaveApplicationService>());

  _printServiceStatus('GeofenceExitMonitoringService', isServiceRegistered<GeofenceExitMonitoringService>());

  print("=====================================");

  if (showDetails) {
    print("");
    print("🔍 DETAILED SERVICE INFORMATION:");
    for (String service in services) {
      try {
        print("   ✅ $service: Ready");
      } catch (e) {
        print("   ❌ $service: Error - $e");
      }
    }
    print("=====================================");
  }
}

/// Helper method to print service status
void _printServiceStatus(String serviceName, bool isRegistered) {
  final status = isRegistered ? '✅' : '❌';
  final statusText = isRegistered ? 'Registered' : 'Not Registered';
  print("   $status $serviceName: $statusText");
}

/// Validate that all required services are registered
bool validateServiceLocator() {
  print("🔍 Validating Service Locator...");

  final requiredServices = [
    'DatabaseHelper',
    'ConnectivityService',
    'FirebaseAuthService',
    'AttendanceRepository',
    'AttendancePdfService', // ✅ ADDED
    'NotificationService',
    'LeaveApplicationRepository',
    'LeaveApplicationService',
  ];

  bool allValid = true;

  for (String serviceName in requiredServices) {
    bool isValid = false;

    switch (serviceName) {
      case 'DatabaseHelper':
        isValid = isServiceRegistered<DatabaseHelper>();
        break;
      case 'ConnectivityService':
        isValid = isServiceRegistered<ConnectivityService>();
        break;
      case 'FirebaseAuthService':
        isValid = isServiceRegistered<FirebaseAuthService>();
        break;
      case 'AttendanceRepository':
        isValid = isServiceRegistered<AttendanceRepository>();
        break;
      case 'AttendancePdfService': // ✅ ADDED
        isValid = isServiceRegistered<AttendancePdfService>();
        break;
      case 'NotificationService':
        isValid = isServiceRegistered<NotificationService>();
        break;
      case 'LeaveApplicationRepository':
        isValid = isServiceRegistered<LeaveApplicationRepository>();
        break;
      case 'LeaveApplicationService':
        isValid = isServiceRegistered<LeaveApplicationService>();
        break;
    }

    if (!isValid) {
      print("❌ Required service not registered: $serviceName");
      allValid = false;
    } else {
      print("✅ Required service registered: $serviceName");
    }
  }

  if (allValid) {
    print("✅ All required services are properly registered");
  } else {
    print("❌ Some required services are missing");
  }

  return allValid;
}

/// Quick authentication service helper
FirebaseAuthService get authService {
  if (!isServiceRegistered<FirebaseAuthService>()) {
    throw Exception('FirebaseAuthService is not registered. Authentication will not work.');
  }
  return getIt<FirebaseAuthService>();
}

/// Quick connectivity service helper
ConnectivityService get connectivityService {
  if (!isServiceRegistered<ConnectivityService>()) {
    throw Exception('ConnectivityService is not registered.');
  }
  return getIt<ConnectivityService>();
}

/// Quick database helper
DatabaseHelper get databaseHelper {
  if (!isServiceRegistered<DatabaseHelper>()) {
    throw Exception('DatabaseHelper is not registered.');
  }
  return getIt<DatabaseHelper>();
}

/// ✅ NEW: Quick PDF service helper
AttendancePdfService get pdfService {
  if (!isServiceRegistered<AttendancePdfService>()) {
    throw Exception('AttendancePdfService is not registered.');
  }
  return getIt<AttendancePdfService>();
}

/// Service health check
Future<Map<String, bool>> checkServiceHealth() async {
  print("🏥 Performing service health check...");

  final healthStatus = <String, bool>{};

  try {
    // Check critical services
    healthStatus['FirebaseAuthService'] = isServiceRegistered<FirebaseAuthService>();
    healthStatus['DatabaseHelper'] = isServiceRegistered<DatabaseHelper>();
    healthStatus['ConnectivityService'] = isServiceRegistered<ConnectivityService>();
    healthStatus['AttendanceRepository'] = isServiceRegistered<AttendanceRepository>();
    healthStatus['AttendancePdfService'] = isServiceRegistered<AttendancePdfService>(); // ✅ ADDED
    healthStatus['NotificationService'] = isServiceRegistered<NotificationService>();
    healthStatus['GeofenceExitMonitoringService'] = isServiceRegistered<GeofenceExitMonitoringService>();


    // Check if services are actually functional
    if (healthStatus['DatabaseHelper'] == true) {
      try {
        final db = getIt<DatabaseHelper>();
        healthStatus['DatabaseHelper_functional'] = db != null;
      } catch (e) {
        healthStatus['DatabaseHelper_functional'] = false;
        print("❌ DatabaseHelper functional test failed: $e");
      }
    }

    if (healthStatus['ConnectivityService'] == true) {
      try {
        final connectivity = getIt<ConnectivityService>();
        healthStatus['ConnectivityService_functional'] = connectivity != null;
      } catch (e) {
        healthStatus['ConnectivityService_functional'] = false;
        print("❌ ConnectivityService functional test failed: $e");
      }
    }

    if (healthStatus['GeofenceExitMonitoringService'] == true) {
      try {
        final geofenceService = getIt<GeofenceExitMonitoringService>();
        healthStatus['GeofenceExitMonitoringService_functional'] = geofenceService != null;
      } catch (e) {
        healthStatus['GeofenceExitMonitoringService_functional'] = false;
        print("❌ GeofenceExitMonitoringService functional test failed: $e");
      }
    }

    // ✅ NEW: Check PDF service functionality
    if (healthStatus['AttendancePdfService'] == true) {
      try {
        final pdfService = getIt<AttendancePdfService>();
        healthStatus['AttendancePdfService_functional'] = pdfService != null;
      } catch (e) {
        healthStatus['AttendancePdfService_functional'] = false;
        print("❌ AttendancePdfService functional test failed: $e");
      }

    }

    print("✅ Service health check completed");

    // Print health summary
    print("📊 HEALTH SUMMARY:");
    healthStatus.forEach((service, isHealthy) {
      final status = isHealthy ? '✅' : '❌';
      print("   $status $service");
    });

  } catch (e) {
    print("❌ Error during health check: $e");
  }

  return healthStatus;
}



