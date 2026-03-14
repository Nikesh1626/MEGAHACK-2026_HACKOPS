import '../constants/firestore_schema.dart';

class QueueEntry {
  final String id;
  final String clinicId;
  final String clinicName;
  final String userId;
  final DateTime joinedAt;
  final int position;
  final int estimatedWaitMinutes;
  final int userTargetPosition;
  final QueueStatus status;
  final List<QueueUpdate> updates;

  QueueEntry({
    required this.id,
    required this.clinicId,
    required this.clinicName,
    required this.userId,
    required this.joinedAt,
    required this.position,
    required this.estimatedWaitMinutes,
    required this.userTargetPosition,
    required this.status,
    this.updates = const [],
  });

  QueueEntry copyWith({
    String? id,
    String? clinicId,
    String? clinicName,
    String? userId,
    DateTime? joinedAt,
    int? position,
    int? estimatedWaitMinutes,
    int? userTargetPosition,
    QueueStatus? status,
    List<QueueUpdate>? updates,
  }) {
    return QueueEntry(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      clinicName: clinicName ?? this.clinicName,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      position: position ?? this.position,
      estimatedWaitMinutes: estimatedWaitMinutes ?? this.estimatedWaitMinutes,
      userTargetPosition: userTargetPosition ?? this.userTargetPosition,
      status: status ?? this.status,
      updates: updates ?? this.updates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      FsFields.id: id,
      FsFields.clinicId: clinicId,
      FsFields.clinicName: clinicName,
      FsFields.userId: userId,
      FsFields.joinedAt: joinedAt.toIso8601String(),
      FsFields.position: position,
      FsFields.estimatedWaitMinutes: estimatedWaitMinutes,
      FsFields.userTargetPosition: userTargetPosition,
      FsFields.status: status.name,
      FsFields.updates: updates.map((u) => u.toJson()).toList(),
    };
  }

  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    return QueueEntry(
      id: json[FsFields.id],
      clinicId: json[FsFields.clinicId],
      clinicName: json[FsFields.clinicName],
      userId: json[FsFields.userId],
      joinedAt: DateTime.parse(json[FsFields.joinedAt]),
      position: json[FsFields.position],
      estimatedWaitMinutes: json[FsFields.estimatedWaitMinutes],
      userTargetPosition:
          json[FsFields.userTargetPosition] ??
          (json[FsFields.userTargetPosition] as int? ?? 4),
      status: QueueStatus.values.firstWhere(
        (e) => e.name == json[FsFields.status],
      ),
      updates: (json[FsFields.updates] as List?)
              ?.map((u) => QueueUpdate.fromJson(u))
              .toList() ??
          [],
    );
  }
}

enum QueueStatus {
  waiting,
  confirmed,
  called,
  completed,
  cancelled,
}

class QueueUpdate {
  final String message;
  final DateTime timestamp;

  QueueUpdate({
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      FsFields.message: message,
      FsFields.timestamp: timestamp.toIso8601String(),
    };
  }

  factory QueueUpdate.fromJson(Map<String, dynamic> json) {
    return QueueUpdate(
      message: json[FsFields.message],
      timestamp: DateTime.parse(json[FsFields.timestamp]),
    );
  }
}
