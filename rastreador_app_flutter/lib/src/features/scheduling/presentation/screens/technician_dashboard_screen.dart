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

class TechnicianDashboardScreen extends StatelessWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final techId = context.watch<AppSessionController>().currentUserId;
    final repository = context.read<ScheduleRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do instalador'),
        actions: const [SessionAppBarActions()],
      ),
      body: FutureBuilder<List<InstallationSchedule>>(
        future: repository.fetchTechnicianSchedules(techId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Carregando agenda do instalador...');
          }

          if (snapshot.hasError) {
            return EmptyState(
              title: 'Erro ao carregar agenda',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final schedules = snapshot.data ?? const [];
          final toStart = schedules
              .where((item) => item.status == ScheduleStatus.scheduled)
              .length;
          final inService = schedules
              .where((item) => item.status == ScheduleStatus.inService)
              .length;
          final completed = schedules
              .where((item) => item.status == ScheduleStatus.completed)
              .length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                title: 'Painel do instalador',
                subtitle:
                    'Fluxo enxuto para uso em campo: receber, iniciar e concluir com agilidade.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: [
                  MetricCard(
                    label: 'A iniciar',
                    value: '$toStart',
                    icon: Icons.play_circle,
                  ),
                  MetricCard(
                    label: 'Em atendimento',
                    value: '$inService',
                    icon: Icons.build,
                  ),
                  MetricCard(
                    label: 'Concluídos',
                    value: '$completed',
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
                        'Orientação de campo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Confirme o deslocamento antes de sair.\n'
                        '2. Inicie o atendimento somente ao chegar ao local.\n'
                        '3. Conclua com observações técnicas objetivas para manter a rastreabilidade.',
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
