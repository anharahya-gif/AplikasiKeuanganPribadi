class TransactionModel {
  final String id;
  final double amount;
  final String type; // 'income', 'expense', or 'transfer'
  final String categoryId;
  final String accountId; // For transfer, this is the SOURCE account
  final String? toAccountId; // For transfer, this is the DESTINATION account
  final String? imagePath; // Local path to attached photo
  final DateTime date;
  final String description;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.imagePath,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'image_path': imagePath,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'expense',
      categoryId: map['category_id'] ?? '',
      accountId: map['account_id'] ?? '',
      toAccountId: map['to_account_id'],
      imagePath: map['image_path'],
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      description: map['description'] ?? '',
    );
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    String? imagePath,
    DateTime? date,
    String? description,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      imagePath: imagePath ?? this.imagePath,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }
}
