import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/attendance_service.dart';
import '../../utils/app_localizations.dart';

enum _ViewMode { daily, range }

enum _ShiftView { opening, mid, closing }

class ManageAttendanceScreen extends StatefulWidget {
  const ManageAttendanceScreen({super.key});

  @override
  State<ManageAttendanceScreen> createState() => _ManageAttendanceScreenState();
}

class _ManageAttendanceScreenState extends State<ManageAttendanceScreen> {
  late UserService _userService;
  _ViewMode _mode = _ViewMode.daily;
  DateTime _selectedDate = DateTime.now();
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  TimeOfDay? _scheduleStart;
  TimeOfDay? _scheduleEnd;
  _ShiftView? _selectedShift;
  int _requiredMinutes = 8 * 60;
  int _lunchMinutes = 60;
  int _snackMinutes = 15;
  // persisted map of userId -> assigned shift (null = All)
  final Map<String, _ShiftView?> _userShiftAssignments = {};
  // shift-specific times
  TimeOfDay? _openingStart;
  TimeOfDay? _openingEnd;
  TimeOfDay? _midStart;
  TimeOfDay? _midEnd;
  TimeOfDay? _closingStart;
  TimeOfDay? _closingEnd;

  // Map userId -> filtered entries
  final Map<String, List<AttendanceEntry>> _results = {};
  // Map userId -> leaves map (dateKey -> payload)
  final Map<String, Map<String, dynamic>> _leaves = {};
  // Map userId -> total worked duration across current filter
  final Map<String, Duration> _totalWorked = {};
  // Map userId -> total days attended across current filter
  final Map<String, int> _totalDays = {};
  // Map userId -> total overtime duration across current filter
  final Map<String, Duration> _totalOvertime = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _userService = GetIt.I<UserService>();
    _userService.addListener(_onUsersChanged);
    AttendanceService.instance.addListener(_onAttendanceChanged);
    // load schedule
    AttendanceService.instance.loadSchedule().then((m) {
      if (!mounted) return;
      setState(() {
        final start = (m['start'] as String?) ?? '09:00';
        final end = (m['end'] as String?) ?? '18:00';
        _requiredMinutes = (m['requiredMinutes'] as int?) ?? (8 * 60);
        _lunchMinutes = (m['lunchMinutes'] as int?) ?? 60;
        _snackMinutes = (m['snackMinutes'] as int?) ?? 15;
        final sp = start.split(':');
        final ep = end.split(':');
        _scheduleStart = TimeOfDay(
          hour: int.parse(sp[0]),
          minute: int.parse(sp[1]),
        );
        _scheduleEnd = TimeOfDay(
          hour: int.parse(ep[0]),
          minute: int.parse(ep[1]),
        );
        // optional per-user shifts stored as map of userId -> shift string
        try {
          final us = m['userShifts'] as Map<String, dynamic>?;
          if (us != null) {
            _userShiftAssignments.clear();
            us.forEach((k, v) {
              final s = (v as String?) ?? '';
              switch (s) {
                case 'opening':
                  _userShiftAssignments[k] = _ShiftView.opening;
                  break;
                case 'mid':
                  _userShiftAssignments[k] = _ShiftView.mid;
                  break;
                case 'closing':
                  _userShiftAssignments[k] = _ShiftView.closing;
                  break;
                default:
                  _userShiftAssignments[k] = null;
              }
            });
          }
        } catch (_) {}
        // load shift-specific times
        try {
          final openingS = (m['openingStart'] as String?) ?? '';
          if (openingS.isNotEmpty) {
            final parts = openingS.split(':');
            _openingStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          final openingE = (m['openingEnd'] as String?) ?? '';
          if (openingE.isNotEmpty) {
            final parts = openingE.split(':');
            _openingEnd = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          final midS = (m['midStart'] as String?) ?? '';
          if (midS.isNotEmpty) {
            final parts = midS.split(':');
            _midStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          final midE = (m['midEnd'] as String?) ?? '';
          if (midE.isNotEmpty) {
            final parts = midE.split(':');
            _midEnd = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          final closingS = (m['closingStart'] as String?) ?? '';
          if (closingS.isNotEmpty) {
            final parts = closingS.split(':');
            _closingStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          final closingE = (m['closingEnd'] as String?) ?? '';
          if (closingE.isNotEmpty) {
            final parts = closingE.split(':');
            _closingEnd = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        } catch (_) {}
      });
    });
    // initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilter());
  }

  void _onUsersChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _userService.removeListener(_onUsersChanged);
    AttendanceService.instance.removeListener(_onAttendanceChanged);
    super.dispose();
  }

  void _onAttendanceChanged() {
    if (!mounted) {
      return;
    }
    _applyFilter();
  }

  Future<void> _applyFilter() async {
    // Collect users by role but deduplicate by id to avoid duplicates
    final Map<String, User> userMap = {};
    for (final u in _userService.getUsersByRole(UserRole.cashier)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.staff)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.salesPromoter)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.inventoryClerk)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.deliveryReceiver)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.manager)) {
      userMap[u.id] = u;
    }
    final users = userMap.values.toList();
    setState(() => _loading = true);

