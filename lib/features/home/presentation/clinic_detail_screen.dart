import 'package:flutter/material.dart';
import '../../../core/services/webhook_service.dart';
import '../../../core/services/queue_service.dart';
import '../../../core/services/geofencing_service.dart';
import '../../myqueue/CheckInScreen.dart';

class ClinicDetailScreen extends StatefulWidget {
  final String clinicName;

  const ClinicDetailScreen({super.key, required this.clinicName});

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  bool _isCalling = false;
  bool _isJoiningQueue = false;
  bool _isSettingUpGeofence = false;
  bool _useGeofencing = false; // Toggle for geofencing vs immediate join
  final _queueService = QueueService();
  final _geofencingService = GeofencingService();

  Future<void> _handleCallButton() async {
    setState(() {
      _isCalling = true;
    });

    try {
      // Send webhook with user data
      final success = await WebhookService.sendUserDataToWebhook();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Calling clinic... Webhook sent successfully!' 
              : 'Calling clinic... (Webhook failed)'),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calling clinic... (Webhook error)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _isCalling = false;
      });
    }
  }

  Future<void> _handleSetupGeofence() async {
    setState(() {
      _isSettingUpGeofence = true;
    });

    try {
      // Mock clinic coordinates (in production, these would come from your database)
      final clinicId = widget.clinicName.toLowerCase().replaceAll(' ', '_');
      final clinicLat = 28.6139 + (clinicId.hashCode % 10) * 0.001; // Mock latitude
      final clinicLng = 77.2090 + (clinicId.hashCode % 10) * 0.001; // Mock longitude
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      final success = await _geofencingService.startGeofenceMonitoring(
        clinicId: clinicId,
        clinicName: widget.clinicName,
        latitude: clinicLat,
        longitude: clinicLng,
        userId: userId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Geofence activated! You\'ll be notified when you arrive at the clinic.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          
          // Navigate back
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to activate geofence. Please check location permissions.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up geofence: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUpGeofence = false;
        });
      }
    }
  }

  Future<void> _handleJoinQueue() async {
    setState(() {
      _isJoiningQueue = true;
    });

    try {
      // Generate a unique clinic ID from clinic name
      final clinicId = widget.clinicName.toLowerCase().replaceAll(' ', '_');
      
      // Join the queue (userId would come from auth service in production)
      final queueEntry = await _queueService.joinQueue(
        clinicId: clinicId,
        clinicName: widget.clinicName,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully joined queue. Your number: ${queueEntry.userTargetPosition}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to CheckInScreen to show queue status
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CheckInScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join queue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningQueue = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clinicName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinic Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.clinicName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Open',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        const Text(
                          '4.5',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, color: Colors.grey, size: 20),
                        const SizedBox(width: 4),
                        const Text(
                          '15 min wait',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '123 Main Street, New Delhi, India',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Services Section
            const Text(
              'Available Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'General Medicine',
                'Cardiology',
                'Emergency',
                'Orthopedics',
                'Neurology',
                'Pediatrics',
              ].map((service) => Chip(
                label: Text(service),
                backgroundColor: Colors.teal[50],
                side: BorderSide(color: Colors.teal[200]!),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Contact Information
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildContactRow(Icons.phone, '+91 98765 43210'),
                    const Divider(),
                    _buildContactRow(Icons.email, 'info@clinic.com'),
                    const Divider(),
                    _buildContactRow(Icons.access_time, '24/7 Emergency Services'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Check-in Method Selection
            const Text(
              'Check-in Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _useGeofencing ? Icons.location_on : Icons.touch_app,
                        color: Colors.teal[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _useGeofencing
                                  ? 'Smart Geofencing'
                                  : 'Immediate Join',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[900],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _useGeofencing
                                  ? 'Auto check-in when you arrive (within 50m)'
                                  : 'Join the queue right now',
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useGeofencing,
                        onChanged: (value) {
                          setState(() {
                            _useGeofencing = value;
                          });
                        },
                        activeColor: Colors.teal,
                      ),
                    ],
                  ),
                  if (_useGeofencing) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You\'ll get a notification when near the clinic',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCalling ? null : _handleCallButton,
                    icon: _isCalling 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.phone),
                    label: Text(_isCalling ? 'Calling...' : 'Call'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isJoiningQueue || _isSettingUpGeofence)
                        ? null
                        : (_useGeofencing ? _handleSetupGeofence : _handleJoinQueue),
                    icon: (_isJoiningQueue || _isSettingUpGeofence)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_useGeofencing ? Icons.navigation : Icons.queue),
                    label: Text(
                      _isJoiningQueue
                          ? 'Joining...'
                          : _isSettingUpGeofence
                              ? 'Setting up...'
                              : _useGeofencing
                                  ? 'Activate Geofence'
                                  : 'Join Queue',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}