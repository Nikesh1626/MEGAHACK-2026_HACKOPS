import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/firestore_schema.dart';
import '../model/queue_entry.dart';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final _queueController = StreamController<QueueEntry?>.broadcast();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<QueueEntry?> get queueStream => _queueController.stream;

  QueueEntry? _currentQueue;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;

  /// Get current active queue entry
  QueueEntry? get currentQueue => _currentQueue;

  Future<QueueEntry> joinQueue({
    required String clinicId,
    required String clinicName,
    required String userId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be logged in to join a queue');
    }

    await cancelQueue();

    return _firestore.runTransaction((transaction) async {
      final activeQueueSnapshot = await _firestore
          .collection(FsCollections.queueEntries)
          .where(FsFields.clinicId, isEqualTo: clinicId)
          .where(FsFields.status,
              whereIn: ['waiting', 'confirmed', 'called']).get();

      final nextPosition = activeQueueSnapshot.docs.length + 1;
      final estimatedWaitMinutes = nextPosition * 5;
      final now = DateTime.now();
      final docRef = _firestore.collection(FsCollections.queueEntries).doc();

      transaction.set(docRef, {
        FsFields.clinicId: clinicId,
        FsFields.clinicName: clinicName,
        FsFields.userId: user.uid,
        FsFields.userName: user.displayName ?? user.email ?? userId,
        FsFields.userEmail: user.email,
        FsFields.joinedAt: FieldValue.serverTimestamp(),
        FsFields.position: nextPosition,
        FsFields.estimatedWaitMinutes: estimatedWaitMinutes,
        FsFields.userTargetPosition: nextPosition,
        FsFields.status: 'confirmed',
        FsFields.updates: [
          {
            FsFields.message: 'Joined queue at $clinicName',
            FsFields.timestamp: now.toIso8601String(),
          }
        ],
        FsFields.updatedAt: FieldValue.serverTimestamp(),
      });

      final queueEntry = QueueEntry(
        id: docRef.id,
        clinicId: clinicId,
        clinicName: clinicName,
        userId: user.uid,
        joinedAt: now,
        position: nextPosition,
        estimatedWaitMinutes: estimatedWaitMinutes,
        userTargetPosition: nextPosition,
        status: QueueStatus.confirmed,
        updates: [
          QueueUpdate(
            message: 'Joined queue at $clinicName',
            timestamp: now,
          ),
        ],
      );

      _currentQueue = queueEntry;
      _queueController.add(queueEntry);
      return queueEntry;
    });
  }

  /// Cancel current queue
  Future<void> cancelQueue() async {
    if (_currentQueue != null) {
      await _firestore
          .collection(FsCollections.queueEntries)
          .doc(_currentQueue!.id)
          .set({
        FsFields.status: 'cancelled',
        FsFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _currentQueue = null;
      _queueController.add(null);
    }
  }

  /// Load saved queue from local storage
  Future<void> loadSavedQueue() async {
    final user = _auth.currentUser;
    if (user == null) {
      _currentQueue = null;
      _queueController.add(null);
      return;
    }
    await _queueSubscription?.cancel();
    _queueSubscription = _firestore
        .collection(FsCollections.queueEntries)
        .where(FsFields.userId, isEqualTo: user.uid)
        .where(FsFields.status, whereIn: ['waiting', 'confirmed', 'called'])
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) {
            _currentQueue = null;
            _queueController.add(null);
            return;
          }

          final docs = snapshot.docs.toList()
            ..sort((a, b) {
              final aTs = a.data()[FsFields.joinedAt];
              final bTs = b.data()[FsFields.joinedAt];
              final aDate = aTs is Timestamp ? aTs.toDate() : DateTime.now();
              final bDate = bTs is Timestamp ? bTs.toDate() : DateTime.now();
              return bDate.compareTo(aDate);
            });

          final activeDoc = docs.first;
          _currentQueue = _fromFirestore(activeDoc);
          _queueController.add(_currentQueue);
        });
  }

  QueueEntry _fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final joinedAt = data[FsFields.joinedAt];
    final updatesRaw = data[FsFields.updates] as List<dynamic>? ?? const [];

    final statusName = (data[FsFields.status] ?? 'waiting').toString();
    final status = QueueStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => QueueStatus.waiting,
    );

    return QueueEntry(
      id: doc.id,
      clinicId: (data[FsFields.clinicId] ?? '').toString(),
      clinicName: (data[FsFields.clinicName] ?? 'Clinic').toString(),
      userId: (data[FsFields.userId] ?? '').toString(),
      joinedAt: joinedAt is Timestamp ? joinedAt.toDate() : DateTime.now(),
      position: (data[FsFields.position] as num?)?.toInt() ?? 1,
      estimatedWaitMinutes:
          (data[FsFields.estimatedWaitMinutes] as num?)?.toInt() ?? 0,
      userTargetPosition:
          (data[FsFields.userTargetPosition] as num?)?.toInt() ??
              (data[FsFields.position] as num?)?.toInt() ??
              1,
      status: status,
      updates: updatesRaw.map((item) {
        final map = item as Map<String, dynamic>;
        final timestamp = map[FsFields.timestamp];
        DateTime parsedTimestamp;
        if (timestamp is Timestamp) {
          parsedTimestamp = timestamp.toDate();
        } else {
          parsedTimestamp =
              DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
        }
        return QueueUpdate(
          message: (map[FsFields.message] ?? '').toString(),
          timestamp: parsedTimestamp,
        );
      }).toList(),
    );
  }

  void dispose() {
    _queueSubscription?.cancel();
    _queueController.close();
  }
}
