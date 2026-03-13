import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/queue_entry.dart';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final _queueController = StreamController<QueueEntry?>.broadcast();
  Stream<QueueEntry?> get queueStream => _queueController.stream;

  QueueEntry? _currentQueue;
  Timer? _simulationTimer;
  int? _targetPosition; // Store the random target position for jump

  /// Get current active queue entry
  QueueEntry? get currentQueue => _currentQueue;

  /// Join a queue at a clinic
  /// NOTE: This is a TEMPORARY DEMO feature with simulated queue (positions 2-10)
  /// Will be replaced with live backend queue system in production
  Future<QueueEntry> joinQueue({
    required String clinicId,
    required String clinicName,
    required String userId,
  }) async {
    // Cancel existing queue if any
    await cancelQueue();

    // DEMO: Queue starts at 1 and counts UP to user's position (4-10)
    // User gets notification at position 3 (before their turn)
    // Queue will count: 1→2→3 (notification)→4→5...→user position
    final random = Random();
    final userPosition = random.nextInt(7) + 4; // Random position: 4 to 10
    _targetPosition = userPosition;
    
    final position = 1; // Queue always starts at 1
    final waitTime = (userPosition - position) * 5; // Wait time based on remaining positions

    final queueEntry = QueueEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clinicId: clinicId,
      clinicName: clinicName,
      userId: userId,
      joinedAt: DateTime.now(),
      position: position,
      estimatedWaitMinutes: waitTime,
      userTargetPosition: userPosition,
      status: QueueStatus.confirmed,
      updates: [
        QueueUpdate(
          message: 'Queue starting. Your position: ${userPosition}${_getOrdinalSuffix(userPosition)}',
          timestamp: DateTime.now(),
        ),
      ],
    );

    _currentQueue = queueEntry;
    await _saveQueue(queueEntry);
    _queueController.add(queueEntry);

    // Start simulation
    _startQueueSimulation();

    return queueEntry;
  }

  /// Cancel current queue
  Future<void> cancelQueue() async {
    if (_currentQueue != null) {
      _currentQueue = null;
      _simulationTimer?.cancel();
      await _clearSavedQueue();
      _queueController.add(null);
    }
  }

  /// Load saved queue from local storage
  Future<void> loadSavedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString('current_queue');
    
    if (queueJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(queueJson);
        _currentQueue = QueueEntry.fromJson(json);
        _queueController.add(_currentQueue);
        
        // Resume simulation if still waiting
        if (_currentQueue!.status == QueueStatus.confirmed ||
            _currentQueue!.status == QueueStatus.waiting) {
          _startQueueSimulation();
        }
      } catch (e) {
        // Invalid data, clear it
        await _clearSavedQueue();
      }
    }
  }

  /// Save queue to local storage
  Future<void> _saveQueue(QueueEntry queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_queue', jsonEncode(queue.toJson()));
  }

  /// Clear saved queue
  Future<void> _clearSavedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_queue');
  }

  /// Simulate queue progression (TEMPORARY - counts up from 1 to user position)
  /// TODO: Replace with real-time backend updates when live queue is activated
  void _startQueueSimulation() {
    _simulationTimer?.cancel();
    
    // Queue moves every 3 seconds, counting UP from 1 to user's position
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentQueue == null) {
        timer.cancel();
        return;
      }

      // Don't update if already called or completed
      if (_currentQueue!.status == QueueStatus.called ||
          _currentQueue!.status == QueueStatus.completed ||
          _currentQueue!.status == QueueStatus.cancelled) {
        timer.cancel();
        return;
      }

      // Queue counts up until reaching user's position
      if (_targetPosition != null && _currentQueue!.position < _targetPosition!) {
        final newPosition = _currentQueue!.position + 1;
        final updates = List<QueueUpdate>.from(_currentQueue!.updates);
        
        // Regular queue movement update
        final random = Random();
        final clinicUpdates = [
          'Queue progressing: now calling position $newPosition',
          'Patient completed their visit',
          'Queue moving smoothly',
        ];
        
        if (random.nextInt(2) == 0) {
          updates.insert(0, QueueUpdate(
            message: clinicUpdates[random.nextInt(clinicUpdates.length)],
            timestamp: DateTime.now(),
          ));
        }
        
        // Calculate remaining wait time (user position - current position)
        final remainingPositions = (_targetPosition! - newPosition).clamp(0, 1000);
        final newWaitTime = remainingPositions * 5;

        _currentQueue = _currentQueue!.copyWith(
          position: newPosition,
          estimatedWaitMinutes: newWaitTime,
          userTargetPosition: _targetPosition,
          updates: updates,
        );

        _saveQueue(_currentQueue!);
        _queueController.add(_currentQueue);
      } else if (_targetPosition != null && _currentQueue!.position >= _targetPosition!) {
        // Reached user's position: mark as called
        final updates = List<QueueUpdate>.from(_currentQueue!.updates);
        updates.insert(0, QueueUpdate(
          message: 'You are next! Please proceed to the clinic',
          timestamp: DateTime.now(),
        ));

        _currentQueue = _currentQueue!.copyWith(
          status: QueueStatus.called,
          estimatedWaitMinutes: 0,
          userTargetPosition: _targetPosition,
          updates: updates,
        );

        _saveQueue(_currentQueue!);
        _queueController.add(_currentQueue);
        timer.cancel();
      }
    });
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

  void dispose() {
    _simulationTimer?.cancel();
    _queueController.close();
  }
}
