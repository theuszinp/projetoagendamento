import '../../users/domain/app_user.dart';
import 'address.dart';
import 'customer.dart';
import 'schedule_priority.dart';
import 'schedule_status.dart';
import 'schedule_timeline_entry.dart';

class InstallationSchedule {
  const InstallationSchedule({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.customer,
    required this.address,
    required this.createdAt,
    required this.timeline,
    this.installer,
    this.desiredDate,
    this.vehicleSummary,
    this.sellerNotes,
    this.serviceDescription,
  });

  final int id;
  final String title;
  final SchedulePriority priority;
  final ScheduleStatus status;
  final Customer customer;
  final Address address;
  final DateTime createdAt;
  final DateTime? desiredDate;
  final String? vehicleSummary;
  final String? sellerNotes;
  final String? serviceDescription;
  final AppUser? installer;
  final List<ScheduleTimelineEntry> timeline;

  String get protocol => 'AG-${id.toString().padLeft(5, '0')}';
}
