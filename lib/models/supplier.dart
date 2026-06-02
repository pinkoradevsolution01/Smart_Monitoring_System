class Supplier {
  final int? id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isActive;
  final DateTime createdAt;

  Supplier({
    this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    this.notes = '',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'],
      contactPerson: map['contactPerson'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      notes: map['notes'] ?? '',
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
