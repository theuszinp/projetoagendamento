class CepFormatter {
  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String format(String value) {
    final digits = digitsOnly(value);
    if (digits.length <= 5) {
      return digits;
    }

    final end = digits.length > 8 ? 8 : digits.length;
    return '${digits.substring(0, 5)}-${digits.substring(5, end)}';
  }
}
