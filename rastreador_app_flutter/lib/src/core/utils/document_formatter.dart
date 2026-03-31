class DocumentFormatter {
  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  static bool isValidLength(String value) {
    final digits = digitsOnly(value);
    return digits.length == 11 || digits.length == 14;
  }

  static String format(String value) {
    final digits = digitsOnly(value);
    if (digits.length <= 11) {
      return _formatCpf(digits);
    }

    return _formatCnpj(digits);
  }

  static String _formatCpf(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 11; index++) {
      if (index == 3 || index == 6) {
        buffer.write('.');
      }
      if (index == 9) {
        buffer.write('-');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  static String _formatCnpj(String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 14; index++) {
      if (index == 2 || index == 5) {
        buffer.write('.');
      }
      if (index == 8) {
        buffer.write('/');
      }
      if (index == 12) {
        buffer.write('-');
      }
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
