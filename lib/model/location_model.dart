// lib/model/location_model.dart

class LocationModel {
  String? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive;

  LocationModel({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isActive,
  });

  // Add this method to your LocationModel class in lib/model/location_model.dart

  LocationModel copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isActive,
  }) {
    return LocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      isActive: isActive ?? this.isActive,
    );
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] is String)
          ? double.parse(json['latitude'])
          : json['latitude']?.toDouble() ?? 0.0,
      longitude: (json['longitude'] is String)
          ? double.parse(json['longitude'])
          : json['longitude']?.toDouble() ?? 0.0,
      radius: (json['radius'] is String)
          ? double.parse(json['radius'])
          : json['radius']?.toDouble() ?? 200.0,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
    };
  }
}
