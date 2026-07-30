import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final backupDetails = financeProvider.localBackupDetails;
            final bool hasLocalBackup = backupDetails != null;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              title: const Row(
                children: [
                  Icon(Icons.backup_outlined, color: AppTheme.primaryColor),
                  SizedBox(width: 10),
                  Text('Cadangkan & Pulihkan', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PART 1: LOCAL BACKUP
                    Text(
                      'CADANGAN LOKAL (FOLDER TERPISAH)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Menyimpan salinan database di folder dokumen aplikasi agar aman jika database utama terhapus/rusak.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    
                    // Backup status box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasLocalBackup 
                            ? Colors.green.withOpacity(0.08) 
                            : Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasLocalBackup 
                              ? Colors.green.withOpacity(0.2) 
                              : Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasLocalBackup ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            color: hasLocalBackup ? Colors.green : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasLocalBackup ? 'Cadangan Lokal Tersedia' : 'Belum Ada Cadangan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: hasLocalBackup ? Colors.green : Colors.orange,
                                  ),
                                ),
                                if (hasLocalBackup) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Waktu: ${DateHelper.formatSimple(backupDetails['lastModified'] as DateTime)} ${DateFormat('HH:mm').format(backupDetails['lastModified'] as DateTime)}',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                  Text(
                                    'Ukuran: ${((backupDetails['size'] as int) / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () async {
                              final success = await financeProvider.createLocalBackup();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success 
                                        ? 'Cadangan lokal berhasil dibuat!' 
                                        : 'Gagal membuat cadangan lokal!'),
                                  ),
                                );
                              }
                              setStateDialog(() {});
                            },
                            child: const Text('Cadangkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(
                                color: hasLocalBackup ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: !hasLocalBackup ? null : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Pulihkan Cadangan Lokal?'),
                                  content: const Text('PERINGATAN: Seluruh data saat ini akan ditimpa oleh data cadangan lokal Anda. Tindakan ini tidak dapat dibatalkan.'),
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
                                final success = await financeProvider.restoreFromLocalBackup();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success 
                                          ? 'Data berhasil dipulihkan dari cadangan lokal!' 
                                          : 'Gagal memulihkan data!'),
                                    ),
                                  );
                                  Navigator.pop(context); // Close backup dialog
                                }
                              }
                            },
                            child: const Text('Pulihkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    
                    // PART 2: EXTERNAL EXPORT/IMPORT
                    Text(
                      'EKSPOR & IMPOR EKSTERNAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ekspor database ke file luar untuk dipindahkan ke HP lain, atau impor file database eksternal.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3F3D56),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              try {
                                final dbPath = await DbHelper.instance.getDatabasePath();
                                final file = File(dbPath);
                                
                                if (await file.exists()) {
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      files: [XFile(dbPath)],
                                      text: 'Cadangan Database KeuanganKu - ${DateHelper.formatSimple(DateTime.now())}',
                                    ),
                                  );
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('File database utama tidak ditemukan!')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal mengekspor data: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3F3D56),
                              side: const BorderSide(color: Color(0xFF3F3D56)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.file_open_outlined, size: 16),
                            label: const Text('Impor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Impor File Database?'),
                                  content: const Text('PERINGATAN: Memilih file database eksternal akan menimpa seluruh data saat ini. Pastikan file yang diimpor adalah file database KeuanganKu yang valid.'),
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
                                      child: const Text('Impor'),
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
                                    
                                    final success = await financeProvider.importDatabase(pickedPath);
                                    if (context.mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Database berhasil diimpor dengan sukses!')),
                                        );
                                        Navigator.pop(context); // Close backup dialog
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Gagal impor: File yang dipilih bukan database SQLite KeuanganKu yang valid!'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Terjadi kesalahan: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
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
