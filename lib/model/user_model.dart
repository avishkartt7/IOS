import 'dart:convert';
// Add required import for math
import 'dart:math' as math;

class UserModel {
  String? id;
  String? name;
  String? designation;
  String? department;
  String? email;
  String? phone;
  String? pin;
  String? image;
  FaceFeatures? faceFeatures;
  int? registeredOn;
  bool? profileCompleted;
  bool? faceRegistered;

  UserModel({
    this.id,
    this.name,
    this.designation,
    this.department,
    this.email,
    this.phone,
    this.pin,
    this.image,
    this.faceFeatures,
    this.registeredOn,
    this.profileCompleted,
    this.faceRegistered,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      designation: json['designation'],
      department: json['department'],
      email: json['email'],
      phone: json['phone'],
      pin: json['pin'],
      image: json['image'],
      faceFeatures: json['faceFeatures'] != null 
          ? FaceFeatures.fromJson(json['faceFeatures'])
          : null,
      registeredOn: json['registeredOn'],
      profileCompleted: json['profileCompleted'],
      faceRegistered: json['faceRegistered'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'designation': designation,
      'department': department,
      'email': email,
      'phone': phone,
      'pin': pin,
      'image': image,
      'faceFeatures': faceFeatures?.toJson(),
      'registeredOn': registeredOn,
      'profileCompleted': profileCompleted,
      'faceRegistered': faceRegistered,
    };
  }

  // Helper method to check if user is fully registered
  bool get isFullyRegistered {
    return profileCompleted == true && 
           faceRegistered == true && 
           image != null && 
           image!.isNotEmpty;
  }

  // Helper method to get display name
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return 'User';
  }

  // Helper method to get user info summary
  String get userSummary {
    List<String> parts = [];
    if (name != null && name!.isNotEmpty) parts.add(name!);
    if (designation != null && designation!.isNotEmpty) parts.add(designation!);
    if (department != null && department!.isNotEmpty) parts.add(department!);
    return parts.join(' • ');
  }

  // Copy method for updating user data
  UserModel copyWith({
    String? id,
    String? name,
    String? designation,
    String? department,
    String? email,
    String? phone,
    String? pin,
    String? image,
    FaceFeatures? faceFeatures,
    int? registeredOn,
    bool? profileCompleted,
    bool? faceRegistered,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      pin: pin ?? this.pin,
      image: image ?? this.image,
      faceFeatures: faceFeatures ?? this.faceFeatures,
      registeredOn: registeredOn ?? this.registeredOn,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      faceRegistered: faceRegistered ?? this.faceRegistered,
    );
  }
}

class FaceFeatures {
  Points? rightEar;
  Points? leftEar;
  Points? rightEye;
  Points? leftEye;
  Points? rightCheek;
  Points? leftCheek;
  Points? rightMouth;
  Points? leftMouth;
  Points? noseBase;
  Points? bottomMouth;

  FaceFeatures({
    this.rightEar,
    this.leftEar,
    this.rightEye,
    this.leftEye,
    this.rightCheek,
    this.leftCheek,
    this.rightMouth,
    this.leftMouth,
    this.noseBase,
    this.bottomMouth,
  });

