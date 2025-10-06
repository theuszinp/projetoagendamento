import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

// ----------------------------------------------------
// MODELO DE USUÁRIO (TÉCNICO)
// ----------------------------------------------------
class User {
  final int id;
  final String name;
  final String role;

  User({required this.id, required this.name, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    // Garante que o ID é um inteiro
    final rawId = json['id'];
    int userId;
    if (rawId is int) {
      userId = rawId;
    } else if (rawId is String) {
      userId = int.tryParse(rawId) ?? 0;
    } else {
      userId = 0;
    }

    return User(
      id: userId,
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
  List<User> _technicians = []; // Lista para os técnicos disponíveis
  bool _isLoadingTickets = true;
  bool _isLoadingTechs = true;
  String? _errorMessage;

  // Estado para filtrar os tickets. Inicialmente, mostra apenas Pendentes.
  String _currentFilter = 'PENDING'; // Valores possíveis: 'PENDING', 'APPROVED', 'REJECTED', 'ALL'

  @override
  void initState() {
    super.initState();
    // Otimização: Inicia o carregamento de tickets e técnicos em paralelo.
    _fetchTechnicians();
    _fetchTickets();
  }

  // ----------------------------------------------------
  // LÓGICA: BUSCAR TÉCNICOS (GET /users)
  // ----------------------------------------------------
  Future<void> _fetchTechnicians() async {
    // Mantém o isLoadingTechs = true para o primeiro carregamento ou recarga
    if (!mounted) return;
    if (!_isLoadingTechs) {
      setState(() {
        _isLoadingTechs = true;
      });
    }

    try {
      // Usando /users e filtrando no Flutter
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
          if (mounted) {
            setState(() {
              // Mapeia e filtra APENAS por usuários com role 'tech'
              _technicians = userList
                  .map((json) => User.fromJson(json))
                  .where((user) => user.role.toLowerCase() == 'tech') // Garante que a comparação é minúscula
                  .toList();
              _isLoadingTechs = false;
              _errorMessage = null;
            });
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          setState(() {
            _errorMessage = errorData['error'] ?? 'Falha ao carregar técnicos. Código: ${response.statusCode}';
            _isLoadingTechs = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro de rede ao carregar técnicos: $e';
          _isLoadingTechs = false;
        });
      }
    }
  }

  // ----------------------------------------------------
  // LÓGICA: BUSCAR TICKETS (GET /tickets)
  // ----------------------------------------------------
  Future<void> _fetchTickets() async {
    if (!mounted) return;
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
        if (mounted) {
          setState(() {
            // Armazena todos os tickets recebidos
            _tickets = data['tickets'] ?? [];
            _isLoadingTickets = false;
            _errorMessage = null;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          setState(() {
            _errorMessage = errorData['error'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}';
            _isLoadingTickets = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro de rede ou servidor: $e';
          _isLoadingTickets = false;
        });
      }
    }
  }

  // ----------------------------------------------------
  // LÓGICA: REPROVAR TICKET (PUT /tickets/:id/reject)
  // ----------------------------------------------------
  Future<void> _rejectTicket(String ticketId, int adminId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Reprovação'),
        content: Text('Tem certeza que deseja reprovar o Ticket #$ticketId? Ele será devolvido ao solicitante.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reprovar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    // Feedback imediato
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reprovando ticket #$ticketId...')),
      );
    }

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/$ticketId/reject');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode({
          'admin_id': adminId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket reprovado com sucesso!')),
          );
          _fetchTickets(); // Recarrega a lista
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Falha ao reprovar ticket. Código: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reprovar ticket: ${e.toString()}')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // LÓGICA: APROVAR E ATRIBUIR TICKET (PUT /tickets/:id/approve)
  // ----------------------------------------------------
  Future<void> _approveTicket({
    required String ticketId,
    required int adminId,
    required int assignedToId,
    required String techName,
  }) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aprovando e atribuindo ticket #$ticketId ao $techName...')),
      );
    }

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
          'assigned_to': assignedToId, // Envia o ID do técnico
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ticket aprovado e atribuído a $techName!')),
          );
          _fetchTickets(); // Recarrega a lista
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Falha ao aprovar ticket. Código: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar ticket: ${e.toString()}')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // UI: DIALOG DE APROVAÇÃO COM DROPDOWN
  // ----------------------------------------------------
  Future<void> _showAssignmentDialog(Map<String, dynamic> ticket) async {
    // A variável selectedTech é inicializada aqui fora, mas será usada E alterada
    // dentro do StatefulBuilder para garantir a re-renderização.
    User? initialSelectedTech;

    // Pré-seleciona o técnico se já houver um atribuído
    if (ticket['assigned_to'] != null) {
      // Tenta converter assigned_to para int, caso seja String
      final assignedToId = (ticket['assigned_to'] is int) ? ticket['assigned_to'] : int.tryParse(ticket['assigned_to'].toString());
      if (assignedToId != null) {
        try {
          initialSelectedTech = _technicians.firstWhere((t) => t.id == assignedToId);
        } catch (_) {
          initialSelectedTech = null;
        }
      }
    }

    return showDialog(
      context: context,
      // O StatefulBuilder envolve o AlertDialog para que possamos usar setState
      // e reabilitar o botão APROVAR quando um técnico for selecionado.
      builder: (BuildContext context) {
        // Declara selectedTech dentro do builder para ser mutável e persistir o valor
        // entre as chamadas do setState do StatefulBuilder.
        User? selectedTech = initialSelectedTech;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Atribuir Técnico e Aprovar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ticket # ${ticket['id']} - Cliente: ${ticket['customer_name']}'),
                  const SizedBox(height: 15),
                  const Text('Selecione o Técnico:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
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
                          // Usa o setState do StatefulBuilder para reconstruir o diálogo (e o botão)
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
                  else if (selectedTech == null && ticket['status'] == 'PENDING')
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Selecione o técnico para liberar a aprovação.', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Aprovar e Atribuir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  // A condição de habilitação é reavaliada após cada setState do Dropdown
                  onPressed: selectedTech != null && _technicians.isNotEmpty
                      ? () {
                          Navigator.of(context).pop();
                          _approveTicket(
                            ticketId: ticket['id'].toString(),
                            adminId: widget.userId,
                            assignedToId: selectedTech!.id,
                            techName: selectedTech!.name,
                          );
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------
  // UI: CONSTRÓI O WIDGET DE FILTRO (Dropdown)
  // ----------------------------------------------------
  Widget _buildFilterDropdown() {
    Map<String, String> filters = {
      'PENDING': 'Pendentes de Avaliação',
      'APPROVED': 'Aprovados/Atribuídos',
      'REJECTED': 'Reprovados',
      'ALL': 'Todos os Tickets',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text('Filtrar por Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _currentFilter,
              isExpanded: true,
              items: filters.keys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key,
                  child: Text(filters[key]!),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _currentFilter = newValue;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // UI: ITEM DA LISTA AJUSTADO COM BOTÕES DE AÇÃO
  // ----------------------------------------------------
  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    final ticketStatus = (ticket['status'] ?? 'PENDING').toString().toUpperCase();
    final ticketId = ticket['id'].toString();

    // Define o status e a cor com base no campo 'status' do backend
    String statusText;
    Color statusColor;

    switch (ticketStatus) {
      case 'APPROVED':
        statusText = 'APROVADO / ATRIBUÍDO';
        statusColor = Colors.green.shade700;
        break;
      case 'REJECTED':
        statusText = 'REPROVADO';
        statusColor = Colors.red.shade700;
        break;
      case 'PENDING':
      default:
        statusText = 'PENDENTE DE AVALIAÇÃO';
        statusColor = Colors.orange.shade700;
        break;
    }

    // Busca o nome do técnico na lista carregada
    final assignedToId = ticket['assigned_to'];
    String assignedTechName = 'Ninguém';
    if (assignedToId != null) {
      final techIdInt = (assignedToId is int) ? assignedToId : int.tryParse(assignedToId.toString());
      if (techIdInt != null) {
        final tech = _technicians.cast<User?>().firstWhere(
            (t) => t?.id == techIdInt,
            orElse: () => null
        );
        assignedTechName = tech?.name ?? ticket['assigned_to_name'] ?? 'ID #$assignedToId (Desconhecido)';
      }
    }

    // Formata a data (simplificado)
    String date = 'Data indisponível';
    if (ticket.containsKey('created_at')) {
      try {
        final dateTime = DateTime.parse(ticket['created_at']);
        // Formato DD/MM/AAAA hh:mm
        date = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} às ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        date = ticket['created_at'].toString().substring(0, 16);
      }
    }

    // Define se os botões de ação devem aparecer (apenas para status PENDING)
    final showActions = ticketStatus == 'PENDING';

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
            const SizedBox(height: 8),
            Text('Cliente: ${ticket['customer_name'] ?? 'N/A'}'),
            Text('Endereço: ${ticket['customer_address'] ?? 'N/A'}'),
            Text('Prioridade: ${ticket['priority'] ?? 'N/A'}'),
            if (ticketStatus == 'APPROVED')
              Text('Atribuído a: $assignedTechName', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            Text('Criação: $date', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            // Botões de Ação, visíveis apenas se o status for PENDENTE
            if (showActions)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reprovar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _rejectTicket(ticketId, widget.userId),
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
                    onPressed: (_isLoadingTechs)
                        ? null
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
    final isOverallLoading = _isLoadingTickets || _isLoadingTechs;
    final loadingMessage = _isLoadingTickets ? 'Carregando Tickets...' : 'Carregando Técnicos...';

    // Filtra a lista de tickets com base no estado _currentFilter
    final filteredTickets = _tickets.where((ticket) {
      final status = (ticket['status'] ?? 'PENDING').toString().toUpperCase();
      return _currentFilter == 'ALL' || status == _currentFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
        backgroundColor: Theme.of(context).primaryColor, // Usa a cor do tema
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Volta para a tela de Login
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            tooltip: 'Sair',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isOverallLoading ? null : () { // Desabilita o botão se estiver carregando
              _fetchTechnicians();
              _fetchTickets();
            },
            tooltip: 'Recarregar Tudo',
          ),
        ],
      ),
      body: Column( // Envolve o corpo em Column para adicionar o filtro
        children: [
          _buildFilterDropdown(), // Widget de filtro
          Expanded(
            child: isOverallLoading
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
                    : filteredTickets.isEmpty
                        ? Center(
                            child: Text(
                              (_tickets.isEmpty && _currentFilter == 'ALL')
                                  ? 'Nenhum ticket encontrado no total.'
                                  : 'Nenhum ticket encontrado com o status selecionado.',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator( // Adiciona RefreshIndicator para puxar para recarregar
                            onRefresh: () async {
                              await _fetchTechnicians();
                              await _fetchTickets();
                            },
                            child: ListView.builder(
                                itemCount: filteredTickets.length,
                                itemBuilder: (context, index) {
                                  return _buildTicketItem(filteredTickets[index] as Map<String, dynamic>);
                                },
                              ),
                          )
          ),
        ],
      ),
    );
  }
}