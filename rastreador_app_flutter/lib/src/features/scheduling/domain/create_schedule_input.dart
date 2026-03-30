import 'address.dart';
import 'customer.dart';
import 'schedule_priority.dart';
import 'vehicle.dart';

class CreateScheduleInput {
  const CreateScheduleInput({
    required this.title,
    required this.serviceDescription,
    required this.priority,
    required this.customer,
    required this.address,
    required this.vehicle,
    required this.desiredDate,
    required this.sellerNotes,
  });

  final String title;
  final String serviceDescription;
  final SchedulePriority priority;
  final Customer customer;
  final Address address;
  final Vehicle vehicle;
  final DateTime desiredDate;
  final String sellerNotes;

  String get desiredDateIso => desiredDate.toIso8601String();
}
