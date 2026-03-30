import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../data/schedule_repository.dart';
import '../controllers/technician_agenda_controller.dart';
import '../widgets/schedule_card.dart';
import '../widgets/schedule_filters_bar.dart';

class TechnicianAgendaScreen extends StatelessWidget {
  const TechnicianAgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final technicianId = context.watch<AppSessionController>().currentUserId;

    return ChangeNotifierProvider(
      create: (_) => TechnicianAgendaController(
        context.read<ScheduleRepository>(),
        technicianId,
      )..load(),
      child: const _TechnicianAgendaView(),
    );
  }
}

class _TechnicianAgendaView extends StatelessWidget {
  const _TechnicianAgendaView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TechnicianAgendaController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha agenda'),
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
              title: 'Serviços atribuídos',
              subtitle:
                  'Somente ordens atribuídas ao instalador logado aparecem aqui.',
            ),
            const SizedBox(height: 16),
            ScheduleFiltersBar(
              selectedStatus: controller.selectedStatus,
              onChanged: controller.updateStatus,
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: controller.updateSearch,
              decoration: const InputDecoration(
                labelText: 'Buscar por cliente, protocolo ou endereço',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (controller.isLoading)
              const SizedBox(
                height: 300,
                child: LoadingView(label: 'Carregando serviços atribuídos...'),
              )
            else if (controller.errorMessage != null)
              EmptyState(
                title: 'Falha ao carregar agenda',
                message: controller.errorMessage!,
                icon: Icons.error_outline,
              )
            else if (controller.filteredSchedules.isEmpty)
              const EmptyState(
                title: 'Nenhum serviço atribuído',
                message: 'Quando o admin vincular novos atendimentos, eles aparecerão aqui.',
              )
            else
              ...controller.filteredSchedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScheduleCard(
                    schedule: schedule,
                    onTap: () async {
                      final shouldRefresh = await context.push(
                        AppRoutes.technicianDetails(schedule.id),
                        extra: schedule,
                      );

                      if (context.mounted && shouldRefresh == true) {
                        await controller.load();
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
