// lib/utils/enhanced_geofence_util.dart - CORRECTED VERSION

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:face_auth_compatible/model/location_model.dart';
import 'package:face_auth_compatible/model/polygon_location_model.dart';
import 'package:geodesy/geodesy.dart';
import 'package:face_auth_compatible/repositories/polygon_location_repository.dart';
import 'package:face_auth_compatible/repositories/location_repository.dart';
import 'package:face_auth_compatible/repositories/location_exemption_repository.dart';
import 'package:face_auth_compatible/services/service_locator.dart';
import 'dart:math' show sqrt, cos, pi;

class EnhancedGeofenceUtil {
  // Cache for location data to improve performance
  static List<LocationModel>? _cachedCircularLocations;
  static List<PolygonLocationModel>? _cachedPolygonLocations;
  static DateTime? _locationCacheTime;
  static const Duration _locationCacheTimeout = Duration(minutes: 5);

  // Check location permissions
  static Future<bool> checkLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable the services'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, please enable them in app settings',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Permissions are granted
    return true;
  }

  // Get current position with timeout
  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  // Get and cache location data
  static Future<void> _loadLocationData() async {
    // Check if cache is still valid
    if (_locationCacheTime != null &&
        DateTime.now().difference(_locationCacheTime!) < _locationCacheTimeout &&
        _cachedCircularLocations != null &&
        _cachedPolygonLocations != null) {
      return; // Use cached data
    }

    try {
      // Load fresh data
      final locationRepository = getIt<LocationRepository>();
      final polygonRepository = getIt<PolygonLocationRepository>();

      _cachedCircularLocations = await locationRepository.getActiveLocations();
      _cachedPolygonLocations = await polygonRepository.getActivePolygonLocations();
      _locationCacheTime = DateTime.now();

      debugPrint('Location data cached: ${_cachedCircularLocations?.length ?? 0} circular, ${_cachedPolygonLocations?.length ?? 0} polygon');
    } catch (e) {
      debugPrint('Error loading location data: $e');
      // Keep existing cache if available
    }
  }

  // Helper method to get active locations (for background use)
  static Future<List<LocationModel>> _getActiveLocations() async {
    try {
      await _loadLocationData();
      return _cachedCircularLocations ?? [];
    } catch (e) {
      debugPrint('Error getting active locations: $e');
      return [];
    }
  }

  // Helper method to get active polygon locations (for background use)
  static Future<List<PolygonLocationModel>> _getActivePolygonLocations() async {
    try {
      await _loadLocationData();
      return _cachedPolygonLocations ?? [];
    } catch (e) {
      debugPrint('Error getting active polygon locations: $e');
      return [];
    }
  }

  // Check employee location exemption (internal method)
  static Future<bool> _checkEmployeeLocationExemption(String employeeId) async {
    try {
      final exemptionRepository = getIt<LocationExemptionRepository>();
      return await exemptionRepository.hasLocationExemption(employeeId);
    } catch (e) {
      debugPrint('Error checking location exemption: $e');
      return false;
    }
  }

  // Create exempt location for background checks
  static LocationModel _createExemptLocation() {
    return LocationModel(
      id: 'exempt_location',
      name: 'Location Exempted Employee',
      address: 'Employee has location exemption',
      latitude: 0.0,
      longitude: 0.0,
      radius: 0.0,
      isActive: true,
    );
  }

  // FIXED: Point in polygon check helper
  static bool _isPointInPolygon(double lat, double lng, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool oddNodes = false;

    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < lat && polygon[j].latitude >= lat) ||
          (polygon[j].latitude < lat && polygon[i].latitude >= lat)) {
        double intersectionX = polygon[i].longitude +
            (lat - polygon[i].latitude) /
                (polygon[j].latitude - polygon[i].latitude) *
                (polygon[j].longitude - polygon[i].longitude);

        if (intersectionX < lng) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  // Calculate distance to polygon center
  static double _calculateDistanceToPolygonCenter(
      double lat, double lng, PolygonLocationModel polygon) {
    return Geolocator.distanceBetween(
      lat,
      lng,
      polygon.centerLatitude,
      polygon.centerLongitude,
    );
  }

  // FIXED: Background geofence check method (for monitoring service)
  static Future<Map<String, dynamic>> checkGeofenceStatusForEmployeeBackground(
      String employeeId, {
        Position? currentPosition,
      }) async {
    try {
      debugPrint("Background geofence check for employee: $employeeId");

      // Get current position if not provided
      Position? position = currentPosition;
      if (position == null) {
        try {
          position = await getCurrentPosition();
          if (position == null) {
            debugPrint("Failed to get position for background check");
            return {
              'withinGeofence': false,
              'distance': null,
              'location': null,
              'locationType': 'unknown',
              'isExempted': false,
              'error': 'location_unavailable',
            };
          }
        } catch (e) {
          debugPrint("Failed to get position for background check: $e");
          return {
            'withinGeofence': false,
            'distance': null,
            'location': null,
            'locationType': 'unknown',
            'isExempted': false,
            'error': 'location_unavailable',
          };
        }
      }

      // Check exemption status first
      bool isExempt = await _checkEmployeeLocationExemption(employeeId);
      if (isExempt) {
        debugPrint("Employee $employeeId is location exempt (background check)");
        return {
          'withinGeofence': true,
          'distance': 0.0,
          'location': _createExemptLocation(),
          'locationType': 'exemption',
          'isExempted': true,
        };
      }

      // Get location data
      List<LocationModel> circularLocations = await _getActiveLocations();
      List<PolygonLocationModel> polygonLocations = await _getActivePolygonLocations();

      // Check polygon locations first
      for (PolygonLocationModel polygonLocation in polygonLocations) {
        if (!polygonLocation.isActive) continue;

        bool isInside = _isPointInPolygon(
          position.latitude,
          position.longitude,
          polygonLocation.coordinates,
        );

        if (isInside) {
          double distance = _calculateDistanceToPolygonCenter(
            position.latitude,
            position.longitude,
            polygonLocation,
          );

          debugPrint("Background check: Inside polygon ${polygonLocation.name}");
          return {
            'withinGeofence': true,
            'distance': distance,
            'location': polygonLocation,
            'locationType': 'polygon',
            'isExempted': false,
            'currentLatitude': position.latitude,
            'currentLongitude': position.longitude,
          };
        }
      }

      // Check circular locations
      LocationModel? nearestLocation;
      double? shortestDistance;

      for (LocationModel location in circularLocations) {
        if (!location.isActive) continue;

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );

        if (shortestDistance == null || distance < shortestDistance) {
          shortestDistance = distance;
          nearestLocation = location;
        }
      }

      if (nearestLocation != null) {
        bool isWithinGeofence = shortestDistance! <= nearestLocation.radius;

        debugPrint("Background check: ${isWithinGeofence ? 'Inside' : 'Outside'} ${nearestLocation.name}");

        return {
          'withinGeofence': isWithinGeofence,
          'distance': shortestDistance,
          'location': nearestLocation,
          'locationType': 'circular',
          'isExempted': false,
          'currentLatitude': position.latitude,
          'currentLongitude': position.longitude,
        };
      }

      // No locations found
      debugPrint("Background check: No locations available");
      return {
        'withinGeofence': false,
        'distance': null,
        'location': null,
        'locationType': 'none',
        'isExempted': false,
        'currentLatitude': position.latitude,
        'currentLongitude': position.longitude,
      };

    } catch (e) {
      debugPrint("Error in background geofence check: $e");
      return {
        'withinGeofence': false,
        'distance': null,
        'location': null,
        'locationType': 'error',
        'isExempted': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if employee has location exemption
  static Future<bool> hasLocationExemption(String employeeId) async {
    try {
      final exemptionRepository = getIt<LocationExemptionRepository>();
      return await exemptionRepository.hasLocationExemption(employeeId);
    } catch (e) {
      debugPrint('Error checking location exemption: $e');
      return false;
    }
  }

  /// MAIN METHOD: Check geofence status (with GPS fetch and exemption check)
  static Future<Map<String, dynamic>> checkGeofenceStatus(BuildContext context) async {
    bool hasPermission = await checkLocationPermission(context);
    if (!hasPermission) {
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': null,
      };
    }

    Position? currentPosition = await getCurrentPosition();
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location'),
          backgroundColor: Colors.red,
        ),
      );
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': null,
      };
    }

    // Use the cached position method
    return await checkGeofenceStatusWithPosition(context, currentPosition);
  }

  /// ENHANCED: Check geofence status with employee ID for exemption checking
  static Future<Map<String, dynamic>> checkGeofenceStatusForEmployee(
      BuildContext context,
      String employeeId,
      {Position? currentPosition}
      ) async {
    // First check if employee has location exemption
    bool hasExemption = await hasLocationExemption(employeeId);

    if (hasExemption) {
      debugPrint('Employee $employeeId has location exemption - bypassing geofence');

      // Get current position for logging purposes
      Position? position = currentPosition ?? await getCurrentPosition();

      // Create a virtual location for exempt employees
      LocationModel exemptLocation = LocationModel(
        id: 'exempt_location',
        name: 'Location Exempted Employee',
        address: position != null
            ? 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}'
            : 'Unknown coordinates',
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        radius: 0.0,
        isActive: true,
      );

      return {
        'withinGeofence': true, // Always true for exempt employees
        'location': exemptLocation,
        'distance': 0.0,
        'locationType': 'exemption',
        'isExempted': true,
        'exemptionReason': 'Employee has location exemption',
      };
    }

    // For non-exempt employees, use normal geofence checking
    if (currentPosition != null) {
      return await checkGeofenceStatusWithPosition(context, currentPosition);
    } else {
      return await checkGeofenceStatus(context);
    }
  }

  /// Check geofence status with provided position (for caching)
  static Future<Map<String, dynamic>> checkGeofenceStatusWithPosition(
      BuildContext context,
      Position currentPosition,
      ) async {
    debugPrint('LOCATION CHECK:');
    debugPrint('Current position: ${currentPosition.latitude}, ${currentPosition.longitude}');

    // Load location data (uses cache if available)
    await _loadLocationData();

    // Check polygon locations first and give them priority
    debugPrint('Checking polygon locations first...');
    final polygonResult = await _checkPolygonLocationsWithCache(currentPosition);

    // Always log the polygon result for debugging
    if (polygonResult['location'] != null) {
      final polygonLocation = polygonResult['location'] as PolygonLocationModel;
      debugPrint('Nearest polygon: ${polygonLocation.name}, distance: ${polygonResult['distance']}m, within: ${polygonResult['withinGeofence']}');
    } else {
      debugPrint('No polygon locations found or error occurred');
    }

    // If we're inside a polygon, return that result IMMEDIATELY
    if (polygonResult['withinGeofence'] == true) {
      debugPrint('User is INSIDE polygon: ${(polygonResult['location'] as PolygonLocationModel).name} - STOPPING HERE');
      return polygonResult;
    }

    // Only check circular locations if we're not inside any polygon
    debugPrint('Checking circular locations...');
    final circularResult = await _checkCircularLocationsWithCache(currentPosition);

    // Log the circular result too
    if (circularResult['location'] != null) {
      final circularLocation = circularResult['location'] as LocationModel;
      debugPrint('Nearest circular location: ${circularLocation.name}, distance: ${circularResult['distance']}m, within: ${circularResult['withinGeofence']}');
    } else {
      debugPrint('No circular locations found or error occurred');
    }

    // If we're within a circular geofence, return that result
    if (circularResult['withinGeofence'] == true) {
      debugPrint('User is INSIDE circular geofence - using this result');
      return circularResult;
    }

    // If we're not in any geofence, return the closest one
    // Always prefer polygon if distances are similar
    final polygonDistance = polygonResult['distance'] as double?;
    final circularDistance = circularResult['distance'] as double?;

    debugPrint('Not inside any boundary, comparing distances:');
    debugPrint('Polygon distance: $polygonDistance, Circular distance: $circularDistance');

    // Give polygon a slight advantage (multiply circular distance by 1.1)
    if (polygonDistance != null && circularDistance != null) {
      if (polygonDistance < circularDistance * 1.1) {
        debugPrint('Polygon is closer or similar distance - using polygon result');
        return polygonResult;
      } else {
        debugPrint('Circular is significantly closer - using circular result');
        return circularResult;
      }
    } else if (polygonDistance != null) {
      debugPrint('Only polygon distance available - using polygon result');
      return polygonResult;
    } else if (circularDistance != null) {
      debugPrint('Only circular distance available - using circular result');
      return circularResult;
    }

    // If no locations found at all, return a default result
    debugPrint('No locations found at all');
    return {
      'withinGeofence': false,
      'location': null,
      'distance': null,
      'locationType': null,
    };
  }

  // Check polygon locations with cache
  static Future<Map<String, dynamic>> _checkPolygonLocationsWithCache(Position currentPosition) async {
    try {
      final List<PolygonLocationModel> locations = _cachedPolygonLocations ?? [];

      if (locations.isEmpty) {
        debugPrint('No polygon locations found in cache');
        return {
          'withinGeofence': false,
          'location': null,
          'distance': null,
          'locationType': 'polygon',
        };
      }

      debugPrint('Found ${locations.length} cached polygon locations');

      // Check if the current position is inside any polygon
      double? shortestDistance;
      PolygonLocationModel? closestLocation;

      for (var location in locations) {
        debugPrint('Checking polygon: ${location.name}, coordinates: ${location.coordinates.length} points');

        // Check if inside this polygon
        if (location.containsPoint(currentPosition.latitude, currentPosition.longitude)) {
          debugPrint('User is INSIDE polygon: ${location.name}');
          return {
            'withinGeofence': true,
            'location': location,
            'distance': 0.0,
            'locationType': 'polygon',
          };
        }

        // Calculate distance to polygon boundary
        double distanceToPolygon = location.distanceToPolygon(
            currentPosition.latitude,
            currentPosition.longitude
        );

        debugPrint('Distance to boundary of ${location.name}: ${distanceToPolygon.toStringAsFixed(2)}m');

        // Update closest location
        if (shortestDistance == null || distanceToPolygon < shortestDistance) {
          shortestDistance = distanceToPolygon;
          closestLocation = location;
        }
      }

      // Not inside any polygon, return closest one
      return {
        'withinGeofence': false,
        'location': closestLocation,
        'distance': shortestDistance,
        'locationType': 'polygon',
      };
    } catch (e) {
      debugPrint('Error checking polygon locations: $e');
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': 'polygon',
      };
    }
  }

  // Check circular locations with cache
  static Future<Map<String, dynamic>> _checkCircularLocationsWithCache(Position currentPosition) async {
    try {
      final List<LocationModel> locations = _cachedCircularLocations ?? [];

      if (locations.isEmpty) {
        debugPrint('No circular locations found in cache');
        return {
          'withinGeofence': false,
          'location': null,
          'distance': null,
          'locationType': 'circular',
        };
      }

      debugPrint('Found ${locations.length} cached circular locations');

      // Find closest location and check if within radius
      LocationModel? closestLocation;
      double? shortestDistance;
      bool withinAnyGeofence = false;

      for (var location in locations) {
        double distanceInMeters = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          location.latitude,
          location.longitude,
        );

        debugPrint('Distance to ${location.name}: ${distanceInMeters.toStringAsFixed(2)}m (radius: ${location.radius}m)');

        // Update closest location if this is closer than previous
        if (shortestDistance == null || distanceInMeters < shortestDistance) {
          shortestDistance = distanceInMeters;
          closestLocation = location;
        }

        // Check if within this location's radius
        if (distanceInMeters <= location.radius) {
          debugPrint('User is WITHIN radius of ${location.name}');
          withinAnyGeofence = true;
          closestLocation = location;
          shortestDistance = distanceInMeters;
          break;
        }
      }

      // Return result
      return {
        'withinGeofence': withinAnyGeofence,
        'location': closestLocation,
        'distance': shortestDistance,
        'locationType': 'circular',
      };
    } catch (e) {
      debugPrint('Error checking circular locations: $e');
      return {
        'withinGeofence': false,
        'location': null,
        'distance': null,
        'locationType': 'circular',
      };
    }
  }

  // Clear cache (useful for testing or when locations are updated)
  static void clearLocationCache() {
    _cachedCircularLocations = null;
    _cachedPolygonLocations = null;
    _locationCacheTime = null;
    debugPrint('Location cache cleared');
  }

  // Force refresh location data
  static Future<void> refreshLocationData() async {
    clearLocationCache();
    await _loadLocationData();
    debugPrint('Location data force refreshed');
  }

  // Import GeoJSON data into the system
  static Future<bool> importGeoJsonData(BuildContext context, String geoJsonString) async {
    try {
      final PolygonLocationRepository repository = getIt<PolygonLocationRepository>();

      // Parse GeoJSON file
      final List<PolygonLocationModel> locations = await repository.loadFromGeoJson(geoJsonString);

      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid polygon locations found in the GeoJSON file'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }

      // Save locations
      final bool success = await repository.savePolygonLocations(locations);

      if (success) {
        // Clear cache to force reload
        clearLocationCache();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${locations.length} polygon locations'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving polygon locations'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return success;
    } catch (e) {
      debugPrint('Error importing GeoJSON: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing GeoJSON: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Legacy methods for backward compatibility

  // Legacy: Check if user is within geofence
  static Future<bool> isWithinGeofence(BuildContext context) async {
    Map<String, dynamic> status = await checkGeofenceStatus(context);
    return status['withinGeofence'] as bool;
  }

  // Legacy: Get distance to office
  static Future<double?> getDistanceToOffice(BuildContext context) async {
    Map<String, dynamic> status = await checkGeofenceStatus(context);
    return status['distance'] as double?;
  }

  // Check if employee can check in/out from current location
  static Future<bool> canCheckInOut(BuildContext context, String employeeId) async {
    // Check if employee has location exemption first
    bool hasExemption = await hasLocationExemption(employeeId);

    if (hasExemption) {
      debugPrint('Employee $employeeId can check in/out from anywhere (exempted)');
      return true;
    }

    // For non-exempt employees, check normal geofence
    return await isWithinGeofence(context);
  }
}