    final startEnd = _computeRange();

    final futures = users.map((u) async {
      // Load current entries
      final entries = await AttendanceService.instance.loadEntries(u.id);

      // Also load archived entries (for past dates)
      final archive = await AttendanceService.instance.loadArchive(u.id);
      // Merge current entries and archive with deduplication
      final allEntries = <AttendanceEntry>[];
      final seen = <String>{};
      for (final e in entries) {
        final key = '${e.time.toIso8601String()}|${e.type}';
        if (!seen.contains(key)) {
          seen.add(key);
          allEntries.add(e);
        }
      }
      archive.forEach((date, entryList) {
        for (final e in entryList) {
          final key = '${e.time.toIso8601String()}|${e.type}';
          if (!seen.contains(key)) {
            seen.add(key);
            allEntries.add(e);
          }
        }
      });

      final filtered = allEntries.where((e) {
        return e.time.isAfter(
              startEnd.start.subtract(const Duration(milliseconds: 1)),
            ) &&
            e.time.isBefore(startEnd.end.add(const Duration(milliseconds: 1)));
      }).toList();
      return MapEntry(u.id, filtered);
    }).toList();

    final pairs = await Future.wait(futures);
    if (!mounted) {
      return;
    }

    _results.clear();
    for (final p in pairs) {
      _results[p.key] = p.value.reversed.toList(); // newest first
    }

    // load leaves for each user
    final leafFutures = users.map((u) async {
      final l = await AttendanceService.instance.loadLeaves(u.id);
      return MapEntry(u.id, l);
    }).toList();
    final leafPairs = await Future.wait(leafFutures);
    _leaves.clear();
    for (final p in leafPairs) {
      _leaves[p.key] = Map<String, dynamic>.from(p.value);
    }

    // compute totals per user for current range
    _totalWorked.clear();
    _totalDays.clear();
    final range = startEnd;
    for (final u in users) {
      final userEntries = _results[u.id] ?? [];
      final userLeaves = _leaves[u.id] ?? {};
      int days = 0;
      Duration workedTotal = Duration.zero;
      Duration overtimeTotal = Duration.zero;
      for (
        var d = range.start;
        !d.isAfter(range.end);
        d = d.add(const Duration(days: 1))
      ) {
        final dayList =
            userEntries
                .where(
                  (e) =>
                      e.time.year == d.year &&
                      e.time.month == d.month &&
                      e.time.day == d.day,
                )
                .toList()
              ..sort((a, b) => a.time.compareTo(b.time));

        // determine shift bounds for this day when a shift is selected
        DateTime? shiftStart;
        DateTime? shiftEnd;
        if (_selectedShift != null &&
            _scheduleStart != null &&
            _scheduleEnd != null) {
          final s = DateTime(
            d.year,
            d.month,
            d.day,
            _scheduleStart!.hour,
            _scheduleStart!.minute,
          );
          final eTime = DateTime(
            d.year,
            d.month,
            d.day,
            _scheduleEnd!.hour,
            _scheduleEnd!.minute,
          );
          final totalMinutes = eTime.difference(s).inMinutes;
          if (totalMinutes > 0) {
            final part = totalMinutes ~/ 3;
            if (_selectedShift == _ShiftView.opening) {
              shiftStart = s;
              shiftEnd = s.add(Duration(minutes: part));
            } else if (_selectedShift == _ShiftView.mid) {
              shiftStart = s.add(Duration(minutes: part));
              shiftEnd = s.add(Duration(minutes: part * 2));
            } else {
              shiftStart = s.add(Duration(minutes: part * 2));
              shiftEnd = eTime;
            }
          }
        }

        final worked = _computeWorkedDuration(
          dayList,
          d,
          shiftStart: shiftStart,
          shiftEnd: shiftEnd,
        );
        final dateKey = _fmtDate(d);
        final leavePayload = userLeaves[dateKey];
        int leaveMinutes = 0;
        if (leavePayload != null && (leavePayload['authorized'] == true)) {
          leaveMinutes = (leavePayload['minutes'] ?? 0) as int;
        }
        final effective = worked + Duration(minutes: leaveMinutes);
        if (effective > Duration.zero) {
          days += 1;
          workedTotal += effective;
          final overtime = effective - const Duration(hours: 9);
          if (overtime > Duration.zero) overtimeTotal += overtime;
        }
      }
      _totalDays[u.id] = days;
      _totalWorked[u.id] = workedTotal;
      _totalOvertime[u.id] = overtimeTotal;
    }

