import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../users/data/user_repository.dart';
import '../../../users/domain/technician_workload.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_status.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleRepository = context.read<ScheduleRepository>();
    final userRepository = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard admin'),
        actions: const [SessionAppBarActions()],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          scheduleRepository.fetchAdminSchedules(),
          userRepository.fetchTechnicianWorkloads(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Montando visão administrativa...');
          }

          if (snapshot.hasError) {
            return EmptyState(
              title: 'Erro ao carregar painel',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final schedules =
              snapshot.data?[0] as List<InstallationSchedule>? ?? const [];
          final workloads =
              snapshot.data?[1] as List<TechnicianWorkload>? ?? const [];

          final pending = schedules
              .where((item) => item.status == ScheduleStatus.pendingApproval)
              .length;
          final scheduled = schedules
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
                title: 'Painel administrativo',
                subtitle:
                    'Aprovação, distribuição de carga, gestão de usuários e visibilidade operacional.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 4 : 2,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  MetricCard(
                    label: 'Pendentes',
                    value: '$pending',
                    icon: Icons.pending,
                  ),
                  MetricCard(
                    label: 'Agendados',
                    value: '$scheduled',
                    icon: Icons.event,
                  ),
                  MetricCard(
                    label: 'Em atendimento',
                    value: '$inService',
                    icon: Icons.build_circle,
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
                        'Carga por instalador',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (workloads.isEmpty)
                        const Text('Nenhuma métrica disponível no momento.')
                      else
                        ...workloads.map(
                          (workload) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(workload.name),
                            subtitle: Text(
                              '${workload.completedServices} concluídos • média ${workload.averageMinutes.toStringAsFixed(0)} min',
                            ),
                            trailing: Text(
                              '${workload.totalMinutes.toStringAsFixed(0)} min',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
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
