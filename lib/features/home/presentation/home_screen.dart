import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
// 1. Import your new screen
import '../../myqueue/CheckInScreen.dart';
import '../../profile/profile_screen.dart';
import 'widgets/Custom_Search_Bar.dart';
import 'widgets/nearby_clinics_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 2. Add a state variable to track the selected tab index
  int _selectedIndex = 0;

  // 3. Method to get the current widget based on selected index
  Widget _getCurrentWidget() {
    switch (_selectedIndex) {
      case 0:
        return const _HomeContent();
      case 1:
        return const CheckInScreen(); // Recreate on each tab switch
      case 2:
        return const ProfileScreen();
      default:
        return const _HomeContent();
    }
  }

  // 4. Create a method to handle tab selection
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Care'),
        centerTitle: false,
      ),
      // 5. Set the body to the current widget based on the selected index
      body: _getCurrentWidget(),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'My Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        // 6. Update the BottomNavigationBar to be stateful
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped, // Call our method when a tab is tapped
      ),
    );
  }
}

// Helper widget to keep the build method clean
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _nearbyClinics = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadNearbyClinics();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      // Default to a location if permission denied or error
      _currentLocation = const LatLng(28.6139, 77.2090); // New Delhi coordinates
    }
  }

  Future<void> _loadNearbyClinics() async {
    // Mock clinic data for map markers
    _nearbyClinics = [
      {
        'name': 'Apollo Hospitals',
        'lat': 28.6139,
        'lng': 77.2090,
        'waitTime': 15,
      },
      {
        'name': 'Fortis Healthcare',
        'lat': 28.6140,
        'lng': 77.2100,
        'waitTime': 25,
      },
      {
        'name': 'Max Super Speciality Hospital',
        'lat': 28.6150,
        'lng': 77.2110,
        'waitTime': 35,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CustomSearchBar(),
          const SizedBox(height: 16),
          // Map view
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoadingLocation
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _currentLocation != null
                      ? FlutterMap(
                          options: MapOptions(
                            initialCenter: _currentLocation!,
                            initialZoom: 13.0,
                            minZoom: 5.0,
                            maxZoom: 18.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.well_queue',
                            ),
                            MarkerLayer(
                              markers: [
                                // Current location marker
                                Marker(
                                  point: _currentLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                                // Clinic markers
                                ..._nearbyClinics.map((clinic) => Marker(
                                  point: LatLng(
                                    clinic['lat'] as double,
                                    clinic['lng'] as double,
                                  ),
                                  width: 30,
                                  height: 30,
                                  child: GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${clinic['name']} - ${clinic['waitTime']} min wait'),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.teal,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.local_hospital,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ],
                        )
                      : const Center(
                          child: Text(
                            'Unable to load map',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nearby Clinics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const NearbyClinicsList(),
        ],
      ),
    );
  }
}
