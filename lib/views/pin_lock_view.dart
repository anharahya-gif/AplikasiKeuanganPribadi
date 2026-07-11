import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/security_provider.dart';
import '../theme/app_theme.dart';

enum PinLockMode { setup, verify, disable, change }

class PinLockView extends StatefulWidget {
  final PinLockMode mode;
  final bool showCancel;

  const PinLockView({
    super.key,
    required this.mode,
    this.showCancel = true,
  });

  @override
  State<PinLockView> createState() => _PinLockViewState();
}

class _PinLockViewState extends State<PinLockView> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _inputPin = '';
  String _tempPin = ''; // stores the first PIN entered during setup/change
  String _title = '';
  String _subtitle = '';
  String _errorText = '';

  // Setup / change sub-steps tracker
  // setup: 0 = enter pin, 1 = confirm pin
  // change: 0 = enter current pin, 1 = enter new pin, 2 = confirm new pin
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initText();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: -15.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    // Auto-authenticate with biometrics if in verify mode
    if (widget.mode == PinLockMode.verify) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometrics();
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _initText() {
    setState(() {
      _errorText = '';
      _inputPin = '';
      switch (widget.mode) {
        case PinLockMode.setup:
          _title = 'Atur PIN Baru';
          _subtitle = 'Buat 4 digit kode keamanan untuk mengunci aplikasi Anda.';
          _currentStep = 0;
          break;
        case PinLockMode.verify:
          _title = 'Masukkan PIN Anda';
          _subtitle = 'Silakan masukkan kode keamanan Anda.';
          break;
        case PinLockMode.disable:
          _title = 'Nonaktifkan PIN';
          _subtitle = 'Masukkan PIN keamanan Anda saat ini untuk menonaktifkan.';
          break;
        case PinLockMode.change:
          _title = 'Masukkan PIN Lama';
          _subtitle = 'Silakan verifikasi PIN Anda saat ini terlebih dahulu.';
          _currentStep = 0;
          break;
      }
    });
  }

  Future<void> _triggerBiometrics() async {
    final security = Provider.of<SecurityProvider>(context, listen: false);
    if (security.isBiometricsEnabled) {
      final success = await security.authenticateWithBiometrics();
      if (success && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _shakeDots() {
    _shakeController.forward(from: 0.0);
    setState(() {
      _inputPin = '';
    });
  }

  void _handleKeyPress(String value) {
    if (_inputPin.length >= 4) return;

    setState(() {
      _inputPin += value;
      _errorText = '';
    });

    if (_inputPin.length == 4) {
      _processPin();
    }
  }

  void _handleBackspace() {
    if (_inputPin.isEmpty) return;
    setState(() {
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      _errorText = '';
    });
  }

  void _processPin() {
    final security = Provider.of<SecurityProvider>(context, listen: false);

    switch (widget.mode) {
      case PinLockMode.setup:
        if (_currentStep == 0) {
          // Store first entry and move to confirmation step
          setState(() {
            _tempPin = _inputPin;
            _inputPin = '';
            _currentStep = 1;
            _title = 'Konfirmasi PIN';
            _subtitle = 'Masukkan ulang 4 digit kode keamanan Anda.';
          });
        } else {
          if (_inputPin == _tempPin) {
            // Success setting PIN
            security.setPin(_inputPin).then((success) {
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN keamanan berhasil diaktifkan')),
                );
                Navigator.pop(context, true);
              }
            });
          } else {
            // Mismatch
            setState(() {
              _errorText = 'PIN tidak cocok. Silakan coba lagi.';
              _currentStep = 0;
              _tempPin = '';
              _title = 'Atur PIN Baru';
              _subtitle = 'Buat 4 digit kode keamanan untuk mengunci aplikasi Anda.';
            });
            _shakeDots();
          }
        }
        break;

      case PinLockMode.verify:
        if (security.verifyPin(_inputPin)) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorText = 'PIN yang Anda masukkan salah.';
          });
          _shakeDots();
        }
        break;

      case PinLockMode.disable:
        if (security.verifyPin(_inputPin)) {
          security.disablePin().then((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kunci keamanan PIN berhasil dinonaktifkan')),
              );
              Navigator.pop(context, true);
            }
          });
        } else {
          setState(() {
            _errorText = 'PIN yang Anda masukkan salah.';
          });
          _shakeDots();
        }
        break;

      case PinLockMode.change:
        if (_currentStep == 0) {
          // Step 0: Verify old pin
          if (security.verifyPin(_inputPin)) {
            setState(() {
              _inputPin = '';
              _currentStep = 1;
              _title = 'Masukkan PIN Baru';
              _subtitle = 'Masukkan 4 digit kode keamanan baru Anda.';
            });
          } else {
            setState(() {
              _errorText = 'PIN lama salah.';
            });
            _shakeDots();
          }
        } else if (_currentStep == 1) {
          // Step 1: Input new pin
          setState(() {
            _tempPin = _inputPin;
            _inputPin = '';
            _currentStep = 2;
            _title = 'Konfirmasi PIN Baru';
            _subtitle = 'Masukkan ulang kode keamanan baru Anda.';
          });
        } else {
          // Step 2: Confirm new pin
          if (_inputPin == _tempPin) {
            security.setPin(_inputPin).then((success) {
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN keamanan berhasil diperbarui')),
                );
                Navigator.pop(context, true);
              }
            });
          } else {
            setState(() {
              _errorText = 'PIN tidak cocok. Silakan coba lagi.';
              _currentStep = 1;
              _tempPin = '';
              _title = 'Masukkan PIN Baru';
              _subtitle = 'Masukkan 4 digit kode keamanan baru Anda.';
            });
            _shakeDots();
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final security = Provider.of<SecurityProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Cancel Button Row
            Align(
              alignment: Alignment.centerLeft,
              child: widget.showCancel
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 12.0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    )
                  : const SizedBox(height: 56),
            ),
            
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Lock
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header Titles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Dot Indicators with Shake Animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isFilled = index < _inputPin.length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled
                                    ? AppTheme.primaryColor
                                    : (isDark ? Colors.grey[800] : Colors.grey[300]),
                                border: isFilled
                                    ? Border.all(color: AppTheme.primaryColor)
                                    : Border.all(color: Colors.transparent),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  
                  // Error Text Display
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 20,
                    child: _errorText.isNotEmpty
                        ? Text(
                            _errorText,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.expenseColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  
                  const Spacer(),

                  // Custom Numeric Numpad Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumButton('1'),
                            _buildNumButton('2'),
                            _buildNumButton('3'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumButton('4'),
                            _buildNumButton('5'),
                            _buildNumButton('6'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumButton('7'),
                            _buildNumButton('8'),
                            _buildNumButton('9'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Left action button (Biometrics or Cancel)
                            _buildLeftActionBtn(security, isDark),
                            _buildNumButton('0'),
                            // Right backspace button
                            _buildBackspaceButton(isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Circular Number Button
  Widget _buildNumButton(String value) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _handleKeyPress(value),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
          boxShadow: AppTheme.getShadow(context),
        ),
        child: Center(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // Widget: Bottom Left Key (Biometrics or Cancel)
  Widget _buildLeftActionBtn(SecurityProvider security, bool isDark) {
    if (widget.mode == PinLockMode.verify && security.isBiometricsEnabled) {
      return GestureDetector(
        onTap: _triggerBiometrics,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.fingerprint_rounded,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
        ),
      );
    }

    // Default: Empty button, or Cancel if specified
    return const SizedBox(width: 72, height: 72);
  }

  // Widget: Backspace Button
  Widget _buildBackspaceButton(bool isDark) {
    return GestureDetector(
      onLongPress: () {
        setState(() {
          _inputPin = '';
        });
      },
      onTap: _handleBackspace,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: isDark ? Colors.white60 : Colors.black54,
            size: 22,
          ),
        ),
      ),
    );
  }
}
