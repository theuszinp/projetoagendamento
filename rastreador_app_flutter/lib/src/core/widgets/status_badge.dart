import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../features/scheduling/domain/schedule_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
  });

  final ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ScheduleStatus.pendingApproval => AppColors.warning,
      ScheduleStatus.approved => AppColors.brand,
      ScheduleStatus.scheduled => AppColors.brand,
      ScheduleStatus.inService => AppColors.accent,
      ScheduleStatus.completed => AppColors.success,
      ScheduleStatus.rejected => AppColors.danger,
      ScheduleStatus.rescheduleRequested => AppColors.warning,
      ScheduleStatus.cancelled => AppColors.textMuted,
      ScheduleStatus.technicalIssue => AppColors.danger,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
