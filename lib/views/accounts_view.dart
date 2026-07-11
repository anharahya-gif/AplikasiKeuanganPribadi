import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/finance_provider.dart';
import '../models/account_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';

class AccountsView extends StatefulWidget {
  const AccountsView({super.key});

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  final List<int> _colorPalette = [
    0xFF2563EB, // Sapphire Blue
    0xFF10B981, // Emerald Green
    0xFFF59E0B, // Amber Gold
    0xFFEF4444, // Ruby Red
    0xFF8B5CF6, // Amethyst Purple
    0xFFEC4899, // Rose Pink
    0xFF06B6D4, // Cyan
    0xFF64748B, // Slate Grey
  ];

  void _showAddAccountSheet(BuildContext context, {Account? accountToEdit}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat.decimalPattern('id');
    final nameController = TextEditingController(text: accountToEdit?.name ?? '');
    final balanceController = TextEditingController(
      text: accountToEdit != null ? formatter.format(accountToEdit.balance.toInt()) : '',
    );
    final adminFeeController = TextEditingController(
      text: accountToEdit != null && accountToEdit.adminFee > 0 
          ? formatter.format(accountToEdit.adminFee.toInt()) 
          : '',
    );
    int selectedColor = accountToEdit?.colorCode ?? _colorPalette.first;
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          accountToEdit == null ? 'Tambah Akun / Dompet' : 'Edit Akun',
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nama Akun',
                        hintText: 'Misal: Bank BCA, Dompet Tunai',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama akun tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        IndCurrencyInputFormatter(),
                      ],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: accountToEdit == null ? 'Saldo Awal' : 'Saldo Saat Ini',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Saldo tidak boleh kosong';
                        }
                        final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
                        if (double.tryParse(cleanVal) == null) {
                          return 'Masukkan angka yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: adminFeeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        IndCurrencyInputFormatter(),
                      ],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Biaya Admin Bulanan (Opsional)',
                        prefixText: 'Rp ',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
                          if (double.tryParse(cleanVal) == null || double.parse(cleanVal) < 0) {
                            return 'Masukkan nominal yang valid';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        'Jika diisi, potongan biaya admin bulanan akan tercatat otomatis setiap bulan baru.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pilih Warna Dompet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Color selection grid
                    SizedBox(
                      height: 50,
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
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: Color(colorVal),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: isDark ? Colors.white : Colors.black,
                                        width: 3,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Color(colorVal).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final name = nameController.text.trim();
                            final cleanBalStr = balanceController.text.replaceAll(RegExp(r'[^0-9]'), '');
                            final balance = double.parse(cleanBalStr);
                            final cleanFeeStr = adminFeeController.text.replaceAll(RegExp(r'[^0-9]'), '');
                            final adminFee = cleanFeeStr.isEmpty
                                ? 0.0
                                : double.parse(cleanFeeStr);
                            
                            final provider = Provider.of<FinanceProvider>(context, listen: false);
                            if (accountToEdit == null) {
                              provider.addAccount(name, balance, selectedColor, adminFee: adminFee);
                            } else {
                              provider.updateAccountDetails(
                                accountToEdit.copyWith(
                                  name: name,
                                  balance: balance,
                                  colorCode: selectedColor,
                                  adminFee: adminFee,
                                ),
                              );
                            }
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          accountToEdit == null ? 'Tambah Akun' : 'Simpan Perubahan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBackupRestoreDialog(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Text('Cadangkan & Pulihkan Data', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gunakan fitur ini untuk mencadangkan data keuangan Anda sebelum mengganti perangkat atau memulihkan data lama.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // Backup button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Cadangkan Data (Ekspor)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                try {
                  final dbPath = await DbHelper.instance.getDatabasePath();
                  final file = File(dbPath);
                  
                  if (await file.exists()) {
                    await Share.shareXFiles(
                      [XFile(dbPath)],
                      text: 'Backup KeuanganKu - ${DateHelper.formatSimple(DateTime.now())}',
                    );
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File database tidak ditemukan!')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal melakukan backup: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            
            // Restore button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: const Text('Pulihkan Data (Impor)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                
                // Confirm dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Pulihkan Data?'),
                    content: const Text('PERINGATAN: Memulihkan data akan menimpa seluruh data keuangan Anda saat ini dengan file backup pilihan Anda. Proses ini tidak dapat dibatalkan.'),
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
                        child: const Text('Pulihkan'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    // Pick file
                    final result = await FilePicker.pickFiles(
                      type: FileType.any,
                    );
                    
                    if (result != null && result.files.single.path != null) {
                      final pickedPath = result.files.single.path!;
                      
                      // Close current DB
                      await DbHelper.instance.closeDatabase();
                      
                      // Overwrite DB file
                      final dbPath = await DbHelper.instance.getDatabasePath();
                      final backupFile = File(pickedPath);
                      await backupFile.copy(dbPath);
                      
                      // Reload provider
                      await provider.refreshData();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data berhasil dipulihkan dengan sukses!')),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memulihkan data: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Dompet & Akun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            tooltip: 'Cadangkan & Pulihkan Data',
            onPressed: () => _showBackupRestoreDialog(context),
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Total net balance across all accounts
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                  boxShadow: AppTheme.getShadow(context),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL KEKAYAAN BERSIH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyHelper.format(provider.totalBalance),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Dompet Anda (${provider.accounts.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah'),
                      onPressed: () => _showAddAccountSheet(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Wallets list
              Expanded(
                child: provider.accounts.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada akun terdaftar.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.accounts.length,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemBuilder: (context, index) {
                          final account = provider.accounts[index];
                          final Color accColor = Color(account.colorCode);

                          return Dismissible(
                            key: Key(account.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              // If this is the only account, don't allow delete
                              if (provider.accounts.length <= 1) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Anda harus menyisakan minimal satu akun utama.'),
                                    backgroundColor: AppTheme.expenseColor,
                                  ),
                                );
                                return false;
                              }
                              
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Hapus Akun?'),
                                  content: Text(
                                    'Menghapus akun "${account.name}" akan menghapus seluruh data transaksi yang menggunakan akun ini secara permanen. Apakah Anda yakin?',
                                  ),
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
                              provider.deleteAccountDetails(account.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Akun "${account.name}" berhasil dihapus.')),
                              );
                            },
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: AppTheme.expenseColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
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
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: accColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyHelper.format(account.balance),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        if (account.adminFee > 0) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Biaya Admin Bulanan: ${CurrencyHelper.format(account.adminFee)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.orange[300] : Colors.orange[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showAddAccountSheet(
                                      context,
                                      accountToEdit: account,
                                    ),
                                  ),
                                ],
                              ),
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
}
