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
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        child: Text(
          session.currentUser?.name.isNotEmpty == true
              ? session.currentUser!.name[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
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
                session.currentUser?.name ?? 'Usuário',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
