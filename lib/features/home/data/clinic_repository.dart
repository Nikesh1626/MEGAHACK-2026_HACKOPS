import '../../../core/model/clinic.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ClinicRepository {
  // Mock clinic data with realistic locations
  static const List<Map<String, dynamic>> _mockClinics = [
    {
      'id': '1',
      'name': 'Apollo Hospitals',
      'lat': 28.6139,
      'lng': 77.2090,
      'waitTimeMinutes': 15,
      'services': ['General Medicine', 'Cardiology', 'Emergency'],
      'rating': 4.5,
      'address': 'Mathura Road, New Delhi',
    },
    {
      'id': '2',
      'name': 'Fortis Healthcare',
      'lat': 28.6140,
      'lng': 77.2100,
      'waitTimeMinutes': 25,
      'services': ['Orthopedics', 'Neurology', 'Pediatrics'],
      'rating': 4.3,
      'address': 'Vasant Kunj, New Delhi',
    },
    {
      'id': '3',
      'name': 'Max Super Speciality Hospital',
      'lat': 28.6150,
      'lng': 77.2110,
      'waitTimeMinutes': 35,
      'services': ['Oncology', 'Cardiac Surgery', 'Transplant'],
      'rating': 4.7,
      'address': 'Saket, New Delhi',
    },
    {
      'id': '4',
      'name': 'AIIMS Delhi',
      'lat': 28.6160,
      'lng': 77.2120,
      'waitTimeMinutes': 45,
      'services': ['Emergency', 'Trauma', 'Specialized Care'],
      'rating': 4.8,
      'address': 'Ansari Nagar, New Delhi',
    },
    {
      'id': '5',
      'name': 'Safdarjung Hospital',
      'lat': 28.6170,
      'lng': 77.2130,
      'waitTimeMinutes': 20,
      'services': ['General Medicine', 'Surgery', 'Maternity'],
      'rating': 4.2,
      'address': 'Safdarjung Enclave, New Delhi',
    },
    {
      'id': '6',
      'name': 'Gangaram Hospital',
      'lat': 28.6180,
      'lng': 77.2140,
      'waitTimeMinutes': 30,
      'services': ['Cardiology', 'Neurology', 'Orthopedics'],
      'rating': 4.4,
      'address': 'Pusa Road, New Delhi',
    },
  ];

  Future<List<Clinic>> getNearbyClinics() async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      // Calculate distances and sort by proximity
      final clinicsWithDistance = _mockClinics.map((clinicData) {
        final clinicLocation = LatLng(
          clinicData['lat'] as double,
          clinicData['lng'] as double,
        );
        
        final distance = _calculateDistance(currentLocation, clinicLocation);
        
        return Clinic(
          id: clinicData['id'] as String,
          name: clinicData['name'] as String,
          distance: distance,
          waitTimeMinutes: clinicData['waitTimeMinutes'] as int,
          services: List<String>.from(clinicData['services'] as List),
          rating: clinicData['rating'] as double,
          address: clinicData['address'] as String,
        );
      }).toList();

      // Sort by distance and return top 5
      clinicsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      return clinicsWithDistance.take(5).toList();
      
    } catch (e) {
      // If location access fails, return default clinics
      await Future.delayed(const Duration(seconds: 1));
      return _mockClinics.take(3).map((clinicData) => Clinic(
        id: clinicData['id'] as String,
        name: clinicData['name'] as String,
        distance: clinicData['lat'] as double, // Using lat as distance for fallback
        waitTimeMinutes: clinicData['waitTimeMinutes'] as int,
        services: List<String>.from(clinicData['services'] as List),
        rating: clinicData['rating'] as double,
        address: clinicData['address'] as String,
      )).toList();
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }
}