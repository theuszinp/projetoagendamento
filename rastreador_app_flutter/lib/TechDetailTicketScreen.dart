import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart'; // ✅ Importação correta

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
    _currentStatus =
        widget.ticket['tech_status'] ?? widget.ticket['status'] ?? 'APPROVED';
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isProcessing) return;

    String confirmTitle = '';
    String confirmContent = '';
    Color confirmColor = Colors.blue;

    if (newStatus == 'IN_PROGRESS') {
      confirmTitle = 'Iniciar Serviço';
      confirmContent = 'Deseja realmente iniciar este serviço agora?';
      confirmColor = Colors.orange;
    } else if (newStatus == 'COMPLETED') {
      confirmTitle = 'Concluir Serviço';
      confirmContent =
          'Tem certeza que deseja marcar este serviço como concluído? Esta ação é final.';
      confirmColor = Colors.green;
    }

    final confirm = await _confirmDialog(
      title: confirmTitle,
      content: confirmContent,
      confirmText: 'Confirmar',
      confirmColor: confirmColor,
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      // 💡 CORREÇÃO APLICADA: Rota atualizada para o padrão correto do backend.
      final url =
          Uri.parse('$API_BASE_URL/ticket/${widget.ticket['id']}/tech-status');

      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.authToken}',
            },
            body: jsonEncode({
              'new_status': newStatus,
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
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(
          data['error'] ?? 'Falha ao atualizar status (${response.statusCode})',
          Colors.red,
        );
        debugPrint('Erro API: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Erro de rede. Verifique sua conexão.', Colors.orange);
      debugPrint('Erro de rede: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(content, style: GoogleFonts.poppins(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.blue.shade600;
      case 'IN_PROGRESS':
        return Colors.orange.shade700;
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Aguardando Início';
      case 'IN_PROGRESS':
        return 'Em Andamento';
      case 'COMPLETED':
        return 'Concluído';
      case 'REJECTED':
        return 'Reprovado';
      default:
        return status;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
      case 'ALTA':
        return 'Alta';
      case 'MEDIUM':
      case 'MÉDIA':
      case 'MEDIA':
        return 'Média';
      case 'LOW':
      case 'BAIXA':
        return 'Baixa';
      default:
        return priority;
    }
  }

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => _updateStatus(status) : null,
        icon: _isProcessing && isEnabled
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(icon, color: Colors.white),
        label: Text(label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: isEnabled ? 4 : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context,
            _currentStatus == 'COMPLETED' || _currentStatus == 'IN_PROGRESS');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: Text(
            'Serviço #${ticket['id']}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 3,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 25),
              _buildSectionTitle(
                  'Detalhes do Chamado', LucideIcons.clipboardList),
              _buildDetailCard([
                _buildDetailRow('Título', ticket['title'] ?? 'N/A'),
                _buildDetailRow(
                    'Prioridade',
                    _getPriorityLabel(
                        ticket['priority']?.toString() ?? 'N/A')),
                _buildDetailRow(
                    'Descrição', ticket['description'] ?? 'Sem descrição',
                    isMultiline: true),
                _buildDetailRow(
                  'Criado em',
                  ticket['created_at'] != null
                      ? DateTime.tryParse(ticket['created_at'].toString())
                              ?.toLocal()
                              .toString()
                              .substring(0, 16)
                              .replaceAll('-', '/') ??
                          'N/A'
                      : 'N/A',
                ),
              ]),
              const SizedBox(height: 25),
              _buildSectionTitle('Informações do Cliente', LucideIcons.user),
              _buildDetailCard([
                _buildDetailRow('Nome', ticket['customer_name']),
                _buildDetailRow('Endereço', ticket['customer_address'],
                    isMultiline: true),
                _buildDetailRow(
                    'Telefone', ticket['customer_phone'] ?? 'Não informado'),
              ]),
              const SizedBox(height: 25),
              _buildSectionTitle('Ações de Status', LucideIcons.settings),
              const SizedBox(height: 10),
              _buildActionButton(
                label: _currentStatus == 'IN_PROGRESS'
                    ? 'Em Andamento (Atual)'
                    : 'Iniciar Serviço',
                status: 'IN_PROGRESS',
                color: Colors.orange.shade700,
                icon: Icons.timer,
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                label: _currentStatus == 'COMPLETED'
                    ? 'Concluído'
                    : 'Finalizar Serviço',
                status: 'COMPLETED',
                color: Colors.green.shade700,
                icon: Icons.done_all,
              ),
              if (_currentStatus == 'REJECTED') ...[
                const SizedBox(height: 20),
                Text(
                  'Este ticket foi reprovado pelo administrador.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _getStatusColor(_currentStatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.8),
      ),
      child: Center(
        child: Text(
          'Status Atual: ${_getStatusText(_currentStatus)}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade700, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700),
        ),
      ],
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(String label, String? value,
      {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.grey.shade800)),
          const SizedBox(height: 3),
          Text(
            value ?? 'N/A',
            style: GoogleFonts.poppins(fontSize: 14.5, color: Colors.black87),
            softWrap: true,
          ),
          if (isMultiline) const SizedBox(height: 6),
        ],
      ),
    );
  }
}
