import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'queue_service.dart';

/// Service to handle geofencing and automatic check-in when user arrives near clinic
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  StreamSubscription<Position>? _positionStream;
  final _queueService = QueueService();
  
  // Geofence configuration
  static const double _geofenceRadiusMeters = 50.0; // 50 meters radius
  static const int _locationUpdateIntervalSeconds = 10; // Check every 10 seconds
  
  // Active geofence data
  String? _activeClinicId;
  String? _activeClinicName;
  double? _clinicLatitude;
  double? _clinicLongitude;
  bool _isMonitoring = false;
  bool _hasEnteredGeofence = false;
  bool _notificationShown = false;

  /// Initialize notification system
  Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request notification permission on supported platforms (Android 13+, iOS)
    await requestNotificationPermission();
  }
  /// Request notification permissions (Android 13+, iOS)
  Future<bool> requestNotificationPermission() async {
    try {
      // For Android 13+, use permission_handler
      final status = await Permission.notification.status;
      
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        if (kDebugMode) {
          print('Notification permission result: $result');
        }
        return result.isGranted;
      }
      
      // For iOS
      final iosPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Notification permission request failed: $e');
      }
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  /// Start monitoring geofence for a specific clinic
  Future<bool> startGeofenceMonitoring({
    required String clinicId,
    required String clinicName,
    required double latitude,
    required double longitude,
    required String userId,
  }) async {
    try {
      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permission not granted');
        }
        return false;
      }

      // Save geofence data
      _activeClinicId = clinicId;
      _activeClinicName = clinicName;
      _clinicLatitude = latitude;
      _clinicLongitude = longitude;
      _hasEnteredGeofence = false;
      _notificationShown = false;
      _isMonitoring = true;

      // Save to preferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geofence_clinic_id', clinicId);
      await prefs.setString('geofence_clinic_name', clinicName);
      await prefs.setDouble('geofence_latitude', latitude);
      await prefs.setDouble('geofence_longitude', longitude);
      await prefs.setString('geofence_user_id', userId);
      await prefs.setBool('geofence_active', true);

      // Start location monitoring
      _startLocationUpdates();

      if (kDebugMode) {
        print('Geofence monitoring started for $clinicName at ($latitude, $longitude)');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting geofence monitoring: $e');
      }
      return false;
    }
  }

  /// Start listening to location updates
  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onLocationUpdate);
  }

  /// Handle location update and check geofence
  Future<void> _onLocationUpdate(Position position) async {
    if (!_isMonitoring || _clinicLatitude == null || _clinicLongitude == null) {
      return;
    }

    // Calculate distance to clinic
    final distanceMeters = _calculateDistance(
      position.latitude,
      position.longitude,
      _clinicLatitude!,
      _clinicLongitude!,
    );

    if (kDebugMode) {
      print('Current distance to clinic: ${distanceMeters.toStringAsFixed(2)}m');
    }

    // Check if user entered geofence
    if (distanceMeters <= _geofenceRadiusMeters && !_hasEnteredGeofence) {
      _hasEnteredGeofence = true;
      await _onGeofenceEntered();
    }
    // Check if user exited geofence
    else if (distanceMeters > _geofenceRadiusMeters && _hasEnteredGeofence) {
      _hasEnteredGeofence = false;
      _notificationShown = false;
      if (kDebugMode) {
        print('Exited geofence area');
      }
    }
  }

  /// Handle geofence entry - show notification
  Future<void> _onGeofenceEntered() async {
    if (_notificationShown) return;

    _notificationShown = true;
    
    if (kDebugMode) {
      print('Entered geofence! Showing notification...');
    }

    // Show notification
    await _showArrivalNotification();
  }

  /// Show notification when user arrives at clinic
  Future<void> _showArrivalNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications for clinic arrival',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'You have arrived!',
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      '🏥 Welcome to $_activeClinicName!',
      'Tap to confirm your arrival and join the queue',
      notificationDetails,
      payload: 'confirm_arrival:$_activeClinicId',
    );
  }

  /// Show notification when queue position is within threshold (e.g., <= 4)
  Future<void> showQueuePositionNotification({
    required String clinicName,
    required int position,
    required int estimatedMinutes,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'queue_channel',
      'Queue Notifications',
      channelDescription: 'Notifications for queue position updates',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Queue update',
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1,
      'Queue moving fast at $clinicName',
      'Reach the clinic: you\'re next in (pos $position). ETA ~ $estimatedMinutes min.',
      notificationDetails,
      payload: 'queue_position:$position',
    );
  }

  /// Show notification when the user's queue is called (arrived)
  Future<void> showQueueArrivedNotification({
    required String clinicName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'queue_channel',
      'Queue Notifications',
      channelDescription: 'Notifications for queue position updates',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'Queue arrived',
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      2,
      'Your queue is ready at $clinicName',
      'Please proceed to the clinic. You are being called now.',
      notificationDetails,
      payload: 'queue_called',
    );
  }

  /// Confirm arrival and join queue
  Future<bool> confirmArrival() async {
    if (_activeClinicId == null || _activeClinicName == null) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('geofence_user_id') ?? 
                     'user_${DateTime.now().millisecondsSinceEpoch}';

      // Join the queue automatically
      await _queueService.joinQueue(
        clinicId: _activeClinicId!,
        clinicName: _activeClinicName!,
        userId: userId,
      );

      // Stop monitoring after successful check-in
      await stopGeofenceMonitoring();

      if (kDebugMode) {
        print('Automatically joined queue at $_activeClinicName');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error confirming arrival: $e');
      }
      return false;
    }
  }

  /// Stop geofence monitoring
  Future<void> stopGeofenceMonitoring() async {
    _positionStream?.cancel();
    _positionStream = null;
    
    _activeClinicId = null;
    _activeClinicName = null;
    _clinicLatitude = null;
    _clinicLongitude = null;
    _isMonitoring = false;
    _hasEnteredGeofence = false;
    _notificationShown = false;

    // Clear from preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('geofence_clinic_id');
    await prefs.remove('geofence_clinic_name');
    await prefs.remove('geofence_latitude');
    await prefs.remove('geofence_longitude');
    await prefs.remove('geofence_user_id');
    await prefs.setBool('geofence_active', false);

    if (kDebugMode) {
      print('Geofence monitoring stopped');
    }
  }

  /// Resume geofence monitoring from saved state (e.g., after app restart)
  Future<void> resumeGeofenceMonitoring() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('geofence_active') ?? false;

      if (!isActive) return;

      final clinicId = prefs.getString('geofence_clinic_id');
      final clinicName = prefs.getString('geofence_clinic_name');
      final latitude = prefs.getDouble('geofence_latitude');
      final longitude = prefs.getDouble('geofence_longitude');
      final userId = prefs.getString('geofence_user_id');

      if (clinicId != null && clinicName != null && 
          latitude != null && longitude != null && userId != null) {
        await startGeofenceMonitoring(
          clinicId: clinicId,
          clinicName: clinicName,
          latitude: latitude,
          longitude: longitude,
          userId: userId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resuming geofence monitoring: $e');
      }
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // Earth's radius in meters
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_degreesToRadians(lat1)) * 
              cos(_degreesToRadians(lat2)) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Check if currently monitoring
  bool get isMonitoring => _isMonitoring;

  /// Get active clinic name
  String? get activeClinicName => _activeClinicName;

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
  }
}
