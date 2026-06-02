class DamageReport {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalValue;
  final String reason;
  final String reportedBy;
  final DateTime reportDate;
  final String? returnStatus; // 'pending', 'returned', null
  final String? returnApprovedBy;
  final String? returnSignature;
  final DateTime? returnDate;
  final String? paymentStatus; // 'pending', 'paid', null
  final String? responsiblePerson; // User name or 'All Staff'
  final String? responsibleUserId; // User ID if specific user
  final DateTime? paymentDate;

  DamageReport({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalValue,
    required this.reason,
    required this.reportedBy,
    required this.reportDate,
    this.returnStatus,
    this.returnApprovedBy,
    this.returnSignature,
    this.returnDate,
    this.paymentStatus,
    this.responsiblePerson,
    this.responsibleUserId,
    this.paymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalValue': totalValue,
      'reason': reason,
      'reportedBy': reportedBy,
      'reportDate': reportDate.toIso8601String(),
      'returnStatus': returnStatus,
      'returnApprovedBy': returnApprovedBy,
      'returnSignature': returnSignature,
      'returnDate': returnDate?.toIso8601String(),
      'paymentStatus': paymentStatus,
      'responsiblePerson': responsiblePerson,
      'responsibleUserId': responsibleUserId,
      'paymentDate': paymentDate?.toIso8601String(),
    };
  }

  factory DamageReport.fromMap(Map<String, dynamic> map) {
    return DamageReport(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unitPrice'] as double,
      totalValue: map['totalValue'] as double,
      reason: map['reason'] as String,
      reportedBy: map['reportedBy'] as String,
      reportDate: DateTime.parse(map['reportDate'] as String),
      returnStatus: map['returnStatus'] as String?,
      returnApprovedBy: map['returnApprovedBy'] as String?,
      returnSignature: map['returnSignature'] as String?,
      returnDate: map['returnDate'] != null
          ? DateTime.parse(map['returnDate'] as String)
          : null,
      paymentStatus: map['paymentStatus'] as String?,
      responsiblePerson: map['responsiblePerson'] as String?,
      responsibleUserId: map['responsibleUserId'] as String?,
      paymentDate: map['paymentDate'] != null
          ? DateTime.parse(map['paymentDate'] as String)
          : null,
    );
  }

  DamageReport copyWith({
    int? id,
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalValue,
    String? reason,
    String? reportedBy,
    DateTime? reportDate,
    String? returnStatus,
    String? returnApprovedBy,
    String? returnSignature,
    DateTime? returnDate,
    String? paymentStatus,
    String? responsiblePerson,
    String? responsibleUserId,
    DateTime? paymentDate,
  }) {
    return DamageReport(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalValue: totalValue ?? this.totalValue,
      reason: reason ?? this.reason,
      reportedBy: reportedBy ?? this.reportedBy,
      reportDate: reportDate ?? this.reportDate,
      returnStatus: returnStatus ?? this.returnStatus,
      returnApprovedBy: returnApprovedBy ?? this.returnApprovedBy,
      returnSignature: returnSignature ?? this.returnSignature,
      returnDate: returnDate ?? this.returnDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      responsibleUserId: responsibleUserId ?? this.responsibleUserId,
      paymentDate: paymentDate ?? this.paymentDate,
    );
  }
}
