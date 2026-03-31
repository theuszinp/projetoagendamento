import '../../../core/network/api_client.dart';
import '../domain/completed_services_report.dart';

class ReportRepository {
  ReportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CompletedServicesReport> fetchCompletedServicesReport({
    required DateTime from,
    required DateTime to,
    String? search,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/reports/completed-services',
        query: <String, dynamic>{
          'from': _formatDate(from),
          'to': _formatDate(to),
          if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        },
      );

      final range = (response['range'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final summary = (response['summary'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final rows = (response['rows'] as List?) ?? const [];

      return CompletedServicesReport(
        from: DateTime.tryParse((range['from'] ?? '').toString()) ?? from,
        to: DateTime.tryParse((range['to'] ?? '').toString()) ?? to,
        summary: CompletedServicesSummary(
          totalServices:
              int.tryParse((summary['total_services'] ?? 0).toString()) ?? 0,
          totalMinutes:
              double.tryParse((summary['total_minutes'] ?? 0).toString()) ?? 0,
          averageMinutes:
              double.tryParse((summary['avg_minutes'] ?? 0).toString()) ?? 0,
          techniciansInvolved: int.tryParse(
                (summary['technicians_involved'] ?? 0).toString(),
              ) ??
              0,
          servicesWithPhotos: int.tryParse(
                (summary['services_with_photos'] ?? 0).toString(),
              ) ??
              0,
        ),
        items: rows
            .map(
              (item) =>
                  _mapItem((item as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
    } on ApiException catch (error) {
      if (error.isNotFound) {
        throw ApiException(
          'Seu backend atual ainda não suporta o relatório completo de serviços concluídos.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  CompletedServiceItem _mapItem(Map<String, dynamic> json) {
    return CompletedServiceItem(
      ticketId: int.tryParse((json['ticket_id'] ?? 0).toString()) ?? 0,
      title: (json['title'] ?? 'Serviço concluído').toString(),
      customerName: (json['customer_name'] ?? 'Cliente').toString(),
      customerAddress: (json['customer_address'] ?? 'Endereço não informado')
          .toString(),
      sellerName: (json['seller_name'] ?? 'Vendedor').toString(),
      technicianName: (json['tech_name'] ?? 'Instalador').toString(),
      completedAt:
          DateTime.tryParse((json['completed_at'] ?? '').toString()) ??
              DateTime.now(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()),
      attachmentsCount:
          int.tryParse((json['attachments_count'] ?? 0).toString()) ?? 0,
      durationMinutes:
          double.tryParse((json['duration_min'] ?? 0).toString()) ?? 0,
    );
  }

  String _formatDate(DateTime value) {
    return value.toIso8601String().split('T').first;
  }
}
