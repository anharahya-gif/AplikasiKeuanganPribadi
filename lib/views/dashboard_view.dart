import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/finance_provider.dart';
import '../models/category_model.dart';
import '../models/account_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';
import 'accounts_view.dart';
import 'settings_view.dart';
import 'add_transaction_view.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Consumer<FinanceProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: provider.refreshData,
              child: CustomScrollView(
                slivers: [
                  // App Bar / Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, Selamat Datang 👋',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kelola Keuanganmu',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          // Premium Quick Settings or Profile Circle
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsView(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                ),
                                boxShadow: AppTheme.getShadow(context),
                              ),
                              child: Icon(
                                Icons.settings_outlined,
                                color: Theme.of(context).primaryColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main Balance Card (Glassmorphic & Gradient)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: _buildBalanceCard(context, provider),
                    ),
                  ),

                  // Accounts / Wallets Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dompet & Rekening',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AccountsView(),
                                ),
                              );
                            },
                            child: const Text('Detail'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Accounts Horizontal List
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.accounts.length,
                        itemBuilder: (context, index) {
                          final account = provider.accounts[index];
                          return _buildAccountItem(context, account);
                        },
                      ),
                    ),
                  ),

                  // Budgets Breakdown Alert / Section
                  if (provider.budgets.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                        child: Text(
                          'Anggaran Bulan Ini',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildBudgetOverview(context, provider),
                      ),
                    ),
                  ],

                  // Recent Transactions Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaksi Terbaru',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transactions List
                  if (provider.filteredTransactions.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Belum ada transaksi di bulan ini.\nTekan tombol + di bawah untuk menambahkan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildListDelegate(
                        provider.filteredTransactions.take(5).map((tx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                            child: _buildTransactionTile(context, tx, provider),
                          );
                        }).toList(),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100), // Padding bottom for floating action button
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget: Balance Card with modern look
  Widget _buildBalanceCard(BuildContext context, FinanceProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
            const Color(0xFF3F3D56),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative background pattern (handmade overlapping circles)
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            
            // Card Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL SALDO',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyHelper.format(provider.totalBalance),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Income and Expense indicators
                  Row(
                    children: [
                      // Income Row
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Color(0xFF4ADE80), // Light green
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pemasukan',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      CurrencyHelper.format(provider.totalIncomeForMonth),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Expense Row
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFFB7185), // Light red
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pengeluaran',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      CurrencyHelper.format(provider.totalExpenseForMonth),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Account Card for horizontal list
  Widget _buildAccountItem(BuildContext context, dynamic account) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accColor = Color(account.colorCode);

    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              Text(
                CurrencyHelper.format(account.balance),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget: Budget overview row
  Widget _buildBudgetOverview(BuildContext context, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate total monthly budget vs total monthly spending
    double totalBudgetLimit = provider.budgets.fold(0.0, (sum, b) => sum + b.amount);
    
    // Spend on budget categories
    double totalBudgetSpent = 0.0;
    for (var b in provider.budgets) {
      totalBudgetSpent += provider.getExpenseForCategory(b.categoryId);
    }
    
    double progress = totalBudgetLimit > 0 ? (totalBudgetSpent / totalBudgetLimit) : 0.0;
    if (progress > 1.0) progress = 1.0;
    
    final Color progressColor = progress >= 0.9 
        ? AppTheme.expenseColor 
        : progress >= 0.75 
            ? Colors.orange 
            : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batas Pengeluaran',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyHelper.format(totalBudgetSpent),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'dari ${CurrencyHelper.format(totalBudgetLimit)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // Widget: Transaction list tile
  Widget _buildTransactionTile(BuildContext context, dynamic tx, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTransfer = tx.type == 'transfer';
    
    // Find category
    final category = provider.categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => Category(
        id: '',
        name: 'Lainnya',
        iconCode: Icons.help_outline.codePoint,
        colorCode: 0xFF9E9E9E,
        type: 'expense',
      ),
    );

    // Find source account
    final account = provider.accounts.firstWhere(
      (a) => a.id == tx.accountId,
      orElse: () => Account(
        id: '',
        name: 'Akun',
        balance: 0,
        colorCode: 0xFF9E9E9E,
      ),
    );

    // Find destination account (only if transfer)
    Account? toAccount;
    if (isTransfer && tx.toAccountId != null) {
      toAccount = provider.accounts.firstWhere(
        (a) => a.id == tx.toAccountId,
        orElse: () => Account(
          id: '',
          name: 'Tujuan',
          balance: 0,
          colorCode: 0xFF9E9E9E,
        ),
      );
    }

    // Determine details & display
    String title = tx.description.isNotEmpty ? tx.description : category.name;
    if (isTransfer) {
      if (tx.description.isNotEmpty) {
        title = tx.description;
      } else if (toAccount != null) {
        title = 'Transfer: ${account.name} ➔ ${toAccount.name}';
      } else {
        title = 'Transfer Uang';
      }
    }

    final IconData iconData = isTransfer 
        ? Icons.swap_horiz_rounded 
        : IconData(category.iconCode, fontFamily: 'MaterialIcons');
        
    final Color iconColor = isTransfer 
        ? Colors.orange 
        : Color(category.colorCode);

    // Determine prefix and color
    String amountPrefix = '';
    Color amountColor;
    
    if (isTransfer) {
      amountColor = Colors.orange;
      if (provider.selectedAccountId == tx.accountId) {
        amountPrefix = '-';
        amountColor = AppTheme.expenseColor;
      } else if (provider.selectedAccountId == tx.toAccountId) {
        amountPrefix = '+';
        amountColor = AppTheme.incomeColor;
      } else {
        amountPrefix = '⇌ ';
      }
    } else {
      final bool isIncome = tx.type == 'income';
      amountPrefix = isIncome ? '+' : '-';
      amountColor = isIncome ? AppTheme.incomeColor : (isDark ? Colors.white : AppTheme.lightTextPrimary);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddTransactionView(transaction: tx),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
          boxShadow: AppTheme.getShadow(context),
        ),
        child: Row(
          children: [
            // Category / Transfer Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(account.colorCode).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isTransfer && toAccount != null 
                              ? '${account.name} ➔ ${toAccount.name}' 
                              : account.name,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(account.colorCode),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateHelper.getRelativeDay(tx.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      if (tx.imagePath != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.attach_file_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Amount
            Text(
              '$amountPrefix${CurrencyHelper.format(tx.amount).replaceFirst('Rp ', '')}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
