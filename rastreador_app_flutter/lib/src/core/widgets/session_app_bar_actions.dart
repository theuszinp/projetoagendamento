import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../session/app_session_controller.dart';

class SessionAppBarActions extends StatelessWidget {
  const SessionAppBarActions({
    super.key,
    this.onRefresh,
  });

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSessionController>();

    return PopupMenuButton<_SessionAction>(
      tooltip: 'Conta',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.10)),
        ),
        child: Center(
          child: Text(
            session.currentUser?.name.isNotEmpty == true
                ? session.currentUser!.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      onSelected: (action) async {
        switch (action) {
          case _SessionAction.refresh:
            if (onRefresh != null) {
              await onRefresh!.call();
            }
            break;
          case _SessionAction.logout:
            await context.read<AppSessionController>().logout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_SessionAction>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.currentUser?.name ?? 'Usuario',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                session.currentUser?.email ?? '',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        if (onRefresh != null)
          const PopupMenuItem<_SessionAction>(
            value: _SessionAction.refresh,
            child: Row(
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 10),
                Text('Atualizar'),
              ],
            ),
          ),
        const PopupMenuItem<_SessionAction>(
          value: _SessionAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Sair'),
            ],
          ),
        ),
      ],
    );
  }
}

enum _SessionAction {
  refresh,
  logout,
}
