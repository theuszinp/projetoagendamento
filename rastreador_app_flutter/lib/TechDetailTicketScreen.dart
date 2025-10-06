// TechDetailTicketScreen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// URL base do seu backend (a mesma que já usamos)
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class TechDetailTicketScreen extends StatefulWidget {
  final String authToken;
  final int techId; // ID do técnico logado (user_id)
  final Map<String, dynamic> ticket; // Dados do ticket a ser gerenciado

  const TechDetailTicketScreen({
    super.key,
    required this.authToken,
    required this.techId,
    required this.ticket,
  });

  @override
  State<TechDetailTicketScreen> createState() => _TechDetailTicketScreenState();
}

class _TechDetailTicketScreenState extends State<TechDetailTicketScreen> {
  // O status inicial será o que veio do ticket
  late String _currentStatus; 
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket['status'] ?? 'APPROVED'; // Começa como APPROVED ou o status atual
  }

  // ----------------------------------------------------
  // LÓGICA: ATUALIZAR STATUS DO TICKET (PUT /tickets/:id/status)
  // ----------------------------------------------------
  Future<void> _updateStatus(String newStatus) async {
    // Evita múltiplas requisições
    if (_isProcessing) return; 

    // 💡 ADICIONADO: Se for mudar para IN_PROGRESS, confirma a ação
    if (newStatus == 'IN_PROGRESS') {
        final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Início'),
          content: Text('Deseja realmente iniciar o serviço do Ticket #${widget.ticket['id']} agora?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim, Iniciar', style: TextStyle(color: Colors.blue))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // Mensagem de confirmação para status 'COMPLETED'
    if (newStatus == 'COMPLETED') {
        final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Conclusão'),
          content: Text('Tem certeza que deseja marcar o Ticket #${widget.ticket['id']} como CONCLUÍDO? Esta ação é final.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim, Concluir', style: TextStyle(color: Colors.green))),
          ],
        ),
      );
      if (confirm != true) return;
    }


    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final url = Uri.parse('$API_BASE_URL/tickets/${widget.ticket['id']}/status');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonEncode({
          'new_status': newStatus, // Ajustado para 'new_status' para bater com o server.js
          'tech_id': widget.techId, // Envia o ID do Técnico logado para validação no backend
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _currentStatus = newStatus;
          });
          _showSnackBar('Status atualizado para ${_getStatusText(newStatus)}.', Colors.green);
          
          // 🌟 CORREÇÃO FEITA AQUI: Retorna 'true' para a tela anterior
          // para que a lista de tickets recarregue/filtre corretamente.
          Navigator.pop(context, true); 
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['error'] ?? 'Falha ao atualizar status.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Erro de rede: Verifique sua conexão.', Colors.deepOrange);
      // ignore: avoid_print
      print('Erro de rede: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      // Garante que o SnackBar seja exibido mesmo após um pop, se necessário.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  // ----------------------------------------------------
  // UI: WIDGET AUXILIAR PARA STATUS
  // ----------------------------------------------------
  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED': return Colors.blue.shade700;
      case 'IN_PROGRESS': return Colors.orange.shade700;
      case 'COMPLETED': return Colors.green.shade700;
      case 'REJECTED': return Colors.red.shade700;
      default: return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'APPROVED': return 'AGUARDANDO INÍCIO';
      case 'IN_PROGRESS': return 'EM ANDAMENTO';
      case 'COMPLETED': return 'CONCLUÍDO';
      case 'REJECTED': return 'REPROVADO';
      default: return status;
    }
  }

  // ----------------------------------------------------
  // UI: WIDGET AUXILIAR PARA BOTÃO DE AÇÃO
  // ----------------------------------------------------
  Widget _buildActionButton({
    required String label, 
    required String status, 
    required Color color, 
    required IconData icon
  }) {
    final isFinished = _currentStatus == 'COMPLETED' || _currentStatus == 'REJECTED';

    // REGRA ESPECÍFICA PARA O BOTÃO FINALIZAR: Só pode finalizar se estiver em IN_PROGRESS
    bool canComplete = status == 'COMPLETED' && _currentStatus == 'IN_PROGRESS';
    
    // REGRA ESPECÍFICA PARA O BOTÃO INICIAR: Só pode iniciar se estiver em APPROVED
    bool canStart = status == 'IN_PROGRESS' && _currentStatus == 'APPROVED';

    // Define se o botão deve estar habilitado
    bool isEnabled = !isFinished && !_isProcessing;

    if (status == 'COMPLETED') {
        isEnabled = isEnabled && canComplete;
    } else if (status == 'IN_PROGRESS') {
        isEnabled = isEnabled && canStart;
    } else {
        // Para qualquer outro status futuro
        isEnabled = isEnabled && (_currentStatus != status);
    }
    
    return ElevatedButton.icon(
      // Apenas se o isEnabled for true
      onPressed: isEnabled ? () => _updateStatus(status) : null,
      icon: _isProcessing && isEnabled // Mostra o loader apenas se estiver processando E o botão estiver habilitado
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        // Se não estiver habilitado, reduz a elevação para dar a aparência de desabilitado
        elevation: isEnabled ? 4 : 0, 
      ),
    );
  }


  // ----------------------------------------------------
  // UI: WIDGET PRINCIPAL
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return PopScope(
      // O PopScope é usado para garantir que, se o ticket foi atualizado para IN_PROGRESS ou COMPLETED,
      // e o usuário usar o botão de voltar padrão (do AppBar ou do celular), 
      // a tela anterior (Dashboard) ainda force um refresh.
      canPop: true, // Permite o pop padrão
      onPopInvoked: (didPop) {
        if (didPop) {
          // Se o pop ocorreu (usuário clicou em voltar), retorna true SE o status foi alterado
          // para garantir que a lista seja recarregada.
          if (_currentStatus == 'COMPLETED' || _currentStatus == 'IN_PROGRESS') {
            Navigator.pop(context, true);
          } else {
            // Se não houve alteração relevante, retorna null
            Navigator.pop(context, null);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Serviço #${ticket['id']} - Detalhes'),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Destaque do Status Atual
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _getStatusColor(_currentStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _getStatusColor(_currentStatus), width: 1.5),
                ),
                child: Text(
                  'STATUS ATUAL: ${_getStatusText(_currentStatus)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(_currentStatus),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // 2. Detalhes do Chamado
              const Text('Detalhes do Chamado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildDetailRow('Título', ticket['title']),
              _buildDetailRow('Prioridade', ticket['priority']),
              _buildDetailRow('Descrição', ticket['description'], isMultiline: true),
              // 💡 Exibe a data formatada
              _buildDetailRow('Data de Criação', 
                ticket['created_at'] != null 
                  ? DateTime.tryParse(ticket['created_at'].toString())?.toLocal().toString().substring(0, 16).replaceAll('-', '/') 
                  : 'N/A'
              ),
              const SizedBox(height: 20),
              
              // 3. Detalhes do Cliente (CRUCIAL PARA O TÉCNICO)
              const Text('Informações do Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildDetailRow('Nome', ticket['customer_name']),
              _buildDetailRow('Endereço', ticket['customer_address'], isMultiline: true),
              
              // Linha para exibir o número do cliente
              _buildDetailRow('Telefone', ticket['customer_phone'] ?? 'Não informado'), 
              
              const SizedBox(height: 30),

              // 4. Ações do Técnico
              const Text('Ações de Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),

              // Botão 1: Marcar como Em Andamento (IN_PROGRESS)
              _buildActionButton(
                label: _currentStatus == 'IN_PROGRESS' ? 'Em Andamento (Atual)' : 'Marcar como Em Andamento',
                status: 'IN_PROGRESS',
                color: Colors.orange.shade700,
                icon: Icons.timer,
              ),
              const SizedBox(height: 10),

              // Botão 2: Marcar como Concluído (COMPLETED)
              _buildActionButton(
                label: _currentStatus == 'COMPLETED' ? 'Concluído' : 'Finalizar Serviço',
                status: 'COMPLETED',
                color: Colors.green.shade700,
                icon: Icons.done_all,
              ),
              
              if (_currentStatus == 'REJECTED')
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text('Este ticket foi reprovado pelo administrador. Nenhuma ação é necessária.', 
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para exibir os detalhes
  Widget _buildDetailRow(String label, String? value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A', 
            style: const TextStyle(fontSize: 16),
            softWrap: true,
          ),
          if (isMultiline) const SizedBox(height: 8),
        ],
      ),
    );
  }
}