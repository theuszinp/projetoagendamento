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
import '../controllers/seller_schedule_list_controller.dart';
import '../widgets/schedule_card.dart';
import '../widgets/schedule_filters_bar.dart';

class SellerScheduleListScreen extends StatelessWidget {
  const SellerScheduleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sellerId = context.watch<AppSessionController>().currentUserId;

    return ChangeNotifierProvider(
      create: (_) => SellerScheduleListController(
        context.read<ScheduleRepository>(),
        sellerId,
      )..load(),
      child: const _SellerScheduleListView(),
    );
  }
}

class _SellerScheduleListView extends StatelessWidget {
  const _SellerScheduleListView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SellerScheduleListController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus agendamentos'),
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
              title: 'Acompanhamento do vendedor',
              subtitle:
                  'Visão clara do pipeline: pendência, aprovação, execução e conclusão.',
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
                labelText: 'Buscar por cliente, protocolo ou título',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            if (controller.isLoading)
              const SizedBox(
                height: 300,
                child: LoadingView(label: 'Buscando seus agendamentos...'),
              )
            else if (controller.errorMessage != null)
              EmptyState(
                title: 'Erro ao carregar agendamentos',
                message: controller.errorMessage!,
                icon: Icons.error_outline,
              )
            else if (controller.filteredSchedules.isEmpty)
              const EmptyState(
                title: 'Nenhum agendamento encontrado',
                message:
                    'Quando uma nova solicitação for criada, ela aparecerá aqui com timeline e status.',
              )
            else
              ...controller.filteredSchedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScheduleCard(
                    schedule: schedule,
                    onTap: () => context.push(
                      AppRoutes.sellerDetails(schedule.id),
                      extra: schedule,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
