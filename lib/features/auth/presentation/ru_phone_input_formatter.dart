import 'package:flutter/services.dart';

/// Russian mobile number: always starts with `+7`, then 10 digits.
/// Display: `+7 999 123-45-67`.
class RuPhoneInputFormatter extends TextInputFormatter {
  static const countryPrefix = '+7';

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Normalize pasted / typed value into canonical display form.
  static String format(String raw) {
    var digits = digitsOnly(raw);
    if (digits.isEmpty) {
      return '$countryPrefix ';
    }
    // 8XXXXXXXXXX → 7XXXXXXXXXX
    if (digits.startsWith('8') && digits.length >= 11) {
      digits = '7${digits.substring(1)}';
    }
    if (!digits.startsWith('7')) {
      digits = '7$digits';
    }
    digits = digits.substring(0, digits.length.clamp(0, 11));
    final local = digits.length > 1 ? digits.substring(1) : '';
    final buf = StringBuffer(countryPrefix);
    if (local.isEmpty) {
      buf.write(' ');
      return buf.toString();
    }
    buf.write(' ');
    buf.write(local.substring(0, local.length.clamp(0, 3)));
    if (local.length > 3) {
      buf.write(' ');
      buf.write(local.substring(3, local.length.clamp(3, 6)));
    }
    if (local.length > 6) {
      buf.write('-');
      buf.write(local.substring(6, local.length.clamp(6, 8)));
    }
    if (local.length > 8) {
      buf.write('-');
      buf.write(local.substring(8, local.length.clamp(8, 10)));
    }
    return buf.toString();
  }

  static bool isComplete(String value) {
    final digits = digitsOnly(value);
    return digits.length == 11 && digits.startsWith('7');
  }

  static String toE164(String value) {
    final digits = digitsOnly(value);
    if (digits.isEmpty) {
      return countryPrefix;
    }
    return '+$digits';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
