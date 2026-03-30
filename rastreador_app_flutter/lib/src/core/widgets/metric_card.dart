import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.highlight,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ?? AppColors.brand;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 150 || constraints.maxWidth < 170;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: compact ? 18 : 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(icon, size: compact ? 18 : 20),
                ),
                SizedBox(height: compact ? 12 : 18),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: compact ? 22 : 24,
                        height: 1,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
