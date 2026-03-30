import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_status.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sellerId = context.watch<AppSessionController>().currentUserId;
    final repository = context.read<ScheduleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard vendedor'),
        actions: const [SessionAppBarActions()],
      ),
      body: FutureBuilder<List<InstallationSchedule>>(
        future: repository.fetchSellerSchedules(sellerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Carregando dashboard do vendedor...');
          }

          if (snapshot.hasError) {
            return EmptyState(
              title: 'Não foi possível carregar o dashboard',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final schedules = snapshot.data ?? const [];
          final pending = schedules
              .where((item) => item.status == ScheduleStatus.pendingApproval)
              .length;
          final scheduled = schedules
              .where((item) => item.status == ScheduleStatus.scheduled)
              .length;
          final completed = schedules
              .where((item) => item.status == ScheduleStatus.completed)
              .length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                title: 'Dashboard do vendedor',
                subtitle:
                    'Cadastro rápido, visão do pipeline e retorno claro sobre aprovações.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: [
                  MetricCard(
                    label: 'Pendentes de aprovação',
                    value: pending.toString(),
                    icon: Icons.pending_actions,
                  ),
                  MetricCard(
                    label: 'Agendados',
                    value: scheduled.toString(),
                    icon: Icons.event_available,
                  ),
                  MetricCard(
                    label: 'Concluídos',
                    value: completed.toString(),
                    icon: Icons.task_alt,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boas práticas de operação',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Cadastre dados completos do cliente e do veículo.\n'
                        '2. Use observações objetivas para acelerar a aprovação.\n'
                        '3. Priorize datas desejadas realistas para reduzir reagendamentos.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
