// import removed: no longer needed

class Payroll {
  final int? id;
  final String employeeId;
  final String employeeName;
  final int year;
  final int month;

  // Income breakdown
  final double basicRatePerDay;
  final double regularPay;
  final double overtimeHours;
  final double overtimePay;
  final double nightDiff;
  final double specHoliday;
  final double leaveAmount;
  final double absentAmount;
  final double lateAmount;
  final double undertimeAmount;
  final double cola;
  final double thirteenth;
  final double adjustment;

  // Allowances
  final double allowanceMeal;
  final double allowanceLodging;
  final double allowanceTranspo;
  final double allowanceOther;

  // Deductions
  final double sss;
  final double hdmf;
  final double phi;
  final double wtax;

  final double otherInsurance;
  final double otherVoluntary;
  final double otherHmo;
  final double otherOther;

  // Loan/Amortization (total)
  final double loanDeductions;

  // Totals
  final double grossPay;
  final double totalDeductions;
  final double netPay;

  final bool paid;
  final String createdAt;

  Payroll({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.year,
    required this.month,
    this.regularPay = 0.0,
    this.basicRatePerDay = 0.0,
    this.overtimeHours = 0.0,
    this.overtimePay = 0.0,
    this.nightDiff = 0.0,
    this.specHoliday = 0.0,
    this.leaveAmount = 0.0,
    this.absentAmount = 0.0,
    this.lateAmount = 0.0,
    this.undertimeAmount = 0.0,
    this.cola = 0.0,
    this.thirteenth = 0.0,
    this.adjustment = 0.0,
    this.allowanceMeal = 0.0,
    this.allowanceLodging = 0.0,
    this.allowanceTranspo = 0.0,
    this.allowanceOther = 0.0,
    this.sss = 0.0,
    this.hdmf = 0.0,
    this.phi = 0.0,
    this.wtax = 0.0,
    this.otherInsurance = 0.0,
    this.otherVoluntary = 0.0,
    this.otherHmo = 0.0,
    this.otherOther = 0.0,
    this.loanDeductions = 0.0,
    required this.grossPay,
    required this.totalDeductions,
    required this.netPay,
    this.paid = false,
    required this.createdAt,
  });

