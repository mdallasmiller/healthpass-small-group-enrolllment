import 'package:flutter/services.dart';

/// Auto-formats a numeric string into MM/DD/YYYY as the user types.
class DateSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(d[i]);
    }
    final t = buf.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Digits only.
final digitsOnly = FilteringTextInputFormatter.digitsOnly;

/// Digits plus common phone punctuation.
final phoneChars = FilteringTextInputFormatter.allow(RegExp(r'[0-9()+\-\s]'));

/// Digits plus a dash (e.g. EIN / Tax ID).
final taxIdChars = FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]'));

/// Validates an OPTIONAL MM/DD/YYYY date (empty is allowed for admin fields).
String? optionalDateValidator(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v.trim());
  if (m == null) return 'Use MM/DD/YYYY';
  final mon = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (mon < 1 || mon > 12) return 'Invalid month';
  final date = DateTime(year, mon, day);
  if (date.year != year || date.month != mon || date.day != day) return 'Invalid date';
  return null;
}

/// Validates an OPTIONAL email (empty allowed).
String? optionalEmailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return (v.contains('@') && v.contains('.')) ? null : 'Enter a valid email';
}
