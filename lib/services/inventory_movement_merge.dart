/// Combine a cloud snapshot with local history without deleting local entries.
/// Local SQLite IDs are not globally unique across devices. When two devices
/// use the same number for different records, preserve both histories by
/// assigning the cloud record an unused local ID instead of aborting restore.
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

  final usedIds = <int>{};
  for (final row in result) {
    final id = int.tryParse(row['id']?.toString() ?? '');
    if (id != null) {
      usedIds.add(id);
    }
  }
  var nextLocalId = usedIds.isEmpty
      ? 1
      : usedIds.reduce((largest, value) => value > largest ? value : largest) +
            1;

  for (final incoming in remote) {
    // Keep the local before/after values: older backend versions do not store
    // them and reconstructing them from the change would invent data.
    // This also recognizes a cloud record that was remapped locally during a
    // previous restore because another device used the same numeric ID.
    if (result.any((row) => sameMovement(row, incoming))) {
      continue;
    }

    final copied = Map<String, dynamic>.from(incoming);
    final incomingId = int.tryParse(incoming['id']?.toString() ?? '');
    if (incomingId == null || usedIds.contains(incomingId)) {
      while (usedIds.contains(nextLocalId)) {
        nextLocalId += 1;
      }
      copied['id'] = nextLocalId;
      usedIds.add(nextLocalId);
      nextLocalId += 1;
    } else {
      usedIds.add(incomingId);
    }
    result.add(copied);
  }
  return result;
}
