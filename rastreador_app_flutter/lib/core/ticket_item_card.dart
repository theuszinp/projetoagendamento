// Caminho sugerido: lib/widgets/ticket_item_card.dart

import 'package:flutter/material.dart';
// Certifique-se de que este caminho está correto para o seu arquivo de modelos
import '../core/models.dart';

class TicketItemCard extends StatelessWidget {
  final Ticket ticket;
  final List<User> technicians; // Lista de técnicos para buscar o nome
  final bool isLoadingTechs; // Para desabilitar o botão de aprovação/atribuição
  final Future<void> Function(int ticketId) onReject;
  final Future<void> Function(Ticket ticket) onShowAssignmentDialog;

  const TicketItemCard({
    super.key,
    required this.ticket,
    required this.technicians,
    required this.isLoadingTechs,
    required this.onReject,
    required this.onShowAssignmentDialog,
  });

  @override
  Widget build(BuildContext context) {
    // A LÓGICA DE BUSCA DO NOME DO TÉCNICO VEM PARA CÁ
    String assignedTechName = 'Ninguém';
    bool techFound = false;
    if (ticket.assignedToId != null) {
      final tech = technicians
          .cast<User?>()
          .firstWhere((t) => t?.id == ticket.assignedToId, orElse: () => null);
      assignedTechName = tech?.name ??
          ticket.assignedToName ??
          'ID #${ticket.assignedToId} (Desconhecido)';
      techFound = tech != null;
    }

    final showApproveButton =
        ticket.status == 'PENDING' || ticket.status == 'APPROVED';
    final showRejectButton = ticket.status == 'PENDING';

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
                    'Ticket #${ticket.id}: ${ticket.title}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // Usando Getters do Modelo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ticket.statusColor, // USANDO GETTER
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ticket.statusIcon,
                          color: Colors.white, size: 14), // USANDO GETTER
                      const SizedBox(width: 4),
                      Text(
                        ticket.statusText, // USANDO GETTER
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Cliente: ${ticket.customerName}'),
            Text('Endereço: ${ticket.customerAddress}'),
            Text('Prioridade: ${ticket.priorityLabel}'),
            if (ticket.status == 'APPROVED')
              Text(
                'Atribuído a: $assignedTechName',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: techFound
                        ? Colors.green.shade600
                        : Colors.red.shade600),
              ),
            Text('Criação: ${ticket.formattedCreatedAt}', // USANDO GETTER
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showRejectButton)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reprovar',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () => onReject(ticket.id), // CHAMANDO CALLBACK
                  ),
                if (showRejectButton && showApproveButton)
                  const SizedBox(width: 10),
                if (showApproveButton)
                  ElevatedButton.icon(
                    icon: Icon(
                      ticket.status == 'APPROVED' ? Icons.cached : Icons.check,
                      color: Colors.white,
                    ),
                    label: Text(ticket.status == 'APPROVED'
                        ? 'Reatribuir'
                        : 'Aprovar e Atribuir'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: ticket.status == 'APPROVED'
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (isLoadingTechs)
                        ? null
                        : () =>
                            onShowAssignmentDialog(ticket), // CHAMANDO CALLBACK
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
