import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/security_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../utils/helpers.dart';
import 'category_manage_view.dart';
import 'pin_lock_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  void _handlePinToggle(BuildContext context, SecurityProvider security) {
    if (security.isPinEnabled) {
      // Navigate to verify current PIN to disable it
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PinLockView(mode: PinLockMode.disable),
        ),
      );
    } else {
      // Navigate to setup PIN
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PinLockView(mode: PinLockMode.setup),
        ),
      );
    }
  }

  void _handleChangePin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PinLockView(mode: PinLockMode.change),
      ),
    );
  }

  Future<void> _handleBiometricToggle(
      BuildContext context, SecurityProvider security, bool enabled) async {
    if (enabled) {
      final isAvailable = await security.canUseBiometrics();
      if (isAvailable) {
        await security.enableBiometrics(true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autentikasi biometrik berhasil diaktifkan')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Perangkat tidak mendukung biometrik, atau sidik jari/wajah belum didaftarkan di pengaturan ponsel.',
              ),
            ),
          );
        }
      }
    } else {
      await security.enableBiometrics(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autentikasi biometrik dinonaktifkan')),
        );
      }
    }
  }

  void _showBackupRestoreDialog(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
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
              'Gunakan fitur ini untuk mengekspor database keuangan Anda atau mengimpor file backup sebelumnya.',
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
                      await financeProvider.refreshData();
                      
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
    final security = Provider.of<SecurityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Section: General Settings
          _buildSectionHeader('Umum'),
          ListTile(
            leading: _buildIconContainer(Icons.category_outlined, Colors.blue),
            title: const Text('Kelola Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Tambah, edit, atau hapus kategori keuangan Anda'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManageView(),
                ),
              );
            },
          ),
          const Divider(indent: 72, height: 1),
          
          ListTile(
            leading: _buildIconContainer(Icons.backup_outlined, Colors.green),
            title: const Text('Cadangkan & Pulihkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Ekspor/Impor seluruh database lokal KeuanganKu'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () => _showBackupRestoreDialog(context),
          ),
          
          const SizedBox(height: 24),
          
          // Section: Security Settings
          _buildSectionHeader('Keamanan & Privasi'),
          
          // Switch for PIN lock
          SwitchListTile(
            secondary: _buildIconContainer(Icons.pin_outlined, AppTheme.primaryColor),
            title: const Text('Kunci PIN Keamanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Minta PIN 4 digit untuk membuka aplikasi'),
            value: security.isPinEnabled,
            activeColor: AppTheme.primaryColor,
            onChanged: (_) => _handlePinToggle(context, security),
          ),
          const Divider(indent: 72, height: 1),

          // Change PIN Button
          if (security.isPinEnabled) ...[
            ListTile(
              leading: _buildIconContainer(Icons.lock_reset_outlined, Colors.orange),
              title: const Text('Ubah PIN Keamanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: const Text('Ganti kode PIN keamanan aktif saat ini'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _handleChangePin(context),
            ),
            const Divider(indent: 72, height: 1),
          ],

          // Switch for Biometrics lock
          SwitchListTile(
            secondary: _buildIconContainer(Icons.fingerprint_rounded, Colors.purple),
            title: const Text('Autentikasi Biometrik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Gunakan Sidik Jari atau Wajah sebagai alternatif PIN'),
            value: security.isBiometricsEnabled,
            activeColor: AppTheme.primaryColor,
            // Disabled if PIN lock is not enabled
            onChanged: security.isPinEnabled
                ? (val) => _handleBiometricToggle(context, security, val)
                : null,
          ),

          const SizedBox(height: 40),
          
          // App Version Footer
          Center(
            child: Text(
              'KeuanganKu v1.0.0',
              style: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}
