import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/category_model.dart';
import '../models/account_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';
import 'add_transaction_view.dart';

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate search query if any
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Hapus Filter',
            onPressed: () {
              final provider = Provider.of<FinanceProvider>(context, listen: false);
              provider.clearFilters();
              _searchController.clear();
            },
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          final groupedTx = provider.groupedTransactions;
          final List<DateTime> sortedDates = groupedTx.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              // 1. Month Selector Header
              _buildMonthSelector(context, provider),

              // 2. Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => provider.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Cari deskripsi, kategori, atau nominal...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // 3. Horizontal Account Filter
              _buildAccountFilterList(context, provider),

              // 4. Horizontal Category Filter
              _buildCategoryFilterList(context, provider),

              const SizedBox(height: 8),

              // 5. Grouped Transactions List
              Expanded(
                child: sortedDates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 60,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak ada transaksi ditemukan.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Coba ganti filter atau tambahkan transaksi baru.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: provider.refreshData,
                        child: ListView.builder(
                          itemCount: sortedDates.length,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final txList = groupedTx[date]!;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateHelper.getRelativeDay(date),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.primaryColor : AppTheme.primaryDarkColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        DateHelper.formatSimple(date),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // List of transactions for this date
                                ...txList.map((tx) => _buildTransactionCard(context, tx, provider)),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Month Selector Widget
  Widget _buildMonthSelector(BuildContext context, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
        boxShadow: AppTheme.getShadow(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: provider.previousMonth,
          ),
          Text(
            DateHelper.formatMonthYear(provider.currentMonth),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: provider.nextMonth,
          ),
        ],
      ),
    );
  }

  // Account Horizontal Filtering Widget
  Widget _buildAccountFilterList(BuildContext context, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.accounts.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final Account? account = isAll ? null : provider.accounts[index - 1];
          final isSelected = isAll 
              ? provider.selectedAccountId == null 
              : provider.selectedAccountId == account!.id;
          
          final String title = isAll ? 'Semua Akun' : account!.name;
          final Color themeColor = isAll 
              ? AppTheme.primaryColor 
              : Color(account!.colorCode);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: FilterChip(
              label: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: themeColor,
              checkmarkColor: Colors.white,
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              side: BorderSide(
                color: isSelected 
                    ? Colors.transparent 
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (selected) {
                provider.filterByAccount(isAll ? null : account!.id);
              },
            ),
          );
        },
      ),
    );
  }

  // Category Horizontal Filtering Widget
  Widget _buildCategoryFilterList(BuildContext context, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.categories.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final Category? category = isAll ? null : provider.categories[index - 1];
          final isSelected = isAll 
              ? provider.selectedCategoryId == null 
              : provider.selectedCategoryId == category!.id;

          final String title = isAll ? 'Semua Kategori' : category!.name;
          final Color themeColor = isAll 
              ? AppTheme.primaryColor 
              : Color(category!.colorCode);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: FilterChip(
              label: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: themeColor,
              checkmarkColor: Colors.white,
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              side: BorderSide(
                color: isSelected 
                    ? Colors.transparent 
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (selected) {
                provider.filterByCategory(isAll ? null : category!.id);
              },
            ),
          );
        },
      ),
    );
  }

  // Transaction Item Widget with slider-delete
  Widget _buildTransactionCard(BuildContext context, dynamic tx, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTransfer = tx.type == 'transfer';
    
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

    final account = provider.accounts.firstWhere(
      (a) => a.id == tx.accountId,
      orElse: () => Account(
        id: '',
        name: 'Akun',
        balance: 0,
        colorCode: 0xFF9E9E9E,
      ),
    );

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

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Transaksi?'),
            content: const Text('Apakah Anda yakin ingin menghapus catatan transaksi ini? Saldo dompet Anda akan disesuaikan kembali.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        provider.deleteTransactionDetails(tx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dihapus.')),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.expenseColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 26,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
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
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            
            // Description & Account Tag
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
                            fontSize: 9,
                            color: Color(account.colorCode),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isTransfer ? 'Transfer' : category.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      if (tx.imagePath != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.attach_file_rounded,
                          size: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Amount
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionView(transaction: tx),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    '$amountPrefix${CurrencyHelper.format(tx.amount).replaceFirst('Rp ', '')}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
