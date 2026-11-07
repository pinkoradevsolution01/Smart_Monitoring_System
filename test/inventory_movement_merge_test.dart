import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/services/inventory_movement_merge.dart';

Map<String, dynamic> movement(
  int id,
  String reference,
  int change, {
  int before = 50,
  int after = 26,
}) => {
  'id': id,
  'productId': 2,
  'reference': reference,
  'movementType': 'sale',
  'quantityChanged': change,
  'quantityBefore': before,
  'quantityAfter': after,
  'reason': 'Sold via POS',
};

void main() {
  test('a cloud snapshot does not erase an unsynced 24-unit sale', () {
    final local = [movement(10, 'SAL24', -24)];
    final merged = mergeInventoryMovements(local, []);
    expect(merged.single['reference'], 'SAL24');
    expect(merged.single['quantityChanged'], -24);
  });

  test('cloud copy cannot replace the local before and after quantities', () {
    final local = movement(10, 'SAL24', -24);
    final cloud = movement(10, 'SAL24', -24, before: 0, after: -24);
    final merged = mergeInventoryMovements([local], [cloud]);
    expect(merged, hasLength(1));
    expect(merged.single['quantityBefore'], 50);
    expect(merged.single['quantityAfter'], 26);
  });

  test('new cloud movements merge and repeated pulls are idempotent', () {
    final merged = mergeInventoryMovements(
      [movement(10, 'SAL24', -24)],
      [movement(11, 'SAL2', -2)],
    );
    expect(merged, hasLength(2));
    expect(
      mergeInventoryMovements(merged, [movement(11, 'SAL2', -2)]),
      hasLength(2),
    );
  });

  test('conflicting local and cloud IDs preserve both movement histories', () {
    final local = [movement(10, 'SAL24', -24)];
    final merged = mergeInventoryMovements(
      local,
      [movement(10, 'OTHER', -2)],
    );

    expect(local.single['reference'], 'SAL24');
    expect(merged, hasLength(2));
    expect(merged[0]['id'], 10);
    expect(merged[1]['id'], isNot(10));
    expect(merged[1]['reference'], 'OTHER');
    expect(
      mergeInventoryMovements(merged, [movement(10, 'OTHER', -2)]),
      hasLength(2),
    );
  });
}
