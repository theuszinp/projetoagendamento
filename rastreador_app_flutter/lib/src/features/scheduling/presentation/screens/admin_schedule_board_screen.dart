import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../users/data/user_repository.dart';
import '../../../users/domain/app_user.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../controllers/admin_schedule_board_controller.dart';
import '../widgets/schedule_card.dart';
import '../widgets/schedule_filters_bar.dart';

class AdminScheduleBoardScreen extends StatelessWidget {
  const AdminScheduleBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminScheduleBoardController(
        context.read<ScheduleRepository>(),
        context.read<UserRepository>(),
      )..load(),
      child: const _AdminScheduleBoardView(),
    );
  }
}

class _AdminScheduleBoardView extends StatelessWidget {
  const _AdminScheduleBoardView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminScheduleBoardController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda geral'),
        actions: [
          SessionAppBarActions(onRefresh: controller.load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              title: 'Gestão de agendamentos',
              subtitle:
                  'Aprovação centralizada, alocação do instalador e controle visual por status.',
            ),
            const SizedBox(height: 16),
            ScheduleFiltersBar(
              selectedStatus: controller.selectedStatus,
              onChanged: controller.updateStatusFilter,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: controller.updateSearch,
              decoration: const InputDecoration(
                labelText: 'Buscar por cliente, instalador, protocolo ou endereço',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (controller.isLoading)
              const SizedBox(
                height: 320,
                child: LoadingView(label: 'Atualizando quadro operacional...'),
              )
            else if (controller.errorMessage != null)
              EmptyState(
                title: 'Falha ao carregar agenda',
                message: controller.errorMessage!,
                icon: Icons.error_outline,
              )
            else if (controller.filteredSchedules.isEmpty)
              const EmptyState(
                title: 'Nenhum agendamento nessa visão',
                message: 'Ajuste os filtros ou aguarde novas solicitações.',
              )
            else
              ...controller.filteredSchedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScheduleCard(
                    schedule: schedule,
                    onTap: () => context.push(
                      AppRoutes.adminDetails(schedule.id),
                      extra: schedule,
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showAssignmentDialog(
                            context,
                            controller,
                            schedule,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(
                              color: AppColors.brand,
                              width: 1.4,
                            ),
                          ),
                          child: Text(
                            schedule.installer == null ? 'Atribuir' : 'Reatribuir',
                          ),
                        ),
                        FilledButton(
                          onPressed: () => controller.reject(schedule.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reprovar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignmentDialog(
    BuildContext context,
    AdminScheduleBoardController controller,
    InstallationSchedule schedule,
  ) async {
    AppUser? selected = schedule.installer;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atribuir instalador para ${schedule.protocol}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AppUser>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Instalador'),
                    items: controller.technicians
                        .map(
                          (technician) => DropdownMenuItem(
                            value: technician,
                            child: Text(technician.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selected = value),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: selected == null
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await controller.approve(
                              scheduleId: schedule.id,
                              technicianId: selected!.id,
                            );
                          },
                    child: const Text('Confirmar aprovação'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
