import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// 💡 IMPORTANTE: Importa a tela de detalhes que acabamos de criar
import 'TechDetailTicketScreen.dart'; // Ajuste o nome do arquivo se for diferente

// URL base do seu backend (repetida para garantir que o arquivo seja independente)
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

/// Define a estrutura de dados esperada para um Ticket
class Ticket {
  final int id;
  final String title;
  final String description;
  final String priority;
  final String customerName;
  final String customerAddress;
  final String? customerPhone; // ✅ NOVO: Adicionado Telefone
  final DateTime createdAt;
  final String status; // 💡 Adicionado Status para o Técnico ver se já iniciou

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.customerName,
    required this.customerAddress,
    this.customerPhone, // ✅ NOVO
    required this.createdAt,
    required this.status, // Novo campo
  });

  // Factory constructor para criar um objeto Ticket a partir de um JSON (Map)
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json.containsKey('description') && json['description'] != null
          ? json['description'] as String
          : 'Sem descrição.',
      priority: json['priority'] as String,
      customerName: json['customer_name'] as String,
      customerAddress: json['customer_address'] as String,
      customerPhone: json['customer_phone'] as String?, // ✅ NOVO: Lendo Telefone (se existir)
      // Trata datas que podem vir nulas ou inválidas, usando now() como fallback seguro
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      // Assumindo que o backend retorna o status
      status: json['status'] as String? ?? 'APPROVED',
    );
  }

  // Converte o objeto Ticket para um Map<String, dynamic> para passar para a tela de detalhes
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_phone': customerPhone, // ✅ NOVO: Incluindo Telefone para a tela de detalhes
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

class TechDashboardScreen extends StatefulWidget {
  final int techId;
  final String authToken; // 💡 Adicionado authToken

  // 💡 Construtor com authToken obrigatório
  const TechDashboardScreen({super.key, required this.techId, required this.authToken});

  @override
  State<TechDashboardScreen> createState() => _TechDashboardScreenState();
}

class _TechDashboardScreenState extends State<TechDashboardScreen> {
  // O FutureBuilder vai usar esta variável para saber o que exibir
  late Future<List<Ticket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    // Inicia a chamada de API assim que a tela é construída
    _ticketsFuture = _fetchAssignedTickets();
  }

  // 💡 Função auxiliar para forçar o refresh da lista
  void _refreshTickets() {
    setState(() {
      _ticketsFuture = _fetchAssignedTickets();
    });
  }

  /// Função para buscar os tickets atribuídos a este técnico
  Future<List<Ticket>> _fetchAssignedTickets() async {
    // 💡 URI para buscar tickets atribuídos
    final uri = Uri.parse('$API_BASE_URL/tickets/assigned/${widget.techId}');
    
    try {
      final response = await http.get(
        uri,
        headers: {
            'Content-Type': 'application/json',
            // O token é enviado no cabeçalho Authorization
            'Authorization': 'Bearer ${widget.authToken}',
        }
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Verifica se 'tickets' é uma lista e a mapeia para objetos Ticket
        if (data['tickets'] is List) {
          // 💡 Adicionando filtro: Mostrar apenas tickets que NÃO estão 'COMPLETED' ou 'REJECTED'
          return (data['tickets'] as List)
              .map((json) => Ticket.fromJson(json))
              .where((ticket) => ticket.status != 'COMPLETED' && ticket.status != 'REJECTED')
              .toList();
        }
        return []; // Retorna lista vazia se o corpo for 200, mas sem tickets
        
      } else if (response.statusCode == 404) {
        // Exemplo: Técnico sem tickets (o backend pode retornar 404 ou 200 com lista vazia)
        return [];
      } else {
        // Erro na API (ex: erro 500)
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Falha ao carregar tickets. Código: ${response.statusCode}');
      }
    } catch (e) {
      // Erro de rede ou timeout
      // ignore: avoid_print
      print('Erro ao buscar chamados: $e');
      throw Exception('Erro de conexão ao buscar chamados: $e');
    }
  }

  // Mapeia a prioridade para uma cor visualmente distinta
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
      default:
        return Colors.green.shade500;
    }
  }
  
  // 💡 Mapeia o status para uma cor e texto para o Técnico
  Color _getStatusColor(String status) {
    switch (status) {
      case 'IN_PROGRESS': return Colors.blue.shade700;
      case 'APPROVED': return Colors.orange.shade700;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'IN_PROGRESS': return 'EM ANDAMENTO';
      case 'APPROVED': return 'A INICIAR';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Chamados Atribuídos'),
        backgroundColor: Colors.indigo.shade700, // Cor mais técnica
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTickets, // Botão de recarregar
            tooltip: 'Recarregar',
          ),
        ]
      ),
      // Usa FutureBuilder para lidar com os estados da chamada assíncrona
      body: FutureBuilder<List<Ticket>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Estado de carregamento
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Estado de erro (ex: falha de rede)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      'Erro ao carregar chamados: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    // Botão para tentar buscar novamente
                    ElevatedButton.icon(
                      onPressed: _refreshTickets,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                    )
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Estado sem dados (sem tickets atribuídos)
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade400, size: 60),
                  const SizedBox(height: 10),
                  const Text(
                    'Parabéns! Nenhuma chamada pendente. 🎉',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text('Todos os seus agendamentos estão em dia.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  // Botão para recarregar
                  TextButton.icon(
                    onPressed: _refreshTickets,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recarregar Lista'),
                  )
                ],
              ),
            );
          } else {
            // Estado com sucesso e dados!
            final tickets = snapshot.data!;
            return ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    // Ícone de prioridade colorida
                    leading: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(ticket.priority),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.build, color: Colors.white),
                    ),
                    title: Text(
                      '#${ticket.id} - ${ticket.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Cliente: ${ticket.customerName}'),
                        Text('Endereço: ${ticket.customerAddress}'),
                        const SizedBox(height: 4),
                        // Mostra o status atual
                        Row(
                          children: [
                            Text(
                              'Status: ${_getStatusText(ticket.status)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(ticket.status),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Prioridade: ${ticket.priority.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getPriorityColor(ticket.priority),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    // 💡 LÓGICA DE NAVEGAÇÃO PARA A TELA DE DETALHES
                    onTap: () async {
                      // Passa os dados do ticket como Map<String, dynamic>
                      final needsRefresh = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TechDetailTicketScreen(
                            authToken: widget.authToken,
                            techId: widget.techId,
                            ticket: ticket.toJson(), // Passa o objeto como Map
                          ),
                        ),
                      );

                      // Se a tela de detalhes retornar 'true', significa que o ticket foi concluído
                      if (needsRefresh == true) {
                        _refreshTickets(); // Recarrega para remover o ticket concluído da lista
                      }
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}