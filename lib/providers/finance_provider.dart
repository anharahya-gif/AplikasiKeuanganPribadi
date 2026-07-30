import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../database/db_helper.dart';

class FinanceProvider with ChangeNotifier {
  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<TransactionModel> _transactions = [];
  List<Budget> _budgets = [];

  DateTime _currentMonth = DateTime.now();
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _searchQuery = '';
  Map<String, dynamic>? _localBackupDetails;
  bool _isLoading = false;

  // Getters
  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  List<TransactionModel> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  DateTime get currentMonth => _currentMonth;
  String get currentMonthStr => DateFormat('yyyy-MM').format(_currentMonth);
  String? get selectedAccountId => _selectedAccountId;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  Map<String, dynamic>? get localBackupDetails => _localBackupDetails;
  bool get isLoading => _isLoading;

  // Constructor
  FinanceProvider() {
    refreshData();
  }

  // Load / Refresh all data from local SQLite
  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await DbHelper.instance.getAllAccounts();
      _categories = await DbHelper.instance.getAllCategories();
      _transactions = await DbHelper.instance.getAllTransactions();
      _budgets = await DbHelper.instance.getBudgetsByMonth(currentMonthStr);
      _localBackupDetails = await DbHelper.instance.getBackupFileDetails();

      final applied = await _checkAndApplyAdminFees();
      if (applied) {
        _accounts = await DbHelper.instance.getAllAccounts();
        _transactions = await DbHelper.instance.getAllTransactions();
      }
    } catch (e) {
      debugPrint("Error loading finance data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Setters for filters
  void setMonth(DateTime month) {
    _currentMonth = month;
    refreshData();
  }

  void nextMonth() {
    setMonth(DateTime(_currentMonth.year, _currentMonth.month + 1));
  }

  void previousMonth() {
    setMonth(DateTime(_currentMonth.year, _currentMonth.month - 1));
  }

  void filterByAccount(String? accountId) {
    _selectedAccountId = accountId;
    notifyListeners();
  }

  void filterByCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedAccountId = null;
    _selectedCategoryId = null;
    _searchQuery = '';
    notifyListeners();
  }

  // --- CALCULATION GETTERS ---

  // Net balance of all accounts combined
  double get totalBalance {
    return _accounts.fold(0.0, (sum, item) => sum + item.balance);
  }

  // Filtered transactions for the selected month + search + filters
  List<TransactionModel> get filteredTransactions {
    return _transactions.where((tx) {
      // 1. Month Filter
      final txMonthStr = DateFormat('yyyy-MM').format(tx.date);
      if (txMonthStr != currentMonthStr) return false;

      // 2. Account Filter
      if (_selectedAccountId != null && tx.accountId != _selectedAccountId) return false;

      // 3. Category Filter
      if (_selectedCategoryId != null && tx.categoryId != _selectedCategoryId) return false;

      // 4. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final descMatch = tx.description.toLowerCase().contains(_searchQuery.toLowerCase());
        final amountMatch = tx.amount.toString().contains(_searchQuery);
        // Find category name
        final cat = _categories.firstWhere((c) => c.id == tx.categoryId, 
            orElse: () => Category(id: '', name: '', iconCode: 0, colorCode: 0, type: ''));
        final catMatch = cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!descMatch && !amountMatch && !catMatch) return false;
      }

      return true;
    }).toList();
  }

  // Total Income for current month and active filters
  double get totalIncomeForMonth {
    return filteredTransactions
        .where((tx) => tx.type == 'income')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  // Total Expense for current month and active filters
  double get totalExpenseForMonth {
    return filteredTransactions
        .where((tx) => tx.type == 'expense')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  // Transactions Grouped by Date (for the transactions list view)
  Map<DateTime, List<TransactionModel>> get groupedTransactions {
    final Map<DateTime, List<TransactionModel>> groups = {};
    for (var tx in filteredTransactions) {
      // Normalize to date only (remove time)
      final dateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!groups.containsKey(dateOnly)) {
        groups[dateOnly] = [];
      }
      groups[dateOnly]!.add(tx);
    }
    return groups;
  }

  // Expense categories spending breakdown (for pie charts & lists)
  Map<Category, double> get categoryExpensesBreakdown {
    final Map<Category, double> breakdown = {};
    
    // Filter expenses in current month (ignoring account filter for comprehensive report, 
    // but applying account filter if user requested to see stats for a specific account)
    final expenses = filteredTransactions.where((tx) => tx.type == 'expense');

    for (var tx in expenses) {
      final cat = _categories.firstWhere((c) => c.id == tx.categoryId, 
          orElse: () => Category(id: 'unknown', name: 'Lainnya', iconCode: Icons.help_outline.codePoint, colorCode: 0xFF9E9E9E, type: 'expense'));
      
      breakdown[cat] = (breakdown[cat] ?? 0.0) + tx.amount;
    }
    return breakdown;
  }

  // Get total expense amount for a specific category in current month
  double getExpenseForCategory(String categoryId) {
    return _transactions
        .where((tx) => tx.type == 'expense' && 
                       tx.categoryId == categoryId && 
                       DateFormat('yyyy-MM').format(tx.date) == currentMonthStr)
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  // --- DATABASE WRITE WRAPPERS ---

  // Accounts
  Future<void> addAccount(String name, double initialBalance, int colorCode, {double adminFee = 0.0}) async {
    final uuid = const Uuid();
    final newAccount = Account(
      id: uuid.v4(),
      name: name,
      balance: initialBalance,
      colorCode: colorCode,
      adminFee: adminFee,
    );
    await DbHelper.instance.createAccount(newAccount);
    
    // If initialBalance > 0, we create a corresponding Initial Balance transaction
    if (initialBalance != 0.0) {
      // Find or create an "Initial Balance" / "Pemasukan Lain" category
      var initialCat = _categories.firstWhere(
        (c) => c.type == 'income' && c.name == 'Pemasukan Lain',
        orElse: () => _categories.firstWhere((c) => c.type == 'income'),
      );
      
      final tx = TransactionModel(
        id: uuid.v4(),
        amount: initialBalance.abs(),
        type: initialBalance > 0 ? 'income' : 'expense',
        categoryId: initialCat.id,
        accountId: newAccount.id,
        date: DateTime.now(),
        description: 'Saldo Awal Akun',
      );
      // We insert via DbHelper but we don't adjust account balance again because createAccount already sets it.
      // Wait, db_helper's createTransaction adjusts account balance.
      // So instead, we can:
      // Option A: Just set createAccount with balance: 0, and then createTransaction of initialBalance. (RECOMMENDED!)
      // Let's modify the flow: create account with 0.0 balance, then call addTransaction.
    }
    
    await refreshData();
  }

  Future<void> updateAccountDetails(Account account) async {
    await DbHelper.instance.updateAccount(account);
    await refreshData();
  }

  Future<void> deleteAccountDetails(String id) async {
    await DbHelper.instance.deleteAccount(id);
    if (_selectedAccountId == id) {
      _selectedAccountId = null;
    }
    await refreshData();
  }

  // Categories
  Future<void> addCategory(String name, int iconCode, int colorCode, String type) async {
    final uuid = const Uuid();
    final newCat = Category(
      id: uuid.v4(),
      name: name,
      iconCode: iconCode,
      colorCode: colorCode,
      type: type,
      isDefault: false,
    );
    await DbHelper.instance.createCategory(newCat);
    await refreshData();
  }

  Future<void> updateCategoryDetails(Category category) async {
    await DbHelper.instance.updateCategory(category);
    await refreshData();
  }

  Future<void> deleteCategoryDetails(String id) async {
    await DbHelper.instance.deleteCategory(id);
    if (_selectedCategoryId == id) {
      _selectedCategoryId = null;
    }
    await refreshData();
  }

  // Transactions
  Future<void> addTransaction({
    required double amount,
    required String type,
    required String categoryId,
    required String accountId,
    String? toAccountId,
    String? imagePath,
    required DateTime date,
    required String description,
  }) async {
    final uuid = const Uuid();
    final tx = TransactionModel(
      id: uuid.v4(),
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      toAccountId: toAccountId,
      imagePath: imagePath,
      date: date,
      description: description,
    );
    await DbHelper.instance.createTransaction(tx);
    await refreshData();
  }

  Future<void> updateTransactionDetails(TransactionModel newTx, TransactionModel oldTx) async {
    await DbHelper.instance.updateTransaction(newTx, oldTx);
    await refreshData();
  }

  Future<void> deleteTransactionDetails(TransactionModel tx) async {
    await DbHelper.instance.deleteTransaction(tx);
    await refreshData();
  }

  // Budgets
  Future<void> setBudget(String categoryId, double amount) async {
    final uuid = const Uuid();
    final budget = Budget(
      id: uuid.v4(),
      categoryId: categoryId,
      amount: amount,
      month: currentMonthStr,
    );
    await DbHelper.instance.createOrUpdateBudget(budget);
    await refreshData();
  }

  Future<void> deleteBudgetDetails(String id) async {
    await DbHelper.instance.deleteBudget(id);
    await refreshData();
  }

  // Check and apply monthly bank admin fees automatically
  Future<bool> _checkAndApplyAdminFees() async {
    bool didApplyAny = false;
    final now = DateTime.now();
    final currentYearMonth = DateFormat('yyyy-MM').format(now);

    // Find a suitable category for admin fees
    Category? adminCat = _categories.firstWhere(
      (c) => c.name.toLowerCase() == 'biaya admin',
      orElse: () => Category(id: '', name: '', iconCode: 0, colorCode: 0, type: ''),
    );

    if (adminCat.id.isEmpty) {
      // Look for Tagihan category or general Lainnya
      final tagihanCat = _categories.firstWhere(
        (c) => c.name.contains('Tagihan') || c.name.contains('Lain'),
        orElse: () => _categories.isNotEmpty 
            ? _categories.first 
            : Category(id: 'temp', name: 'Biaya Admin', iconCode: 0, colorCode: 0, type: 'expense'),
      );
      adminCat = tagihanCat;
    }

    for (final account in _accounts) {
      if (account.adminFee > 0) {
        final targetDesc = 'Biaya Admin Bulanan - ${account.name}';
        
        final alreadyCut = _transactions.any((tx) {
          final txYearMonth = DateFormat('yyyy-MM').format(tx.date);
          return tx.accountId == account.id && 
                 tx.type == 'expense' && 
                 txYearMonth == currentYearMonth && 
                 tx.description == targetDesc;
        });

        if (!alreadyCut) {
          final uuid = const Uuid();
          final autoTx = TransactionModel(
            id: uuid.v4(),
            amount: account.adminFee,
            type: 'expense',
            categoryId: adminCat.id,
            accountId: account.id,
            date: DateTime(now.year, now.month, 1), // Cut on the 1st of current month
            description: targetDesc,
          );
          
          await DbHelper.instance.createTransaction(autoTx);
          didApplyAny = true;
        }
      }
    }
    return didApplyAny;
  }

  // --- BACKUP & RESTORE WRAPPERS ---

  // Create local backup
  Future<bool> createLocalBackup() async {
    final success = await DbHelper.instance.backupDatabase();
    if (success) {
      await refreshData();
    }
    return success;
  }

  // Restore from local backup
  Future<bool> restoreFromLocalBackup() async {
    final success = await DbHelper.instance.restoreDatabase();
    if (success) {
      await refreshData();
    }
    return success;
  }

  // Import external database file with validation
  Future<bool> importDatabase(String pickedPath) async {
    try {
      final pickedFile = File(pickedPath);
      final isValid = await DbHelper.instance.isValidSqliteFile(pickedFile);
      if (!isValid) return false;

      // Close current DB
      await DbHelper.instance.closeDatabase();

      // Copy picked file to main DB path
      final dbPath = await DbHelper.instance.getDatabasePath();
      await pickedFile.copy(dbPath);

      // Reopen database connection & reload data
      await DbHelper.instance.database;
      await refreshData();
      return true;
    } catch (e) {
      debugPrint('Error importing database: $e');
      // Make sure database is reopened if closed
      await DbHelper.instance.database;
      return false;
    }
  }
}