  factory FaceFeatures.fromJson(Map<String, dynamic> json) {
    return FaceFeatures(
      rightEar: json['rightEar'] != null ? Points.fromJson(json['rightEar']) : null,
      leftEar: json['leftEar'] != null ? Points.fromJson(json['leftEar']) : null,
      rightEye: json['rightEye'] != null ? Points.fromJson(json['rightEye']) : null,
      leftEye: json['leftEye'] != null ? Points.fromJson(json['leftEye']) : null,
      rightCheek: json['rightCheek'] != null ? Points.fromJson(json['rightCheek']) : null,
      leftCheek: json['leftCheek'] != null ? Points.fromJson(json['leftCheek']) : null,
      rightMouth: json['rightMouth'] != null ? Points.fromJson(json['rightMouth']) : null,
      leftMouth: json['leftMouth'] != null ? Points.fromJson(json['leftMouth']) : null,
      noseBase: json['noseBase'] != null ? Points.fromJson(json['noseBase']) : null,
      bottomMouth: json['bottomMouth'] != null ? Points.fromJson(json['bottomMouth']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rightEar': rightEar?.toJson(),
      'leftEar': leftEar?.toJson(),
      'rightEye': rightEye?.toJson(),
      'leftEye': leftEye?.toJson(),
      'rightCheek': rightCheek?.toJson(),
      'leftCheek': leftCheek?.toJson(),
      'rightMouth': rightMouth?.toJson(),
      'leftMouth': leftMouth?.toJson(),
      'noseBase': noseBase?.toJson(),
      'bottomMouth': bottomMouth?.toJson(),
    };
  }

  // Helper method to check if face features are complete
  bool get isComplete {
    return rightEye != null && 
           leftEye != null && 
           noseBase != null && 
           rightMouth != null && 
           leftMouth != null;
  }

  // Helper method to get feature summary
  String get featureSummary {
    int featuresCount = 0;
    if (rightEar != null) featuresCount++;
    if (leftEar != null) featuresCount++;
    if (rightEye != null) featuresCount++;
    if (leftEye != null) featuresCount++;
    if (rightCheek != null) featuresCount++;
    if (leftCheek != null) featuresCount++;
    if (rightMouth != null) featuresCount++;
    if (leftMouth != null) featuresCount++;
    if (noseBase != null) featuresCount++;
    if (bottomMouth != null) featuresCount++;
    
    return '$featuresCount/10 features detected';
  }
}

class Points {
  double? x;
  double? y;

  Points({
    this.x,
    this.y,
  });

  factory Points.fromJson(Map<String, dynamic> json) {
    return Points(
      x: json['x']?.toDouble(),
      y: json['y']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  // Helper method to check if point is valid
  bool get isValid {
    return x != null && y != null && x! >= 0 && y! >= 0;
  }

  // Helper method to calculate distance to another point
  double distanceTo(Points other) {
    if (!isValid || !other.isValid) return double.infinity;
    
    double dx = x! - other.x!;
    double dy = y! - other.y!;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() {
    return 'Points(x: $x, y: $y)';
  }
}

// Helper class for authentication result
class AuthenticationResult {
  final bool success;
  final String message;
  final double? similarity;
  final UserModel? user;

  AuthenticationResult({
    required this.success,
    required this.message,
    this.similarity,
    this.user,
  });

  factory AuthenticationResult.success({
    required String message,
    double? similarity,
    UserModel? user,
  }) {
    return AuthenticationResult(
      success: true,
      message: message,
      similarity: similarity,
      user: user,
    );
  }

  factory AuthenticationResult.failure({
    required String message,
  }) {
    return AuthenticationResult(
      success: false,
      message: message,
    );
  }
}

// Helper class for registration progress
class RegistrationProgress {
  final bool pinVerified;
  final bool profileCompleted;
  final bool faceRegistered;
  final bool verificationCompleted;

  RegistrationProgress({
    required this.pinVerified,
    required this.profileCompleted,
    required this.faceRegistered,
    required this.verificationCompleted,
  });

  double get progress {
    int completedSteps = 0;
    if (pinVerified) completedSteps++;
    if (profileCompleted) completedSteps++;
    if (faceRegistered) completedSteps++;
    if (verificationCompleted) completedSteps++;
    return completedSteps / 4.0;
  }

  bool get isComplete {
    return pinVerified && profileCompleted && faceRegistered && verificationCompleted;
  }

  String get currentStep {
    if (!pinVerified) return 'PIN Verification';
    if (!profileCompleted) return 'Profile Setup';
    if (!faceRegistered) return 'Face Registration';
    if (!verificationCompleted) return 'Face Verification';
    return 'Complete';
  }
}

