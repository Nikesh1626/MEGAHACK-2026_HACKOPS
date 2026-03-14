import '../../../core/model/clinic.dart';
import '../../../core/constants/firestore_schema.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class ClinicRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> _staticClinics = [
    {
      FsFields.id: 'apollo_delhi',
      FsFields.name: 'Apollo Hospitals',
      FsFields.lat: 28.6139,
      FsFields.lng: 77.2090,
      FsFields.waitTimeMinutes: 14,
      FsFields.services: ['General Medicine', 'Cardiology', 'Emergency'],
      FsFields.rating: 4.5,
      FsFields.address: 'Mathura Road, New Delhi',
    },
    {
      FsFields.id: 'fortis_vasant_kunj',
      FsFields.name: 'Fortis Healthcare',
      FsFields.lat: 28.5273,
      FsFields.lng: 77.1539,
      FsFields.waitTimeMinutes: 21,
      FsFields.services: ['Orthopedics', 'Neurology', 'Pediatrics'],
      FsFields.rating: 4.3,
      FsFields.address: 'Vasant Kunj, New Delhi',
    },
    {
      FsFields.id: 'max_saket',
      FsFields.name: 'Max Super Speciality Hospital',
      FsFields.lat: 28.5271,
      FsFields.lng: 77.2170,
      FsFields.waitTimeMinutes: 32,
      FsFields.services: ['Oncology', 'Cardiac Surgery', 'Transplant'],
      FsFields.rating: 4.6,
      FsFields.address: 'Saket, New Delhi',
    },
    {
      FsFields.id: 'aiims_ansari',
      FsFields.name: 'AIIMS Delhi',
      FsFields.lat: 28.5672,
      FsFields.lng: 77.2100,
      FsFields.waitTimeMinutes: 39,
      FsFields.services: ['Emergency', 'Trauma', 'Specialized Care'],
      FsFields.rating: 4.7,
      FsFields.address: 'Ansari Nagar, New Delhi',
    },
    {
      FsFields.id: 'safdarjung',
      FsFields.name: 'Safdarjung Hospital',
      FsFields.lat: 28.5708,
      FsFields.lng: 77.2059,
      FsFields.waitTimeMinutes: 26,
      FsFields.services: ['General Medicine', 'Surgery', 'Maternity'],
      FsFields.rating: 4.1,
      FsFields.address: 'Safdarjung Enclave, New Delhi',
    },
  ];

  Future<List<Clinic>> getNearbyClinics() async {
    final snapshot = await _firestore.collection(FsCollections.clinics).get();
    if (snapshot.docs.isEmpty) {
      return _toStaticClinicsSorted();
    }
    return _toSortedClinics(snapshot.docs);
  }

  Stream<List<Clinic>> streamNearbyClinics() {
    return _firestore
        .collection(FsCollections.clinics)
        .snapshots()
        .asyncMap((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _toStaticClinicsSorted();
      }
      return _toSortedClinics(snapshot.docs);
    });
  }

  Future<List<Clinic>> _toSortedClinics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      final clinicsWithDistance = docs.map((doc) {
        final clinicData = doc.data();
        final lat = (clinicData[FsFields.lat] as num?)?.toDouble() ?? 0;
        final lng = (clinicData[FsFields.lng] as num?)?.toDouble() ?? 0;
        final clinicLocation = LatLng(
          lat,
          lng,
        );

        final distance = _calculateDistance(currentLocation, clinicLocation);

        return Clinic(
          id: doc.id,
          name: (clinicData[FsFields.name] ?? 'Unknown Clinic').toString(),
          distance: distance,
          waitTimeMinutes: (clinicData[FsFields.waitTimeMinutes] as num?)
                  ?.toInt() ??
              (clinicData[FsFields.waitTimeMinutesLegacy] as num?)?.toInt() ??
              0,
          services: List<String>.from(
              clinicData[FsFields.services] as List? ?? const []),
          rating: (clinicData[FsFields.rating] as num?)?.toDouble() ?? 0,
          address: (clinicData[FsFields.clinicAddress] ?? '').toString(),
          latitude: lat,
          longitude: lng,
        );
      }).toList();

      clinicsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
      return clinicsWithDistance;
    } catch (e) {
      if (docs.isEmpty) {
        return _toStaticClinicsSorted(distanceFallback: true);
      }
      return docs.map((doc) {
        final clinicData = doc.data();
        final lat = (clinicData[FsFields.lat] as num?)?.toDouble() ?? 0;
        final lng = (clinicData[FsFields.lng] as num?)?.toDouble() ?? 0;
        return Clinic(
          id: doc.id,
          name: (clinicData[FsFields.name] ?? 'Unknown Clinic').toString(),
          distance: 0,
          waitTimeMinutes: (clinicData[FsFields.waitTimeMinutes] as num?)
                  ?.toInt() ??
              (clinicData[FsFields.waitTimeMinutesLegacy] as num?)?.toInt() ??
              0,
          services: List<String>.from(
              clinicData[FsFields.services] as List? ?? const []),
          rating: (clinicData[FsFields.rating] as num?)?.toDouble() ?? 0,
          address: (clinicData[FsFields.clinicAddress] ?? '').toString(),
          latitude: lat,
          longitude: lng,
        );
      }).toList();
    }
  }

  Future<List<Clinic>> _toStaticClinicsSorted({
    bool distanceFallback = false,
  }) async {
    if (distanceFallback) {
      return _staticClinics
          .map((clinicData) => _clinicFromStaticMap(clinicData, distance: 0))
          .toList();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      final clinics = _staticClinics.map((clinicData) {
        final clinicLocation = LatLng(
          (clinicData[FsFields.lat] as num).toDouble(),
          (clinicData[FsFields.lng] as num).toDouble(),
        );
        final distance = _calculateDistance(currentLocation, clinicLocation);
        return _clinicFromStaticMap(clinicData, distance: distance);
      }).toList();

      clinics.sort((a, b) => a.distance.compareTo(b.distance));
      return clinics;
    } catch (_) {
      return _staticClinics
          .map((clinicData) => _clinicFromStaticMap(clinicData, distance: 0))
          .toList();
    }
  }

  Clinic _clinicFromStaticMap(
    Map<String, dynamic> clinicData, {
    required double distance,
  }) {
    return Clinic(
      id: (clinicData[FsFields.id] ?? '').toString(),
      name: (clinicData[FsFields.name] ?? 'Unknown Clinic').toString(),
      distance: distance,
      waitTimeMinutes:
          (clinicData[FsFields.waitTimeMinutes] as num?)?.toInt() ?? 0,
      services: List<String>.from(
        clinicData[FsFields.services] as List? ?? const [],
      ),
      rating: (clinicData[FsFields.rating] as num?)?.toDouble() ?? 0,
      address: (clinicData[FsFields.address] ?? '').toString(),
      latitude: (clinicData[FsFields.lat] as num?)?.toDouble() ?? 0,
      longitude: (clinicData[FsFields.lng] as num?)?.toDouble() ?? 0,
    );
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }
}
