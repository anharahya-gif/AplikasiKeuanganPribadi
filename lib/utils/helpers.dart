import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyHelper {
  static String format(double amount) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(amount);
  }
}

class DateHelper {
  static String formatSimple(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatFull(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }
  
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }
  
  static String getRelativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);
    
    if (checkDate == today) {
      return 'Hari Ini';
    } else if (checkDate == yesterday) {
      return 'Kemarin';
    } else {
      return formatSimple(date);
    }
  }
}

class IndCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Parse the new text to get numbers only
    String newClean = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newClean.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final double value = double.parse(newClean);
    final formatter = NumberFormat.decimalPattern('id');
    final String newFormatted = formatter.format(value);

    // Calculate cursor position after formatting
    int selectionIndex = newValue.selection.end;
    
    // Calculate how many characters of the clean string were typed before the cursor
    int cleanCharsBeforeCursor = 0;
    for (int i = 0; i < selectionIndex && i < newValue.text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) {
        cleanCharsBeforeCursor++;
      }
    }
    
    // Now count where this position lands in the new formatted string
    int formattedCursorPos = 0;
    int cleanCount = 0;
    while (cleanCount < cleanCharsBeforeCursor && formattedCursorPos < newFormatted.length) {
      if (RegExp(r'[0-9]').hasMatch(newFormatted[formattedCursorPos])) {
        cleanCount++;
      }
      formattedCursorPos++;
    }
    
    // Adjust cursor if it lands on a separator
    if (formattedCursorPos < newFormatted.length && newFormatted[formattedCursorPos] == '.') {
      formattedCursorPos++;
    }

    return TextEditingValue(
      text: newFormatted,
      selection: TextSelection.collapsed(offset: formattedCursorPos),
    );
  }
}
