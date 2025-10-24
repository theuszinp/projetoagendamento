import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui'; // Necessário para o BackdropFilter
import 'package:http/http.dart' as http;

// 🌐 URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

// 🎨 Cores principais (As mesmas definidas no arquivo main.dart)
const Color trackerBlue = Color(0xFF322C8E);
const Color trackerYellow = Color(0xFFFFD700);

// 📌 DEFINIÇÃO DOS STATUS USADOS NO BACKEND:
// 'PENDING' -> Aguardando a aprovação do Admin
// 'APPROVED' -> Aprovado pelo Admin (Pronto para o Técnico iniciar)
// 'IN_PROGRESS' -> O técnico iniciou a instalação
// 'COMPLETED' -> O técnico finalizou a instalação
// 'REJECTED' -> Reprovado pelo Admin

// 💡 Definição das Abas em Português para uso nos filtros
const String TAB_PENDENTES = 'PENDENTES';
const String TAB_APROVADOS = 'APROVADOS';
const String TAB_REPROVADOS = 'REPROVADOS';

class SellerTicketListScreen extends StatefulWidget {
  final String authToken;
  final int userId;

  const SellerTicketListScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<SellerTicketListScreen> createState() => _SellerTicketListScreenState();
}

class _SellerTicketListScreenState extends State<SellerTicketListScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _allTickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchSellerTickets();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  // LÓGICA: BUSCAR TODOS OS TICKETS DO VENDEDOR
  // ----------------------------------------------------
  Future<void> _fetchSellerTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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
          _allTickets = data['tickets'] ?? [];
          _isLoading = false;
        });
        _animController.forward(from: 0);
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ??
              'Falha ao carregar tickets. Código: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de rede ou servidor.';
        _isLoading = false;
      });
      // ignore: avoid_print
      print('Erro ao buscar tickets: $e');
    }
  }

  // ----------------------------------------------------
  // WIDGET: ITEM DE TICKET ESTILIZADO (VIDRO FOSCO)
  // ----------------------------------------------------
  Widget _buildTicketItem(Map<String, dynamic> ticket) {
    // Pegando status do Admin e o status de trabalho do Técnico
    final String statusApi = ticket['status'] ?? 'PENDING';
    final String techStatusApi = ticket['tech_status'] ?? statusApi;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Define as cores e ícones de status com a nova lógica
    if (statusApi == 'REJECTED') {
      // Reprovado pelo Admin - Vai para a aba "Reprovados"
      statusText = 'REPROVADO';
      statusColor = Colors.red.shade600;
      statusIcon = Icons.cancel;
    } else if (techStatusApi == 'COMPLETED') {
      // Finalizado pelo Técnico - Vai para a aba "Aprovados"
      statusText = 'INSTALAÇÃO REALIZADA';
      statusColor = Colors.lightBlue.shade600;
      statusIcon = Icons.task_alt;
    } else if (techStatusApi == 'IN_PROGRESS') {
      // Em andamento pelo Técnico - Vai para a aba "Pendentes"
      statusText = 'INSTALAÇÃO EM ANDAMENTO';
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.build_circle;
    } else if (statusApi == 'APPROVED') {
      // Aprovado pelo Admin, mas não iniciado - Vai para a aba "Aprovados"
      statusText = 'AGUARDANDO TÉCNICO';
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle;
    } else {
      // PENDENTE (Aguardando Admin) - Vai para a aba "Pendentes"
      statusText = 'AGUARDANDO APROVAÇÃO';
      statusColor = Colors.grey.shade500;
      statusIcon = Icons.hourglass_bottom;
    }

    final ticketId = ticket['id'].toString();
    final techName = ticket['assigned_to_name'] ?? 'Não Atribuído';
    final cliente = ticket['customer_name'] ?? 'Cliente não informado';
    final String prioridadeApi = ticket['priority'] ?? 'N/A';
    String prioridadeDisplay;

    switch (prioridadeApi.toUpperCase()) {
      case 'LOW':
        prioridadeDisplay = 'Baixa';
        break;
      case 'MEDIUM':
        prioridadeDisplay = 'Média';
        break;
      case 'HIGH':
        prioridadeDisplay = 'Alta';
        break;
      default:
        prioridadeDisplay = 'Não Informada';
    }

    // Aplica a animação de Fade
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListTile(
                textColor: Colors.white,
                iconColor: Colors.white70,
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(statusIcon, color: statusColor),
                ),
                title: Text(
                  'Ticket #$ticketId: ${ticket['title'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Cliente: $cliente',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    // Exibe o técnico se o chamado foi aprovado ou está em andamento/completo
                    if (statusApi != 'PENDING' && statusApi != 'REJECTED')
                      Text(
                        'Técnico: $techName',
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    Text(
                      'Prioridade: $prioridadeDisplay',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // WIDGET: CONTEÚDO DAS ABAS (LÓGICA DE FILTRO)
  // ----------------------------------------------------
  Widget _buildTabView(String tabType) {
    final filteredTickets = _allTickets.where((t) {
      final String statusApi = t['status'] ?? 'PENDING';
      // Assume-se que 'tech_status' é onde o técnico coloca 'IN_PROGRESS' ou 'COMPLETED'
      final String techStatusApi = t['tech_status'] ?? statusApi;

      switch (tabType) {
        case TAB_PENDENTES:
          // Aba Pendentes deve ter: Aguardando Aprovação (PENDING) E Instalação em Andamento (IN_PROGRESS)
          return statusApi == 'PENDING' || techStatusApi == 'IN_PROGRESS';

        case TAB_APROVADOS:
          // Aba Aprovados deve ter: Aprovado (APPROVED) E Instalação Realizada (COMPLETED)
          // Excluímos o IN_PROGRESS pois ele já está na aba PENDENTES
          return statusApi == 'APPROVED' && techStatusApi != 'IN_PROGRESS';

        case TAB_REPROVADOS:
          // Aba Reprovados deve ter: Reprovado pelo Admin (REJECTED)
          return statusApi == 'REJECTED';

        default:
          return false;
      }
    }).toList();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: trackerYellow),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          '⚠️ $_errorMessage',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      );
    }

    if (filteredTickets.isEmpty) {
      String message;
      if (tabType == TAB_PENDENTES) {
        message = 'Nenhum chamado pendente ou em andamento encontrado.';
      } else if (tabType == TAB_APROVADOS) {
        message = 'Nenhum chamado aprovado ou finalizado encontrado.';
      } else {
        message = 'Nenhum chamado reprovado encontrado.';
      }

      return Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        return _buildTicketItem(filteredTickets[index] as Map<String, dynamic>);
      },
    );
  }

  // ----------------------------------------------------
  // UI PRINCIPAL
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Status dos Meus Agendamentos'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Recarregar',
              onPressed: _fetchSellerTickets,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: trackerYellow,
            labelColor: trackerYellow,
            unselectedLabelColor: Colors.white70,
            tabs: [
              // Nomes das abas em Português
              Tab(text: 'Pendentes'),
              Tab(text: 'Aprovados'),
              Tab(text: 'Reprovados'),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fundo com Imagem
            Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.darken,
            ),
            // 2. Fundo com Gradiente
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // 3. Conteúdo das Abas
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight * 2),
              child: TabBarView(
                children: [
                  // Passando as constantes em Português para o filtro
                  _buildTabView(TAB_PENDENTES),
                  _buildTabView(TAB_APROVADOS),
                  _buildTabView(TAB_REPROVADOS),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
