import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/services/queue_service.dart';
import '../../core/services/geofencing_service.dart';
import '../../core/model/queue_entry.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _queueService = QueueService();
  final _geofencingService = GeofencingService();
  StreamSubscription<QueueEntry?>? _queueSubscription;
  QueueEntry? _currentQueue;
  bool _thresholdNotified = false;
  bool _calledNotified = false;

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissionWithDialog();
    _loadQueue();
  }

  /// Request notification permission with user-friendly dialog
  Future<void> _requestNotificationPermissionWithDialog() async {
    // Check if already granted
    final status = await Permission.notification.status;
    if (status.isGranted) return;

    // Show explanation dialog
    if (!mounted) return;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.teal),
            SizedBox(width: 12),
            Text('Enable Notifications'),
          ],
        ),
        content: const Text(
          'Get notified when your queue position reaches 3 or less, so you know when to head to the clinic.\n\nStay updated with real-time alerts!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final granted = await _geofencingService.requestNotificationPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission denied. You can enable it in app settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _loadQueue() async {
    await _queueService.loadSavedQueue();
    _queueSubscription = _queueService.queueStream.listen((queueEntry) {
      if (mounted) {
        setState(() {
          _currentQueue = queueEntry;
        });
        // One-time notification exactly when 3 remain before user's turn
        if (queueEntry != null && !_thresholdNotified) {
          final pos = queueEntry.position;
          final target = queueEntry.userTargetPosition;
          final shouldNotify = (queueEntry.status == QueueStatus.waiting ||
                                queueEntry.status == QueueStatus.confirmed) &&
                               pos == (target - 3);
          if (shouldNotify) {
            _geofencingService.showQueuePositionNotification(
              clinicName: queueEntry.clinicName,
              position: pos,
              estimatedMinutes: queueEntry.estimatedWaitMinutes,
            );
            _thresholdNotified = true;
          }
        }

        // Notify when the user's number is called (arrived at clinic)
        if (queueEntry != null && !_calledNotified &&
            queueEntry.status == QueueStatus.called) {
          _geofencingService.showQueueArrivedNotification(
            clinicName: queueEntry.clinicName,
          );
          _calledNotified = true;
        }
      }
    });
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) {
      return 'th';
    }
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.confirmed:
      case QueueStatus.waiting:
        return Colors.blue;
      case QueueStatus.called:
        return Colors.green;
      case QueueStatus.completed:
        return Colors.grey;
      case QueueStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return 'Waiting';
      case QueueStatus.confirmed:
        return 'Confirmed';
      case QueueStatus.called:
        return 'You\'re Next!';
      case QueueStatus.completed:
        return 'Completed';
      case QueueStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no queue, show empty state
    if (_currentQueue == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Queue'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary.withOpacity(0.15), Colors.grey[200]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.queue_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Active Queue',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join a queue at a clinic to see your position here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                // Show geofence status if active
                if (_geofencingService.isMonitoring) ...[
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
                              Icons.radar,
                              color: Colors.teal[700],
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Geofence Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.teal[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Monitoring: ${_geofencingService.activeClinicName}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.teal[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'ll be notified when you arrive within 50m',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Stop Geofence'),
                                  content: const Text(
                                    'Are you sure you want to stop monitoring your arrival?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Stop'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _geofencingService.stopGeofenceMonitoring();
                                setState(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Geofence monitoring stopped'),
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Stop Monitoring'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentQueue!.clinicName),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Header card with big number and status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Circular number with ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: (_currentQueue!.position / (_currentQueue!.userTargetPosition.clamp(1, 10))),
                            strokeWidth: 10,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_currentQueue!.position}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _currentQueue!.status == QueueStatus.called
                                    ? Colors.green
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              _getOrdinalSuffix(_currentQueue!.position),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentQueue!.status == QueueStatus.called
                                ? "You're next!"
                                : "You're in line",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Chip(
                                label: Text(_getStatusText(_currentQueue!.status)),
                                backgroundColor: _getStatusColor(_currentQueue!.status).withOpacity(0.15),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(_currentQueue!.status),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentQueue!.status == QueueStatus.called
                                    ? 'Please proceed to the clinic'
                                    : 'ETA: ${_currentQueue!.estimatedWaitMinutes} min',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress info
                          LinearProgressIndicator(
                            value: (_currentQueue!.position / (_currentQueue!.userTargetPosition.clamp(1, 10))),
                            minHeight: 6,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor: Colors.grey[200],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'From 1 to ${_currentQueue!.userTargetPosition} • ${(_currentQueue!.userTargetPosition - _currentQueue!.position).clamp(0, 100)} remaining',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Real-time updates',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Timeline updates - showing latest updates first
              ..._currentQueue!.updates.asMap().entries.map((entry) {
                final index = entry.key;
                final update = entry.value;
                final timeFormat = DateFormat('h:mm a');
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          index == 0 ? Icons.update : Icons.schedule,
                          color: index == 0 ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                update.message,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeFormat.format(update.timestamp),
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 60),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancel Check-In'),
                        content: const Text(
                          'Are you sure you want to cancel your queue position?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Yes, Cancel'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _queueService.cancelQueue();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Queue cancelled successfully'),
                          ),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Queue',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// A custom widget for creating the timeline effect for updates
class TimelineUpdate extends StatelessWidget {
  final String title;
  final String time;
  final bool isFirst;

  const TimelineUpdate({
    super.key,
    required this.title,
    required this.time,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // This column creates the timeline line and circle
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isFirst ? Colors.black : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // This column contains the update text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}