import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class AttendanceEntry {
  final DateTime time;
  final String type; // 'IN' or 'OUT'

  AttendanceEntry({required this.time, required this.type});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'type': type,
  };

  static AttendanceEntry fromJson(Map<String, dynamic> j) => AttendanceEntry(
    time: DateTime.parse(j['time'] as String),
    type: j['type'] as String,
  );
}

class AttendanceService extends ChangeNotifier {
  AttendanceService._();

  static final AttendanceService instance = AttendanceService._();

  static const String _kKeyPrefix = 'attendance_entries_';
  static const String _kArchivePrefix = 'attendance_archive_';
  static const String _kScheduleKey = 'attendance_schedule';
  static const String _kLeavesPrefix = 'attendance_leaves_';

  Future<List<AttendanceEntry>> loadEntries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kKeyPrefix$userId');
    if (raw == null) {
      // fallback to DB if available
      try {
        final rows = await DatabaseService().getAttendanceEntries(userId);
        return rows
            .map((r) => AttendanceEntry.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      } catch (e) {
        return <AttendanceEntry>[];
      }
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AttendanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      return <AttendanceEntry>[];
    }
  }

  // Load the per-user archive: map of date (yyyy-MM-dd) -> list of entries
  Future<Map<String, List<AttendanceEntry>>> loadArchive(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kArchivePrefix$userId');
    if (raw == null) {
      return <String, List<AttendanceEntry>>{};
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, List<AttendanceEntry>>{};
      map.forEach((k, v) {
        final list = (v as List<dynamic>)
            .map((e) => AttendanceEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        out[k] = list;
      });
      return out;
    } catch (e) {
      return <String, List<AttendanceEntry>>{};
    }
  }

  /// Load global schedule: returns map { 'start': 'HH:mm', 'end': 'HH:mm', 'requiredMinutes': int }
  Future<Map<String, dynamic>> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kScheduleKey);
    if (raw == null) {
      return <String, dynamic>{
        'start': '09:00',
        'end': '18:00',
        'requiredMinutes': 8 * 60,
        'lunchMinutes': 60,
        'snackMinutes': 15,
      };
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m;
    } catch (e) {
      return <String, dynamic>{
        'start': '09:00',
        'end': '18:00',
        'requiredMinutes': 8 * 60,
        'lunchMinutes': 60,
        'snackMinutes': 15,
      };
    }
  }

  Future<void> saveSchedule(Map<String, dynamic> schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleKey, jsonEncode(schedule));
    try {
      await DatabaseService().saveAttendanceSchedule(schedule);
    } catch (e) {
      // ignore DB errors
    }
    notifyListeners();
  }

  Future<void> _saveEntries(
    String userId,
    List<AttendanceEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('$_kKeyPrefix$userId', raw);
    // also persist to sqlite
    try {
      await DatabaseService().replaceAttendanceEntries(
        userId,
        entries.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      // ignore DB errors
    }
    notifyListeners();
  }

  /// Replace the current entries for a user from an external source.
  /// Used by cloud sync restore paths.
  Future<void> replaceEntries(
    String userId,
    List<AttendanceEntry> entries,
  ) async {
    await _saveEntries(userId, entries);
  }

  /// Returns the next attendance type for the given user's today entries.
  Future<String> nextTypeForUser(String userId) async {
    final entries = await loadEntries(userId);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todaysEntries = entries
        .where((e) => e.time.isAfter(startOfToday))
        .toList();
    if (todaysEntries.isEmpty) {
      return 'IN';
    }
    final last = todaysEntries.last;
    if (last.type == 'IN') {
      final hasLunch = todaysEntries.any((e) => e.type == 'LUNCH');
      final hasSnack = todaysEntries.any((e) => e.type == 'SNACK');
      final hasOut = todaysEntries.any((e) => e.type == 'OUT');
      if (!hasLunch) return 'LUNCH';
      if (!hasSnack) return 'SNACK';
      if (!hasOut) return 'OUT';
      return 'IN';
    }
    if (last.type == 'LUNCH' || last.type == 'SNACK' || last.type == 'OUT') {
      return 'IN';
    }
    return 'IN';
  }

  Future<void> _saveArchive(
    String userId,
    Map<String, List<AttendanceEntry>> a,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final enc = <String, dynamic>{};
    // Ensure each day's entries are deduplicated by time+type
    a.forEach((k, v) {
      final seen = <String>{};
      final dedup = <Map<String, dynamic>>[];
      for (final e in v) {
        final key = '${e.time.toIso8601String()}|${e.type}';
        if (!seen.contains(key)) {
          seen.add(key);
          dedup.add(e.toJson());
        }
      }
      enc[k] = dedup;
    });
    await prefs.setString('$_kArchivePrefix$userId', jsonEncode(enc));
    notifyListeners();
  }

  // Leaves: per-user map date(yyyy-MM-dd) -> {authorized: bool, minutes: int, reason: String}
  Future<Map<String, dynamic>> loadLeaves(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kLeavesPrefix$userId');
    if (raw == null) return <String, dynamic>{};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m;
    } catch (e) {
      // fallback to DB
      try {
        final rows = await DatabaseService().getAttendanceLeaves(userId);
        final out = <String, dynamic>{};
        rows.forEach((k, v) {
          try {
            out[k] = jsonDecode(v);
          } catch (_) {
            out[k] = v;
          }
        });
        return out;
      } catch (e) {
        return <String, dynamic>{};
      }
    }
  }

  Future<void> saveLeave(
    String userId,
    String dateKey,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kLeavesPrefix$userId');
    Map<String, dynamic> m = {};
    if (raw != null) {
      try {
        m = jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        m = {};
      }
    }
    m[dateKey] = payload;
    await prefs.setString('$_kLeavesPrefix$userId', jsonEncode(m));
    // persist to sqlite as well
    try {
      await DatabaseService().saveAttendanceLeave(
        userId,
        dateKey,
        jsonEncode(payload),
      );
    } catch (e) {
      // ignore
    }
    notifyListeners();
  }

  Future<void> removeLeave(String userId, String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kLeavesPrefix$userId');
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.remove(dateKey);
      await prefs.setString('$_kLeavesPrefix$userId', jsonEncode(m));
      try {
        await DatabaseService().removeAttendanceLeave(userId, dateKey);
      } catch (e) {
        // ignore
      }
      notifyListeners();
    } catch (e) {
      return;
    }
  }

  Future<List<AttendanceEntry>> toggle(String userId) async {
    // Load existing entries
    final entries = await loadEntries(userId);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // If there are entries from previous days, archive them grouped by date
    if (entries.isNotEmpty) {
      final toArchive = <String, List<AttendanceEntry>>{};
      final remaining = <AttendanceEntry>[];
      for (final e in entries) {
        final d = DateTime(e.time.year, e.time.month, e.time.day);
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (d.isBefore(startOfToday)) {
          toArchive.putIfAbsent(key, () => <AttendanceEntry>[]).add(e);
        } else {
          remaining.add(e);
        }
      }

      if (toArchive.isNotEmpty) {
        // merge with existing archive
        final existing = await loadArchive(userId);
        toArchive.forEach((k, list) {
          final merged = <AttendanceEntry>[];
          if (existing.containsKey(k)) merged.addAll(existing[k]!);
          merged.addAll(list);
          // deduplicate merged list by time+type
          final seen = <String>{};
          final dedup = <AttendanceEntry>[];
          for (final e in merged) {
            final key = '${e.time.toIso8601String()}|${e.type}';
            if (!seen.contains(key)) {
              seen.add(key);
              dedup.add(e);
            }
          }
          existing[k] = dedup;
        });
        await _saveArchive(userId, existing);
        // save remaining as current entries
        await _saveEntries(userId, remaining);
        // update local entries variable to remaining
        entries
          ..clear()
          ..addAll(remaining);
      }
    }

    // Determine next type for today based on today's entries
    String next = 'IN';
    final todaysEntries = entries
        .where((e) => e.time.isAfter(startOfToday))
        .toList();
    if (todaysEntries.isNotEmpty) {
      final lastEntry = todaysEntries.last;
      if (lastEntry.type == 'IN') {
        // after IN: sequence LUNCH -> IN -> SNACK -> IN -> OUT
        final hasLunch = todaysEntries.any((e) => e.type == 'LUNCH');
        final hasSnack = todaysEntries.any((e) => e.type == 'SNACK');
        final hasOut = todaysEntries.any((e) => e.type == 'OUT');
        if (!hasLunch) {
          next = 'LUNCH';
        } else if (!hasSnack) {
          next = 'SNACK';
        } else if (!hasOut) {
          next = 'OUT';
        } else {
          next = 'IN';
        }
      } else if (lastEntry.type == 'LUNCH' ||
          lastEntry.type == 'SNACK' ||
          lastEntry.type == 'OUT') {
        next = 'IN';
      } else {
        next = 'IN';
      }
    }

    final entry = AttendanceEntry(time: now, type: next);
    final newList = List<AttendanceEntry>.from(entries)..add(entry);
    await _saveEntries(userId, newList);
    return newList;
  }

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kKeyPrefix$userId');
    notifyListeners();
  }

  /// Delete attendance entries for a specific user on a particular date.
  /// Date is treated in local time; only entries matching the date's Y/M/D are removed
  /// from both current entries and the archive.
  Future<void> deleteEntriesForDate(String userId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    // Normalize date key
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // 1) Remove from archive if present
    try {
      final rawArchive = prefs.getString('$_kArchivePrefix$userId');
      if (rawArchive != null) {
        final map = jsonDecode(rawArchive) as Map<String, dynamic>;
        if (map.containsKey(key)) {
          map.remove(key);
          await prefs.setString('$_kArchivePrefix$userId', jsonEncode(map));
        }
      }
    } catch (e) {
      // ignore parsing errors
    }

    // 2) Remove from current entries
    try {
      final raw = prefs.getString('$_kKeyPrefix$userId');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        final entries = list
            .map((e) => AttendanceEntry.fromJson(Map<String, dynamic>.from(e)))
            .where(
              (e) =>
                  !(e.time.year == date.year &&
                      e.time.month == date.month &&
                      e.time.day == date.day),
            )
            .toList();
        await _saveEntries(userId, entries);
      }
    } catch (e) {
      // ignore
    }

    notifyListeners();
  }

  /// Delete attendance entries for a user in the inclusive date range [start, end].
  Future<void> deleteEntriesForRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      await deleteEntriesForDate(userId, d);
    }
    notifyListeners();
  }
}
