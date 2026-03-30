class DateTimeFormatter {
  static String shortDate(DateTime? value) {
    if (value == null) {
      return 'Não informado';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  static String shortTime(DateTime? value) {
    if (value == null) {
      return '--:--';
    }

    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static String shortDateTime(DateTime? value) {
    if (value == null) {
      return 'Não informado';
    }

    return '${shortDate(value)} às ${shortTime(value)}';
  }
}
