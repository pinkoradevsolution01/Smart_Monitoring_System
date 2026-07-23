enum UserRole {
  owner,
  manager,
  salesPromoter,
  inventoryClerk,
  deliveryReceiver,
  cashier,
  staff,
}

class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final String? pin;
  final String? contactNumber;
  final UserRole role;
  final String? businessId; // Links user to a business for multi-device sync
  final DateTime createdAt;
  final bool isActive;
  final String authMethod; // 'password' or 'google' - used to identify OAuth users

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.pin,
    this.contactNumber,
    required this.role,
    this.businessId,
    required this.createdAt,
    this.isActive = true,
    this.authMethod = 'password',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'pin': pin,
      'contactNumber': contactNumber,
      'role': role.toString().split('.').last,
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'authMethod': authMethod,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final rawPin = map['pin']?.toString();
    final rawContactNumber =
        (map['contactNumber'] ?? map['contact_number'])?.toString();
    // Older versions incorrectly stored the owner's phone number in `pin`.
    // Recover that legacy value as a contact number while preserving real 4-digit PINs.
    final legacyContactNumber = rawContactNumber == null &&
            rawPin != null &&
            !RegExp(r'^\d{4}$').hasMatch(rawPin)
        ? rawPin
        : null;
    final roleStr = (map['role'] ?? 'cashier').toString().toLowerCase();
    UserRole parsedRole;
    switch (roleStr) {
      case 'owner':
        parsedRole = UserRole.owner;
        break;
      case 'manager':
        parsedRole = UserRole.manager;
        break;
      case 'salespromoter':
      case 'sales_promoter':
      case 'sales-promoter':
      case 'sales promoter':
        parsedRole = UserRole.salesPromoter;
        break;
      case 'inventoryclerk':
      case 'inventory_clerk':
      case 'inventory-clerk':
      case 'inventory clerk':
        parsedRole = UserRole.inventoryClerk;
        break;
      case 'deliveryreceiver':
      case 'delivery_receiver':
      case 'delivery-receiver':
      case 'delivery receiver':
        parsedRole = UserRole.deliveryReceiver;
        break;
      case 'cashier':
        parsedRole = UserRole.cashier;
        break;
      default:
        parsedRole = UserRole.staff;
    }

    final createdAtValue =
        map['createdAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String();
    final isActiveValue = map['isActive'] ?? map['is_active'] ?? true;
    final authMethodValue = map['authMethod'] ?? map['auth_method'] ?? 'password';
    final isActive = isActiveValue is bool
        ? isActiveValue
        : isActiveValue is num
        ? isActiveValue == 1
        : isActiveValue.toString() == '1' ||
            isActiveValue.toString().toLowerCase() == 'true';

    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? map['full_name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? map['password_hash'] ?? '',
      pin: legacyContactNumber == null ? rawPin : null,
      contactNumber: rawContactNumber ?? legacyContactNumber,
      role: parsedRole,
      businessId: map['businessId'] ?? map['business_id'],
      createdAt: createdAtValue is String
          ? DateTime.parse(createdAtValue)
          : (createdAtValue as DateTime? ?? DateTime.now()),
      isActive: isActive,
      authMethod: authMethodValue.toString(),
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? pin,
    String? contactNumber,
    UserRole? role,
    String? businessId,
    DateTime? createdAt,
    bool? isActive,
    String? authMethod,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      pin: pin ?? this.pin,
      contactNumber: contactNumber ?? this.contactNumber,
      role: role ?? this.role,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      authMethod: authMethod ?? this.authMethod,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
