import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
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
              const _TechnicianHero(),
              const SizedBox(height: 20),
              const SectionHeader(
                eyebrow: 'OPERACAO DE CAMPO',
                title: 'Painel do instalador',
                subtitle:
                    'Veja rapidamente o que precisa iniciar, o que esta em campo e o que ja foi entregue com foto e observacao tecnica.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  MetricCard(
                    label: 'A iniciar',
                    value: '$toStart',
                    icon: Icons.play_circle_outline,
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Fluxo recomendado em campo',
                        subtitle:
                            'Um passo a passo curto para manter rastreabilidade e acabamento profissional.',
                      ),
                      SizedBox(height: 16),
                      ...[
                        _FieldGuideRow(
                          icon: Icons.map_outlined,
                          text:
                              'Abra o Maps pelo endereco do servico antes de sair para o cliente.',
                        ),
                        _FieldGuideRow(
                          icon: Icons.photo_camera_outlined,
                          text:
                              'Depois de iniciar, use a camera do celular ou a galeria para anexar fotos da instalacao.',
                        ),
                        _FieldGuideRow(
                          icon: Icons.task_alt_outlined,
                          text:
                              'Conclua o atendimento com observacao tecnica para atualizar admin e vendedor.',
                        ),
                      ],
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

class _TechnicianHero extends StatelessWidget {
  const _TechnicianHero();

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
            'Campo com menos atrito',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tudo que o instalador precisa fica mais direto: rota, inicio, fotos, observacao tecnica e conclusao com retorno automatico para o time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
          ),
        ],
      ),
    );
  }
}

class _FieldGuideRow extends StatelessWidget {
  const _FieldGuideRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