    setState(() => _loading = false);
  }

  void _clearFilter() {
    setState(() {
      _mode = _ViewMode.daily;
      _selectedDate = DateTime.now();
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _results.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilter());
  }

  DateTimeRange _computeRange() {
    if (_mode == _ViewMode.daily) {
      final d = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
      return DateTimeRange(start: d, end: endOfDay);
    }
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    );
    return DateTimeRange(start: from, end: to);
  }

  Future<void> _editSchedule() async {
    final start = _scheduleStart ?? const TimeOfDay(hour: 9, minute: 0);
    final end = _scheduleEnd ?? const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay s = start;
    TimeOfDay e = end;
    final reqController = TextEditingController(
      text: (_requiredMinutes ~/ 60).toString(),
    );
    final lunchController = TextEditingController(
      text: _lunchMinutes.toString(),
    );
    final snackController = TextEditingController(
      text: _snackMinutes.toString(),
    );

    // prepare editable copy of user shift assignments
    final editedShifts = Map<String, _ShiftView?>.from(_userShiftAssignments);
    // shift times
    TimeOfDay? openingStart = _openingStart;
    TimeOfDay? openingEnd = _openingEnd;
    TimeOfDay? midStart = _midStart;
    TimeOfDay? midEnd = _midEnd;
    TimeOfDay? closingStart = _closingStart;
    TimeOfDay? closingEnd = _closingEnd;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            String computeReqHoursText(TimeOfDay a, TimeOfDay b) {
              final today = DateTime.now();
              var start = DateTime(
                today.year,
                today.month,
                today.day,
                a.hour,
                a.minute,
              );
              var end = DateTime(
                today.year,
                today.month,
                today.day,
                b.hour,
                b.minute,
              );
              if (!end.isAfter(start)) {
                end = end.add(const Duration(days: 1));
              }
              final minutes = end.difference(start).inMinutes;
              final hours = minutes / 60.0;
              return hours.toStringAsFixed(2);
            }

            // initialize controller text to current selection
            reqController.text = computeReqHoursText(s, e);

            return AlertDialog(
              title: Text('Edit Schedule'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Set Store Opening and Closing time',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: s,
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    s = picked;
                                    reqController.text = computeReqHoursText(
                                      s,
                                      e,
                                    );
                                  });
                                }
                              },
                              child: Text('Opening: ${s.format(ctx)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: e,
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    e = picked;
                                    reqController.text = computeReqHoursText(
                                      s,
                                      e,
                                    );
                                  });
                                }
                              },
                              child: Text('Closing: ${e.format(ctx)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reqController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Required hours',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lunchController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Lunch minutes',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: snackController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Snack minutes',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Shift Times',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Opening shift
                      Text('Opening Shift', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      openingStart ??
                                      const TimeOfDay(hour: 7, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    openingStart = picked;
                                  });
                                }
                              },
                              child: Text(
                                openingStart != null
                                    ? 'Start: ${openingStart!.format(ctx)}'
                                    : 'Set Start',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      openingEnd ??
                                      const TimeOfDay(hour: 15, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    openingEnd = picked;
                                  });
                                }
                              },
                              child: Text(
                                openingEnd != null
                                    ? 'End: ${openingEnd!.format(ctx)}'
                                    : 'Set End',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Mid-shift
                      Text('Mid-Shift', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      midStart ??
                                      const TimeOfDay(hour: 10, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    midStart = picked;
                                  });
                                }
                              },
                              child: Text(
                                midStart != null
                                    ? 'Start: ${midStart!.format(ctx)}'
                                    : 'Set Start',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      midEnd ??
                                      const TimeOfDay(hour: 18, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    midEnd = picked;
                                  });
                                }
                              },
                              child: Text(
                                midEnd != null
                                    ? 'End: ${midEnd!.format(ctx)}'
                                    : 'Set End',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Closing shift
                      Text('Closing Shift', style: TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      closingStart ??
                                      const TimeOfDay(hour: 13, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    closingStart = picked;
                                  });
                                }
                              },
                              child: Text(
                                closingStart != null
                                    ? 'Start: ${closingStart!.format(ctx)}'
                                    : 'Set Start',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      closingEnd ??
                                      const TimeOfDay(hour: 21, minute: 0),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    closingEnd = picked;
                                  });
                                }
                              },
                              child: Text(
                                closingEnd != null
                                    ? 'End: ${closingEnd!.format(ctx)}'
                                    : 'Set End',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      // per-user shift assignments
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Assign Shifts',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: Builder(
                          builder: (ctx2) {
                            // collect users similar to build()
                            final userMap = <String, User>{};
                            for (final u in _userService.getUsersByRole(
                              UserRole.cashier,
                            )) {
                              userMap[u.id] = u;
                            }
                            for (final u in _userService.getUsersByRole(
                              UserRole.staff,
                            )) {
                              userMap[u.id] = u;
                            }
                            for (final u in _userService.getUsersByRole(
                              UserRole.salesPromoter,
                            )) {
                              userMap[u.id] = u;
                            }
                            for (final u in _userService.getUsersByRole(
                              UserRole.inventoryClerk,
                            )) {
                              userMap[u.id] = u;
                            }
                            for (final u in _userService.getUsersByRole(
                              UserRole.deliveryReceiver,
                            )) {
                              userMap[u.id] = u;
                            }
                            for (final u in _userService.getUsersByRole(
                              UserRole.manager,
                            )) {
                              userMap[u.id] = u;
                            }
                            final users = userMap.values.toList();
                            if (users.isEmpty) {
                              return const Center(child: Text('No users'));
                            }
                            return ListView.separated(
                              itemCount: users.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 8),
                              itemBuilder: (ctx3, idx) {
                                final u = users[idx];
                                final cur = editedShifts[u.id];
                                return Row(
                                  children: [
                                    Expanded(child: Text(u.name)),
                                    const SizedBox(width: 8),
                                    DropdownButton<_ShiftView?>(
                                      value: cur,
                                      items: [
                                        DropdownMenuItem<_ShiftView?>(
                                          value: null,
                                          child: Text('All'),
                                        ),
                                        DropdownMenuItem<_ShiftView?>(
                                          value: _ShiftView.opening,
                                          child: Text('Opening'),
                                        ),
                                        DropdownMenuItem<_ShiftView?>(
                                          value: _ShiftView.mid,
                                          child: Text('Mid-Shift'),
                                        ),
                                        DropdownMenuItem<_ShiftView?>(
                                          value: _ShiftView.closing,
                                          child: Text('Closing'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setStateDialog(() {
                                          editedShifts[u.id] = v;
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppLocalizations.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppLocalizations.t('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) {
      return;
    }

    final reqHoursDouble =
        double.tryParse(reqController.text) ?? (_requiredMinutes / 60.0);
    final reqHours = reqHoursDouble;
    final lunchMin = int.tryParse(lunchController.text) ?? _lunchMinutes;
    final snackMin = int.tryParse(snackController.text) ?? _snackMinutes;
    setState(() {
      _scheduleStart = s;
      _scheduleEnd = e;
      _requiredMinutes = (reqHours * 60).round();
      _lunchMinutes = lunchMin;
      _snackMinutes = snackMin;
      _openingStart = openingStart;
      _openingEnd = openingEnd;
      _midStart = midStart;
      _midEnd = midEnd;
      _closingStart = closingStart;
      _closingEnd = closingEnd;
    });

    final scheduleMap = {
      'start':
          '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
      'end':
          '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}',
      'requiredMinutes': _requiredMinutes,
      'lunchMinutes': _lunchMinutes,
      'snackMinutes': _snackMinutes,
    };
    // add shift times
    if (openingStart != null) {
      scheduleMap['openingStart'] =
          '${openingStart!.hour.toString().padLeft(2, '0')}:${openingStart!.minute.toString().padLeft(2, '0')}';
    }
    if (openingEnd != null) {
      scheduleMap['openingEnd'] =
          '${openingEnd!.hour.toString().padLeft(2, '0')}:${openingEnd!.minute.toString().padLeft(2, '0')}';
    }
    if (midStart != null) {
      scheduleMap['midStart'] =
          '${midStart!.hour.toString().padLeft(2, '0')}:${midStart!.minute.toString().padLeft(2, '0')}';
    }
    if (midEnd != null) {
      scheduleMap['midEnd'] =
          '${midEnd!.hour.toString().padLeft(2, '0')}:${midEnd!.minute.toString().padLeft(2, '0')}';
    }
    if (closingStart != null) {
      scheduleMap['closingStart'] =
          '${closingStart!.hour.toString().padLeft(2, '0')}:${closingStart!.minute.toString().padLeft(2, '0')}';
    }
    if (closingEnd != null) {
      scheduleMap['closingEnd'] =
          '${closingEnd!.hour.toString().padLeft(2, '0')}:${closingEnd!.minute.toString().padLeft(2, '0')}';
    }
    // persist per-user shift assignments
    String? shiftToString(_ShiftView? v) {
      if (v == null) return 'all';
      switch (v) {
        case _ShiftView.opening:
          return 'opening';
        case _ShiftView.mid:
          return 'mid';
        case _ShiftView.closing:
          return 'closing';
      }
    }

    final Map<String, String> userShiftsOut = {};
    editedShifts.forEach((k, v) {
      final s = shiftToString(v);
      if (s != null) userShiftsOut[k] = s;
    });
    if (userShiftsOut.isNotEmpty) scheduleMap['userShifts'] = userShiftsOut;
    // update persistent in-memory map
    setState(() => _userShiftAssignments.clear());
    setState(() => _userShiftAssignments.addAll(editedShifts));
    await AttendanceService.instance.saveSchedule(scheduleMap);
  }

  Future<void> _pickDate(
    BuildContext ctx,
    DateTime initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _getShiftLabel(String userId) {
    final v = _userShiftAssignments[userId];
    if (v == null) return 'Shift: All';
    switch (v) {
      case _ShiftView.opening:
        return 'Shift: Opening';
      case _ShiftView.mid:
        return 'Shift: Mid-Shift';
      case _ShiftView.closing:
        return 'Shift: Closing';
    }
  }

  Widget _buildShiftBadge(String userId) {
    final v = _userShiftAssignments[userId];
    String label;
    Color color;
    if (v == null) {
      label = 'All';
      color = Colors.blueGrey;
    } else {
      switch (v) {
        case _ShiftView.opening:
          label = 'Opening';
          color = Colors.green;
          break;
        case _ShiftView.mid:
          label = 'Mid-Shift';
          color = Colors.amber;
          break;
        case _ShiftView.closing:
          label = 'Closing';
          color = Colors.red;
          break;
      }
    }
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    // collect users by role and deduplicate by id
    final Map<String, User> userMap = {};
    for (final u in _userService.getUsersByRole(UserRole.cashier)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.staff)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.salesPromoter)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.inventoryClerk)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.deliveryReceiver)) {
      userMap[u.id] = u;
    }
    for (final u in _userService.getUsersByRole(UserRole.manager)) {
      userMap[u.id] = u;
    }

    // apply shift filter: if _selectedShift is null show all; if user assigned null (All) show in any filter
    final users = userMap.values.where((u) {
      if (_selectedShift == null) return true;
      final assigned = _userShiftAssignments[u.id];
      if (assigned == null) return true;
      return assigned == _selectedShift;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('manage_attendance'))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_ShiftView?>(
                    segments: const [
                      ButtonSegment(
                        value: null,
                        label: Text('All Shifts'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                      ButtonSegment(
                        value: _ShiftView.opening,
                        label: Text('Opening'),
                        icon: Icon(Icons.wb_sunny),
                      ),
                      ButtonSegment(
                        value: _ShiftView.mid,
                        label: Text('Mid-Shift'),
                        icon: Icon(Icons.wb_twilight),
                      ),
                      ButtonSegment(
                        value: _ShiftView.closing,
                        label: Text('Closing'),
                        icon: Icon(Icons.nightlight),
                      ),
                    ],
                    selected: {_selectedShift},
                    onSelectionChanged: (Set<_ShiftView?> selected) {
                      setState(() {
                        _selectedShift = selected.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t('manage_attendance'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('Daily'),
                                    selected: _mode == _ViewMode.daily,
                                    onSelected: (v) =>
                                        setState(() => _mode = _ViewMode.daily),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Range'),
                                    selected: _mode == _ViewMode.range,
                                    onSelected: (v) =>
                                        setState(() => _mode = _ViewMode.range),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _applyFilter,
                                    icon: const Icon(Icons.search),
                                    label: Text(AppLocalizations.t('apply')),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: _clearFilter,
                                    icon: const Icon(Icons.clear),
                                    label: Text(AppLocalizations.t('clear')),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Schedule: '),
                                  if (_scheduleStart != null &&
                                      _scheduleEnd != null)
                                    Text(
                                      '${_scheduleStart!.format(context)} - ${_scheduleEnd!.format(context)}',
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Req: ${(_requiredMinutes / 60).toStringAsFixed(1)}h',
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _editSchedule,
                                    icon: const Icon(Icons.schedule),
                                    label: const Text('Edit Schedule'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_mode == _ViewMode.daily)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickDate(
                                          context,
                                          _selectedDate,
                                          (d) =>
                                              setState(() => _selectedDate = d),
                                        ),
                                        icon: const Icon(Icons.calendar_today),
                                        label: Text(
                                          'Date: ${_fmtDate(_selectedDate)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickDate(
                                          context,
                                          _fromDate,
                                          (d) => setState(() => _fromDate = d),
                                        ),
                                        icon: const Icon(Icons.calendar_today),
                                        label: Text(
                                          'From: ${_fmtDate(_fromDate)}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickDate(
                                          context,
                                          _toDate,
                                          (d) => setState(() => _toDate = d),
                                        ),
                                        icon: const Icon(Icons.calendar_today),
                                        label: Text(
                                          'To:   ${_fmtDate(_toDate)}',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : users.isEmpty
                            ? Center(
                                child: Text(AppLocalizations.t('no_users_yet')),
                              )
                            : ListView.separated(
                                itemCount: users.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  final entries = _results[user.id] ?? [];
                                  final leaves = _leaves[user.id] ?? {};
                                  return Card(
                                    child: ExpansionTile(
                                      title: Text(user.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user.email),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _buildShiftBadge(user.id),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getShiftLabel(user.id),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Days: ${_totalDays[user.id] ?? 0} • Hours: ${_formatDurationShort(_totalWorked[user.id] ?? Duration.zero)} • OT: ${_formatDurationShort(_totalOvertime[user.id] ?? Duration.zero)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      childrenPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      children: [
                                        entries.isEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Text(
                                                  AppLocalizations.t(
                                                    'no_records',
                                                  ),
                                                ),
                                              )
                                            : ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxHeight: 300,
                                                    ),
                                                child: _buildPerDayView(
                                                  user.id,
                                                  entries,
                                                  leaves,
                                                ),
                                              ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () async {
                                                final ok = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Confirm',
                                                    ),
                                                    content: const Text(
                                                      'Clear all attendance records for this user?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(false),
                                                        child: const Text('No'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'Yes',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (ok == true) {
                                                  await AttendanceService
                                                      .instance
                                                      .clear(user.id);
                                                  await _applyFilter();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              label: Text(
                                                AppLocalizations.t(
                                                  'clear_records',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  // Break computation removed — admin records authorized breaks/leaves manually.

  Duration _computeWorkedDuration(
    List<AttendanceEntry> list,
    DateTime day, {
    DateTime? shiftStart,
    DateTime? shiftEnd,
  }) {
    if (list.isEmpty) return Duration.zero;
    final defaultStart = DateTime(day.year, day.month, day.day);
    final defaultEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final startOfDay = shiftStart ?? defaultStart;
    final endOfDay = shiftEnd ?? defaultEnd;

    // Ensure entries are sorted
    final entries = List<AttendanceEntry>.from(list)
      ..sort((a, b) => a.time.compareTo(b.time));

    Duration total = Duration.zero;
    DateTime? currentIn;

    for (final e in entries) {
      final t = e.time;
      // cap timestamps to day bounds
      final capped = t.isBefore(startOfDay)
          ? startOfDay
          : (t.isAfter(endOfDay) ? endOfDay : t);

      if (e.type == 'IN') {
        // If already 'IN' and another IN occurs, treat it as implicit OUT for the previous IN
        if (currentIn == null) {
          currentIn = capped;
        } else {
          if (capped.isAfter(currentIn)) {
            total += capped.difference(currentIn);
          }
          // Start new IN session (consecutive IN handling)
          currentIn = capped;
        }
      } else if (e.type == 'OUT' || e.type == 'LUNCH' || e.type == 'SNACK') {
        if (currentIn != null) {
          // add interval from currentIn to this capped time
          if (capped.isAfter(currentIn)) {
            total += capped.difference(currentIn);
          }
          currentIn = null;
        }
        // else ignore unmatched OUT
      }
    }

    // If there's an open IN at end of the window, close it at endOfDay/shift end.
    // For the current day, close at 'now' if earlier than endOfDay to avoid counting until midnight.
    if (currentIn != null) {
      final now = DateTime.now();
      final isToday =
          defaultStart.year == now.year &&
          defaultStart.month == now.month &&
          defaultStart.day == now.day;
      DateTime closeAt;
      if (isToday && now.isBefore(endOfDay)) {
        closeAt = now.isAfter(currentIn) ? now : currentIn;
      } else {
        closeAt = endOfDay;
      }
      if (closeAt.isAfter(currentIn)) total += closeAt.difference(currentIn);
    }

    return total;
  }

  String _formatDurationShort(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h}h ${m}m ${s}s';
  }

  String _friendlyLabel(String type) {
    switch (type) {
      // Original line
      case 'LUNCH':
        return 'LB';
      case 'SNACK':
        return 'SB';
      case 'OUT':
        return 'OUT';
      case 'IN':
      default:
        return 'IN';
    }
  }

  String _remarkForDay(
    String userId,
    Duration worked,
    List<AttendanceEntry> list,
    DateTime day,
    Map<String, dynamic>? leavePayload,
  ) {
    final required = Duration(minutes: _requiredMinutes);
    if (list.isEmpty) {
      if (leavePayload != null && (leavePayload['authorized'] == true)) {
        return 'Excuse';
      }
      return 'Absent';
    }

    int leaveMinutes = 0;
    if (leavePayload != null && (leavePayload['authorized'] == true)) {
      leaveMinutes = (leavePayload['minutes'] ?? 0) as int;
    }
    final effectiveWorked = worked + Duration(minutes: leaveMinutes);

    if (effectiveWorked >= required) {
      if (effectiveWorked > required) return 'Overtime';
      return 'Completed';
    }

    if (leavePayload != null && (leavePayload['authorized'] == true)) {
      return 'Excuse';
    }

    return 'Time Theft';
  }

  Widget _buildPerDayView(
    String userId,
    List<AttendanceEntry> entries,
    Map<String, dynamic> leaves,
  ) {
    final range = _computeRange();
    final days = <DateTime>[];
    for (
      var d = range.start;
      !d.isAfter(range.end);
      d = d.add(const Duration(days: 1))
    ) {
      days.add(DateTime(d.year, d.month, d.day));
    }

    final perDay = <DateTime, List<AttendanceEntry>>{};
    for (final d in days) {
      // if a shift is selected, compute its bounds for this day and filter entries
      DateTime? shiftStart;
      DateTime? shiftEnd;
      if (_selectedShift != null &&
          _scheduleStart != null &&
          _scheduleEnd != null) {
        final s = DateTime(
          d.year,
          d.month,
          d.day,
          _scheduleStart!.hour,
          _scheduleStart!.minute,
        );
        final eTime = DateTime(
          d.year,
          d.month,
          d.day,
          _scheduleEnd!.hour,
          _scheduleEnd!.minute,
        );
        final totalMinutes = eTime.difference(s).inMinutes;
        if (totalMinutes > 0) {
          final part = totalMinutes ~/ 3;
          if (_selectedShift == _ShiftView.opening) {
            shiftStart = s;
            shiftEnd = s.add(Duration(minutes: part));
          } else if (_selectedShift == _ShiftView.mid) {
            shiftStart = s.add(Duration(minutes: part));
            shiftEnd = s.add(Duration(minutes: part * 2));
          } else {
            shiftStart = s.add(Duration(minutes: part * 2));
            shiftEnd = eTime;
          }
        }
      }

      perDay[d] =
          entries
              .where(
                (e) =>
                    e.time.year == d.year &&
                    e.time.month == d.month &&
                    e.time.day == d.day &&
                    (shiftStart == null ||
                        (e.time.isAfter(
                              shiftStart.subtract(
                                const Duration(milliseconds: 1),
                              ),
                            ) &&
                            e.time.isBefore(
                              shiftEnd!.add(const Duration(milliseconds: 1)),
                            ))),
              )
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));
    }

    // compute totals across the range
    int totalDaysAttended = 0;
    Duration totalWorked = Duration.zero;
    Duration totalOvertime = Duration.zero;
    for (final day in days) {
      final list = perDay[day] ?? [];
      final worked = _computeWorkedDuration(list, day);
      final dateKey = _fmtDate(day);
      final leavePayload = leaves[dateKey];
      int leaveMinutes = 0;
      if (leavePayload != null && (leavePayload['authorized'] == true)) {
        leaveMinutes = (leavePayload['minutes'] ?? 0) as int;
      }
      final effective = worked + Duration(minutes: leaveMinutes);
      if (effective > Duration.zero) {
        totalDaysAttended += 1;
        totalWorked += effective;
        final overtime = effective - const Duration(hours: 9);
        if (overtime > Duration.zero) totalOvertime += overtime;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
          child: Row(
            children: [
              Text('Total days: $totalDaysAttended'),
              const SizedBox(width: 12),
              Text('Total hours: ${_formatDurationShort(totalWorked)}'),
              const SizedBox(width: 12),
              Text('Total OT: ${_formatDurationShort(totalOvertime)}'),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: days.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final day = days[i];
              final list = perDay[day] ?? [];
              final worked = _computeWorkedDuration(list, day);
              final dateKey = _fmtDate(day);
              final leavePayload = leaves[dateKey];
              final remark = _remarkForDay(
                userId,
                worked,
                list,
                day,
                leavePayload,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _fmtDate(day),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDurationShort(worked)),
                        const SizedBox(width: 12),
                        if (leavePayload != null)
                          Text(
                            'Recorded break: ${leavePayload['minutes'] ?? 0} m',
                          ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: 'Delete day records',
                          onPressed: () async {
                            final confirm =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(AppLocalizations.t('confirm')),
                                    content: Text(
                                      'Delete attendance records for ${_fmtDate(day)}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          AppLocalizations.t('cancel'),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(
                                          AppLocalizations.t('delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (!confirm) return;
                            await AttendanceService.instance
                                .deleteEntriesForDate(userId, day);
                            await _applyFilter();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.t('deleted')),
                              ),
                            );
                          },
                        ),
                        Chip(label: Text(remark)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(AppLocalizations.t('no_records')),
                      )
                    else
                      Column(
                        children: list.map((e) {
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: e.type == 'IN'
                                  ? Colors.green
                                  : Colors.red,
                              child: Text(
                                _friendlyLabel(e.type),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(_formatTimestamp(e.time)),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (leavePayload != null) ...[
                          TextButton.icon(
                            onPressed: () async {
                              // Edit existing leave
                              final minutes =
                                  (leavePayload['minutes'] ?? 0) as int;
                              final reason =
                                  (leavePayload['reason'] ?? '') as String;
                              final authorized =
                                  (leavePayload['authorized'] == true);
                              final res =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (ctx) {
                                      final minCtrl = TextEditingController(
                                        text: minutes.toString(),
                                      );
                                      final reasonCtrl = TextEditingController(
                                        text: reason,
                                      );
                                      bool auth = authorized;
                                      return AlertDialog(
                                        title: const Text(
                                          'Edit Authorized Break/Leave',
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CheckboxListTile(
                                              value: auth,
                                              onChanged: (v) {
                                                auth = v ?? false;
                                              },
                                              title: const Text('Authorized'),
                                            ),
                                            TextField(
                                              controller: minCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Minutes',
                                              ),
                                            ),
                                            TextField(
                                              controller: reasonCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Reason',
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              final m =
                                                  int.tryParse(minCtrl.text) ??
                                                  0;
                                              Navigator.of(ctx).pop({
                                                'authorized': auth,
                                                'minutes': m,
                                                'reason': reasonCtrl.text,
                                              });
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                              if (res != null) {
                                await AttendanceService.instance.saveLeave(
                                  userId,
                                  dateKey,
                                  res,
                                );
                                await _applyFilter();
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Record'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () async {
                              await AttendanceService.instance.removeLeave(
                                userId,
                                dateKey,
                              );
                              await _applyFilter();
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Remove Record'),
                          ),
                        ] else ...[
                          TextButton.icon(
                            onPressed: () async {
                              final res =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (ctx) {
                                      final minCtrl = TextEditingController(
                                        text:
                                            '${_lunchMinutes + _snackMinutes}',
                                      );
                                      final reasonCtrl = TextEditingController(
                                        text: 'Admin Recorded',
                                      );
                                      bool auth = true;
                                      return AlertDialog(
                                        title: const Text(
                                          'Record Authorized Break/Leave',
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CheckboxListTile(
                                              value: auth,
                                              onChanged: (v) {
                                                auth = v ?? false;
                                              },
                                              title: const Text('Authorized'),
                                            ),
                                            TextField(
                                              controller: minCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Minutes',
                                              ),
                                            ),
                                            TextField(
                                              controller: reasonCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Reason',
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              final m =
                                                  int.tryParse(minCtrl.text) ??
                                                  0;
                                              Navigator.of(ctx).pop({
                                                'authorized': auth,
                                                'minutes': m,
                                                'reason': reasonCtrl.text,
                                              });
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                              if (res != null) {
                                await AttendanceService.instance.saveLeave(
                                  userId,
                                  dateKey,
                                  res,
                                );
                                await _applyFilter();
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Record Leave/Break'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
