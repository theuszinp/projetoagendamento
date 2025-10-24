import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui'; // Necessário para o BackdropFilter
import 'package:http/http.dart' as http;

// 🌐 URL base do seu backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

// 🎨 Cores principais (As mesmas definidas no arquivo main.dart)
const Color trackerBlue = Color(0xFF322C8E);
const Color trackerYellow = Color(0xFFFFD700);

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
  // A lista armazenará todos os tickets do vendedor
  List<dynamic> _allTickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Animações para entrada suave dos itens (Código 1)
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
      // 💡 O endpoint está correto: /tickets/requested/:userId
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
          // O backend deve retornar um objeto com a chave 'tickets'
          _allTickets = data['tickets'] ?? [];
          _isLoading = false;
        });
        // Inicia a animação após carregar os dados
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
        _errorMessage =
            'Erro de rede ou servidor.'; // Mensagem simplificada para o usuário
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
    final status = ticket['status'] ?? 'PENDING';
    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Define as cores e ícones de status
    switch (status) {
      case 'APPROVED':
        statusText = 'APROVADO';
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle;
        break;
      case 'REJECTED':
        statusText = 'REPROVADO';
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel;
        break;
      case 'PENDING':
      default:
        statusText = 'PENDENTE';
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.hourglass_bottom;
        break;
    }

    final ticketId = ticket['id'].toString();
    final techName = ticket['assigned_to_name'] ?? 'Aguardando Atribuição';
    final cliente = ticket['customer_name'] ?? 'Cliente não informado';
    // Mapeamento da prioridade do backend (LOW/MEDIUM/HIGH) para exibição em português
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
            // Efeito de Vidro Fosco
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                // Container semi-transparente para o efeito fosco
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
                // 💡 Cor do texto e ícone definida no nível do ListTile
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
                    color: Colors.white, // Garantir cor no título
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
                    if (status == 'APPROVED')
                      Text(
                        'Técnico: $techName',
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    Text(
                      // 💡 Usando a prioridade mapeada
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
  // WIDGET: CONTEÚDO DAS ABAS
  // ----------------------------------------------------
  Widget _buildTabView(String requiredStatus) {
    // A filtragem funciona corretamente
    final filteredTickets = _allTickets
        .where((t) => (t['status'] ?? 'PENDING') == requiredStatus)
        .toList();

    if (_isLoading) {
      // Indicador de carregamento amarelo do tema
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
      return Center(
        child: Text(
          'Nenhum chamado ${requiredStatus.toLowerCase()} encontrado.',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      // Efeito de 'bounce' ao rolar (Melhoria visual)
      physics: const BouncingScrollPhysics(),
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        // Garantindo que o tipo seja um Map
        return _buildTicketItem(filteredTickets[index] as Map<String, dynamic>);
      },
    );
  }

  // ----------------------------------------------------
  // UI PRINCIPAL (AppBar Transparente e Fundo com Gradiente)
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // Permite que o fundo se estenda para a área da AppBar
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Status dos Meus Agendamentos'),
          // Torna o AppBar transparente para o efeito de fundo
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
            indicatorColor: trackerYellow, // Cor de destaque
            labelColor: trackerYellow,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Aprovados'),
              Tab(text: 'Reprovados'),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Fundo com Imagem (Camada mais profunda)
            Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.darken,
            ),
            // 2. Fundo com Gradiente (Melhora o visual escuro)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  // Cores escuras para o tema
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // 3. Conteúdo das Abas
            // 💡 Ajuste: Usar MediaQuery para obter a altura da AppBar e TabBar
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight * 2),
              child: TabBarView(
                children: [
                  _buildTabView('PENDING'),
                  _buildTabView('APPROVED'),
                  _buildTabView('REJECTED'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