  Payroll copyWith({
    int? id,
    String? employeeId,
    String? employeeName,
    int? year,
    int? month,
    double? regularPay,
    double? basicRatePerDay,
    double? overtimeHours,
    double? overtimePay,
    double? nightDiff,
    double? specHoliday,
    double? leaveAmount,
    double? absentAmount,
    double? lateAmount,
    double? undertimeAmount,
    double? cola,
    double? thirteenth,
    double? adjustment,
    double? allowanceMeal,
    double? allowanceLodging,
    double? allowanceTranspo,
    double? allowanceOther,
    double? sss,
    double? hdmf,
    double? phi,
    double? wtax,
    double? otherInsurance,
    double? otherVoluntary,
    double? otherHmo,
    double? otherOther,
    double? loanDeductions,
    double? grossPay,
    double? deductions,
    double? netPay,
    bool? paid,
    String? createdAt,
  }) {
    return Payroll(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      year: year ?? this.year,
      month: month ?? this.month,
      regularPay: regularPay ?? this.regularPay,
      basicRatePerDay: basicRatePerDay ?? this.basicRatePerDay,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      overtimePay: overtimePay ?? this.overtimePay,
      nightDiff: nightDiff ?? this.nightDiff,
      specHoliday: specHoliday ?? this.specHoliday,
      leaveAmount: leaveAmount ?? this.leaveAmount,
      absentAmount: absentAmount ?? this.absentAmount,
      lateAmount: lateAmount ?? this.lateAmount,
      undertimeAmount: undertimeAmount ?? this.undertimeAmount,
      cola: cola ?? this.cola,
      thirteenth: thirteenth ?? this.thirteenth,
      adjustment: adjustment ?? this.adjustment,
      allowanceMeal: allowanceMeal ?? this.allowanceMeal,
      allowanceLodging: allowanceLodging ?? this.allowanceLodging,
      allowanceTranspo: allowanceTranspo ?? this.allowanceTranspo,
      allowanceOther: allowanceOther ?? this.allowanceOther,
      sss: sss ?? this.sss,
      hdmf: hdmf ?? this.hdmf,
      phi: phi ?? this.phi,
      wtax: wtax ?? this.wtax,
      otherInsurance: otherInsurance ?? this.otherInsurance,
      otherVoluntary: otherVoluntary ?? this.otherVoluntary,
      otherHmo: otherHmo ?? this.otherHmo,
      otherOther: otherOther ?? this.otherOther,
      loanDeductions: loanDeductions ?? this.loanDeductions,
      grossPay: grossPay ?? this.grossPay,
      totalDeductions: deductions ?? totalDeductions,
      netPay: netPay ?? this.netPay,
      paid: paid ?? this.paid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Payroll.fromMap(Map<String, dynamic> m) {
    double parseDouble(String key) {
      final v = m[key];
      if (v == null) return 0.0;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return Payroll(
      id: m['id'] as int?,
      employeeId: (m['employeeId'] ?? '') as String,
      employeeName: (m['employeeName'] ?? '') as String,
      year: (m['year'] ?? 0) as int,
      month: (m['month'] ?? 0) as int,
      regularPay: parseDouble('regularPay'),
      basicRatePerDay: parseDouble('basicRatePerDay'),
      overtimeHours: parseDouble('overtimeHours'),
      overtimePay: parseDouble('overtimePay'),
      nightDiff: parseDouble('nightDiff'),
      specHoliday: parseDouble('specHoliday'),
      leaveAmount: parseDouble('leaveAmount'),
      absentAmount: parseDouble('absentAmount'),
      lateAmount: parseDouble('lateAmount'),
      undertimeAmount: parseDouble('undertimeAmount'),
      cola: parseDouble('cola'),
      thirteenth: parseDouble('thirteenth'),
      adjustment: parseDouble('adjustment'),
      allowanceMeal: parseDouble('allowanceMeal'),
      allowanceLodging: parseDouble('allowanceLodging'),
      allowanceTranspo: parseDouble('allowanceTranspo'),
      allowanceOther: parseDouble('allowanceOther'),
      sss: parseDouble('sss'),
      hdmf: parseDouble('hdmf'),
      phi: parseDouble('phi'),
      wtax: parseDouble('wtax'),
      otherInsurance: parseDouble('otherInsurance'),
      otherVoluntary: parseDouble('otherVoluntary'),
      otherHmo: parseDouble('otherHmo'),
      otherOther: parseDouble('otherOther'),
      loanDeductions: parseDouble('loanDeductions'),
      grossPay: parseDouble('grossPay'),
      totalDeductions: parseDouble('totalDeductions'),
      netPay: parseDouble('netPay'),
      paid: ((m['paid'] ?? 0) as int) == 1,
      createdAt: (m['createdAt'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'year': year,
      'month': month,
      'regularPay': regularPay,
      'basicRatePerDay': basicRatePerDay,
      'overtimeHours': overtimeHours,
      'overtimePay': overtimePay,
      'nightDiff': nightDiff,
      'specHoliday': specHoliday,
      'leaveAmount': leaveAmount,
      'absentAmount': absentAmount,
      'lateAmount': lateAmount,
      'undertimeAmount': undertimeAmount,
      'cola': cola,
      'thirteenth': thirteenth,
      'adjustment': adjustment,
      'allowanceMeal': allowanceMeal,
      'allowanceLodging': allowanceLodging,
      'allowanceTranspo': allowanceTranspo,
      'allowanceOther': allowanceOther,
      'sss': sss,
      'hdmf': hdmf,
      'phi': phi,
      'wtax': wtax,
      'otherInsurance': otherInsurance,
      'otherVoluntary': otherVoluntary,
      'otherHmo': otherHmo,
      'otherOther': otherOther,
      'loanDeductions': loanDeductions,
      'grossPay': grossPay,
      'totalDeductions': totalDeductions,
      'deductions': totalDeductions, // Legacy column for backward compatibility
      'netPay': netPay,
      'paid': paid ? 1 : 0,
      'createdAt': createdAt,
    };
  }
}
