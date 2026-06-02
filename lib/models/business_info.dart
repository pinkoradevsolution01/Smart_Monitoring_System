 class BusinessInfo {
  final String storeName;
  final String businessType;
  final String? storeAddress;
  final String? logoPath;

  BusinessInfo({ 
    required this.storeName,
    required this.businessType,
    this.storeAddress,
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'store_name': storeName,
      'business_type': businessType,
      'store_address': storeAddress,
      'logo_path': logoPath,
    };
  }

  factory BusinessInfo.fromMap(Map<String, dynamic> map) {
    return BusinessInfo(
      storeName: map['store_name'] as String,
      businessType: map['business_type'] as String,
      storeAddress: map['store_address'] as String?,
      logoPath: map['logo_path'] as String?,
    );
  }

  BusinessInfo copyWith({
    String? storeName,
    String? businessType,
    String? storeAddress,
    String? logoPath,
  }) {
    return BusinessInfo(
      storeName: storeName ?? this.storeName,
      businessType: businessType ?? this.businessType,
      storeAddress: storeAddress ?? this.storeAddress,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
