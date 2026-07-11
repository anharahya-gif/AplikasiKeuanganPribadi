import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/category_model.dart';
import '../models/budget_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';

class BudgetView extends StatefulWidget {
  const BudgetView({super.key});

  @override
  State<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<BudgetView> {
  
  void _showSetBudgetDialog(BuildContext context, Category category, Budget? currentBudget) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat.decimalPattern('id');
    final controller = TextEditingController(
      text: currentBudget != null ? formatter.format(currentBudget.amount.toInt()) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(category.colorCode).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                  color: Color(category.colorCode),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Anggaran ${category.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atur batas maksimum pengeluaran untuk kategori ini di bulan aktif.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    IndCurrencyInputFormatter(),
                  ],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Batas Bulanan',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan nominal budget';
                    }
                    final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (double.tryParse(cleanVal) == null || double.parse(cleanVal) <= 0) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (currentBudget != null)
              TextButton(
                onPressed: () {
                  final provider = Provider.of<FinanceProvider>(context, listen: false);
                  provider.deleteBudgetDetails(currentBudget.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Anggaran ${category.name} dihapus.')),
                  );
                },
                child: const Text('Hapus', style: TextStyle(color: AppTheme.expenseColor)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final cleanStr = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final limit = double.parse(cleanStr);
                  final provider = Provider.of<FinanceProvider>(context, listen: false);
                  provider.setBudget(category.id, limit);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Anggaran ${category.name} berhasil disimpan.')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batas Anggaran Bulanan'),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          // Budgets are only set for expense categories
          final expenseCategories = provider.categories.where((c) => c.type == 'expense').toList();

          return Column(
            children: [
              // Month Selector Header
              _buildMonthSelector(context, provider),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Geser/Tap kategori pengeluaran di bawah ini untuk mengatur batas anggaran belanja Anda.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Categories Budget List
              Expanded(
                child: expenseCategories.isEmpty
                    ? const Center(
                        child: Text(
                          'Kategori pengeluaran kosong.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: expenseCategories.length,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        itemBuilder: (context, index) {
                          final category = expenseCategories[index];
                          
                          // Find budget for this category
                          final Budget budget = provider.budgets.firstWhere(
                            (b) => b.categoryId == category.id,
                            orElse: () => Budget(id: '', categoryId: '', amount: -1, month: ''),
                          );
                          final hasBudget = budget.amount != -1;
                          
                          // Find expense for this category in current month
                          final double spent = provider.getExpenseForCategory(category.id);
                          final double budgetLimit = hasBudget ? budget.amount : 0.0;
                          
                          double progress = budgetLimit > 0 ? (spent / budgetLimit) : 0.0;
                          if (progress > 1.0) progress = 1.0;
                          
                          final Color progressColor = progress >= 1.0 
                              ? AppTheme.expenseColor 
                              : progress >= 0.8 
                                  ? Colors.orange 
                                  : Color(category.colorCode);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                              ),
                              boxShadow: AppTheme.getShadow(context),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Icon
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Color(category.colorCode).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                                        color: Color(category.colorCode),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Name
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    // Budget Limit Display & Action
                                    hasBudget
                                        ? TextButton.icon(
                                            icon: const Icon(Icons.edit_outlined, size: 14),
                                            label: Text(
                                              CurrencyHelper.format(budgetLimit),
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: progress >= 1.0 
                                                    ? AppTheme.expenseColor 
                                                    : Theme.of(context).primaryColor,
                                              ),
                                            ),
                                            onPressed: () => _showSetBudgetDialog(context, category, budget),
                                          )
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                              foregroundColor: AppTheme.primaryColor,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () => _showSetBudgetDialog(context, category, null),
                                            child: const Text('Atur Batas', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          ),
                                  ],
                                ),
                                if (hasBudget) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Terpakai: ${CurrencyHelper.format(spent)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Sisa: ${CurrencyHelper.format(budgetLimit - spent >= 0 ? budgetLimit - spent : 0.0)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: budgetLimit - spent < 0 
                                              ? AppTheme.expenseColor 
                                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                  if (spent > budgetLimit) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: AppTheme.expenseColor, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Peringatan: Pengeluaran melebihi batas anggaran sebesar ${CurrencyHelper.format(spent - budgetLimit)}!',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.expenseColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]
                                ],
                              ],
                            ),
                          );
                        },
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
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}
