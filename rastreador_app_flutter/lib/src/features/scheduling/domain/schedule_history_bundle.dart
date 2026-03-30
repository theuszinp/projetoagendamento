import 'schedule_note.dart';
import 'schedule_timeline_entry.dart';

class ScheduleHistoryBundle {
  const ScheduleHistoryBundle({
    required this.timeline,
    required this.notes,
  });

  final List<ScheduleTimelineEntry> timeline;
  final List<ScheduleNote> notes;
}
