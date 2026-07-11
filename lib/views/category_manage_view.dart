import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';

class CategoryManageView extends StatefulWidget {
  const CategoryManageView({super.key});

  @override
  State<CategoryManageView> createState() => _CategoryManageViewState();
}

class _CategoryManageViewState extends State<CategoryManageView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<int> _colorPalette = [
    0xFF10B981, // Emerald Green
    0xFF059669, // Forest Green
    0xFF3B82F6, // Blue
    0xFF06B6D4, // Cyan
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
    0xFFF43F5E, // Rose Red
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber Orange
    0xFFD97706, // Brown
    0xFF64748B, // Slate Gray
    0xFF0F172A, // Charcoal
  ];

  final List<IconData> _iconPalette = [
    Icons.restaurant,
    Icons.directions_car,
    Icons.shopping_bag,
    Icons.sports_esports,
    Icons.receipt_long,
    Icons.medical_services,
    Icons.home,
    Icons.work,
    Icons.trending_up,
    Icons.card_giftcard,
    Icons.flight,
    Icons.school,
    Icons.local_grocery_store,
    Icons.fitness_center,
    Icons.movie,
    Icons.pets,
    Icons.phone_android,
    Icons.favorite,
    Icons.build,
    Icons.brush,
    Icons.more_horiz,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCategorySheet(BuildContext context, {Category? categoryToEdit}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    
    String selectedType = categoryToEdit?.type ?? (_tabController.index == 0 ? 'expense' : 'income');
    int selectedColor = categoryToEdit?.colorCode ?? _colorPalette.first;
    IconData selectedIcon = categoryToEdit != null 
        ? IconData(categoryToEdit.iconCode, fontFamily: 'MaterialIcons')
        : _iconPalette.first;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 
                24, 
                24, 
                MediaQuery.of(context).viewInsets.bottom + 24
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            categoryToEdit == null ? 'Buat Kategori Kustom' : 'Edit Kategori',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Nama Kategori',
                          hintText: 'Misal: Kopi, Laundry, Bonus',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama kategori tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Segmented type controller
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Pengeluaran')),
                              selected: selectedType == 'expense',
                              selectedColor: AppTheme.expenseColor,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: selectedType == 'expense' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedType = 'expense';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Pemasukan')),
                              selected: selectedType == 'income',
                              selectedColor: AppTheme.incomeColor,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: selectedType == 'income' ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedType = 'income';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pilih Warna',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Colors Palette Grid
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colorPalette.length,
                          itemBuilder: (context, index) {
                            final colorVal = _colorPalette[index];
                            final isSelected = selectedColor == colorVal;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedColor = colorVal;
                                });
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: Color(colorVal),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pilih Ikon',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      // Icons Grid
                      SizedBox(
                        height: 100,
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: _iconPalette.length,
                          itemBuilder: (context, index) {
                            final icon = _iconPalette[index];
                            final isSelected = selectedIcon.codePoint == icon.codePoint;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedIcon = icon;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Color(selectedColor).withOpacity(0.12)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Color(selectedColor), width: 1.5)
                                      : null,
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected ? Color(selectedColor) : Colors.grey[500],
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedType == 'income' ? AppTheme.incomeColor : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final name = nameController.text.trim();
                              
                              final provider = Provider.of<FinanceProvider>(context, listen: false);
                              if (categoryToEdit == null) {
                                provider.addCategory(name, selectedIcon.codePoint, selectedColor, selectedType);
                              } else {
                                provider.updateCategoryDetails(
                                  Category(
                                    id: categoryToEdit.id,
                                    name: name,
                                    iconCode: selectedIcon.codePoint,
                                    colorCode: selectedColor,
                                    type: selectedType,
                                    isDefault: categoryToEdit.isDefault,
                                  ),
                                );
                              }
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            categoryToEdit == null ? 'Simpan Kategori' : 'Simpan Perubahan',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
        ),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          final expenseCategories = provider.categories.where((c) => c.type == 'expense').toList();
          final incomeCategories = provider.categories.where((c) => c.type == 'income').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryGrid(context, expenseCategories, provider),
              _buildCategoryGrid(context, incomeCategories, provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCategorySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryGrid(
      BuildContext context, List<Category> categories, FinanceProvider provider) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (categories.isEmpty) {
      return const Center(
        child: Text('Belum ada kategori.', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final Color color = Color(cat.colorCode);

        return GestureDetector(
          onLongPress: () {
            // Options sheet for Custom Categories
            if (!cat.isDefault) {
              _showOptionsDialog(context, cat, provider);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kategori bawaan sistem tidak dapat diubah atau dihapus.'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }
          },
          onTap: () {
            if (!cat.isDefault) {
              _showAddCategorySheet(context, categoryToEdit: cat);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kategori bawaan sistem tidak dapat diubah atau dihapus.'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              boxShadow: AppTheme.getShadow(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Text(
                    cat.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (cat.isDefault) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Sistem',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptionsDialog(BuildContext context, Category category, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Kategori "${category.name}"?'),
        content: const Text(
          'Seluruh transaksi yang terhubung dengan kategori ini akan dihapus secara permanen. Apakah Anda yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              provider.deleteCategoryDetails(category.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kategori "${category.name}" berhasil dihapus.')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
