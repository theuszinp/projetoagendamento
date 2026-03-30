enum SchedulePriority {
  low,
  medium,
  high;

  static SchedulePriority fromApi(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'HIGH':
      case 'ALTA':
        return SchedulePriority.high;
      case 'MEDIUM':
      case 'MEDIA':
      case 'MÉDIA':
        return SchedulePriority.medium;
      default:
        return SchedulePriority.low;
    }
  }

  String get apiValue {
    switch (this) {
      case SchedulePriority.low:
        return 'LOW';
      case SchedulePriority.medium:
        return 'MEDIUM';
      case SchedulePriority.high:
        return 'HIGH';
    }
  }

  String get label {
    switch (this) {
      case SchedulePriority.low:
        return 'Baixa';
      case SchedulePriority.medium:
        return 'Média';
      case SchedulePriority.high:
        return 'Alta';
    }
  }
}
