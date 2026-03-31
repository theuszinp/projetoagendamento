import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/maps/map_launcher_service.dart';
import '../../../../core/media/installation_photo_picker_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/app_session_controller.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/session_app_bar_actions.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/schedule_repository.dart';
import '../../domain/installation_schedule.dart';
import '../../domain/schedule_history_bundle.dart';
import '../../domain/schedule_status.dart';
import '../widgets/schedule_attachments_card.dart';
import '../widgets/schedule_notes_card.dart';
import '../widgets/schedule_timeline_card.dart';

class TechnicianJobDetailsScreen extends StatefulWidget {
  const TechnicianJobDetailsScreen({
    super.key,
    required this.schedule,
    this.scheduleId,
  });

  final InstallationSchedule? schedule;
  final int? scheduleId;

  @override
  State<TechnicianJobDetailsScreen> createState() =>
      _TechnicianJobDetailsScreenState();
}

class _TechnicianJobDetailsScreenState extends State<TechnicianJobDetailsScreen> {
  final InstallationPhotoPickerService _photoPicker =
      InstallationPhotoPickerService();

  late Future<_TechnicianJobDetailsData> _detailsFuture;
  InstallationSchedule? _schedule;
  bool _isProcessing = false;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _detailsFuture = _loadDetails();
  }

  Future<_TechnicianJobDetailsData> _loadDetails() async {
    final repository = context.read<ScheduleRepository>();
    final schedule = await _resolveSchedule();
    if (schedule == null) {
      return const _TechnicianJobDetailsData(
        history: ScheduleHistoryBundle(
          timeline: [],
          notes: [],
          attachments: [],
        ),
      );
    }

    _schedule = schedule;

    try {
      final history = await repository.fetchScheduleHistory(schedule.id);
      return _TechnicianJobDetailsData(schedule: schedule, history: history);
    } catch (error) {
      return _TechnicianJobDetailsData(
        schedule: schedule,
        history: const ScheduleHistoryBundle(
          timeline: [],
          notes: [],
          attachments: [],
        ),
        historyError: resolveErrorMessage(error),
      );
    }
  }

  Future<void> _refreshDetails() async {
    setState(() {
      _detailsFuture = _loadDetails();
    });
  }

  Future<InstallationSchedule?> _resolveSchedule() async {
    final repository = context.read<ScheduleRepository>();
    final technicianId = context.read<AppSessionController>().currentUserId;
    final scheduleId = widget.scheduleId ?? _schedule?.id;
    if (scheduleId == null) {
      return _schedule;
    }

    final fromDetails = await repository.fetchScheduleById(scheduleId);
    if (fromDetails != null) {
      return fromDetails;
    }

    final schedules = await repository.fetchTechnicianSchedules(technicianId);
    return _findById(schedules, scheduleId) ?? _schedule;
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

    try {
      await context.read<ScheduleRepository>().createScheduleNote(
            scheduleId: schedule.id,
            content: content,
            noteType: 'technical',
          );
      if (!mounted) {
        return;
      }

      await _refreshDetails();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observação técnica registrada.'),
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

  Future<void> _startService() async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await context.read<ScheduleRepository>().startService(schedule.id);
      if (!mounted) {
        return;
      }

      await _refreshDetails();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Atendimento iniciado com sucesso.'),
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
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _completeService() async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await context.read<ScheduleRepository>().completeService(schedule.id);
      if (!mounted) {
        return;
      }

      await _refreshDetails();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Instalação concluída. Admin e vendedor já podem ver a conclusão.',
          ),
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
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    final schedule = _schedule;
    final repository = context.read<ScheduleRepository>();
    if (schedule == null) {
      return;
    }

    setState(() => _isUploadingAttachment = true);

    try {
      final payload = await _photoPicker.pick(source);
      if (payload == null) {
        return;
      }

      await repository.uploadScheduleAttachment(
            scheduleId: schedule.id,
            fileName: payload.fileName,
            contentType: payload.contentType,
            base64Content: payload.base64Content,
          );
      if (!mounted) {
        return;
      }

      await _refreshDetails();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto anexada com sucesso.'),
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
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _openOnMap() async {
    final schedule = _schedule;
    if (schedule == null) {
      return;
    }

    final opened = await MapLauncherService.openAddress(
      schedule.address.fullText,
    );

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir o Google Maps neste aparelho.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_schedule?.protocol ?? 'Detalhes do serviço'),
        actions: [
          SessionAppBarActions(
            onRefresh: _refreshDetails,
          ),
        ],
      ),
      body: FutureBuilder<_TechnicianJobDetailsData>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _schedule == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _schedule == null) {
            return EmptyState(
              title: 'Falha ao carregar serviço',
              message: resolveErrorMessage(snapshot.error!),
              icon: Icons.error_outline,
            );
          }

          final data = snapshot.data;
          final item = data?.schedule ?? _schedule;
          if (item == null) {
            return const EmptyState(
              title: 'Serviço não encontrado',
              message: 'Não foi possível recuperar esse detalhe pela rota atual.',
            );
          }

          final timeline = data?.history.timeline.isNotEmpty == true
              ? data!.history.timeline
              : item.timeline;
          final notes = data?.history.notes ?? const [];
          final attachments = data?.history.attachments ?? const [];
          final canUploadPhotos =
              item.status == ScheduleStatus.inService ||
              item.status == ScheduleStatus.completed;

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
                      if (item.vehicleSummary != null) ...[
                        const SizedBox(height: 6),
                        Text('Veículo: ${item.vehicleSummary}'),
                      ],
                      if ((item.serviceDescription ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Escopo do serviço',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(item.serviceDescription!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ActionPanel(
                schedule: item,
                isProcessing: _isProcessing,
                onOpenMap: _openOnMap,
                onStart: _startService,
                onComplete: _completeService,
              ),
              const SizedBox(height: 16),
              ScheduleAttachmentsCard(
                attachments: attachments,
                isUploading: _isUploadingAttachment,
                showUploadActions: true,
                uploadEnabled: canUploadPhotos,
                onUploadFromCamera: () => _uploadPhoto(ImageSource.camera),
                onUploadFromGallery: () => _uploadPhoto(ImageSource.gallery),
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
                  title: 'Observações técnicas',
                  inputLabel: 'Registrar observação técnica',
                  submitLabel: 'Salvar observação técnica',
                  onSubmit: _submitNote,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.schedule,
    required this.isProcessing,
    required this.onOpenMap,
    required this.onStart,
    required this.onComplete,
  });

  final InstallationSchedule schedule;
  final bool isProcessing;
  final Future<void> Function() onOpenMap;
  final Future<void> Function() onStart;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final canStart = schedule.status == ScheduleStatus.scheduled;
    final canComplete = schedule.status == ScheduleStatus.inService;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ações rápidas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir no Google Maps'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: canStart && !isProcessing ? onStart : null,
              icon: isProcessing && canStart
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: const Text('Iniciar atendimento'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: canComplete && !isProcessing ? onComplete : null,
              icon: isProcessing && canComplete
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.task_alt),
              label: const Text('Concluir instalação'),
            ),
            const SizedBox(height: 12),
            Text(
              'Depois de iniciar o atendimento, registre as fotos da instalação e conclua o serviço por aqui.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicianJobDetailsData {
  const _TechnicianJobDetailsData({
    this.schedule,
    required this.history,
    this.historyError,
  });

  final InstallationSchedule? schedule;
  final ScheduleHistoryBundle history;
  final String? historyError;
}
