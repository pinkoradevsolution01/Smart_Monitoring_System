import 'package:uuid/uuid.dart';

enum LoyaltyEntryType { earn, redeem, adjust }

class LoyaltyLedgerEntry {
  final int? id;

  /// Stable identity for syncing this entry across devices. Local integer IDs
  /// are only meaningful inside one SQLite database.
  final String syncId;
  final int customerId;
  final int? saleId;
  final LoyaltyEntryType entryType;
  final int points;
  final int balanceAfter;
  final String? notes;
  final DateTime createdAt;

  LoyaltyLedgerEntry({
    this.id,
    String? syncId,
    required this.customerId,
    this.saleId,
    required this.entryType,
    required this.points,
    required this.balanceAfter,
    this.notes,
    DateTime? createdAt,
  }) : syncId = syncId ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'syncId': syncId,
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
      syncId: map['syncId'] as String?,
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
