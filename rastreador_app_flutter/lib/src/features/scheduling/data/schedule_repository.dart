import '../../../core/network/api_client.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../core/utils/schedule_description_codec.dart';
import '../../users/domain/app_user.dart';
import '../../users/domain/user_role.dart';
import '../domain/address.dart';
import '../domain/create_schedule_input.dart';
import '../domain/customer.dart';
import '../domain/installation_schedule.dart';
import '../domain/schedule_attachment.dart';
import '../domain/schedule_history_bundle.dart';
import '../domain/schedule_note.dart';
import '../domain/schedule_priority.dart';
import '../domain/schedule_status.dart';
import '../domain/schedule_timeline_entry.dart';

class ScheduleRepository {
  ScheduleRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<InstallationSchedule?> fetchScheduleById(int scheduleId) async {
    try {
      final response = await _apiClient.getJson('/schedules/$scheduleId');
      final ticket = response['ticket'];
      if (ticket is! Map) {
        return null;
      }

      return _mapSchedule(ticket.cast<String, dynamic>());
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<InstallationSchedule>> fetchAdminSchedules() async {
    final response = await _apiClient.getJson('/tickets');
    final list = (response['tickets'] as List?) ?? const [];
    return _mapSchedules(list);
  }

  Future<List<InstallationSchedule>> fetchSellerSchedules(int sellerId) async {
    final response = await _apiClient.getJson('/tickets/requested/$sellerId');
    final list = (response['tickets'] as List?) ?? const [];
    return _mapSchedules(list);
  }

  Future<List<InstallationSchedule>> fetchTechnicianSchedules(
    int technicianId,
  ) async {
    final response = await _apiClient.getJson('/tickets/assigned/$technicianId');
    final list = (response['tickets'] as List?) ?? const [];
    return _mapSchedules(list);
  }

  Future<void> createSchedule({
    required int requesterId,
    required CreateScheduleInput input,
  }) async {
    await _apiClient.postJson(
      '/tickets',
      body: <String, dynamic>{
        'title': input.title,
        'description': ScheduleDescriptionCodec.encode(input),
        'priority': input.priority.apiValue,
        'requestedBy': requesterId,
        'customerName': input.customer.name,
        'address': input.address.fullText,
        'identifier': input.customer.document,
        'phoneNumber': input.customer.phone,
      },
    );
  }

  Future<void> approveSchedule({
    required int scheduleId,
    required int technicianId,
  }) async {
    await _apiClient.putJson(
      '/tickets/$scheduleId/approve',
      body: <String, dynamic>{'assigned_to': technicianId},
    );
  }

  Future<void> rejectSchedule(int scheduleId) async {
    await _apiClient.putJson('/tickets/$scheduleId/reject');
  }

  Future<void> startService(int scheduleId) async {
    await _updateTechnicalStatus(scheduleId, 'IN_PROGRESS');
  }

  Future<void> completeService(int scheduleId) async {
    await _updateTechnicalStatus(scheduleId, 'COMPLETED');
  }

  Future<ScheduleHistoryBundle> fetchScheduleHistory(int scheduleId) async {
    try {
      final response = await _apiClient.getJson('/schedules/$scheduleId/history');
      final history = (response['history'] as List?) ?? const [];
      final notes = (response['notes'] as List?) ?? const [];
      final attachments = (response['attachments'] as List?) ?? const [];

      return ScheduleHistoryBundle(
        timeline: history
            .map(
              (item) => _mapTimelineEntry((item as Map).cast<String, dynamic>()),
            )
            .toList(),
        notes: notes
            .map(
              (item) => _mapScheduleNote((item as Map).cast<String, dynamic>()),
            )
            .toList(),
        attachments: attachments
            .map(
              (item) =>
                  _mapScheduleAttachment((item as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
    } on ApiException catch (error) {
      if (error.isNotFound) {
        return const ScheduleHistoryBundle(
          timeline: [],
          notes: [],
          attachments: [],
        );
      }
      rethrow;
    }
  }

  Future<void> createScheduleNote({
    required int scheduleId,
    required String content,
    String? noteType,
  }) async {
    try {
      await _apiClient.postJson(
        '/schedules/$scheduleId/notes',
        body: <String, dynamic>{
          'content': content,
          if (noteType != null) 'note_type': noteType,
        },
      );
    } on ApiException catch (error) {
      if (error.isNotFound) {
        throw ApiException(
          'Seu backend atual ainda não suporta observações e histórico em tempo real. Atualize a API primeiro.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<ScheduleAttachment> uploadScheduleAttachment({
    required int scheduleId,
    required String fileName,
    required String contentType,
    required String base64Content,
  }) async {
    try {
      final response = await _apiClient.postJson(
        '/schedules/$scheduleId/attachments',
        body: <String, dynamic>{
          'file_name': fileName,
          'content_type': contentType,
          'base64_content': base64Content,
        },
      );
      final attachment = response['attachment'];
      if (attachment is! Map) {
        throw ApiException('Resposta inválida ao enviar foto.');
      }

      return _mapScheduleAttachment(attachment.cast<String, dynamic>());
    } on ApiException catch (error) {
      if (error.isNotFound) {
        throw ApiException(
          'Seu backend atual ainda não suporta anexos de instalação. Atualize a API primeiro.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<void> _updateTechnicalStatus(int scheduleId, String status) async {
    await _apiClient.putJson(
      '/tickets/$scheduleId/tech-status',
      body: <String, dynamic>{'new_status': status},
    );
  }

  ScheduleTimelineEntry _mapTimelineEntry(Map<String, dynamic> json) {
    final nextStatus = (json['next_status'] ?? '').toString();
    final note = (json['note'] ?? '').toString().trim();
    final actorName = (json['actor_name'] ?? '').toString().trim();
    final createdAt =
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now();

    String label;
    if (nextStatus.startsWith('NOTE:')) {
      final noteType = nextStatus.replaceFirst('NOTE:', '').toLowerCase();
      switch (noteType) {
        case 'internal':
          label = 'Observação interna';
          break;
        case 'technical':
          label = 'Observação técnica';
          break;
        case 'seller':
          label = 'Observação comercial';
          break;
        default:
          label = 'Observação';
      }
    } else {
      switch (nextStatus) {
        case 'PENDING':
          label = 'Solicitado';
          break;
        case 'APPROVED':
          label = 'Aprovado';
          break;
        case 'REJECTED':
          label = 'Reprovado';
          break;
        case 'IN_PROGRESS':
          label = 'Atendimento iniciado';
          break;
        case 'COMPLETED':
          label = 'Concluído';
          break;
        case 'ATTACHMENT:PHOTO':
          label = 'Foto anexada';
          break;
        default:
          label = nextStatus.isEmpty ? 'Atualização' : nextStatus;
      }
    }

    final description = [
      if (actorName.isNotEmpty) 'Por $actorName',
      if (note.isNotEmpty) note,
    ].join(' • ');

    return ScheduleTimelineEntry(
      label: label,
      createdAt: createdAt,
      description: description.isEmpty ? null : description,
    );
  }

  ScheduleNote _mapScheduleNote(Map<String, dynamic> json) {
    return ScheduleNote(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      type: (json['note_type'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      authorName: (json['author_name'] ?? '').toString(),
      authorRole: (json['author_role'] ?? '').toString(),
    );
  }

  ScheduleAttachment _mapScheduleAttachment(Map<String, dynamic> json) {
    final uploadedByName = (json['uploaded_by_name'] ?? '').toString().trim();

    return ScheduleAttachment(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      url: (json['url'] ?? '').toString(),
      fileName: (json['file_name'] ?? 'foto-instalacao.jpg').toString(),
      contentType: (json['content_type'] ?? 'image/jpeg').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      uploadedByName: uploadedByName.isEmpty ? null : uploadedByName,
    );
  }

  List<InstallationSchedule> _mapSchedules(List<dynamic> rawList) {
    return rawList
        .map(
          (item) => _mapSchedule((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  InstallationSchedule _mapSchedule(Map<String, dynamic> json) {
    final description = (json['description'] ?? '').toString();
    final metadata = ScheduleDescriptionCodec.decode(description);
    final createdAt =
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now();
    final approvedAt =
        DateTime.tryParse((json['approved_at'] ?? '').toString());
    final startedAt = DateTime.tryParse((json['started_at'] ?? '').toString());
    final completedAt =
        DateTime.tryParse((json['completed_at'] ?? '').toString());
    final status = _mapStatus(
      apiStatus: (json['status'] ?? '').toString(),
      techStatus: (json['tech_status'] ?? '').toString(),
    );

    final installerId = int.tryParse((json['assigned_to'] ?? '').toString());
    final installerName =
        (json['assigned_to_name'] ?? json['approved_by_admin_name'] ?? '')
            .toString();

    return InstallationSchedule(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      title: (json['title'] ?? 'Instalação').toString(),
      priority: SchedulePriority.fromApi((json['priority'] ?? '').toString()),
      status: status,
      customer: Customer(
        id: int.tryParse((json['customer_id'] ?? '').toString()),
        name: (json['customer_name'] ?? 'Cliente').toString(),
        document: (json['identifier'] ?? '').toString(),
        phone: metadata.contactPhone ?? 'Não informado',
      ),
      address: Address(
        fullText:
            (json['customer_address'] ?? 'Endereço não informado').toString(),
      ),
      createdAt: createdAt,
      desiredDate: DateTime.tryParse(metadata.desiredDateLabel ?? ''),
      vehicleSummary: metadata.vehicleSummary,
      sellerNotes: metadata.sellerNotes,
      serviceDescription: metadata.technicalDetails ?? description,
      installer: installerId == null
          ? null
          : AppUser(
              id: installerId,
              name: installerName.isEmpty ? 'Instalador' : installerName,
              email: '',
              role: UserRole.technician,
            ),
      timeline: [
        ScheduleTimelineEntry(
          label: 'Solicitado',
          createdAt: createdAt,
          description:
              'Solicitação criada em ${DateTimeFormatter.shortDateTime(createdAt)}.',
        ),
        if (approvedAt != null)
          ScheduleTimelineEntry(
            label: status == ScheduleStatus.rejected ? 'Reprovado' : 'Aprovado',
            createdAt: approvedAt,
            description:
                'Movimentado pelo admin em ${DateTimeFormatter.shortDateTime(approvedAt)}.',
          ),
        if (startedAt != null)
          ScheduleTimelineEntry(
            label: 'Atendimento iniciado',
            createdAt: startedAt,
            description:
                'Instalador iniciou o atendimento em ${DateTimeFormatter.shortDateTime(startedAt)}.',
          ),
        if (completedAt != null)
          ScheduleTimelineEntry(
            label: 'Concluído',
            createdAt: completedAt,
            description:
                'Serviço concluído em ${DateTimeFormatter.shortDateTime(completedAt)}.',
          ),
      ],
    );
  }

  ScheduleStatus _mapStatus({
    required String apiStatus,
    required String techStatus,
  }) {
    final normalizedApi = apiStatus.trim().toUpperCase();
    final normalizedTech = techStatus.trim().toUpperCase();

    if (normalizedApi == 'REJECTED') {
      return ScheduleStatus.rejected;
    }

    if (normalizedTech == 'COMPLETED') {
      return ScheduleStatus.completed;
    }

    if (normalizedTech == 'IN_PROGRESS') {
      return ScheduleStatus.inService;
    }

    if (normalizedApi == 'APPROVED') {
      return ScheduleStatus.scheduled;
    }

    return ScheduleStatus.pendingApproval;
  }
}
