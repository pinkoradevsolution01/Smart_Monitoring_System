import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/payroll.dart';
import '../../models/user.dart';
import '../../services/payroll_service.dart';
import '../../utils/app_localizations.dart';
import '../../services/user_service.dart';
import '../../services/attendance_service.dart';
import '../../services/bulk_payroll_service.dart';

class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen> {
  final _service = PayrollService.instance;
  List<Payroll> _payrolls = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'unpaid', 'paid'

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.getAllPayrolls();
    setState(() {
      _payrolls = rows;
      _loading = false;
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    final employeeNameCtl = TextEditingController();
    final employeeIdCtl = TextEditingController();
    // income controllers
    final regularCtl = TextEditingController(text: '0');
    final basicRateCtl = TextEditingController(text: '0');
    final overtimeCtl = TextEditingController(text: '0');
    final nightDiffCtl = TextEditingController(text: '0');
    final specHolidayCtl = TextEditingController(text: '0');
    final colaCtl = TextEditingController(text: '0');
    final thirteenthCtl = TextEditingController(text: '0');
    final adjustmentCtl = TextEditingController(text: '0');
    // allowances
    final mealCtl = TextEditingController(text: '0');
    final lodgingCtl = TextEditingController(text: '0');
    final transpoCtl = TextEditingController(text: '0');
    final otherAllowCtl = TextEditingController(text: '0');
    // deductible items (absent/late/undertime)
    final absentCtl = TextEditingController(text: '0');
    final lateCtl = TextEditingController(text: '0');
    final undertimeCtl = TextEditingController(text: '0');
    // government deductions
    final sssCtl = TextEditingController(text: '0');
    final hdmfCtl = TextEditingController(text: '0');
    final phiCtl = TextEditingController(text: '0');
    final wtaxCtl = TextEditingController(text: '0');
    // other deductions
    final otherInsCtl = TextEditingController(text: '0');
    final otherVolCtl = TextEditingController(text: '0');
    final otherHmoCtl = TextEditingController(text: '0');
    final otherOtherCtl = TextEditingController(text: '0');
    // loan
    final loanCtl = TextEditingController(text: '0');
    int month = DateTime.now().month;
    int year = DateTime.now().year;
    DateTime fromDate = DateTime(year, month, 1);
    DateTime toDate = DateTime(
      year,
      month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    // Use a Map to persist attendance data across rebuilds
    final attendanceData = {'totalDays': 0, 'totalHours': Duration.zero};

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            double parseDouble(TextEditingController c) =>
                double.tryParse(c.text) ?? 0.0;

            Future<void> recomputeAttendance(String userId) async {
              final start = DateTime(
                fromDate.year,
                fromDate.month,
                fromDate.day,
              );
              final end = DateTime(
                toDate.year,
                toDate.month,
                toDate.day,
                23,
                59,
                59,
              );

              // debug only
              if (kDebugMode) {
                debugPrint(
                  'DEBUG: Recomputing for user $userId from $start to $end',
                );
              }

              final entries = await AttendanceService.instance.loadEntries(
                userId,
              );
              final leaves = await AttendanceService.instance.loadLeaves(
                userId,
              );

              // Also load archived entries (for past dates)
              final archive = await AttendanceService.instance.loadArchive(
                userId,
              );
              // Merge entries and archive with deduplication (by time+type)
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

              // debug only
              if (kDebugMode) {
                debugPrint(
                  'DEBUG: Loaded ${entries.length} entries, ${leaves.length} leaves',
                );
              }
              if (kDebugMode) {
                for (var e in allEntries) {
                  debugPrint(
                    'DEBUG ENTRY: ${e.type} at ${e.time.toIso8601String()}',
                  );
                }
              }

              int days = 0;
              Duration hours = Duration.zero;
              for (
                var d = start;
                !d.isAfter(end);
                d = d.add(const Duration(days: 1))
              ) {
                final dayList =
                    allEntries
                        .where(
                          (e) =>
                              e.time.year == d.year &&
                              e.time.month == d.month &&
                              e.time.day == d.day,
                        )
                        .toList()
                      ..sort((a, b) => a.time.compareTo(b.time));
                // debug only
                if (kDebugMode) {
                  debugPrint(
                    'DEBUG DAY: ${d.toIso8601String()} -> ${dayList.length} entries',
                  );
                }
                if (kDebugMode) {
                  for (var e in dayList) {
                    debugPrint(
                      'DEBUG DAY ENTRY: ${e.type} at ${e.time.toIso8601String()}',
                    );
                  }
                }

                // Sum IN->OUT segments (treat LUNCH/SNACK as closers)
                Duration worked = Duration.zero;
                final startOfDay = DateTime(d.year, d.month, d.day);
                final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
                final entriesSorted = List<AttendanceEntry>.from(dayList)
                  ..sort((a, b) => a.time.compareTo(b.time));
                DateTime? currentIn;
                final intervals = <Map<String, DateTime>>[];
                for (final e in entriesSorted) {
                  final t = e.time;
                  final capped = t.isBefore(startOfDay)
                      ? startOfDay
                      : (t.isAfter(endOfDay) ? endOfDay : t);
                  if (e.type == 'IN') {
                    if (currentIn == null) {
                      currentIn = capped;
                    } else {
                      // consecutive IN -> treat as implicit OUT for previous
                      if (capped.isAfter(currentIn)) {
                        worked += capped.difference(currentIn);
                        intervals.add({'start': currentIn, 'end': capped});
                      }
                      currentIn = null;
                    }
                  } else if (e.type == 'OUT' ||
                      e.type == 'LUNCH' ||
                      e.type == 'SNACK') {
                    if (currentIn != null) {
                      if (capped.isAfter(currentIn)) {
                        worked += capped.difference(currentIn);
                        intervals.add({'start': currentIn, 'end': capped});
                      }
                      currentIn = null;
                    }
                  }
                }
                if (currentIn != null) {
                  // For the current day, close at now instead of endOfDay
                  final now = DateTime.now();
                  final isToday =
                      startOfDay.year == now.year &&
                      startOfDay.month == now.month &&
                      startOfDay.day == now.day;
                  final closeAt = isToday
                      ? (now.isAfter(currentIn) ? now : currentIn)
                      : endOfDay;
                  if (closeAt.isAfter(currentIn)) {
                    worked += closeAt.difference(currentIn);
                    intervals.add({'start': currentIn, 'end': closeAt});
                  }
                }
                // debug long days
                if (kDebugMode && worked > const Duration(hours: 10)) {
                  debugPrint(
                    'PAYROLL DEBUG: Day ${_fmtDate(d)} has worked ${worked.inHours}h ${worked.inMinutes.remainder(60)}m',
                  );
                  for (final it in intervals) {
                    debugPrint(
                      '  interval: ${it['start']?.toIso8601String()} -> ${it['end']?.toIso8601String()}',
                    );
                  }
                }

                final dateKey =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                final leavePayload = leaves[dateKey];
                int leaveMinutes = 0;
                if (leavePayload != null &&
                    (leavePayload['authorized'] == true)) {
                  leaveMinutes = (leavePayload['minutes'] ?? 0) as int;
                }
                final effective = worked + Duration(minutes: leaveMinutes);
                if (effective > Duration.zero) {
                  days += 1;
                  hours += effective;
                }
              }

              attendanceData['totalDays'] = days;
              attendanceData['totalHours'] = hours;

              // debug only
              if (kDebugMode) {
                debugPrint(
                  'DEBUG: Computed $days days, ${hours.inHours}h ${hours.inMinutes % 60}m',
                );
              }
              if (kDebugMode) {
                debugPrint(
                  'DEBUG: attendanceData now: ${attendanceData['totalDays']} days',
                );
              }

              final hourlyRate = double.tryParse(basicRateCtl.text) ?? 0.0;
              // use seconds for payroll calculation (keep seconds precision)
              final totalHoursDecimal = hours.inSeconds / 3600.0;
              final computed = totalHoursDecimal * hourlyRate;
              regularCtl.text = computed.toStringAsFixed(2);

              if (kDebugMode) {
                debugPrint('DEBUG: Calling setState');
              }
              setState(() {});
              if (kDebugMode) {
                debugPrint('DEBUG: setState complete');
              }
            }

            double gross = 0.0;
            gross += parseDouble(regularCtl);
            // basic rate is stored separately (per-day). Not automatically added to gross here.
            gross += parseDouble(overtimeCtl);
            gross += parseDouble(nightDiffCtl);
            gross += parseDouble(specHolidayCtl);
            gross += parseDouble(colaCtl);
            gross += parseDouble(thirteenthCtl);
            gross += parseDouble(adjustmentCtl);
            gross +=
                parseDouble(mealCtl) +
                parseDouble(lodgingCtl) +
                parseDouble(transpoCtl) +
                parseDouble(otherAllowCtl);

            double deductions = 0.0;
            deductions +=
                parseDouble(absentCtl) +
                parseDouble(lateCtl) +
                parseDouble(undertimeCtl);
            deductions +=
                parseDouble(sssCtl) +
                parseDouble(hdmfCtl) +
                parseDouble(phiCtl) +
                parseDouble(wtaxCtl);
            deductions +=
                parseDouble(otherInsCtl) +
                parseDouble(otherVolCtl) +
                parseDouble(otherHmoCtl) +
                parseDouble(otherOtherCtl);
            deductions += parseDouble(loanCtl);

            final net = gross - deductions;

            return AlertDialog(
              title: Text(AppLocalizations.t('manage_payroll')),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select employee from dropdown so we can compute regular pay
                      DropdownButtonFormField<String>(
                        initialValue: null,
                        items: UserService().users
                            .where(
                              (u) => u.isActive && u.role != UserRole.owner,
                            )
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(u.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          final u = UserService().users.firstWhere(
                            (x) => x.id == val,
                          );
                          employeeNameCtl.text = u.name;
                          employeeIdCtl.text = u.id;
                          await recomputeAttendance(u.id);
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.t('name'),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      // Employee ID is set via the dropdown selection
                      TextFormField(
                        controller: employeeIdCtl,
                        decoration: InputDecoration(labelText: 'Employee ID'),
                        readOnly: true,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Date Range'),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: fromDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  fromDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                  final userId = employeeIdCtl.text.trim();
                                  if (userId.isNotEmpty) {
                                    await recomputeAttendance(userId);
                                  } else {
                                    setState(() {});
                                  }
                                }
                              },
                              child: Text(DateFormat.yMd().format(fromDate)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete attendance records for the selected range
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text(
                                'Delete Records in Range',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () async {
                                final userId = employeeIdCtl.text.trim();
                                if (userId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.t(
                                          'select_employee_first',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final confirm =
                                    await showDialog<bool>(
                                      context: ctx,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          AppLocalizations.t('confirm'),
                                        ),
                                        content: Text(
                                          '${AppLocalizations.t('delete_records_confirm')} ${DateFormat.yMd().format(fromDate)} — ${DateFormat.yMd().format(toDate)}',
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
                                // perform delete
                                await AttendanceService.instance
                                    .deleteEntriesForRange(
                                      userId,
                                      fromDate,
                                      toDate,
                                    );
                                // recompute
                                await recomputeAttendance(userId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.t('deleted'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: toDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  toDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    23,
                                    59,
                                    59,
                                  );
                                  final userId = employeeIdCtl.text.trim();
                                  if (userId.isNotEmpty) {
                                    await recomputeAttendance(userId);
                                  } else {
                                    setState(() {});
                                  }
                                }
                              },
                              child: Text(DateFormat.yMd().format(toDate)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Display attendance totals
                      if (employeeIdCtl.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Attendance Summary',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Days Attended:'),
                                  Text(
                                    '${attendanceData['totalDays']} days',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Hours Worked:'),
                                  Text(
                                    '${(attendanceData['totalHours'] as Duration).inHours}h ${(attendanceData['totalHours'] as Duration).inMinutes.remainder(60)}m ${(attendanceData['totalHours'] as Duration).inSeconds.remainder(60)}s',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Income'),
                      ),
                      const SizedBox(height: 8),
                      _numField(
                        'Regular Pay',
                        regularCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Basic Rate (per hour)',
                        basicRateCtl,
                        onChanged: (v) async {
                          // if employee already selected, recompute regular pay
                          final userId = employeeIdCtl.text.trim();
                          if (userId.isNotEmpty) {
                            // attendanceData is computed elsewhere (recomputeAttendance),
                            // reuse the stored total hours to compute regular pay.
                            final hourlyRate =
                                double.tryParse(basicRateCtl.text) ?? 0.0;
                            final totalHours =
                                (attendanceData['totalHours'] as Duration);
                            // use seconds precision
                            final totalHoursDecimal =
                                totalHours.inSeconds / 3600.0;
                            final computed = totalHoursDecimal * hourlyRate;
                            regularCtl.text = computed.toStringAsFixed(2);
                            setState(() {});
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                      _numField(
                        'Overtime Amount',
                        overtimeCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Night Differential',
                        nightDiffCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Special Holiday',
                        specHolidayCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'COLA',
                        colaCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        '13th Month',
                        thirteenthCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Adjustment',
                        adjustmentCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Allowances'),
                      ),
                      _numField(
                        'Meal Allowance',
                        mealCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Lodging Allowance',
                        lodgingCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Transpo Allowance',
                        transpoCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Other Allowance',
                        otherAllowCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Deductions (adjustments)'),
                      ),
                      _numField(
                        'Absent Amount',
                        absentCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Late Amount',
                        lateCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Undertime Amount',
                        undertimeCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Govt. Deductions'),
                      ),
                      _numField(
                        'SSS',
                        sssCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'HDMF',
                        hdmfCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'PHI',
                        phiCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'WTax',
                        wtaxCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Other Deductions'),
                      ),
                      _numField(
                        'Insurance',
                        otherInsCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Voluntary',
                        otherVolCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'HMO',
                        otherHmoCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      _numField(
                        'Other',
                        otherOtherCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Loan Deductions'),
                      ),
                      _numField(
                        'Loan Total',
                        loanCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Pay'),
                          Text(AppCurrency.peso(gross)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Deductions'),
                          Text(AppCurrency.peso(deductions)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Pay'),
                          Text(
                            AppCurrency.peso(net),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final grossVal = gross;
                    final deductionsVal = deductions;
                    final netVal = net;
                    final p = Payroll(
                      employeeId: employeeIdCtl.text.trim(),
                      employeeName: employeeNameCtl.text.trim(),
                      year: year,
                      month: month,
                      basicRatePerDay: parseDouble(basicRateCtl),
                      regularPay: parseDouble(regularCtl),
                      overtimeHours: 0,
                      overtimePay: parseDouble(overtimeCtl),
                      nightDiff: parseDouble(nightDiffCtl),
                      specHoliday: parseDouble(specHolidayCtl),
                      leaveAmount: 0,
                      absentAmount: parseDouble(absentCtl),
                      lateAmount: parseDouble(lateCtl),
                      undertimeAmount: parseDouble(undertimeCtl),
                      cola: parseDouble(colaCtl),
                      thirteenth: parseDouble(thirteenthCtl),
                      adjustment: parseDouble(adjustmentCtl),
                      allowanceMeal: parseDouble(mealCtl),
                      allowanceLodging: parseDouble(lodgingCtl),
                      allowanceTranspo: parseDouble(transpoCtl),
                      allowanceOther: parseDouble(otherAllowCtl),
                      sss: parseDouble(sssCtl),
                      hdmf: parseDouble(hdmfCtl),
                      phi: parseDouble(phiCtl),
                      wtax: parseDouble(wtaxCtl),
                      otherInsurance: parseDouble(otherInsCtl),
                      otherVoluntary: parseDouble(otherVolCtl),
                      otherHmo: parseDouble(otherHmoCtl),
                      otherOther: parseDouble(otherOtherCtl),
                      loanDeductions: parseDouble(loanCtl),
                      grossPay: grossVal,
                      totalDeductions: deductionsVal,
                      netPay: netVal,
                      paid: false,
                      createdAt: DateTime.now().toIso8601String(),
                    );
                    await _service.insertPayroll(p);
                    Navigator.pop(ctx);
                    await _load();
                    // Generate and show PDF payslip
                    await _generatePayslipPDF(p);
                  },
                  child: Text(AppLocalizations.t('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePayslipPDF(Payroll p) async {
    final pdf = pw.Document();
    final monthName = DateFormat.MMMM().format(DateTime(p.year, p.month));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 500,
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Header - Centered
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                      color: PdfColors.grey200,
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'PAYSLIP',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$monthName ${p.year}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  // Employee Info - Centered Box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Employee Name:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            pw.Text(
                              p.employeeName,
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Employee ID:',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            pw.Text(
                              p.employeeId,
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Income Section
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    child: pw.Text(
                      'INCOME',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow('Regular Pay', p.regularPay),
                  _buildPdfRow('Overtime Pay', p.overtimePay),
                  _buildPdfRow('Night Differential', p.nightDiff),
                  _buildPdfRow('Special Holiday', p.specHoliday),
                  _buildPdfRow('COLA', p.cola),
                  _buildPdfRow('13th Month', p.thirteenth),
                  _buildPdfRow('Adjustment', p.adjustment),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    child: pw.Text(
                      'ALLOWANCES',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow('Meal Allowance', p.allowanceMeal),
                  _buildPdfRow('Lodging Allowance', p.allowanceLodging),
                  _buildPdfRow('Transportation', p.allowanceTranspo),
                  _buildPdfRow('Other Allowance', p.allowanceOther),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: _buildPdfRow(
                      'GROSS PAY',
                      p.grossPay,
                      isBold: true,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  // Deductions Section
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    child: pw.Text(
                      'DEDUCTIONS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow('Absent', p.absentAmount),
                  _buildPdfRow('Late', p.lateAmount),
                  _buildPdfRow('Undertime', p.undertimeAmount),
                  _buildPdfRow('SSS', p.sss),
                  _buildPdfRow('HDMF', p.hdmf),
                  _buildPdfRow('PhilHealth', p.phi),
                  _buildPdfRow('Withholding Tax', p.wtax),
                  _buildPdfRow('Insurance', p.otherInsurance),
                  _buildPdfRow('Voluntary', p.otherVoluntary),
                  _buildPdfRow('HMO', p.otherHmo),
                  _buildPdfRow('Other Deductions', p.otherOther),
                  _buildPdfRow('Loan', p.loanDeductions),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(color: PdfColors.red200),
                    ),
                    child: _buildPdfRow(
                      'TOTAL DEDUCTIONS',
                      p.totalDeductions,
                      isBold: true,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(
                        color: PdfColors.green400,
                        width: 2,
                      ),
                    ),
                    child: _buildPdfRow(
                      'NET PAY',
                      p.netPay,
                      isBold: true,
                      fontSize: 18,
                    ),
                  ),
                  pw.Spacer(),
                  pw.SizedBox(height: 24),
                  pw.Center(
                    child: pw.Text(
                      'Generated on ${DateFormat.yMd().add_jm().format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Show PDF preview/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Payslip_${p.employeeName}_${monthName}_${p.year}.pdf',
    );
  }

  pw.Widget _buildPdfRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
          pw.Text(
            AppCurrency.peso(amount),
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(
    String label,
    TextEditingController ctrl, {
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _showDetailsDialog(Payroll p) async {
    final monthName = DateFormat.MMMM().format(DateTime(p.year, p.month));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payroll Details'),
        contentPadding: const EdgeInsets.all(0),
        content: SizedBox(
          width: 595, // A4 width in points (210mm)
          height: 842, // A4 height in points (297mm)
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PAYSLIP',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$monthName ${p.year}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Employee Info Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow('Employee Name', p.employeeName),
                      _detailRow('Employee ID', p.employeeId),
                      _detailRow('Period', '$monthName ${p.year}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Income Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'INCOME',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Basic Rate/Day',
                  AppCurrency.peso(p.basicRatePerDay),
                ),
                _detailRow('Regular Pay', AppCurrency.peso(p.regularPay)),
                _detailRow('Overtime Pay', AppCurrency.peso(p.overtimePay)),
                _detailRow('Night Differential', AppCurrency.peso(p.nightDiff)),
                _detailRow('Special Holiday', AppCurrency.peso(p.specHoliday)),
                _detailRow('COLA', AppCurrency.peso(p.cola)),
                _detailRow('13th Month', AppCurrency.peso(p.thirteenth)),
                _detailRow('Adjustment', AppCurrency.peso(p.adjustment)),
                const SizedBox(height: 12),

                // Allowances Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ALLOWANCES',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow('Meal', AppCurrency.peso(p.allowanceMeal)),
                _detailRow('Lodging', AppCurrency.peso(p.allowanceLodging)),
                _detailRow(
                  'Transportation',
                  AppCurrency.peso(p.allowanceTranspo),
                ),
                _detailRow('Other', AppCurrency.peso(p.allowanceOther)),
                const SizedBox(height: 12),

                // Gross Pay Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _detailRow(
                    'GROSS PAY',
                    AppCurrency.peso(p.grossPay),
                    isBold: true,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Deductions Section
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEDUCTIONS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow('Absent', AppCurrency.peso(p.absentAmount)),
                _detailRow('Late', AppCurrency.peso(p.lateAmount)),
                _detailRow('Undertime', AppCurrency.peso(p.undertimeAmount)),
                _detailRow('SSS', AppCurrency.peso(p.sss)),
                _detailRow('HDMF', AppCurrency.peso(p.hdmf)),
                _detailRow('PhilHealth', AppCurrency.peso(p.phi)),
                _detailRow('Withholding Tax', AppCurrency.peso(p.wtax)),
                _detailRow('Insurance', AppCurrency.peso(p.otherInsurance)),
                _detailRow('Voluntary', AppCurrency.peso(p.otherVoluntary)),
                _detailRow('HMO', AppCurrency.peso(p.otherHmo)),
                _detailRow('Other Deductions', AppCurrency.peso(p.otherOther)),
                _detailRow('Loan', AppCurrency.peso(p.loanDeductions)),
                const SizedBox(height: 12),

                // Total Deductions Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _detailRow(
                    'TOTAL DEDUCTIONS',
                    AppCurrency.peso(p.totalDeductions),
                    isBold: true,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),

                // Net Pay Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade400, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _detailRow(
                    'NET PAY',
                    AppCurrency.peso(p.netPay),
                    isBold: true,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),

                // Footer
                Center(
                  child: Text(
                    'Generated on ${DateFormat.yMd().add_jm().format(DateTime.now())}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('close')),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Payroll p) {
    final monthName = DateFormat.MMMM().format(DateTime(p.year, p.month));
    final currency = NumberFormat.simpleCurrency(
      name: 'PHP',
      decimalDigits: 2,
      locale: 'en_PH',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _showDetailsDialog(p),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    p.employeeName.isNotEmpty
                        ? p.employeeName
                              .split(' ')
                              .map((s) => s.isNotEmpty ? s[0] : '')
                              .take(2)
                              .join()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.employeeName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '$monthName ${p.year} • ${p.employeeId}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          Chip(
                            label: Text(p.paid ? 'Paid' : 'Unpaid'),
                            backgroundColor: p.paid
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            labelStyle: TextStyle(
                              color: p.paid
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(p.grossPay),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(p.netPay),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'pdf',
                          child: ListTile(
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Export PDF'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_paid',
                          child: ListTile(
                            leading: Icon(Icons.payment),
                            title: Text(
                              p.paid ? 'Mark as Unpaid' : 'Mark as Paid',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                      onSelected: (v) async {
                        if (v == 'pdf') {
                          await _generatePayslipPDF(p);
                        } else if (v == 'toggle_paid') {
                          final updated = p.copyWith(paid: !p.paid);
                          await _service.updatePayroll(updated);
                          await _load();
                        } else if (v == 'delete') {
                          final ok =
                              await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(AppLocalizations.t('confirm')),
                                  content: Text(
                                    'Delete payroll for ${p.employeeName}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(AppLocalizations.t('cancel')),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(AppLocalizations.t('delete')),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (ok) {
                            await _service.deletePayroll(p.id!);
                            await _load();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAutoGenerateDialog() async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Auto-Generate Payroll'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select period to generate payroll for all active employees:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(12, (i) => i + 1).map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(
                              DateFormat.MMMM().format(DateTime(2000, m)),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => selectedMonth = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            List.generate(
                              5,
                              (i) => DateTime.now().year - 2 + i,
                            ).map((y) {
                              return DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              );
                            }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => selectedYear = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Auto-Generation Details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Computes from attendance records\n'
                        '• Includes all active non-owner users\n'
                        '• Auto-calculates SSS, PhilHealth, HDMF\n'
                        '• You can review & adjust before saving',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('cancel')),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate'),
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateAndReview(selectedYear, selectedMonth);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndReview(int year, int month) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating payrolls from attendance data...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generate payrolls
      final payrolls = await BulkPayrollService.instance.generateForPeriod(
        year,
        month,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (payrolls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No active employees found or no attendance data for this period.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show review dialog
      await _showReviewDialog(payrolls, year, month);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating payrolls: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReviewDialog(
    List<Payroll> payrolls,
    int year,
    int month,
  ) async {
    final monthName = DateFormat.MMMM().format(DateTime(year, month));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review Generated Payrolls - $monthName $year'),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 900,
          height: 600,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Generated ${payrolls.length} payroll records',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'Total Net: ${AppCurrency.peso(payrolls.fold<double>(0.0, (sum, p) => sum + p.netPay))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: payrolls.length,
                  itemBuilder: (_, i) {
                    final p = payrolls[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text((i + 1).toString())),
                      title: Text(p.employeeName),
                      subtitle: Text('ID: ${p.employeeId}'),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppCurrency.peso(p.grossPay),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            AppCurrency.peso(p.netPay),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Show details for this payroll
                        _showDetailsDialog(p);
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap any record to view details. You can manually adjust records after saving.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t('cancel')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save All'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveAllPayrolls(payrolls);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllPayrolls(List<Payroll> payrolls) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Saving payroll records...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (final payroll in payrolls) {
        await _service.insertPayroll(payroll);
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      await _load(); // Reload list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully saved ${payrolls.length} payroll records!',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Export PDFs',
            textColor: Colors.white,
            onPressed: () {
              _exportAllPDFs(payrolls);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving payrolls: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAllPDFs(List<Payroll> payrolls) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Generating ${payrolls.length} PDF payslips...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      for (final payroll in payrolls) {
        await _generatePayslipPDF(payroll);
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Brief delay between PDFs
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${payrolls.length} PDF payslips!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDFs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayrolls = _filter == 'all'
        ? _payrolls
        : _payrolls.where((p) => _filter == 'paid' ? p.paid : !p.paid).toList();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('payroll'))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('All'),
                        icon: Icon(Icons.list),
                      ),
                      ButtonSegment(
                        value: 'unpaid',
                        label: Text('Unpaid'),
                        icon: Icon(Icons.pending),
                      ),
                      ButtonSegment(
                        value: 'paid',
                        label: Text('Paid'),
                        icon: Icon(Icons.check_circle),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() {
                        _filter = selected.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredPayrolls.isEmpty
                ? Center(child: Text(AppLocalizations.t('no_records')))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          itemCount: filteredPayrolls.length,
                          separatorBuilder: (context, _) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _buildRow(filteredPayrolls[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'auto_generate',
            onPressed: _showAutoGenerateDialog,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Auto-Generate'),
            backgroundColor: Colors.green,
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'manual_add',
            onPressed: _showAddDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
