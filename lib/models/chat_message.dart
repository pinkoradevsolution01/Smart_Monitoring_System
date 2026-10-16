/// Model for AI assistant chat messages
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Optional owner-facing link label for the records supporting a SmartPlus
  /// response. It is deliberately navigation-only and never performs actions.
  final String? recordTarget;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.recordTarget,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'recordTarget': recordTarget,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.parse(json['timestamp'] as String),
    recordTarget: json['recordTarget'] as String?,
  );
}
