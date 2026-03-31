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
              title: 'Nao foi possivel carregar o dashboard',
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
              const _SellerHero(),
              const SizedBox(height: 20),
              const SectionHeader(
                eyebrow: 'PIPELINE COMERCIAL',
                title: 'Visao do vendedor',
                subtitle:
                    'Acompanhe suas solicitacoes, veja o que esta pendente e mantenha o cadastro mais redondo para o admin aprovar mais rapido.',
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                shrinkWrap: true,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  MetricCard(
                    label: 'Pendentes de aprovacao',
                    value: pending.toString(),
                    icon: Icons.pending_actions_outlined,
                    highlight: AppColors.warning,
                  ),
                  MetricCard(
                    label: 'Agendados',
                    value: scheduled.toString(),
                    icon: Icons.event_available_outlined,
                  ),
                  MetricCard(
                    label: 'Concluidos',
                    value: completed.toString(),
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
                        title: 'Como acelerar a aprovacao',
                        subtitle:
                            'Pequenos ajustes no cadastro melhoram muito a velocidade da operacao.',
                      ),
                      SizedBox(height: 16),
                      ...[
                        _AdviceRow(
                          icon: Icons.badge_outlined,
                          text:
                              'Use CPF ou CNPJ para puxar cliente existente e evitar retrabalho.',
                        ),
                        _AdviceRow(
                          icon: Icons.location_on_outlined,
                          text:
                              'Complete CEP, numero e detalhes operacionais com clareza.',
                        ),
                        _AdviceRow(
                          icon: Icons.directions_car_outlined,
                          text:
                              'Cadastre o veiculo com placa, ano e modelo para reduzir contato de volta.',
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

class _SellerHero extends StatelessWidget {
  const _SellerHero();

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
            'Venda bem. Cadastre melhor.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seu fluxo comercial agora fica mais rapido com cliente reutilizavel por CPF/CNPJ, endereco inteligente e retorno visual mais claro.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
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
