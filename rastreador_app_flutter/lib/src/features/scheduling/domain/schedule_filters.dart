import 'schedule_status.dart';

class ScheduleFilters {
  const ScheduleFilters({
    this.status,
    this.search = '',
  });

  final ScheduleStatus? status;
  final String search;

  ScheduleFilters copyWith({
    ScheduleStatus? status,
    String? search,
  }) {
    return ScheduleFilters(
      status: status ?? this.status,
      search: search ?? this.search,
    );
  }
}
