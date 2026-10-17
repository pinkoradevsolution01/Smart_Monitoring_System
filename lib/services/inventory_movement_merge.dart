/// Combine a cloud snapshot with local history without deleting local entries.
/// Local IDs are not globally unique, so a conflicting ID must never overwrite
/// a different movement. Stop the restore and leave the records intact.
List<Map<String, dynamic>> mergeInventoryMovements(
  List<Map<String, dynamic>> local,
  List<Map<String, dynamic>> remote,
) {
  final result = local.map((row) => Map<String, dynamic>.from(row)).toList();
  bool sameMovement(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['productId'] == b['productId'] &&
      a['reference'] == b['reference'] &&
      a['movementType'] == b['movementType'] &&
      a['quantityChanged'] == b['quantityChanged'] &&
      a['reason'] == b['reason'];

  for (final incoming in remote) {
    // Keep the local before/after values: older backend versions do not store
    // them and reconstructing them from the change would invent data.
    if (result.any(
      (row) => row['id'] == incoming['id'] && sameMovement(row, incoming),
    )) {
      continue;
    }
    if (result.any((row) => row['id'] == incoming['id'])) {
      throw StateError(
        'Inventory movement ID conflict. No local movement history was replaced.',
      );
    }
    result.add(Map<String, dynamic>.from(incoming));
  }
  return result;
}
