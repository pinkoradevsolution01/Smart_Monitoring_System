import 'package:sqflite/sqflite.dart';
import '../models/payroll.dart';
import 'database_service.dart';

class PayrollService {
  PayrollService._internal();
  static final PayrollService instance = PayrollService._internal();

  Future<Database> get _db async => await DatabaseService().database;

  Future<void> initialize() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payrolls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employeeId TEXT NOT NULL,
        employeeName TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        basicRatePerDay REAL NOT NULL DEFAULT 0,
        regularPay REAL NOT NULL DEFAULT 0,
        overtimeHours REAL NOT NULL DEFAULT 0,
        overtimePay REAL NOT NULL DEFAULT 0,
        nightDiff REAL NOT NULL DEFAULT 0,
        specHoliday REAL NOT NULL DEFAULT 0,
        leaveAmount REAL NOT NULL DEFAULT 0,
        absentAmount REAL NOT NULL DEFAULT 0,
        lateAmount REAL NOT NULL DEFAULT 0,
        undertimeAmount REAL NOT NULL DEFAULT 0,
        cola REAL NOT NULL DEFAULT 0,
        thirteenth REAL NOT NULL DEFAULT 0,
        adjustment REAL NOT NULL DEFAULT 0,
        allowanceMeal REAL NOT NULL DEFAULT 0,
        allowanceLodging REAL NOT NULL DEFAULT 0,
        allowanceTranspo REAL NOT NULL DEFAULT 0,
        allowanceOther REAL NOT NULL DEFAULT 0,
        sss REAL NOT NULL DEFAULT 0,
        hdmf REAL NOT NULL DEFAULT 0,
        phi REAL NOT NULL DEFAULT 0,
        wtax REAL NOT NULL DEFAULT 0,
        otherInsurance REAL NOT NULL DEFAULT 0,
        otherVoluntary REAL NOT NULL DEFAULT 0,
        otherHmo REAL NOT NULL DEFAULT 0,
        otherOther REAL NOT NULL DEFAULT 0,
        loanDeductions REAL NOT NULL DEFAULT 0,
        grossPay REAL NOT NULL DEFAULT 0,
        totalDeductions REAL NOT NULL DEFAULT 0,
        netPay REAL NOT NULL DEFAULT 0,
        paid INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Add missing columns for older DBs (safe attempt)
    Future<void> tryAdd(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // ignore if column exists
      }
    }

    await tryAdd('ALTER TABLE payrolls ADD COLUMN regularPay REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN basicRatePerDay REAL DEFAULT 0',
    );
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN overtimeHours REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN overtimePay REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN nightDiff REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN specHoliday REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN leaveAmount REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN absentAmount REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN lateAmount REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN undertimeAmount REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN cola REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN thirteenth REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN adjustment REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN allowanceMeal REAL DEFAULT 0',
    );
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN allowanceLodging REAL DEFAULT 0',
    );
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN allowanceTranspo REAL DEFAULT 0',
    );
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN allowanceOther REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN sss REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN hdmf REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN phi REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN wtax REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN otherInsurance REAL DEFAULT 0',
    );
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN otherVoluntary REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN otherHmo REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN otherOther REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN loanDeductions REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN grossPay REAL DEFAULT 0');
    await tryAdd(
      'ALTER TABLE payrolls ADD COLUMN totalDeductions REAL DEFAULT 0',
    );
    await tryAdd('ALTER TABLE payrolls ADD COLUMN netPay REAL DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN paid INTEGER DEFAULT 0');
    await tryAdd('ALTER TABLE payrolls ADD COLUMN createdAt TEXT');

    // Handle legacy 'deductions' column - copy to totalDeductions if it exists
    try {
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM pragma_table_info('payrolls') WHERE name='deductions'",
      );
      if (result.isNotEmpty && (result.first['count'] as int) > 0) {
        // Legacy column exists, migrate data
        await db.execute(
          'UPDATE payrolls SET totalDeductions = deductions WHERE totalDeductions = 0',
        );
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<int> insertPayroll(Payroll p) async {
    final db = await _db;
    return db.insert('payrolls', p.toMap());
  }

  Future<List<Payroll>> getAllPayrolls() async {
    final db = await _db;
    final maps = await db.query('payrolls', orderBy: 'createdAt DESC');
    return maps.map((m) => Payroll.fromMap(m)).toList();
  }

  Future<Payroll?> getPayrollById(int id) async {
    final db = await _db;
    final maps = await db.query('payrolls', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Payroll.fromMap(maps.first);
  }

  Future<int> updatePayroll(Payroll p) async {
    final db = await _db;
    return db.update('payrolls', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deletePayroll(int id) async {
    final db = await _db;
    return db.delete('payrolls', where: 'id = ?', whereArgs: [id]);
  }
}
