import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/account_model.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';
import 'category_manage_view.dart';
import 'image_viewer_view.dart';

class AddTransactionView extends StatefulWidget {
  final TransactionModel? transaction; // If not null, edit mode

  const AddTransactionView({super.key, this.transaction});

  @override
  State<AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<AddTransactionView> {
  final _formKey = GlobalKey<FormState>();
  
  late String _selectedType; // 'expense', 'income', 'transfer'
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId; // Destination for transfer
  
  // Image attachments variables
  File? _tempPickedFile; // New image picked during this session
  String? _existingImagePath; // Image already saved from DB
  bool _imageRemoved = false; // Flag if user deleted the photo

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    
    _selectedType = tx?.type ?? 'expense';
    final formatter = NumberFormat.decimalPattern('id');
    _amountController = TextEditingController(
      text: tx != null ? formatter.format(tx.amount.toInt()) : '',
    );
    _descriptionController = TextEditingController(text: tx?.description ?? '');
    _selectedDate = tx?.date ?? DateTime.now();
    _selectedCategoryId = tx?.categoryId;
    _selectedAccountId = tx?.accountId;
    _selectedToAccountId = tx?.toAccountId;
    _existingImagePath = tx?.imagePath;
    
    // Select default accounts if adding new
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      
      if (tx == null) {
        if (provider.accounts.isNotEmpty) {
          setState(() {
            _selectedAccountId = provider.accounts.first.id;
            
            // Set default destination account (different from source)
            if (provider.accounts.length > 1) {
              _selectedToAccountId = provider.accounts[1].id;
            }
          });
        }
      }
      
      // Select first category matching type
      _setDefaultCategoryForType(provider);
    });
  }

  void _setDefaultCategoryForType(FinanceProvider provider) {
    if (_selectedType == 'transfer') return;
    
    final matchingCats = provider.categories.where(
      (c) => c.type == _selectedType
    ).toList();
    
    if (matchingCats.isNotEmpty) {
      // Keep selected category if it matches the current type
      final currentSelected = provider.categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => Category(id: '', name: '', iconCode: 0, colorCode: 0, type: ''),
      );
      
      if (currentSelected.type != _selectedType) {
        setState(() {
          _selectedCategoryId = matchingCats.first.id;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        setState(() {
          _tempPickedFile = File(pickedFile.path);
          _imageRemoved = false;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal membuka kamera/galeri: $e")),
      );
    }
  }

  Future<String?> _saveLocalImage() async {
    // If user clicked remove
    if (_imageRemoved) {
      if (_existingImagePath != null) {
        try {
          final file = File(_existingImagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint("Error deleting old image: $e");
        }
      }
      return null;
    }

    // If there is a new photo picked
    if (_tempPickedFile != null) {
      // Revert/Delete previous saved file if any
      if (_existingImagePath != null) {
        try {
          final file = File(_existingImagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint("Error deleting old replaced image: $e");
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      final folderPath = p.join(appDir.path, 'attachments');
      await Directory(folderPath).create(recursive: true);

      final extension = p.extension(_tempPickedFile!.path).isEmpty 
          ? '.jpg' 
          : p.extension(_tempPickedFile!.path);
      final filename = 'tx_${const Uuid().v4()}$extension';
      final savePath = p.join(folderPath, filename);

      // Copy file to persistent application folder
      final File savedFile = await _tempPickedFile!.copy(savePath);
      return savedFile.path;
    }

    // No changes
    return _existingImagePath;
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    if (_selectedType != 'transfer' && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih kategori')),
      );
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih dompet asal')),
      );
      return;
    }
    if (_selectedType == 'transfer' && _selectedToAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih dompet tujuan')),
      );
      return;
    }
    if (_selectedType == 'transfer' && _selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dompet asal dan tujuan tidak boleh sama')),
      );
      return;
    }

    // Save image to local directory
    final savedImagePath = await _saveLocalImage();

    final cleanAmountStr = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.parse(cleanAmountStr);
    final description = _descriptionController.text.trim();

    // Setup category for transfer to fulfill SQLite constraints
    String categoryId;
    if (_selectedType == 'transfer') {
      final defaultCat = provider.categories.firstWhere(
        (c) => c.id.isNotEmpty,
        orElse: () => Category(id: 'temp', name: 'Transfer', iconCode: 0, colorCode: 0, type: 'expense'),
      );
      categoryId = defaultCat.id;
    } else {
      categoryId = _selectedCategoryId!;
    }

    if (widget.transaction == null) {
      // Create new transaction
      provider.addTransaction(
        amount: amount,
        type: _selectedType,
        categoryId: categoryId,
        accountId: _selectedAccountId!,
        toAccountId: _selectedType == 'transfer' ? _selectedToAccountId : null,
        imagePath: savedImagePath,
        date: _selectedDate,
        description: description,
      );
    } else {
      // Update existing transaction
      final oldTx = widget.transaction!;
      final newTx = oldTx.copyWith(
        amount: amount,
        type: _selectedType,
        categoryId: categoryId,
        accountId: _selectedAccountId!,
        toAccountId: _selectedType == 'transfer' ? _selectedToAccountId : null,
        imagePath: savedImagePath,
        date: _selectedDate,
        description: description,
      );
      provider.updateTransactionDetails(newTx, oldTx);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<FinanceProvider>(context);

    // Filter categories by type
    final filteredCats = provider.categories.where(
      (c) => c.type == _selectedType
    ).toList();

    Color nominalColor = AppTheme.primaryColor;
    if (_selectedType == 'income') {
      nominalColor = AppTheme.incomeColor;
    } else if (_selectedType == 'transfer') {
      nominalColor = Colors.orange;
    } else {
      nominalColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    }

    final hasPhotoAttached = (!_imageRemoved && (_tempPickedFile != null || _existingImagePath != null));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Catat Transaksi' : 'Edit Catatan'),
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.expenseColor),
              onPressed: () async {
                final confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Catatan?'),
                    content: const Text('Apakah Anda yakin ingin menghapus transaksi ini? Saldo dompet Anda akan disesuaikan kembali.'),
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

                if (confirm == true) {
                  // Delete image attachment from storage if it exists
                  if (_existingImagePath != null) {
                    try {
                      final file = File(_existingImagePath!);
                      if (await file.exists()) {
                        await file.delete();
                      }
                    } catch (e) {
                      debugPrint("Error deleting attachment on delete: $e");
                    }
                  }
                  
                  provider.deleteTransactionDetails(widget.transaction!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            )
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Transaction Type Segmented Controller (Human-like Custom Slider)
                Center(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypeTab(
                          label: 'Pengeluaran',
                          isSelected: _selectedType == 'expense',
                          activeColor: AppTheme.expenseColor,
                          onTap: () {
                            setState(() {
                              _selectedType = 'expense';
                              _setDefaultCategoryForType(provider);
                            });
                          },
                        ),
                        _buildTypeTab(
                          label: 'Pemasukan',
                          isSelected: _selectedType == 'income',
                          activeColor: AppTheme.incomeColor,
                          onTap: () {
                            setState(() {
                              _selectedType = 'income';
                              _setDefaultCategoryForType(provider);
                            });
                          },
                        ),
                        _buildTypeTab(
                          label: 'Transfer',
                          isSelected: _selectedType == 'transfer',
                          activeColor: Colors.orange,
                          onTap: () {
                            setState(() {
                              _selectedType = 'transfer';
                              // Set default destination if it matches source
                              if (_selectedToAccountId == null || _selectedToAccountId == _selectedAccountId) {
                                final others = provider.accounts.where((a) => a.id != _selectedAccountId).toList();
                                if (others.isNotEmpty) {
                                  _selectedToAccountId = others.first.id;
                                }
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // 2. Big Nominal Field
                Text(
                  'NOMINAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                 TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    IndCurrencyInputFormatter(),
                  ],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: nominalColor,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan jumlah uang';
                    }
                    final cleanVal = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (double.tryParse(cleanVal) == null || double.parse(cleanVal) <= 0) {
                      return 'Masukkan nominal yang valid';
                    }
                    return null;
                  },
                ),
                
                const Divider(height: 1, thickness: 1.5),
                const SizedBox(height: 24),

                // 3. Source Wallet Picker
                Text(
                  _selectedType == 'transfer' ? 'DARI DOMPET (ASAL)' : 'SUMBER DANA / DOMPET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.accounts.length,
                    itemBuilder: (context, index) {
                      final acc = provider.accounts[index];
                      final isSelected = _selectedAccountId == acc.id;
                      final Color themeColor = Color(acc.colorCode);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            acc.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          checkmarkColor: Colors.white,
                          selected: isSelected,
                          selectedColor: themeColor,
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
                            if (selected) {
                              setState(() {
                                _selectedAccountId = acc.id;
                                // If transfer and source equals destination, change destination
                                if (_selectedType == 'transfer' && _selectedAccountId == _selectedToAccountId) {
                                  final others = provider.accounts.where((a) => a.id != _selectedAccountId).toList();
                                  if (others.isNotEmpty) {
                                    _selectedToAccountId = others.first.id;
                                  }
                                }
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                // 3b. Destination Wallet Picker (Only for transfer)
                if (_selectedType == 'transfer') ...[
                  const SizedBox(height: 24),
                  Text(
                    'KE DOMPET (TUJUAN)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.accounts.length,
                      itemBuilder: (context, index) {
                        final acc = provider.accounts[index];
                        final isSelected = _selectedToAccountId == acc.id;
                        final Color themeColor = Color(acc.colorCode);

                        // Disable or hide source account
                        final isSource = _selectedAccountId == acc.id;
                        if (isSource) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              acc.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            checkmarkColor: Colors.white,
                            selected: isSelected,
                            selectedColor: themeColor,
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
                              if (selected) {
                                setState(() {
                                  _selectedToAccountId = acc.id;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 4. Date & Description Row
                Row(
                  children: [
                    // Date picker pill
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TANGGAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateHelper.getRelativeDay(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Description Box
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DESKRIPSI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Catatan tambahan...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4b. Custom Photo Attachment Section
                Text(
                  'LAMPIRAN FOTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (!hasPhotoAttached)
                  // Dashed outline human-like custom container for picking images
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                        style: BorderStyle.solid,
                      ),
                      boxShadow: AppTheme.getShadow(context),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, size: 20),
                          label: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.photo_library_outlined, size: 20),
                          label: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                  )
                else
                  // Thumbnail preview card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                        // Clickable Thumbnail image
                        GestureDetector(
                          onTap: () {
                            final imagePath = _tempPickedFile?.path ?? _existingImagePath;
                            if (imagePath != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ImageViewerStr(
                                    imagePath: imagePath,
                                    title: _descriptionController.text.isNotEmpty
                                        ? _descriptionController.text
                                        : 'Foto Struk',
                                  ),
                                ),
                              );
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: _tempPickedFile != null
                                  ? Image.file(_tempPickedFile!, fit: BoxFit.cover)
                                  : Image.file(File(_existingImagePath!), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Foto Struk Terlampir',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sentuh gambar untuk memperbesar / zoom',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.expenseColor, size: 24),
                          onPressed: () {
                            setState(() {
                              _tempPickedFile = null;
                              _imageRemoved = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 5. Category Selection Grid (Only if NOT transfer)
                if (_selectedType != 'transfer') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PILIH KATEGORI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.settings, size: 14),
                        label: const Text('Kelola', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoryManageView(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  filteredCats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Belum ada kategori untuk tipe ini.\nBuat di menu Kelola.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: filteredCats.length,
                          itemBuilder: (context, index) {
                            final cat = filteredCats[index];
                            final isSelected = _selectedCategoryId == cat.id;
                            final Color color = Color(cat.colorCode);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = cat.id;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? color.withOpacity(0.12)
                                      : (isDark ? AppTheme.darkSurface : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected 
                                        ? color 
                                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected ? null : AppTheme.getShadow(context),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                                        color: color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        cat.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected 
                                              ? (isDark ? Colors.white : Colors.black)
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
                
                const SizedBox(height: 32),

                // 6. Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == 'income' 
                          ? AppTheme.incomeColor 
                          : (_selectedType == 'transfer' ? Colors.orange : AppTheme.primaryColor),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _saveForm,
                    child: Text(
                      widget.transaction == null 
                          ? (_selectedType == 'income' 
                              ? 'Catat Pemasukan' 
                              : (_selectedType == 'transfer' ? 'Catat Transfer' : 'Catat Pengeluaran')) 
                          : 'Simpan Perubahan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
}
