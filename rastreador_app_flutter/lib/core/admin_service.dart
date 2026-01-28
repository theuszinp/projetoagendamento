import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AdminService {
  final ApiClient _api;

  AdminService(this._api);

  /// GET /users (admin)
  Future<List<dynamic>> fetchTechniciansData() async {
    final data = await _api.getJson('/users');
    final users = (data['users'] as List?) ?? [];
    return users;
  }

  /// GET /tickets (admin)
  Future<List<dynamic>> fetchTicketsData() async {
    final data = await _api.getJson('/tickets');
    final tickets = (data['tickets'] as List?) ?? [];
    return tickets;
  }

  /// PUT /tickets/:id/reject
  Future<void> rejectTicket(int ticketId, {String? reason}) async {
    await _api.putJson('/tickets/$ticketId/reject', body: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> approveTicket(int ticketId, {int? techId}) async {
    // Alguns backends usam um endpoint /approve; aqui usamos o PUT padrão
    await _api.putJson('/tickets/$ticketId/approve', body: {
      if (techId != null) 'assigned_to': techId,
    });
  }
}
