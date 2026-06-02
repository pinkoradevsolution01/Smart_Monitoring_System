import 'package:flutter/foundation.dart';
import '../models/payroll.dart';
import '../models/user.dart';
import 'user_service.dart';
import 'attendance_service.dart';

class BulkPayrollService {
  BulkPayrollService._();
  static final BulkPayrollService instance = BulkPayrollService._();

  /// Generate payrolls for all active non-owner employees for a given month/year
  Future<List<Payroll>> generateForPeriod(
    int year,
    int month, {
    List<String>? employeeIds,
    String? shiftFilter, // 'Opening', 'Mid-Shift', 'Closing', or null for all
  }) async {
    final allUsers = UserService().users;

    // Filter users: active, non-owner, optionally by specific IDs or shift
    var users = allUsers.where((u) => u.isActive && u.role != UserRole.owner);

    if (employeeIds != null && employeeIds.isNotEmpty) {
      users = users.where((u) => employeeIds.contains(u.id));
    }

    // Note: Shift filtering is available through attendance records.
    // To filter by shift, pass specific employeeIds instead.

    final payrolls = <Payroll>[];
    for (final user in users) {
      try {
        final payroll = await _generateForEmployee(user, year, month);
        payrolls.add(payroll);
      } catch (e) {
        // Skip employees with errors and continue
        debugPrint('Error generating payroll for ${user.name}: $e');
      }
    }

    return payrolls;
  }

