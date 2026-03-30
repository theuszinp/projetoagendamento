class ScheduleTimelineEntry {
  const ScheduleTimelineEntry({
    required this.label,
    required this.createdAt,
    this.description,
  });

  final String label;
  final DateTime createdAt;
  final String? description;
}
