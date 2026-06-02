/// Business model for multi-device shared data
/// Each business represents one client with multiple devices
class Business {
  final String id;
  final String name;
  final String ownerId;
  final String ownerEmail;
  final DateTime createdAt;
  final bool isActive;
  final int maxDevices;
  final String? contactNumber;
  final String? address;

  Business({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerEmail,
    required this.createdAt,
    this.isActive = true,
    this.maxDevices = 10,
    this.contactNumber,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
      'max_devices': maxDevices,
      'contact_number': contactNumber,
      'address': address,
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerId: map['owner_id'] as String,
      ownerEmail: map['owner_email'] as String,
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : (map['created_at'] as DateTime),
      isActive: map['is_active'] == true || (map['is_active'] as int?) == 1,
      maxDevices: map['max_devices'] as int? ?? 10,
      contactNumber: map['contact_number'] as String?,
      address: map['address'] as String?,
    );
  }

  Business copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? ownerEmail,
    DateTime? createdAt,
    bool? isActive,
    int? maxDevices,
    String? contactNumber,
    String? address,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      maxDevices: maxDevices ?? this.maxDevices,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
    );
  }
}
