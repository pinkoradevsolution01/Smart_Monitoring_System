    class AdminAccount {
  final String id;
  final String name;
  final String email;
  final String password;
  final String? contactNumber;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final DateTime? lastModified;

  AdminAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.contactNumber,
    this.profilePictureUrl,
    required this.createdAt,
    this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'contactNumber': contactNumber,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  factory AdminAccount.fromMap(Map<String, dynamic> map) {
    return AdminAccount(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Admin',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      contactNumber: map['contactNumber'],
      profilePictureUrl: map['profilePictureUrl'],
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : (map['createdAt'] as DateTime? ?? DateTime.now()),
      lastModified: map['lastModified'] is String
          ? DateTime.parse(map['lastModified'])
          : map['lastModified'] as DateTime?,
    );
  }

  AdminAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? contactNumber,
    String? profilePictureUrl,
    DateTime? createdAt,
    DateTime? lastModified,
  }) { 
    return AdminAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      contactNumber: contactNumber ?? this.contactNumber,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}  
