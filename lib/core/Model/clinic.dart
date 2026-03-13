class Clinic {
  final String id;
  final String name;
  final double distance;
  final int waitTimeMinutes;
  final List<String> services;
  final double rating;
  final String address;

  Clinic({
    required this.id,
    required this.name,
    required this.distance,
    required this.waitTimeMinutes,
    required this.services,
    required this.rating,
    required this.address,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'],
      name: json['name'],
      distance: (json['distance'] as num).toDouble(),
      waitTimeMinutes: (json['wait_time_minutes'] as num).toInt(),
      services: List<String>.from(json['services']),
      rating: (json['rating'] as num).toDouble(),
      address: json['address'] ?? '',
    );
  }
}