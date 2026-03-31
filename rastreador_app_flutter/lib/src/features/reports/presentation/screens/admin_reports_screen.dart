import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../data/report_repository.dart';
import '../../domain/completed_services_report.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<CompletedServicesReport> _reportFuture;
  int _selectedRangeDays = 30;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<CompletedServicesReport> _loadReport() {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: _selectedRangeDays));

    return context.read<ReportRepository>().fetchCompletedServicesReport(
          from: from,
          to: now,
          search: _search,
        );
  }

  Future<void> _refresh() async {
    setState(() {
      _reportFuture = _loadReport();
    });
  }

  void _applySearch() {
    setState(() {
      _search = _searchController.text.trim();
      _reportFuture = _loadReport();
    });
  }

  void _selectRange(int days) {
    if (_selectedRangeDays == days) {
      return;
    }

    setState(() {
      _selectedRangeDays = days;
      _reportFuture = _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          SessionAppBarActions(onRefresh: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              title: 'Serviços concluídos',
              subtitle:
                  'Visão consolidada do que já foi executado, com tempo médio, fotos e responsáveis.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RangeChip(
                  label: '7 dias',
                  selected: _selectedRangeDays == 7,
                  onTap: () => _selectRange(7),
                ),
                _RangeChip(
                  label: '30 dias',
                  selected: _selectedRangeDays == 30,
                  onTap: () => _selectRange(30),
                ),
                _RangeChip(
                  label: '90 dias',
                  selected: _selectedRangeDays == 90,
                  onTap: () => _selectRange(90),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                labelText:
                    'Buscar por cliente, instalador, vendedor, endereço ou serviço',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<CompletedServicesReport>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 360,
                    child: LoadingView(label: 'Montando relatório operacional...'),
                  );
                }

                if (snapshot.hasError) {
                  return EmptyState(
                    title: 'Erro ao carregar relatório',
                    message: resolveErrorMessage(snapshot.error!),
                    icon: Icons.error_outline,
                  );
                }

                final report = snapshot.data;
                if (report == null || report.items.isEmpty) {
                  return const EmptyState(
                    title: 'Nenhum serviço concluído nesse filtro',
                    message:
                        'Ajuste o período ou a busca para localizar os atendimentos realizados.',
                  );
                }

                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_available,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Período: ${DateTimeFormatter.shortDate(report.from)} até ${DateTimeFormatter.shortDate(report.to)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 1100 ? 4 : 2,
                      shrinkWrap: true,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio:
                          MediaQuery.of(context).size.width > 1100 ? 1.35 : 1.05,
                      children: [
                        MetricCard(
                          label: 'Serviços concluídos',
                          value: '${report.summary.totalServices}',
                          icon: Icons.task_alt,
                        ),
                        MetricCard(
                          label: 'Com fotos',
                          value: '${report.summary.servicesWithPhotos}',
                          icon: Icons.photo_library_outlined,
                          highlight: AppColors.accent,
                        ),
                        MetricCard(
                          label: 'Instaladores ativos',
                          value: '${report.summary.techniciansInvolved}',
                          icon: Icons.groups_outlined,
                        ),
                        MetricCard(
                          label: 'Tempo médio',
                          value: '${report.summary.averageMinutes.toStringAsFixed(0)} min',
                          icon: Icons.timelapse_outlined,
                          highlight: AppColors.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...report.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CompletedServiceCard(item: item),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _CompletedServiceCard extends StatelessWidget {
  const _CompletedServiceCard({required this.item});

  final CompletedServiceItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(AppRoutes.adminDetails(item.ticketId)),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Concluído',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('${item.customerName} • ${item.customerAddress}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.person_outline,
                    label: 'Vendedor',
                    value: item.sellerName,
                  ),
                  _InfoPill(
                    icon: Icons.build_circle_outlined,
                    label: 'Instalador',
                    value: item.technicianName,
                  ),
                  _InfoPill(
                    icon: Icons.photo_camera_back_outlined,
                    label: 'Fotos',
                    value: '${item.attachmentsCount}',
                  ),
                  _InfoPill(
                    icon: Icons.schedule,
                    label: 'Duração',
                    value: '${item.durationMinutes.toStringAsFixed(0)} min',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Concluído em ${DateTimeFormatter.shortDateTime(item.completedAt)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandLight.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
