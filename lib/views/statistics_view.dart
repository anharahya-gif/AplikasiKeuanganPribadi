import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../models/category_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';

class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  bool _isExpense = true;
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Analisis'),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          // Get data based on type (income or expense)
          final Map<Category, double> breakdown = _getBreakdownData(provider);
          final double totalAmount = breakdown.values.fold(0.0, (sum, val) => sum + val);

          return Column(
            children: [
              // 1. Month Selector
              _buildMonthSelector(context, provider),

              // 2. Type Selector (Pengeluaran vs Pemasukan)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeTab(
                          label: 'Pengeluaran',
                          isSelected: _isExpense,
                          activeColor: AppTheme.expenseColor,
                          onTap: () => setState(() {
                            _isExpense = true;
                            _touchedIndex = -1;
                          }),
                        ),
                      ),
                      Expanded(
                        child: _buildTypeTab(
                          label: 'Pemasukan',
                          isSelected: !_isExpense,
                          activeColor: AppTheme.incomeColor,
                          onTap: () => setState(() {
                            _isExpense = false;
                            _touchedIndex = -1;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Main Chart & Legend View
              Expanded(
                child: totalAmount == 0.0
                    ? _buildEmptyState(context, isDark)
                    : RefreshIndicator(
                        onRefresh: provider.refreshData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                          children: [
                            // Pie chart display
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse
                                            .touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 50,
                                  sections: _buildPieChartSections(breakdown, totalAmount),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Center Total Indicator
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    _isExpense ? 'TOTAL PENGELUARAN' : 'TOTAL PEMASUKAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyHelper.format(totalAmount),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      color: _isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Detailed category items breakdown
                            Text(
                              'RINCIAN KATEGORI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // Sorted breakdown list
                            ..._buildBreakdownList(context, breakdown, totalAmount, isDark),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Get data grouped by category based on selected filters
  Map<Category, double> _getBreakdownData(FinanceProvider provider) {
    final Map<Category, double> breakdown = {};
    final transactions = provider.filteredTransactions.where(
      (tx) => tx.type == (_isExpense ? 'expense' : 'income')
    );

    for (var tx in transactions) {
      final category = provider.categories.firstWhere(
        (c) => c.id == tx.categoryId,
        orElse: () => Category(
          id: 'other',
          name: 'Lainnya',
          iconCode: Icons.more_horiz.codePoint,
          colorCode: 0xFF9E9E9E,
          type: _isExpense ? 'expense' : 'income',
        ),
      );

      breakdown[category] = (breakdown[category] ?? 0.0) + tx.amount;
    }

    // Sort by value descending
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }

  // Build the slices of the Pie Chart
  List<PieChartSectionData> _buildPieChartSections(Map<Category, double> breakdown, double total) {
    int index = 0;
    return breakdown.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final percentage = (amount / total) * 100;
      final isTouched = index == _touchedIndex;
      final double radius = isTouched ? 65.0 : 55.0;
      final double fontSize = isTouched ? 16.0 : 12.0;

      final section = PieChartSectionData(
        color: Color(category.colorCode),
        value: amount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))
          ],
        ),
      );
      index++;
      return section;
    }).toList();
  }

  // Build list of category rows
  List<Widget> _buildBreakdownList(
      BuildContext context, Map<Category, double> breakdown, double total, bool isDark) {
    int index = 0;
    return breakdown.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final percentage = total > 0 ? (amount / total) * 100 : 0.0;
      final isTouched = index == _touchedIndex;
      index++;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTouched 
              ? Color(category.colorCode).withOpacity(0.08)
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTouched
                ? Color(category.colorCode)
                : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            width: isTouched ? 1.5 : 1,
          ),
          boxShadow: AppTheme.getShadow(context),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(category.colorCode).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconData(category.iconCode, fontFamily: 'MaterialIcons'),
                color: Color(category.colorCode),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Name & Percent
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(category.colorCode).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(category.colorCode),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Value
            Text(
              CurrencyHelper.format(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.lightTextPrimary,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 80,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tidak ada data statistik.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _isExpense 
                ? 'Belum ada pengeluaran di bulan ini.' 
                : 'Belum ada pemasukan di bulan ini.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Type tab selector
  Widget _buildTypeTab({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
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
