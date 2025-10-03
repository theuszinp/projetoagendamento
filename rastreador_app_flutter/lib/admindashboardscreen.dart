import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Importa a URL base definida em main.dart
// (Presume-se que a constante API_BASE_URL está acessível ou definida)
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class AdminDashboardScreen extends StatefulWidget {
  final String authToken;
  // Adicionando o userId (admin_id) que será usado na aprovação
  final int userId; 

  const AdminDashboardScreen({
    super.key, 
    required this.authToken,
    required this.userId, // Agora a tela precisa receber o ID do admin logado
  });

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

  // Função para buscar todos os tickets (GET /tickets)
  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // CORREÇÃO DA ROTA: de '/tickets/all' para '/tickets'
      final url = Uri.parse('$API_BASE_URL/tickets'); 
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          // A autenticação JWT deve ser usada, mas aqui usamos o token como Bearer
          'Authorization': 'Bearer ${widget.authToken}', 
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // O backend retorna { tickets: [...] }, então precisamos extrair a lista
        setState(() {
          _tickets = data['tickets'] ?? []; // Garante que a lista seja extraída corretamente
          _isLoading = false;
        });
      } else {
        // Tenta decodificar o erro, que agora deve ser JSON
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}';
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

  // A função de aprovar no backend agora exige assigned_to e admin_id
  Future<void> _manageTicket(String ticketId) async {
    // Usaremos um valor placeholder por enquanto, mas ele deve ser substituído pelo ID do técnico real.
    // É VITAL que assigned_to seja um ID válido de um técnico/usuário no seu DB
    final placeholderAssignedToId = 2; // Substitua pelo ID de um técnico de teste

    // Usa o ID do admin logado
    final adminId = widget.userId; 

    await _showAssignmentDialog(ticketId, adminId, placeholderAssignedToId);
  }

  Future<void> _showAssignmentDialog(String ticketId, int adminId, int assignedToId) async {
    // Implementação de um diálogo real para selecionar o técnico (necessário para o backend)
    // Para simplificar e testar a API, chamaremos a aprovação diretamente com o placeholder.

    // APROVAÇÃO REAL (PUT /tickets/:id/approve)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aprovando ticket e atribuindo ao técnico ID $assignedToId...')),
    );

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/approve');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        // Dados exigidos pelo backend: assigned_to e admin_id
        body: json.encode({
          'admin_id': adminId,
          'assigned_to': assignedToId,
        }), 
      );

      if (response.statusCode == 200) {
        // Sucesso: atualiza a lista de tickets
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket aprovado e atribuído com sucesso!')),
        );
        _fetchTickets(); // Recarrega a lista para mostrar a mudança de status
      } else {
        // Erro no gerenciamento
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Falha ao gerenciar ticket. Código: ${response.statusCode}');
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
    // Usamos a coluna 'approved' do DB para determinar o status
    final isApproved = ticket['approved'] == true;
    final isAssigned = ticket['assigned_to'] != null;

    String statusText = 'PENDENTE';
    Color statusColor = Colors.orange.shade700;

    if (isApproved && isAssigned) {
      statusText = 'APROVADO / ATRIBUÍDO';
      statusColor = Colors.green.shade700;
    } else if (isApproved && !isAssigned) {
      statusText = 'APROVADO (SEM TÉCNICO)';
      statusColor = Colors.lightGreen.shade700;
    }
    // Reprovação precisa de uma coluna 'reproved' no DB. Por enquanto, 
    // se não for aprovado, é PENDENTE.

    final ticketId = ticket['id'].toString();

    // Formata a data para melhor visualização (usamos 'created_at' do DB)
    String date = 'Data indisponível';
    if (ticket.containsKey('created_at')) {
      try {
        final dateTime = DateTime.parse(ticket['created_at']);
        date = '${dateTime.day}/${dateTime.month}/${dateTime.year} às ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        date = ticket['created_at'].toString();
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
                  'Ticket #$ticketId: ${ticket['title']}',
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
            const SizedBox(height: 4),
            Text('Cliente: ${ticket['customer_name'] ?? 'N/A'}'),
            Text('Endereço: ${ticket['customer_address'] ?? 'N/A'}'),
            Text('Prioridade: ${ticket['priority'] ?? 'N/A'}'),
            Text('Solicitado por: ${ticket['requested_by'] ?? 'N/A'}'),
            Text('Atribuído a: ${ticket['assigned_to'] ?? 'Ninguém'}'),
            Text('Criação: $date'),
            const SizedBox(height: 12),
            // Botões de Ação, visíveis apenas se AINDA não estiver aprovado
            if (!isApproved)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Reprovar: Você precisaria de uma rota PUT /tickets/:id/reprove no backend,
                  // que faria um UPDATE setando 'approved=false' (ou adicionaria uma coluna 'reproved=true')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reprovar', style: TextStyle(color: Colors.red)),
                    // Desabilitei o Reprovar pois a rota no backend não suporta reprovação
                    onPressed: null, 
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Aprovar e Atribuir'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _manageTicket(ticketId), // Chama a função que vai aprovar
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
