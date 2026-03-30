import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((status) {
          final isSelected = selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
              label: Text(
                status?.label ?? 'Todos',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: Colors.white,
              selectedColor: AppColors.brand,
              side: BorderSide(
                color: isSelected
                    ? AppColors.brand
                    : AppColors.brand.withValues(alpha: 0.20),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(status),
            ),
          );
        }).toList(),
      ),
    );
  }
}
