import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/account_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('personal_finance.db');
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'personal_finance.db');
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN to_account_id TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE accounts ADD COLUMN admin_fee REAL DEFAULT 0.0');
    }
  }

  Future _createDB(Database db, int version) async {
    // Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance REAL NOT NULL,
        color_code INTEGER NOT NULL,
        admin_fee REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon_code INTEGER NOT NULL,
        color_code INTEGER NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER NOT NULL
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        to_account_id TEXT,
        image_path TEXT,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        amount REAL NOT NULL,
        month TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Prepopulate Data
    await _prepopulateDefaultData(db);
  }

  Future _prepopulateDefaultData(Database db) async {
    final uuid = const Uuid();

    // 1. Default Accounts
    final defaultAccounts = [
      Account(id: uuid.v4(), name: 'Dompet Tunai', balance: 0.0, colorCode: 0xFF10B981), // Emerald Green
      Account(id: uuid.v4(), name: 'Rekening Bank', balance: 0.0, colorCode: 0xFF3B82F6), // Blue
      Account(id: uuid.v4(), name: 'E-Wallet', balance: 0.0, colorCode: 0xFF8B5CF6), // Violet
    ];

    for (var account in defaultAccounts) {
      await db.insert('accounts', account.toMap());
    }

    // 2. Default Categories
    final defaultCategories = [
      // Income Categories
      Category(id: uuid.v4(), name: 'Gaji', iconCode: Icons.work.codePoint, colorCode: 0xFF10B981, type: 'income', isDefault: true),
      Category(id: uuid.v4(), name: 'Investasi', iconCode: Icons.trending_up.codePoint, colorCode: 0xFF059669, type: 'income', isDefault: true),
      Category(id: uuid.v4(), name: 'Dana Hibah / Hadiah', iconCode: Icons.card_giftcard.codePoint, colorCode: 0xFF06B6D4, type: 'income', isDefault: true),
      Category(id: uuid.v4(), name: 'Pemasukan Lain', iconCode: Icons.more_horiz.codePoint, colorCode: 0xFF6B7280, type: 'income', isDefault: true),

      // Expense Categories
      Category(id: uuid.v4(), name: 'Makanan & Minuman', iconCode: Icons.restaurant.codePoint, colorCode: 0xFFF43F5E, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Transportasi', iconCode: Icons.directions_car.codePoint, colorCode: 0xFFF59E0B, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Belanja', iconCode: Icons.shopping_bag.codePoint, colorCode: 0xFFEC4899, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Hiburan', iconCode: Icons.sports_esports.codePoint, colorCode: 0xFF8B5CF6, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Tagihan & Utilitas', iconCode: Icons.receipt_long.codePoint, colorCode: 0xFF3B82F6, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Kesehatan', iconCode: Icons.medical_services.codePoint, colorCode: 0xFF14B8A6, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Rumah & Sewa', iconCode: Icons.home.codePoint, colorCode: 0xFFD97706, type: 'expense', isDefault: true),
      Category(id: uuid.v4(), name: 'Pengeluaran Lain', iconCode: Icons.more_horiz.codePoint, colorCode: 0xFF6B7280, type: 'expense', isDefault: true),
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category.toMap());
    }
  }

  // --- ACCOUNTS CRUD ---
  Future<String> createAccount(Account account) async {
    final db = await instance.database;
    await db.insert('accounts', account.toMap());
    return account.id;
  }

  Future<List<Account>> getAllAccounts() async {
    final db = await instance.database;
    final result = await db.query('accounts');
    return result.map((json) => Account.fromMap(json)).toList();
  }

  Future<Account?> getAccountById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateAccount(Account account) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await instance.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CATEGORIES CRUD ---
  Future<String> createCategory(Category category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap());
    return category.id;
  }

  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- TRANSACTIONS CRUD ---
  Future<String> createTransaction(TransactionModel tx) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Insert transaction
      await txn.insert('transactions', tx.toMap());

      if (tx.type == 'transfer' && tx.toAccountId != null) {
        // Subtract source account balance
        final srcAccountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
        if (srcAccountMap.isNotEmpty) {
          final srcAccount = Account.fromMap(srcAccountMap.first);
          await txn.update(
            'accounts',
            srcAccount.copyWith(balance: srcAccount.balance - tx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [tx.accountId],
          );
        }
        // Add destination account balance
        final destAccountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.toAccountId]);
        if (destAccountMap.isNotEmpty) {
          final destAccount = Account.fromMap(destAccountMap.first);
          await txn.update(
            'accounts',
            destAccount.copyWith(balance: destAccount.balance + tx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [tx.toAccountId],
          );
        }
      } else {
        // Update single account balance (income/expense)
        final accountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
        if (accountMap.isNotEmpty) {
          final account = Account.fromMap(accountMap.first);
          final newBalance = tx.type == 'income'
              ? account.balance + tx.amount
              : account.balance - tx.amount;

          await txn.update(
            'accounts',
            account.copyWith(balance: newBalance).toMap(),
            where: 'id = ?',
            whereArgs: [tx.accountId],
          );
        }
      }
    });
    return tx.id;
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> updateTransaction(TransactionModel newTx, TransactionModel oldTx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. REVERT OLD TRANSACTION
      if (oldTx.type == 'transfer' && oldTx.toAccountId != null) {
        // Revert source account (add amount back)
        final oldSrcMap = await txn.query('accounts', where: 'id = ?', whereArgs: [oldTx.accountId]);
        if (oldSrcMap.isNotEmpty) {
          final oldSrcAcc = Account.fromMap(oldSrcMap.first);
          await txn.update(
            'accounts',
            oldSrcAcc.copyWith(balance: oldSrcAcc.balance + oldTx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [oldTx.accountId],
          );
        }
        // Revert destination account (subtract amount)
        final oldDestMap = await txn.query('accounts', where: 'id = ?', whereArgs: [oldTx.toAccountId]);
        if (oldDestMap.isNotEmpty) {
          final oldDestAcc = Account.fromMap(oldDestMap.first);
          await txn.update(
            'accounts',
            oldDestAcc.copyWith(balance: oldDestAcc.balance - oldTx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [oldTx.toAccountId],
          );
        }
      } else {
        // Revert normal transaction
        final oldAccMap = await txn.query('accounts', where: 'id = ?', whereArgs: [oldTx.accountId]);
        if (oldAccMap.isNotEmpty) {
          final oldAcc = Account.fromMap(oldAccMap.first);
          final revertedBalance = oldTx.type == 'income'
              ? oldAcc.balance - oldTx.amount
              : oldAcc.balance + oldTx.amount;
          await txn.update(
            'accounts',
            oldAcc.copyWith(balance: revertedBalance).toMap(),
            where: 'id = ?',
            whereArgs: [oldTx.accountId],
          );
        }
      }

      // 2. APPLY NEW TRANSACTION
      if (newTx.type == 'transfer' && newTx.toAccountId != null) {
        // Apply new source account (subtract amount)
        final newSrcMap = await txn.query('accounts', where: 'id = ?', whereArgs: [newTx.accountId]);
        if (newSrcMap.isNotEmpty) {
          final newSrcAcc = Account.fromMap(newSrcMap.first);
          await txn.update(
            'accounts',
            newSrcAcc.copyWith(balance: newSrcAcc.balance - newTx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [newTx.accountId],
          );
        }
        // Apply new destination account (add amount)
        final newDestMap = await txn.query('accounts', where: 'id = ?', whereArgs: [newTx.toAccountId]);
        if (newDestMap.isNotEmpty) {
          final newDestAcc = Account.fromMap(newDestMap.first);
          await txn.update(
            'accounts',
            newDestAcc.copyWith(balance: newDestAcc.balance + newTx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [newTx.toAccountId],
          );
        }
      } else {
        // Apply normal transaction
        final newAccMap = await txn.query('accounts', where: 'id = ?', whereArgs: [newTx.accountId]);
        if (newAccMap.isNotEmpty) {
          final newAcc = Account.fromMap(newAccMap.first);
          final finalBalance = newTx.type == 'income'
              ? newAcc.balance + newTx.amount
              : newAcc.balance - newTx.amount;
          await txn.update(
            'accounts',
            newAcc.copyWith(balance: finalBalance).toMap(),
            where: 'id = ?',
            whereArgs: [newTx.accountId],
          );
        }
      }

      // 3. UPDATE TRANSACTION RECORD
      return await txn.update(
        'transactions',
        newTx.toMap(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );
    });
  }

  Future<int> deleteTransaction(TransactionModel tx) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      if (tx.type == 'transfer' && tx.toAccountId != null) {
        // Revert source account (add amount back)
        final srcAccountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
        if (srcAccountMap.isNotEmpty) {
          final srcAccount = Account.fromMap(srcAccountMap.first);
          await txn.update(
            'accounts',
            srcAccount.copyWith(balance: srcAccount.balance + tx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [tx.accountId],
          );
        }
        // Revert destination account (subtract amount)
        final destAccountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.toAccountId]);
        if (destAccountMap.isNotEmpty) {
          final destAccount = Account.fromMap(destAccountMap.first);
          await txn.update(
            'accounts',
            destAccount.copyWith(balance: destAccount.balance - tx.amount).toMap(),
            where: 'id = ?',
            whereArgs: [tx.toAccountId],
          );
        }
      } else {
        // Revert normal transaction
        final accountMap = await txn.query('accounts', where: 'id = ?', whereArgs: [tx.accountId]);
        if (accountMap.isNotEmpty) {
          final account = Account.fromMap(accountMap.first);
          final newBalance = tx.type == 'income'
              ? account.balance - tx.amount
              : account.balance + tx.amount;

          await txn.update(
            'accounts',
            account.copyWith(balance: newBalance).toMap(),
            where: 'id = ?',
            whereArgs: [tx.accountId],
          );
        }
      }

      // Delete transaction
      return await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );
    });
  }

  // --- BUDGETS CRUD ---
  Future<String> createOrUpdateBudget(Budget budget) async {
    final db = await instance.database;
    final existing = await db.query(
      'budgets',
      where: 'category_id = ? AND month = ?',
      whereArgs: [budget.categoryId, budget.month],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return existing.first['id'] as String;
    } else {
      await db.insert('budgets', budget.toMap());
      return budget.id;
    }
  }

  Future<List<Budget>> getBudgetsByMonth(String month) async {
    final db = await instance.database;
    final result = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
    );
    return result.map((json) => Budget.fromMap(json)).toList();
  }

  Future<int> deleteBudget(String id) async {
    final db = await instance.database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- BACKUP & RESTORE UTILITIES ---

  // Get the path of the backup file in application documents directory
  Future<String> getBackupDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return join(directory.path, 'backups', 'personal_finance_backup.db');
  }

  // Check if a backup file exists in the application documents directory
  Future<bool> hasBackupFile() async {
    try {
      final path = await getBackupDatabasePath();
      return await File(path).exists();
    } catch (e) {
      debugPrint('Error checking backup file existence: $e');
      return false;
    }
  }

  // Get details (modification date and size) of the backup file
  Future<Map<String, dynamic>?> getBackupFileDetails() async {
    try {
      final path = await getBackupDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        return {
          'lastModified': stat.modified,
          'size': stat.size,
        };
      }
    } catch (e) {
      debugPrint('Error getting backup file details: $e');
    }
    return null;
  }

  // Verify if a file is a valid SQLite 3 database file
  Future<bool> isValidSqliteFile(File file) async {
    try {
      if (!await file.exists()) return false;
      final bytes = await file.openRead(0, 16).first;
      if (bytes.length < 16) return false;
      final header = String.fromCharCodes(bytes.take(15));
      return header == "SQLite format 3" && bytes[15] == 0;
    } catch (e) {
      debugPrint('Error validating SQLite file: $e');
      return false;
    }
  }

  // Safe backup of active database to backups directory
  Future<bool> backupDatabase() async {
    try {
      final dbPath = await getDatabasePath();
      final backupPath = await getBackupDatabasePath();
      
      // Close database to ensure all writes are flushed
      await closeDatabase();
      
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final backupFile = File(backupPath);
        // Ensure backups directory exists
        await backupFile.parent.create(recursive: true);
        await dbFile.copy(backupPath);
        
        // Reopen database connection
        await database;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error backing up database: $e');
      // Attempt to reopen database if closed
      await database;
      return false;
    }
  }

  // Safe restore of database from backups directory
  Future<bool> restoreDatabase() async {
    try {
      final dbPath = await getDatabasePath();
      final backupPath = await getBackupDatabasePath();
      
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        // Close database first to unlock the file
        await closeDatabase();
        
        final dbFile = File(dbPath);
        await backupFile.copy(dbPath);
        
        // Reopen database connection
        await database;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error restoring database: $e');
      // Attempt to reopen database if closed
      await database;
      return false;
    }
  }
}
