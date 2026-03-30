import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../users/domain/user_role.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_history_bundle.dart';
import '../widgets/schedule_notes_card.dart';
import '../widgets/schedule_timeline_card.dart';

class ScheduleDetailsScreen extends StatefulWidget {
  const ScheduleDetailsScreen({
    super.key,
    required this.schedule,
    this.scheduleId,
    this.allowAdminNotes = false,
  });

  final InstallationSchedule? schedule;
  final int? scheduleId;
  final bool allowAdminNotes;

  @override
  State<ScheduleDetailsScreen> createState() => _ScheduleDetailsScreenState();
}

class _ScheduleDetailsScreenState extends State<ScheduleDetailsScreen> {
  late Future<_ScheduleDetailsData> _detailsFuture;
  InstallationSchedule? _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _detailsFuture = _loadDetails();
  }

  Future<_ScheduleDetailsData> _loadDetails() async {
    final repository = context.read<ScheduleRepository>();
    final schedule = await _resolveSchedule();
    if (schedule == null) {
      return const _ScheduleDetailsData(
        history: ScheduleHistoryBundle(timeline: [], notes: []),
      );
    }

    _schedule = schedule;

    try {
      final history = await repository.fetchScheduleHistory(schedule.id);
      return _ScheduleDetailsData(schedule: schedule, history: history);
    } catch (error) {
      return _ScheduleDetailsData(
        schedule: schedule,
        history: const ScheduleHistoryBundle(timeline: [], notes: []),
        historyError: resolveErrorMessage(error),
      );
    }
  }

  Future<InstallationSchedule?> _resolveSchedule() async {
    final repository = context.read<ScheduleRepository>();
    final session = context.read<AppSessionController>();

    if (_schedule != null) {
      return _schedule;
    }

    final scheduleId = widget.scheduleId;
    if (scheduleId == null) {
      return null;
    }

    final fromDetails = await repository.fetchScheduleById(scheduleId);
    if (fromDetails != null) {
      return fromDetails;
    }

    switch (session.role) {
      case UserRole.admin:
        final schedules = await repository.fetchAdminSchedules();
        return _findById(schedules, scheduleId);
      case UserRole.seller:
        final schedules = await repository.fetchSellerSchedules(
          session.currentUserId,
        );
        return _findById(schedules, scheduleId);
      case UserRole.technician:
      case UserRole.unknown:
        return null;
    }
  }

  InstallationSchedule? _findById(
    List<InstallationSchedule> schedules,
    int scheduleId,
  ) {
    for (final schedule in schedules) {
      if (schedule.id == scheduleId) {
        return schedule;
      }
    }

    return null;
  }

  Future<void> _submitNote(String content) async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }

    final role = context.read<AppSessionController>().role;
    final noteType = role == UserRole.admin ? 'internal' : 'seller';

    try {
      await context.read<ScheduleRepository>().createScheduleNote(
            scheduleId: schedule.id,
            content: content,
            noteType: noteType,
          );
      if (!mounted) {
        return;
      }

      setState(() => _detailsFuture = _loadDetails());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observação registrada com sucesso.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolveErrorMessage(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppSessionController>().role;
    final canWriteNotes = role == UserRole.admin || role == UserRole.seller;

    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule?.protocol ?? 'Detalhes do agendamento'),
        actions: [
          SessionAppBarActions(
            onRefresh: () async => setState(() => _detailsFuture = _loadDetails()),
          ),
        ],
      ),
      body: FutureBuilder<_ScheduleDetailsData>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _schedule == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _schedule == null) {
            return EmptyState(
              title: 'Falha ao carregar agendamento',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final data = snapshot.data;
          final item = data?.schedule ?? _schedule;
          if (item == null) {
            return const EmptyState(
              title: 'Agendamento não encontrado',
              message:
                  'Não foi possível recuperar esse detalhe pela rota atual.',
            );
          }

          final timeline = data?.history.timeline.isNotEmpty == true
              ? data!.history.timeline
              : item.timeline;
          final notes = data?.history.notes ?? const [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Cliente: ${item.customer.name}'),
                      const SizedBox(height: 6),
                      Text('Telefone: ${item.customer.phone}'),
                      const SizedBox(height: 6),
                      Text('Endereço: ${item.address.fullText}'),
                      const SizedBox(height: 6),
                      Text(
                        'Data desejada: ${DateTimeFormatter.shortDateTime(item.desiredDate)}',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Criado em: ${DateTimeFormatter.shortDateTime(item.createdAt)}',
                      ),
                      if (item.vehicleSummary != null) ...[
                        const SizedBox(height: 6),
                        Text('Veículo: ${item.vehicleSummary}'),
                      ],
                      if (item.installer != null) ...[
                        const SizedBox(height: 6),
                        Text('Instalador: ${item.installer!.name}'),
                      ],
                      if ((item.serviceDescription ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Descrição operacional',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(item.serviceDescription!),
                      ],
                      if ((item.sellerNotes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.allowAdminNotes
                              ? 'Observações do vendedor'
                              : 'Observações iniciais',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(item.sellerNotes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else ...[
                if ((data?.historyError ?? '').isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Não foi possível carregar o histórico real. Exibindo a timeline local.\n\n${data!.historyError}',
                      ),
                    ),
                  ),
                ScheduleTimelineCard(items: timeline),
                const SizedBox(height: 16),
                ScheduleNotesCard(
                  notes: notes,
                  title: widget.allowAdminNotes
                      ? 'Observações e notas internas'
                      : 'Observações registradas',
                  inputLabel: widget.allowAdminNotes
                      ? 'Registrar observação interna'
                      : 'Adicionar complemento do vendedor',
                  submitLabel: widget.allowAdminNotes
                      ? 'Salvar nota interna'
                      : 'Salvar observação',
                  onSubmit: canWriteNotes ? _submitNote : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleDetailsData {
  const _ScheduleDetailsData({
    this.schedule,
    required this.history,
    this.historyError,
  });

  final InstallationSchedule? schedule;
  final ScheduleHistoryBundle history;
  final String? historyError;
}