  /// Generate payroll for a single employee based on attendance data
  Future<Payroll> _generateForEmployee(User user, int year, int month) async {
    final attendanceService = AttendanceService.instance;

    // Load attendance archive for the user
    final archive = await attendanceService.loadArchive(user.id);
    final schedule = await attendanceService.loadSchedule();
    final leaves = await attendanceService.loadLeaves(user.id);

    // Get all dates in the month
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month

    Duration totalHours = Duration.zero;
    Duration overtimeHours = Duration.zero;

    // Process each day in the month
    for (
      var date = startDate;
      date.isBefore(endDate.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Check if user has leave on this date
      final leaveData = leaves[dateKey];
      if (leaveData != null && leaveData['authorized'] == true) {
        // Count authorized leave as working hours
        final leaveMinutes =
            leaveData['minutes'] ?? (schedule['requiredMinutes'] ?? 480);
        totalHours += Duration(minutes: leaveMinutes);
        continue;
      }

      // Get attendance entries for this date
      final entries = archive[dateKey] ?? [];
      if (entries.isEmpty) continue;

      // Calculate worked hours for the day
      final dayResult = _calculateDayHours(entries, schedule);
      if (dayResult['workedMinutes'] > 0) {
        totalHours += Duration(minutes: dayResult['workedMinutes']);

        // Check for overtime (more than required minutes)
        final requiredMinutes = schedule['requiredMinutes'] ?? 480;
        if (dayResult['workedMinutes'] > requiredMinutes) {
          overtimeHours += Duration(
            minutes: dayResult['workedMinutes'] - requiredMinutes,
          );
        }

        // Note: Night differential (22:00-06:00) can be added as manual adjustment.
        // Automatic calculation would require storing hour-by-hour time entries.
      }
    }

    // Convert to decimal hours
    final totalHoursDecimal = totalHours.inMinutes / 60.0;
    final overtimeHoursDecimal = overtimeHours.inMinutes / 60.0;

    // Default basic rate per hour (configurable in future User model updates)
    // For now, administrators can adjust generated payrolls manually before saving.
    const basicRatePerHour = 50.0; // PHP 50/hour default - adjust as needed
    const basicRatePerDay = basicRatePerHour * 8; // 8-hour day

    final regularPay = totalHoursDecimal * basicRatePerHour;
    final overtimePay =
        overtimeHoursDecimal * basicRatePerHour * 1.25; // 25% overtime premium

    // Default allowances (can be adjusted in review screen before saving)
    const mealAllowance = 0.0; // No default meal allowance
    const transpoAllowance = 0.0; // No default transportation allowance

    // Government contributions (computed based on 2024 salary brackets)
    final grossBeforeDeductions = regularPay + overtimePay;
    final sss = _computeSSS(grossBeforeDeductions);
    const hdmf = 100.0; // HDMF Pag-IBIG contribution (₱100 standard)
    final philHealth = _computePhilHealth(grossBeforeDeductions);
    const withholdingTax = 0.0; // Withholding tax (can be added manually)

    final totalDeductions = sss + hdmf + philHealth + withholdingTax;
    final grossPay =
        regularPay + overtimePay + mealAllowance + transpoAllowance;
    final netPay = grossPay - totalDeductions;

    return Payroll(
      employeeId: user.id,
      employeeName: user.name,
      year: year,
      month: month,
      basicRatePerDay: basicRatePerDay,
      regularPay: regularPay,
      overtimeHours: overtimeHoursDecimal,
      overtimePay: overtimePay,
      nightDiff: 0.0,
      specHoliday: 0.0,
      leaveAmount: 0.0,
      absentAmount: 0.0,
      lateAmount: 0.0,
      undertimeAmount: 0.0,
      cola: 0.0,
      thirteenth: 0.0,
      adjustment: 0.0,
      allowanceMeal: mealAllowance,
      allowanceLodging: 0.0,
      allowanceTranspo: transpoAllowance,
      allowanceOther: 0.0,
      sss: sss,
      hdmf: hdmf,
      phi: philHealth,
      wtax: withholdingTax,
      otherInsurance: 0.0,
      otherVoluntary: 0.0,
      otherHmo: 0.0,
      otherOther: 0.0,
      loanDeductions: 0.0,
      grossPay: grossPay,
      totalDeductions: totalDeductions,
      netPay: netPay,
      paid: false,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Calculate worked minutes for a single day
  Map<String, dynamic> _calculateDayHours(
    List<dynamic> entries,
    Map<String, dynamic> schedule,
  ) {
    if (entries.isEmpty) return {'workedMinutes': 0};

    final lunchMinutes = ((schedule['lunchMinutes'] ?? 60) as num).toInt();
    final snackMinutes = ((schedule['snackMinutes'] ?? 15) as num).toInt();

    DateTime? firstIn;
    DateTime? lastOut;
    int breakMinutes = 0;

    for (final entry in entries) {
      final time = entry.time as DateTime;
      final type = entry.type as String;

      if (type == 'IN' && firstIn == null) {
        firstIn = time;
      } else if (type == 'OUT') {
        lastOut = time;
      } else if (type == 'LUNCH') {
        breakMinutes += lunchMinutes;
      } else if (type == 'SNACK') {
        breakMinutes += snackMinutes;
      }
    }

    if (firstIn == null || lastOut == null) {
      return {'workedMinutes': 0};
    }

    final totalMinutes = lastOut.difference(firstIn).inMinutes;
    final workedMinutes = totalMinutes - breakMinutes;

    return {
      'workedMinutes': workedMinutes > 0 ? workedMinutes : 0,
      'firstIn': firstIn,
      'lastOut': lastOut,
    };
  }

  /// Simplified SSS contribution calculation (2024 rates)
  double _computeSSS(double monthlySalary) {
    if (monthlySalary < 4250) return 180.0;
    if (monthlySalary < 4750) return 202.50;
    if (monthlySalary < 5250) return 225.0;
    if (monthlySalary < 5750) return 247.50;
    if (monthlySalary < 6250) return 270.0;
    if (monthlySalary < 6750) return 292.50;
    if (monthlySalary < 7250) return 315.0;
    if (monthlySalary < 7750) return 337.50;
    if (monthlySalary < 8250) return 360.0;
    if (monthlySalary < 8750) return 382.50;
    if (monthlySalary < 9250) return 405.0;
    if (monthlySalary < 9750) return 427.50;
    if (monthlySalary < 10250) return 450.0;
    if (monthlySalary < 10750) return 472.50;
    if (monthlySalary < 11250) return 495.0;
    if (monthlySalary < 11750) return 517.50;
    if (monthlySalary < 12250) return 540.0;
    if (monthlySalary < 12750) return 562.50;
    if (monthlySalary < 13250) return 585.0;
    if (monthlySalary < 13750) return 607.50;
    if (monthlySalary < 14250) return 630.0;
    if (monthlySalary < 14750) return 652.50;
    if (monthlySalary < 15250) return 675.0;
    if (monthlySalary < 15750) return 697.50;
    if (monthlySalary < 16250) return 720.0;
    if (monthlySalary < 16750) return 742.50;
    if (monthlySalary < 17250) return 765.0;
    if (monthlySalary < 17750) return 787.50;
    if (monthlySalary < 18250) return 810.0;
    if (monthlySalary < 18750) return 832.50;
    if (monthlySalary < 19250) return 855.0;
    if (monthlySalary < 19750) return 877.50;
    return 900.0; // Maximum
  }

  /// Simplified PhilHealth contribution calculation (2024 rates)
  double _computePhilHealth(double monthlySalary) {
    if (monthlySalary < 10000) return 450.0; // Minimum
    if (monthlySalary > 90000) return 4050.0; // Maximum (capped at 90k)
    return monthlySalary * 0.045; // 4.5% of basic salary
  }
}
