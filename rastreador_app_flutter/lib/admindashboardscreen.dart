import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Importa a URL base definida em main.dart
// (Presume-se que a constante API_BASE_URL está acessível ou definida em main.dart)
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';
// Se você definiu em main.dart: import 'main.dart';
// E se a variável é pública: const String API_BASE_URL = MainApp.API_BASE_URL;

class AdminDashboardScreen extends StatefulWidget {
  final String authToken;

  const AdminDashboardScreen({super.key, required this.authToken});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  // Função para buscar todos os tickets (GET /tickets/all)
  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/all');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tickets = data;
          _isLoading = false;
        });
      } else {
        // Se a API retornar um erro (ex: 401, 404, 500)
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Erros de conexão (DNS, timeout, etc.)
      setState(() {
        _errorMessage = 'Erro de rede ou servidor: $e';
        _isLoading = false;
      });
      print('Erro ao buscar tickets: $e');
    }
  }

  // Função para aprovar ou reprovar um ticket (PUT /tickets/:id/approve)
  Future<void> _manageTicket(String ticketId, bool approve) async {
    // Sinaliza ao usuário que a ação está em andamento (opcional, mas bom UX)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(approve ? 'Aprovando ticket...' : 'Reprovando ticket...')),
    );

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/approve');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({'approve': approve}), // Envia true ou false
      );

      if (response.statusCode == 200) {
        // Sucesso: atualiza a lista de tickets
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Ticket aprovado com sucesso!' : 'Ticket reprovado com sucesso!')),
        );
        _fetchTickets(); // Recarrega a lista para mostrar a mudança de status
      } else {
        // Erro no gerenciamento
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Falha ao gerenciar ticket. Código: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerenciar ticket: ${e.toString()}')),
      );
      print('Erro ao gerenciar ticket: $e');
    }
  }

  // Constrói a UI para um único item da lista
  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'PENDENTE';
    final statusColor = status == 'APROVADO' ? Colors.green.shade700 : (status == 'REPROVADO' ? Colors.red.shade700 : Colors.orange.shade700);
    final statusText = status.toUpperCase();
    final ticketId = ticket['id'].toString();

    // Formata a data para melhor visualização (se o campo 'data' existir)
    String date = 'Data indisponível';
    if (ticket.containsKey('data')) {
      try {
        final dateTime = DateTime.parse(ticket['data']);
        date = '${dateTime.day}/${dateTime.month}/${dateTime.year} às ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        date = ticket['data'].toString();
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ticket #$ticketId',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Usuário: ${ticket['userName'] ?? 'Desconhecido'} (${ticket['userId'] ?? 'N/A'})'),
            Text('Serviço: ${ticket['serviceType'] ?? 'Não especificado'}'),
            Text('Data e Hora: $date'),
            const SizedBox(height: 12),
            // Botões de Ação, visíveis apenas se o status não for final
            if (status == 'PENDENTE')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reprovar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _manageTicket(ticketId, false),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Aprovar'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _manageTicket(ticketId, true),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTickets,
            tooltip: 'Recarregar Tickets',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'Erro ao carregar dados:\n$_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchTickets,
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _tickets.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum ticket encontrado.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tickets.length,
                      itemBuilder: (context, index) {
                        return _buildTicketItem(_tickets[index] as Map<String, dynamic>);
                      },
                    ),
    );
  }
}
