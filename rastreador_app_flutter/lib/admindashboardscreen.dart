import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

// ----------------------------------------------------
// MODELO DE USUÁRIO (TÉCNICO) - Criado para este arquivo
// ----------------------------------------------------
class User {
  final int id;
  final String name;
  final String role; 

  User({required this.id, required this.name, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }
}
// ----------------------------------------------------

class AdminDashboardScreen extends StatefulWidget {
  final String authToken;
  final int userId; // ID do admin logado

  const AdminDashboardScreen({
    super.key, 
    required this.authToken,
    required this.userId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _tickets = [];
  List<User> _technicians = []; // Nova lista para os técnicos
  bool _isLoadingTickets = true;
  bool _isLoadingTechs = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicia o carregamento de tickets e técnicos em paralelo
    _fetchTechnicians();
    _fetchTickets();
  }
  
  // ----------------------------------------------------
  // LÓGICA: BUSCAR TÉCNICOS (GET /users)
  // ----------------------------------------------------
  Future<void> _fetchTechnicians() async {
    setState(() {
      _isLoadingTechs = true;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/users');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['users'] is List) {
          final List<dynamic> userList = data['users'];
          setState(() {
            // Mapeia e filtra APENAS por usuários com role 'tech'
            _technicians = userList
                .map((json) => User.fromJson(json))
                .where((user) => user.role == 'tech')
                .toList();
            _isLoadingTechs = false;
          });
        }
      } else {
        // Erro ao carregar técnicos
        setState(() {
          _errorMessage = 'Falha ao carregar técnicos. Código: ${response.statusCode}';
          _isLoadingTechs = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de rede ao carregar técnicos: $e';
        _isLoadingTechs = false;
      });
      print('Erro ao buscar técnicos: $e');
    }
  }


  // ----------------------------------------------------
  // LÓGICA: BUSCAR TICKETS (GET /tickets)
  // ----------------------------------------------------
  Future<void> _fetchTickets() async {
    setState(() {
      _isLoadingTickets = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/tickets'); 
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
          _tickets = data['tickets'] ?? [];
          _isLoadingTickets = false;
        });
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}';
          _isLoadingTickets = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de rede ou servidor: $e';
        _isLoadingTickets = false;
      });
      print('Erro ao buscar tickets: $e');
    }
  }


  // ----------------------------------------------------
  // LÓGICA: GERENCIAR TICKET (PUT /tickets/:id/approve)
  // ----------------------------------------------------
  Future<void> _manageTicket({
    required String ticketId, 
    required int adminId, 
    required int assignedToId,
  }) async {
    
    // Mensagem de feedback inicial
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aprovando e atribuindo ticket #${ticketId} ao técnico ID $assignedToId...')),
    );

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/approve');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'admin_id': adminId,
          'assigned_to': assignedToId,
        }), 
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket aprovado e atribuído com sucesso!')),
        );
        _fetchTickets(); // Recarrega a lista para mostrar a mudança
      } else {
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

  // ----------------------------------------------------
  // UI: DIALOG DE APROVAÇÃO COM DROPDOWN
  // ----------------------------------------------------
  Future<void> _showAssignmentDialog(Map<String, dynamic> ticket) async {
    User? selectedTech; 

    // Se a lista de técnicos ainda não carregou, avisa e cancela
    if (_isLoadingTechs) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aguarde o carregamento dos técnicos.')),
        );
      return;
    }
    
    // Filtra técnicos que já têm o ID atribuído para pré-selecionar no dropdown, se houver
    if (ticket['assigned_to'] != null) {
      try {
        selectedTech = _technicians.firstWhere(
          (t) => t.id == ticket['assigned_to'],
        );
      } catch (_) {
        // Se o ID atribuído não estiver na lista atual de técnicos
        selectedTech = null;
      }
    }


    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Atribuir Técnico e Aprovar'),
          content: StatefulBuilder( // Permite atualizar o Dropdown no Dialog
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ticket # ${ticket['id']} - Cliente: ${ticket['customer_name']}'),
                  const SizedBox(height: 15),
                  const Text('Selecione o Técnico:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  // Dropdown para seleção do técnico
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<User>(
                        value: selectedTech,
                        hint: const Text('Escolha um técnico'),
                        isExpanded: true,
                        items: _technicians.map((User tech) {
                          return DropdownMenuItem<User>(
                            value: tech,
                            child: Text(tech.name),
                          );
                        }).toList(),
                        onChanged: (User? newValue) {
                          setState(() {
                            selectedTech = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_technicians.isEmpty)
                     const Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text('Nenhum técnico encontrado no banco de dados.', style: TextStyle(color: Colors.red, fontSize: 14)),
                    )
                  else if (selectedTech == null) 
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Selecione o técnico para liberar a aprovação.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              // O botão de aprovar só é habilitado se um técnico for selecionado E houver técnicos.
              onPressed: selectedTech != null && _technicians.isNotEmpty
                  ? () {
                      Navigator.of(context).pop();
                      _manageTicket(
                        ticketId: ticket['id'].toString(), 
                        adminId: widget.userId,
                        assignedToId: selectedTech!.id, // Envia o ID do técnico
                      );
                    }
                  : null, // Desabilitado se selectedTech for null ou não houver técnicos
              child: const Text('Aprovar e Atribuir'),
            ),
          ],
        );
      },
    );
  }


  // ----------------------------------------------------
  // UI: ITEM DA LISTA AJUSTADO
  // ----------------------------------------------------
  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    final isApproved = ticket['approved'] == true;
    final isAssigned = ticket['assigned_to'] != null;
    final assignedToId = ticket['assigned_to'];
    
    // Define o status e a cor
    String statusText = 'PENDENTE';
    Color statusColor = Colors.orange.shade700;

    if (isApproved && isAssigned) {
      statusText = 'APROVADO / ATRIBUÍDO';
      statusColor = Colors.green.shade700;
    } else if (isApproved && !isAssigned) {
      statusText = 'APROVADO (SEM TÉCNICO)';
      statusColor = Colors.lightBlue.shade700;
    }
    
    // Busca o nome do técnico
    String assignedTechName = 'Ninguém';
    if (assignedToId != null) {
        final tech = _technicians.firstWhere(
            (t) => t.id == assignedToId, 
            orElse: () => User(id: -1, name: 'ID #$assignedToId (Desconhecido)', role: 'tech')
        );
        assignedTechName = tech.name;
    }
    
    final ticketId = ticket['id'].toString();

    // Formata a data
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
                Expanded(
                  child: Text(
                    'Ticket #$ticketId: ${ticket['title']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
            Text('Atribuído a: $assignedTechName'),
            Text('Criação: $date'),
            const SizedBox(height: 12),
            
            // Botões de Ação, visíveis apenas se AINDA não estiver aprovado
            if (!isApproved)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reprovar', style: TextStyle(color: Colors.red)),
                    // O Reprovar está desabilitado, pois você precisaria de uma rota específica no backend
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
                    // Chama o Dialog de Atribuição
                    onPressed: (_isLoadingTechs || _technicians.isEmpty) 
                      ? null // Desabilitado se estiver carregando técnicos ou se não houver nenhum
                      : () => _showAssignmentDialog(ticket), 
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // UI: WIDGET PRINCIPAL
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Verifica o estado geral de carregamento
    final isOverallLoading = _isLoadingTickets || _isLoadingTechs;
    final loadingMessage = _isLoadingTickets ? 'Carregando Tickets...' : 'Carregando Técnicos...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchTechnicians();
              _fetchTickets();
            },
            tooltip: 'Recarregar Tudo',
          ),
        ],
      ),
      body: isOverallLoading
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text(loadingMessage),
              ],
            ))
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
                          onPressed: () {
                            _fetchTechnicians();
                            _fetchTickets();
                          },
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
