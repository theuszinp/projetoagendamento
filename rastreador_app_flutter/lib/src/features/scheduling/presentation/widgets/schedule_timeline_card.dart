import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../domain/schedule_timeline_entry.dart';

class ScheduleTimelineCard extends StatelessWidget {
  const ScheduleTimelineCard({
    super.key,
    required this.items,
  });

  final List<ScheduleTimelineEntry> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (items.isEmpty) ...[
              const Text('Ainda não há movimentações registradas.'),
            ] else ...[
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(DateTimeFormatter.shortDateTime(item.createdAt)),
                            if (item.description != null) ...[
                              const SizedBox(height: 4),
                              Text(item.description!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
