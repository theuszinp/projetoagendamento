import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/installation_schedule.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onTap,
    this.trailing,
  });

  final InstallationSchedule schedule;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${schedule.protocol} • ${schedule.customer.name}'),
                      ],
                    ),
                  ),
                  StatusBadge(status: schedule.status),
                ],
              ),
              const SizedBox(height: 14),
              Text('Endereço: ${schedule.address.fullText}'),
              const SizedBox(height: 6),
              Text(
                'Data desejada: ${DateTimeFormatter.shortDateTime(schedule.desiredDate)}',
              ),
              if (schedule.installer != null) ...[
                const SizedBox(height: 6),
                Text('Instalador: ${schedule.installer!.name}'),
              ],
              if (schedule.vehicleSummary != null) ...[
                const SizedBox(height: 6),
                Text('Veículo: ${schedule.vehicleSummary}'),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 16),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
