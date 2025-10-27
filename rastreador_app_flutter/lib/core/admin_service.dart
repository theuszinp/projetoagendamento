import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Para debugPrint

// URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';
const Duration TIMEOUT_DURATION = Duration(seconds: 15);

// Classe de Exceção para erros de API específicos
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, [this.statusCode = 0]);

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

class AdminService {
  final String authToken;

  AdminService({required this.authToken});

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
  }

  // --- BUSCAR TÉCNICOS (GET /users) ---
  // Retorna uma lista de Map<String, dynamic> para ser mapeada para o modelo User fora do Service.
  Future<List<dynamic>> fetchTechniciansData() async {
    final url = Uri.parse('$API_BASE_URL/users');
    try {
      final response =
          await http.get(url, headers: _getHeaders()).timeout(TIMEOUT_DURATION);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['users'] is List) {
          // Filtra aqui, mas você pode deixar o filtro 'tech' no Dashboard para flexibilidade.
          // Por enquanto, retorna a lista bruta para ser filtrada no ViewModel/Widget.
          return data['users'];
        }
        throw ApiException('Formato de resposta inesperado ao buscar usuários.',
            response.statusCode);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(errorData['error'] ?? 'Falha ao carregar técnicos.',
            response.statusCode);
      }
    } catch (e) {
      debugPrint('Erro em fetchTechnicians: $e');
      rethrow; // Propaga a exceção para ser tratada na UI
    }
  }

  // --- BUSCAR TICKETS (GET /tickets) ---
  Future<List<dynamic>> fetchTicketsData() async {
    final url = Uri.parse('$API_BASE_URL/tickets');
    try {
      final response =
          await http.get(url, headers: _getHeaders()).timeout(TIMEOUT_DURATION);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['tickets'] ?? [];
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(errorData['error'] ?? 'Falha ao carregar tickets.',
            response.statusCode);
      }
    } catch (e) {
      debugPrint('Erro em fetchTickets: $e');
      rethrow;
    }
  }

  // --- REPROVAR TICKET (PUT /tickets/:id/reject) ---
  Future<void> rejectTicket({
    required String ticketId,
    required int adminId,
  }) async {
    final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/reject');
    try {
      final response = await http
          .put(
            url,
            headers: _getHeaders(),
            body: json.encode({'admin_id': adminId}),
          )
          .timeout(TIMEOUT_DURATION);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw ApiException(errorData['error'] ?? 'Falha ao reprovar ticket.',
            response.statusCode);
      }
    } catch (e) {
      debugPrint('Erro em rejectTicket: $e');
      rethrow;
    }
  }

  // --- APROVAR E ATRIBUIR TICKET (PUT /tickets/:id/approve) ---
  Future<void> approveTicket({
    required String ticketId,
    required int adminId,
    required int assignedToId,
  }) async {
    final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/approve');
    try {
      final response = await http
          .put(
            url,
            headers: _getHeaders(),
            body: json.encode({
              'admin_id': adminId,
              'assigned_to': assignedToId,
            }),
          )
          .timeout(TIMEOUT_DURATION);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw ApiException(errorData['error'] ?? 'Falha ao aprovar ticket.',
            response.statusCode);
      }
    } catch (e) {
      debugPrint('Erro em approveTicket: $e');
      rethrow;
    }
  }
}
