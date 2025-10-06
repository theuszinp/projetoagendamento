import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class SellerTicketListScreen extends StatefulWidget {
  final String authToken;
  final int userId; // ID do Vendedor logado

  const SellerTicketListScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<SellerTicketListScreen> createState() => _SellerTicketListScreenState();
}

class _SellerTicketListScreenState extends State<SellerTicketListScreen> {
  // A lista armazenará todos os tickets do vendedor (PENDING, APPROVED, REJECTED)
  List<dynamic> _allTickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSellerTickets();
  }

  // ----------------------------------------------------
  // LÓGICA: BUSCAR TODOS OS TICKETS DO VENDEDOR
  // (GET /tickets/requested/:requested_by_id)
  // ----------------------------------------------------
  Future<void> _fetchSellerTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Usa a rota do backend que retorna todos os tickets solicitados por este usuário
      final url = Uri.parse('$API_BASE_URL/tickets/requested/${widget.userId}');
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
          // Garante que 'tickets' seja uma lista ou um fallback vazio
          _allTickets = data['tickets'] ?? []; 
          _isLoading = false;
        });
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de rede ou servidor: $e';
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------
  // UI: WIDGET DE ITEM DE TICKET
  // ----------------------------------------------------
  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'PENDING';
    
    // Define cores e textos de status
    String statusText;
    Color statusColor;
    
    switch (status) {
      case 'APPROVED':
        statusText = 'APROVADO';
        statusColor = Colors.green.shade700;
        break;
      case 'REJECTED':
        statusText = 'REPROVADO';
        statusColor = Colors.red.shade700;
        break;
      case 'PENDING':
      default:
        statusText = 'PENDENTE';
        statusColor = Colors.orange.shade700;
        break;
    }
    
    final ticketId = ticket['id'].toString();
    final techName = ticket['assigned_to_name'] ?? 'Aguardando Atribuição'; // Supondo que o backend envie o nome do técnico
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          'Ticket #$ticketId: ${ticket['title']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Cliente: ${ticket['customer_name'] ?? 'N/A'}'),
            if (status == 'APPROVED') 
              Text('Técnico: $techName', style: const TextStyle(fontWeight: FontWeight.w500)),
            if (status == 'REJECTED')
              const Text('Motivo: Verifique o histórico (em breve)', style: TextStyle(color: Colors.red)),
            Text('Prioridade: ${ticket['priority'] ?? 'N/A'}'),
          ],
        ),
        trailing: Container(
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
      ),
    );
  }

  // ----------------------------------------------------
  // UI: TAB VIEW (Conteúdo das Abas)
  // ----------------------------------------------------
  Widget _buildTabView(String requiredStatus) {
    // Filtra os tickets para exibir apenas os do status da aba
    final filteredTickets = 
        _allTickets.where((t) => (t['status'] ?? 'PENDING') == requiredStatus).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Erro ao carregar: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
    }
    
    if (filteredTickets.isEmpty) {
      return Center(
        child: Text(
          'Nenhum chamado $requiredStatus encontrado.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        return _buildTicketItem(filteredTickets[index] as Map<String, dynamic>);
      },
    );
  }

  // ----------------------------------------------------
  // UI: WIDGET PRINCIPAL
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // PENDING, APPROVED, REJECTED
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Status dos Meus Agendamentos'),
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchSellerTickets,
              tooltip: 'Recarregar Agendamentos',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Aprovados'),
              Tab(text: 'Reprovados'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabView('PENDING'),
            _buildTabView('APPROVED'),
            _buildTabView('REJECTED'),
          ],
        ),
      ),
    );
  }
}