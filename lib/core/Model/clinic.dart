import '../constants/firestore_schema.dart';

class Clinic {
  final String id;
  final String name;
  final double distance;
  final int waitTimeMinutes;
  final List<String> services;
  final double rating;
  final String address;
  final double latitude;
  final double longitude;

  Clinic({
    required this.id,
    required this.name,
    required this.distance,
    required this.waitTimeMinutes,
    required this.services,
    required this.rating,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json[FsFields.id],
      name: json[FsFields.name],
      distance: (json['distance'] as num).toDouble(),
      waitTimeMinutes: (json[FsFields.waitTimeMinutes] as num).toInt(),
      services: List<String>.from(json[FsFields.services]),
      rating: (json[FsFields.rating] as num).toDouble(),
      address: json[FsFields.address] ?? '',
      latitude: (json[FsFields.lat] as num?)?.toDouble() ?? 0,
      longitude: (json[FsFields.lng] as num?)?.toDouble() ?? 0,
    );
  }
}
