/// Model for subscription records from Supabase cloud database
class SubscriptionRecord {
  final int id;
  final String deviceId;
  final String activationCode;
  final String packageName;
  final String? deviceName;
  final DateTime activatedAt;
  final DateTime? expiresAt;
  final String status; // active, expired, cancelled
  final DateTime? lastCheckedAt;
  final String? notes;

  SubscriptionRecord({
    required this.id,
    required this.deviceId,
    required this.activationCode,
    required this.packageName,
    this.deviceName,
    required this.activatedAt,
    required this.expiresAt,
    required this.status,
    this.lastCheckedAt,
    this.notes,
  });

  /// Create from Supabase JSON response
  factory SubscriptionRecord.fromJson(Map<String, dynamic> json) {
    return SubscriptionRecord(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      activationCode: json['activation_code'] as String,
      packageName: json['package_name'] as String,
      deviceName: json['device_name'] as String?,
      activatedAt: DateTime.parse(json['activated_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      status: json['status'] as String,
      lastCheckedAt: json['last_checked_at'] != null
          ? DateTime.parse(json['last_checked_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'activation_code': activationCode,
      'package_name': packageName,
      'device_name': deviceName,
      'activated_at': activatedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'status': status,
      'last_checked_at': lastCheckedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Check if subscription is active
  bool get isActive =>
      status == 'active' &&
      (expiresAt == null || DateTime.now().isBefore(expiresAt!));

  /// Check if subscription is expired
  bool get isExpired =>
      status == 'expired' ||
      (status == 'active' && expiresAt != null && DateTime.now().isAfter(expiresAt!));

  /// Get remaining days until expiry
  int? get remainingDays => expiresAt?.difference(DateTime.now()).inDays;

  /// Get formatted status with expiry info
  String get formattedStatus {
    if (status == 'cancelled') {
      return 'Cancelled';
    } else if (isActive) {
      return expiresAt == null ? 'Active (Perpetual)' : 'Active ($remainingDays days left)';
    } else if (isExpired) {
      return 'Expired';
    } else {
      return status;
    }
  }

  @override
  String toString() {
    return 'SubscriptionRecord(id: $id, device: $deviceName, package: $packageName, status: $status)';
  }
}
