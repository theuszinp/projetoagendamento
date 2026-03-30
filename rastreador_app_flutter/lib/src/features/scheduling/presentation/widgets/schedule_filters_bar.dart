import 'package:flutter/material.dart';

import '../../domain/schedule_status.dart';

class ScheduleFiltersBar extends StatelessWidget {
  const ScheduleFiltersBar({
    super.key,
    required this.selectedStatus,
    required this.onChanged,
  });

  final ScheduleStatus? selectedStatus;
  final ValueChanged<ScheduleStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <ScheduleStatus?>[
      null,
      ScheduleStatus.pendingApproval,
      ScheduleStatus.scheduled,
      ScheduleStatus.inService,
      ScheduleStatus.completed,
      ScheduleStatus.rejected,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((status) {
        final isSelected = selectedStatus == status;
        return ChoiceChip(
          label: Text(status?.label ?? 'Todos'),
          selected: isSelected,
          onSelected: (_) => onChanged(status),
        );
      }).toList(),
    );
  }
}
