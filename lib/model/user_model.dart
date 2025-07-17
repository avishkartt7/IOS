// lib/model/user_model.dart - FIXED VERSION

class UserModel {
  String? id;
  String? name;
  String? image;
  FaceFeatures? faceFeatures;
  int? registeredOn;

  UserModel({
    this.id,
    this.name,
    this.image,
    this.faceFeatures,
    this.registeredOn,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      faceFeatures: json["faceFeatures"] != null 
          ? FaceFeatures.fromJson(json["faceFeatures"])
          : null,
      registeredOn: json['registeredOn'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'faceFeatures': faceFeatures?.toJson() ?? {},
      'registeredOn': registeredOn,
    };
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
    this.rightMouth,
    this.leftMouth,
    this.leftCheek,
    this.rightCheek,
    this.leftEye,
    this.rightEar,
    this.leftEar,
    this.rightEye,
    this.noseBase,
    this.bottomMouth,
  });

  factory FaceFeatures.fromJson(Map<String, dynamic> json) => FaceFeatures(
        rightMouth: json["rightMouth"] != null 
            ? Points.fromJson(json["rightMouth"])
            : null,
        leftMouth: json["leftMouth"] != null 
            ? Points.fromJson(json["leftMouth"])
            : null,
        leftCheek: json["leftCheek"] != null 
            ? Points.fromJson(json["leftCheek"])
            : null,
        rightCheek: json["rightCheek"] != null 
            ? Points.fromJson(json["rightCheek"])
            : null,
        leftEye: json["leftEye"] != null 
            ? Points.fromJson(json["leftEye"])
            : null,
        rightEar: json["rightEar"] != null 
            ? Points.fromJson(json["rightEar"])
            : null,
        leftEar: json["leftEar"] != null 
            ? Points.fromJson(json["leftEar"])
            : null,
        rightEye: json["rightEye"] != null 
            ? Points.fromJson(json["rightEye"])
            : null,
        noseBase: json["noseBase"] != null 
            ? Points.fromJson(json["noseBase"])
            : null,
        bottomMouth: json["bottomMouth"] != null 
            ? Points.fromJson(json["bottomMouth"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "rightMouth": rightMouth?.toJson(),
        "leftMouth": leftMouth?.toJson(),
        "leftCheek": leftCheek?.toJson(),
        "rightCheek": rightCheek?.toJson(),
        "leftEye": leftEye?.toJson(),
        "rightEar": rightEar?.toJson(),
        "leftEar": leftEar?.toJson(),
        "rightEye": rightEye?.toJson(),
        "noseBase": noseBase?.toJson(),
        "bottomMouth": bottomMouth?.toJson(),
      };
}

// 🔧 FIXED: Changed from int? to double? for ML Kit compatibility
class Points {
  double? x;
  double? y;

  Points({
    required this.x,
    required this.y,
  });

  factory Points.fromJson(Map<String, dynamic> json) => Points(
        x: json['x'] != null ? (json['x'] as num).toDouble() : null,
        y: json['y'] != null ? (json['y'] as num).toDouble() : null,
      );

  Map<String, dynamic> toJson() => {
        'x': x, 
        'y': y
      };

  @override
  String toString() => 'Points(x: $x, y: $y)';
}