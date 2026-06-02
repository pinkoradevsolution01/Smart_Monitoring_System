class CCTVTimestamp {
  final int? id;
  final DateTime timestamp;
  final String? description;
  final String? videoPath;
  final DateTime createdAt;

  CCTVTimestamp({
    this.id,
    required this.timestamp,
    this.description,
    this.videoPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'videoPath': videoPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CCTVTimestamp.fromMap(Map<String, dynamic> map) {
    return CCTVTimestamp(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      description: map['description'] as String?,
      videoPath: map['videoPath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String get formattedTimestamp {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    }
  }

  String get formattedDate {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
