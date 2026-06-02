enum LoyaltyEntryType { earn, redeem, adjust }

class LoyaltyLedgerEntry {
  final int? id;
  final int customerId;
  final int? saleId;
  final LoyaltyEntryType entryType;
  final int points;
  final int balanceAfter;
  final String? notes;
  final DateTime createdAt;

  LoyaltyLedgerEntry({
    this.id,
    required this.customerId,
    this.saleId,
    required this.entryType,
    required this.points,
    required this.balanceAfter,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'saleId': saleId,
      'entryType': entryType.toString().split('.').last,
      'points': points,
      'balanceAfter': balanceAfter,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LoyaltyLedgerEntry.fromMap(Map<String, dynamic> map) {
    return LoyaltyLedgerEntry(
      id: map['id'] as int?,
      customerId: (map['customerId'] as num?)?.toInt() ?? 0,
      saleId: (map['saleId'] as num?)?.toInt(),
      entryType: LoyaltyEntryType.values.firstWhere(
        (entry) =>
            entry.toString().split('.').last == (map['entryType'] ?? 'earn'),
        orElse: () => LoyaltyEntryType.earn,
      ),
      points: (map['points'] as num?)?.toInt() ?? 0,
      balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'] as String)
          : (map['createdAt'] as DateTime? ?? DateTime.now()),
    );
  }
}
