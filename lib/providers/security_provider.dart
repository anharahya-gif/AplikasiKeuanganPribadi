import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../views/pin_lock_view.dart';

class SecurityProvider with ChangeNotifier {
  bool _isPinEnabled = false;
  bool _isBiometricsEnabled = false;
  String _savedPin = '';
  bool _isLockScreenActive = false;

  final LocalAuthentication _auth = LocalAuthentication();

  // Getters
  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isLockScreenActive => _isLockScreenActive;
  bool get hasPin => _savedPin.isNotEmpty;

  // Initialize and load security configurations
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPinEnabled = prefs.getBool('pin_enabled') ?? false;
      _isBiometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      _savedPin = prefs.getString('saved_pin') ?? '';

      // Fallback sanity check: if pin is enabled but no PIN is saved, disable it
      if (_isPinEnabled && _savedPin.isEmpty) {
        _isPinEnabled = false;
        await prefs.setBool('pin_enabled', false);
      }
    } catch (e) {
      debugPrint('Error initializing SecurityProvider: $e');
    }
    notifyListeners();
  }

  // Set / Save new security PIN
  Future<bool> setPin(String newPin) async {
    if (newPin.length != 4) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_pin', newPin);
      await prefs.setBool('pin_enabled', true);
      
      _savedPin = newPin;
      _isPinEnabled = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting PIN: $e');
      return false;
    }
  }

  // Disable Security PIN & Biometrics
  Future<void> disablePin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_pin');
      await prefs.setBool('pin_enabled', false);
      await prefs.setBool('biometrics_enabled', false);

      _savedPin = '';
      _isPinEnabled = false;
      _isBiometricsEnabled = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
    }
  }

  // Toggle biometric settings status
  Future<void> enableBiometrics(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometrics_enabled', enabled);
      _isBiometricsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling biometrics: $e');
    }
  }

  // Verify if entered PIN matches saved PIN
  bool verifyPin(String input) {
    return _savedPin == input;
  }

  // Check if biometric sensor is available on device
  Future<bool> canUseBiometrics() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometrics availability: $e');
      return false;
    }
  }

  // Trigger Local biometric authentication (Fingerprint / Face ID)
  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricsEnabled) return false;
    
    final bool available = await canUseBiometrics();
    if (!available) return false;

    try {
      return await _auth.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke KeuanganKu',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Error authenticating with biometrics: $e');
      return false;
    }
  }

  // Push full-screen PIN Overlay View securely
  void showLockScreen(BuildContext context, {bool showCancel = false}) {
    if (!_isPinEnabled || _isLockScreenActive) return;
    
    _isLockScreenActive = true;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinLockView(
          mode: PinLockMode.verify,
          showCancel: showCancel,
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      _isLockScreenActive = false;
    });
  }
}
