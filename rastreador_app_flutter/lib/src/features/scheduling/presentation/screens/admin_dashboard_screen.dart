import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
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
            return const LoadingView(label: 'Montando visao administrativa...');
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
              _DashboardHero(
                title: 'Operacao sob controle',
                subtitle:
                    'Acompanhe a fila de aprovacao, a distribuicao dos instaladores e a execucao do dia em uma visao mais executiva.',
                statLabel: 'Base analisada',
                statValue: '${schedules.length} servicos',
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                eyebrow: 'RESUMO OPERACIONAL',
                title: 'Painel administrativo',
                subtitle:
                    'Aprovacao, distribuicao de carga, gestao de usuarios e visibilidade operacional.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 4 : 2,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: MediaQuery.of(context).size.width > 1100
                    ? 1.35
                    : MediaQuery.of(context).size.width > 700
                        ? 1.18
                        : 1.02,
                children: [
                  MetricCard(
                    label: 'Pendentes',
                    value: '$pending',
                    icon: Icons.pending_actions_outlined,
                    highlight: AppColors.warning,
                  ),
                  MetricCard(
                    label: 'Agendados',
                    value: '$scheduled',
                    icon: Icons.event_available_outlined,
                  ),
                  MetricCard(
                    label: 'Em atendimento',
                    value: '$inService',
                    icon: Icons.build_circle_outlined,
                    highlight: AppColors.accent,
                  ),
                  MetricCard(
                    label: 'Concluidos',
                    value: '$completed',
                    icon: Icons.task_alt_outlined,
                    highlight: AppColors.success,
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
                      const SectionHeader(
                        title: 'Carga por instalador',
                        subtitle:
                            'Leitura rapida de volume entregue, tempo medio e intensidade operacional.',
                      ),
                      const SizedBox(height: 16),
                      if (workloads.isEmpty)
                        const Text('Nenhuma metrica disponivel no momento.')
                      else
                        ...workloads.map(
                          (workload) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.engineering_outlined,
                                    color: AppColors.brand,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workload.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${workload.completedServices} concluidos • media ${workload.averageMinutes.toStringAsFixed(0)} min',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${workload.totalMinutes.toStringAsFixed(0)} min',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.brand),
                                ),
                              ],
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

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.title,
    required this.subtitle,
    required this.statLabel,
    required this.statValue,
  });

  final String title;
  final String subtitle;
  final String statLabel;
  final String statValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brand, AppColors.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.query_stats, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  '$statLabel: $statValue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
