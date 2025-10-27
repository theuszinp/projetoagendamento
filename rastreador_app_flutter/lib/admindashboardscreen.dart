// Caminho esperado do arquivo: lib/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';

// Imports solicitados
import '../core/admin_service.dart'; // Importa AdminService e ApiException
import '../core/models.dart'; // Importa User e Ticket

// 🎯 IMPORT CORRIGIDO: O caminho é '../core/ticket_item_card.dart'
import '../core/ticket_item_card.dart'; // Importa o Card Fatorado

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
  // Use o novo modelo Ticket
  List<Ticket> _tickets = [];
  List<User> _technicians = [];

  // Variáveis de estado
  bool _isLoadingTickets = true;
  bool _isLoadingTechs = true;
  String? _errorMessage;
  String _currentFilter = 'PENDING';

  // Instância do serviço
  late final AdminService _adminService;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(authToken: widget.authToken);
    _loadData();
  }

  // ----------------------------------------------------
  // LÓGICA: CARREGAMENTO DE DADOS (Manter)
  // ----------------------------------------------------
  Future<void> _loadData() async {
    // Otimização: Carrega em paralelo
    final fetchTechsFuture = _fetchTechnicians();
    final fetchTicketsFuture = _fetchTickets();
    await Future.wait([fetchTechsFuture, fetchTicketsFuture]);
  }

  Future<void> _fetchTechnicians() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTechs = true;
      _errorMessage = null;
    });

    try {
      final userListJson = await _adminService.fetchTechniciansData();

      if (mounted) {
        setState(() {
          _technicians = userListJson
              .map((json) => User.fromJson(json))
              .where((user) => user.role.toLowerCase() == 'tech')
              .toList();
          _isLoadingTechs = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          // Limpa a exceção para exibir apenas a mensagem de erro da API
          _errorMessage =
              'Erro ao carregar técnicos: ${e.toString().split(':')[1].trim()}';
          _isLoadingTechs = false;
        });
      }
    }
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTickets = true;
      _errorMessage = null;
    });

    try {
      final ticketListJson = await _adminService.fetchTicketsData();

      if (mounted) {
        setState(() {
          _tickets =
              ticketListJson.map((json) => Ticket.fromJson(json)).toList();
          _isLoadingTickets = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Erro ao carregar tickets: ${e.toString().split(':')[1].trim()}';
          _isLoadingTickets = false;
        });
      }
    }
  }

  // ----------------------------------------------------
  // LÓGICA: REPROVAR TICKET (Manter)
  // ----------------------------------------------------
  Future<void> _rejectTicket(int ticketId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Reprovação'),
        content: Text('Tem certeza que deseja reprovar o Ticket #$ticketId?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Reprovar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reprovando ticket #$ticketId...')),
      );
    }

    try {
      await _adminService.rejectTicket(
        ticketId: ticketId.toString(),
        adminId: widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket reprovado com sucesso!')),
        );
        _fetchTickets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reprovar ticket: ${e.toString()}')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // LÓGICA: APROVAR E ATRIBUIR TICKET (Manter)
  // ----------------------------------------------------
  Future<void> _approveTicket({
    required int ticketId,
    required int assignedToId,
    required String techName,
  }) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Aprovando e atribuindo ticket #$ticketId ao $techName...')),
      );
    }

    try {
      await _adminService.approveTicket(
        ticketId: ticketId.toString(),
        adminId: widget.userId,
        assignedToId: assignedToId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket aprovado e atribuído a $techName!')),
        );
        _fetchTickets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar ticket: ${e.toString()}')),
        );
      }
    }
  }

  // ----------------------------------------------------
  // UI: DIALOG DE APROVAÇÃO COM DROPDOWN (Manter aqui)
  // ----------------------------------------------------
  // O diálogo está complexo, mas por lidar com a seleção de técnico
  // e chamar o _approveTicket, é aceitável mantê-lo no State.
  // Poderia ser movido para um arquivo de Dialog, mas o benefício é menor.
  Future<void> _showAssignmentDialog(Ticket ticket) async {
    // Variável local para manter o estado da seleção dentro do diálogo
    User? initialSelectedTech;

    // Pré-seleciona o técnico
    if (ticket.assignedToId != null) {
      try {
        initialSelectedTech =
            _technicians.firstWhere((t) => t.id == ticket.assignedToId);
      } catch (_) {
        initialSelectedTech = null;
      }
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        // Usa `StatefulBuilder` apenas para o conteúdo do AlertDialog
        User? selectedTech = initialSelectedTech;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final isApproved = ticket.status == 'APPROVED';

            return AlertDialog(
              title: Text(isApproved
                  ? 'Reatribuir Técnico'
                  : 'Atribuir Técnico e Aprovar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Ticket # ${ticket.id} - Cliente: ${ticket.customerName}'),
                  const SizedBox(height: 15),
                  const Text('Selecione o Técnico:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                      child: Text('Nenhum técnico encontrado.',
                          style: TextStyle(color: Colors.red, fontSize: 14)),
                    ),
                  if (selectedTech == null && ticket.status == 'PENDING')
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                          'Selecione o técnico para liberar a aprovação.',
                          style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton.icon(
                  icon: Icon(isApproved ? Icons.cached : Icons.check,
                      color: Colors.white),
                  label: Text(isApproved ? 'Reatribuir' : 'Aprovar e Atribuir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApproved
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: selectedTech != null && _technicians.isNotEmpty
                      ? () {
                          Navigator.of(context).pop();
                          _approveTicket(
                            ticketId: ticket.id,
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
  // UI: DROPDOWN DE FILTRO (Manter)
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
          const Text('Filtrar por Status: ',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
  // UI: WIDGET PRINCIPAL (Atualizado)
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isOverallLoading = _isLoadingTickets || _isLoadingTechs;
    final currentError = _errorMessage;

    // Filtra a lista de tickets usando o modelo Ticket
    final filteredTickets = _tickets.where((ticket) {
      final status = ticket.status;
      return _currentFilter == 'ALL' || status == _currentFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de Administração'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            tooltip: 'Sair',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isOverallLoading ? null : _loadData,
            tooltip: 'Recarregar Tudo',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterDropdown(),
          const Divider(height: 1, thickness: 1),
          Expanded(
              child: isOverallLoading
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(_isLoadingTickets
                            ? 'Carregando Tickets...'
                            : 'Carregando Técnicos...'),
                      ],
                    ))
                  : currentError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'Erro ao carregar dados:\n$currentError',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 16),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _loadData,
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
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                itemCount: filteredTickets.length,
                                itemBuilder: (context, index) {
                                  final ticket = filteredTickets[index];

                                  // ✅ Substituição pela Card Fatorada!
                                  return TicketItemCard(
                                    key: ValueKey(ticket.id),
                                    ticket: ticket,
                                    technicians: _technicians,
                                    isLoadingTechs: _isLoadingTechs,
                                    onReject: (id) => _rejectTicket(
                                        id), // Passa o callback de reprovação
                                    onShowAssignmentDialog:
                                        _showAssignmentDialog, // Passa o callback de aprovação/diálogo
                                  );
                                },
                              ),
                            )),
        ],
      ),
    );
  }

  // ❌ MÉTODO _buildTicketItem FOI REMOVIDO DAQUI
  // E SUA FUNÇÃO FOI SUBSTITUÍDA PELO WIDGET TicketItemCard.
}
