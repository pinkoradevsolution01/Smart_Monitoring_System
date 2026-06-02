import 'package:uuid/uuid.dart';

class Customer {
  final int? id;
  final String customerCode;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final int pointsBalance;
  final int lifetimePoints;
  final String barcodeValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Customer({
    this.id,
    String? customerCode,
    required this.fullName,
    this.phoneNumber,
    this.email,
    this.address,
    this.pointsBalance = 0,
    this.lifetimePoints = 0,
    String? barcodeValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  }) : customerCode = customerCode ?? const Uuid().v4(),
       barcodeValue =
           barcodeValue ??
           'SMS-CUST-${(customerCode ?? const Uuid().v4()).replaceAll('-', '').substring(0, 12).toUpperCase()}',
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerCode': customerCode,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'pointsBalance': pointsBalance,
      'lifetimePoints': lifetimePoints,
      'barcodeValue': barcodeValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      customerCode: (map['customerCode'] as String?) ?? '',
      fullName: (map['fullName'] as String?) ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      pointsBalance: (map['pointsBalance'] as num?)?.toInt() ?? 0,
      lifetimePoints: (map['lifetimePoints'] as num?)?.toInt() ?? 0,
      barcodeValue: (map['barcodeValue'] as String?) ?? '',
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'] as String)
          : (map['createdAt'] as DateTime? ?? DateTime.now()),
      updatedAt: map['updatedAt'] is String
          ? DateTime.parse(map['updatedAt'] as String)
          : (map['updatedAt'] as DateTime? ?? DateTime.now()),
      isActive: (map['isActive'] as int?) != 0,
    );
  }

  Customer copyWith({
    int? id,
    String? customerCode,
    String? fullName,
    String? phoneNumber,
    String? email,
    String? address,
    int? pointsBalance,
    int? lifetimePoints,
    String? barcodeValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
