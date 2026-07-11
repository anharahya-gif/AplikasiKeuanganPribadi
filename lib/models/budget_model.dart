class Budget {
  final String id;
  final String categoryId;
  final double amount;
  final String month; // 'YYYY-MM' format

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount': amount,
      'month': month,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      categoryId: map['category_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      month: map['month'] ?? '',
    );
  }

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    String? month,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
    );
  }
}
