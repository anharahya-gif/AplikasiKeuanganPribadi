class Account {
  final String id;
  final String name;
  final double balance; // Current balance representation
  final int colorCode; // Theme color for wallet
  final double adminFee; // Monthly bank admin fee

  Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorCode,
    this.adminFee = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'color_code': colorCode,
      'admin_fee': adminFee,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      colorCode: map['color_code'] ?? 0xFF9E9E9E,
      adminFee: (map['admin_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    double? balance,
    int? colorCode,
    double? adminFee,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      colorCode: colorCode ?? this.colorCode,
      adminFee: adminFee ?? this.adminFee,
    );
  }
}
