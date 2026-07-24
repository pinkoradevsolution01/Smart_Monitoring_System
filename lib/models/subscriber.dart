class Subscriber {
  final String id;
  final String name;
  final String email;
  final String? contactNumber;
  final DateTime createdAt;
  final String status;

  Subscriber({
    required this.id,
    required this.name,
    required this.email,
    this.contactNumber,
    required this.createdAt,
    this.status = 'active',
  });

  factory Subscriber.fromMap(Map<String, dynamic> m) => Subscriber(
    id: m['id'] as String,
    name: m['name'] as String,
    email: m['email'] as String,
    contactNumber: m['contactNumber'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
    status: m['status'] as String? ?? 'active',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'contactNumber': contactNumber,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };
}
