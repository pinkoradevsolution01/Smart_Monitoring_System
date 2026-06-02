class ShoeSize {
  final String usSize;
  final String ukSize;
  final String euSize;
  final String cmSize;
  final int quantity;

  ShoeSize({
    required this.usSize,
    required this.ukSize,
    required this.euSize,
    required this.cmSize,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'usSize': usSize,
      'ukSize': ukSize,
      'euSize': euSize,
      'cmSize': cmSize,
      'quantity': quantity,
    };
  }

  factory ShoeSize.fromMap(Map<String, dynamic> map) {
    return ShoeSize(
      usSize: map['usSize'] as String,
      ukSize: map['ukSize'] as String,
      euSize: map['euSize'] as String,
      cmSize: map['cmSize'] as String,
      quantity: map['quantity'] as int,
    );
  }

  ShoeSize copyWith({
    String? usSize,
    String? ukSize,
    String? euSize,
    String? cmSize,
    int? quantity,
  }) {
    return ShoeSize(
      usSize: usSize ?? this.usSize,
      ukSize: ukSize ?? this.ukSize,
      euSize: euSize ?? this.euSize,
      cmSize: cmSize ?? this.cmSize,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Common shoe size conversion data
class ShoeSizeConversions {
  static final List<Map<String, String>> menSizes = [
    {'us': '6', 'uk': '5.5', 'eu': '39', 'cm': '24'},
    {'us': '6.5', 'uk': '6', 'eu': '39.5', 'cm': '24.5'},
    {'us': '7', 'uk': '6.5', 'eu': '40', 'cm': '25'},
    {'us': '7.5', 'uk': '7', 'eu': '40.5', 'cm': '25.5'},
    {'us': '8', 'uk': '7.5', 'eu': '41', 'cm': '26'},
    {'us': '8.5', 'uk': '8', 'eu': '42', 'cm': '26.5'},
    {'us': '9', 'uk': '8.5', 'eu': '42.5', 'cm': '27'},
    {'us': '9.5', 'uk': '9', 'eu': '43', 'cm': '27.5'},
    {'us': '10', 'uk': '9.5', 'eu': '44', 'cm': '28'},
    {'us': '10.5', 'uk': '10', 'eu': '44.5', 'cm': '28.5'},
    {'us': '11', 'uk': '10.5', 'eu': '45', 'cm': '29'},
    {'us': '11.5', 'uk': '11', 'eu': '45.5', 'cm': '29.5'},
    {'us': '12', 'uk': '11.5', 'eu': '46', 'cm': '30'},
    {'us': '13', 'uk': '12.5', 'eu': '47.5', 'cm': '31'},
    {'us': '14', 'uk': '13.5', 'eu': '49', 'cm': '32'},
  ];

  static final List<Map<String, String>> womenSizes = [
    {'us': '5', 'uk': '2.5', 'eu': '35', 'cm': '21.5'},
    {'us': '5.5', 'uk': '3', 'eu': '35.5', 'cm': '22'},
    {'us': '6', 'uk': '3.5', 'eu': '36', 'cm': '22.5'},
    {'us': '6.5', 'uk': '4', 'eu': '37', 'cm': '23'},
    {'us': '7', 'uk': '4.5', 'eu': '37.5', 'cm': '23.5'},
    {'us': '7.5', 'uk': '5', 'eu': '38', 'cm': '24'},
    {'us': '8', 'uk': '5.5', 'eu': '38.5', 'cm': '24.5'},
    {'us': '8.5', 'uk': '6', 'eu': '39', 'cm': '25'},
    {'us': '9', 'uk': '6.5', 'eu': '40', 'cm': '25.5'},
    {'us': '9.5', 'uk': '7', 'eu': '40.5', 'cm': '26'},
    {'us': '10', 'uk': '7.5', 'eu': '41', 'cm': '26.5'},
    {'us': '10.5', 'uk': '8', 'eu': '42', 'cm': '27'},
    {'us': '11', 'uk': '8.5', 'eu': '42.5', 'cm': '27.5'},
    {'us': '12', 'uk': '9.5', 'eu': '43.5', 'cm': '28.5'},
  ];

  static final List<Map<String, String>> unisexSizes = [
    {'us': '5', 'uk': '4', 'eu': '37', 'cm': '23'},
    {'us': '6', 'uk': '5', 'eu': '38', 'cm': '24'},
    {'us': '7', 'uk': '6', 'eu': '39', 'cm': '25'},
    {'us': '8', 'uk': '7', 'eu': '40', 'cm': '26'},
    {'us': '9', 'uk': '8', 'eu': '41', 'cm': '27'},
    {'us': '10', 'uk': '9', 'eu': '42', 'cm': '28'},
    {'us': '11', 'uk': '10', 'eu': '43', 'cm': '29'},
    {'us': '12', 'uk': '11', 'eu': '44', 'cm': '30'},
  ];
}
