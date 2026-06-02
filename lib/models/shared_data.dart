import 'dart:convert';

class SharedData {
  final String id;
  final Map<String, dynamic> payload;

  SharedData({required this.id, required this.payload});

  factory SharedData.fromJson(Map<String, dynamic> json) {
    return SharedData(
      id: json['id']?.toString() ?? 'shared',
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};

  @override
  String toString() => jsonEncode(toJson());
}
