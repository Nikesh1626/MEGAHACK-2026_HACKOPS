import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../model/clinic.dart';

class MapsService {
  /// ✅ Fetch user's current location with permission handling
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check and request permission if needed
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied. Please enable them from settings.',
      );
    }

    // If we reach here, permission is granted ✅
    return await Geolocator.getCurrentPosition();
  }

  /// ✅ Fetch nearby clinics from OpenStreetMap Overpass API
  Future<List<Clinic>> fetchNearbyClinics(
      double lat,
      double lon, {
        double radius = 5000,
      }) async {
    const String overpassUrl = 'https://overpass-api.de/api/interpreter';

    // Overpass QL query: search clinics around a location
    String query = """
      [out:json];
      (
        node["amenity"="clinic"](around:$radius,$lat,$lon);
        node["healthcare"="clinic"](around:$radius,$lat,$lon);
      );
      out;
    """;

    final response = await http.post(
      Uri.parse(overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List elements = data['elements'];
      return elements.map((e) => Clinic.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load clinics from Overpass API');
    }
  }
}
