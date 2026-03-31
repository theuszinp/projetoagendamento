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

    final textColor =
        color == AppColors.warning ? AppColors.brandDark : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
