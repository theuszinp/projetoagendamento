// TechDetailTicketScreen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🌐 URL base do backend
const String API_BASE_URL = 'https://projetoagendamento-n20v.onrender.com';

class TechDetailTicketScreen extends StatefulWidget {
  final String authToken;
  final int techId;
  final Map<String, dynamic> ticket;

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
  late String _currentStatus;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.ticket['status'] ?? 'APPROVED';
  }

  // =======================================================
  // 🔁 Função: Atualizar status do ticket
  // =======================================================
  Future<void> _updateStatus(String newStatus) async {
    if (_isProcessing) return;

    // Confirmações de segurança
    if (newStatus == 'IN_PROGRESS') {
      final bool? confirm = await _confirmDialog(
        title: 'Confirmar Início',
        content:
            'Deseja realmente iniciar o serviço do Ticket #${widget.ticket['id']} agora?',
        confirmText: 'Sim, Iniciar',
        confirmColor: Colors.blue,
      );
      if (confirm != true) return;
    } else if (newStatus == 'COMPLETED') {
      final bool? confirm = await _confirmDialog(
        title: 'Confirmar Conclusão',
        content:
            'Tem certeza que deseja marcar o Ticket #${widget.ticket['id']} como CONCLUÍDO? Esta ação é final.',
        confirmText: 'Sim, Concluir',
        confirmColor: Colors.green,
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final url = Uri.parse(
          '$API_BASE_URL/tickets/${widget.ticket['id']}/status'); // 🔗 mesma rota do backend
      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.authToken}',
            },
            body: jsonEncode({
              'new_status': newStatus,
              // ✅ CORREÇÃO: Usando 'user_id' em vez de 'tech_id' para bater com o backend
              'user_id': widget.techId, 
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() => _currentStatus = newStatus);
        _showSnackBar(
          'Status atualizado para ${_getStatusText(newStatus)} com sucesso!',
          Colors.green,
        );
        // Retorna true para atualizar a lista anterior
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(
          data['error'] ?? 'Falha ao atualizar status (${response.statusCode}).',
          Colors.red,
        );
        debugPrint('Erro API: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Erro de rede: verifique sua conexão.', Colors.orange);
      debugPrint('Erro de rede: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // =======================================================
  // 🔹 Diálogo de Confirmação
  // =======================================================
  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // 🔹 Função para mostrar SnackBar
  // =======================================================
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =======================================================
  // 🔹 Cores e textos dos status
  // =======================================================
  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.blue.shade700;
      case 'IN_PROGRESS':
        return Colors.orange.shade700;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'APPROVED':
        return 'AGUARDANDO INÍCIO';
      case 'IN_PROGRESS':
        return 'EM ANDAMENTO';
      case 'COMPLETED':
        return 'CONCLUÍDO';
      case 'REJECTED':
        return 'REPROVADO';
      default:
        return status;
    }
  }

  // =======================================================
  // 🔹 Botões de ação (Iniciar / Concluir)
  // =======================================================
  Widget _buildActionButton({
    required String label,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    final isFinished =
        _currentStatus == 'COMPLETED' || _currentStatus == 'REJECTED';

    bool canStart = status == 'IN_PROGRESS' && _currentStatus == 'APPROVED';
    bool canComplete = status == 'COMPLETED' && _currentStatus == 'IN_PROGRESS';

    bool isEnabled = !isFinished && !_isProcessing;
    if (status == 'IN_PROGRESS') isEnabled &= canStart;
    if (status == 'COMPLETED') isEnabled &= canComplete;

    return ElevatedButton.icon(
      onPressed: isEnabled ? () => _updateStatus(status) : null,
      icon: _isProcessing && isEnabled
          ? const SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isEnabled ? 4 : 0,
      ),
    );
  }

  // =======================================================
  // 🔹 Tela principal
  // =======================================================
  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _currentStatus == 'COMPLETED' ||
            _currentStatus == 'IN_PROGRESS');
        return false;
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
              // Status Atual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(_currentStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _getStatusColor(_currentStatus), width: 1.5),
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

              // Detalhes do Chamado
              const Text('Detalhes do Chamado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildDetailRow('Título', ticket['title']),
              _buildDetailRow('Prioridade', ticket['priority']),
              _buildDetailRow('Descrição', ticket['description'],
                  isMultiline: true),
              _buildDetailRow(
                'Data de Criação',
                ticket['created_at'] != null
                    ? DateTime.tryParse(ticket['created_at'].toString())
                            ?.toLocal()
                            .toString()
                            .substring(0, 16)
                            .replaceAll('-', '/') ??
                        'N/A'
                    : 'N/A',
              ),
              const SizedBox(height: 20),

              // Cliente
              const Text('Informações do Cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildDetailRow('Nome', ticket['customer_name']),
              _buildDetailRow('Endereço', ticket['customer_address'],
                  isMultiline: true),
              _buildDetailRow(
                  'Telefone', ticket['customer_phone'] ?? 'Não informado'),
              const SizedBox(height: 30),

              // Ações
              const Text('Ações de Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildActionButton(
                label: _currentStatus == 'IN_PROGRESS'
                    ? 'Em Andamento (Atual)'
                    : 'Marcar como Em Andamento',
                status: 'IN_PROGRESS',
                color: Colors.orange.shade700,
                icon: Icons.timer,
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: _currentStatus == 'COMPLETED'
                    ? 'Concluído'
                    : 'Finalizar Serviço',
                status: 'COMPLETED',
                color: Colors.green.shade700,
                icon: Icons.done_all,
              ),

              if (_currentStatus == 'REJECTED')
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Text(
                    'Este ticket foi reprovado pelo administrador. Nenhuma ação é necessária.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================================================
  // 🔹 Linha de Detalhes
  // =======================================================
  Widget _buildDetailRow(String label, String? value,
      {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87)),
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