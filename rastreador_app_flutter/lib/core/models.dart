// Arquivo de modelos (lib/core/models.dart)

import 'package:flutter/material.dart';

// ----------------------------------------------------
// MODELO DE USUÁRIO (TÉCNICO)
// ----------------------------------------------------
class User {
  final int id;
  final String name;
  final String role;

  User({required this.id, required this.name, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int userId;

    if (rawId is int) {
      userId = rawId;
    } else if (rawId is String) {
      userId = int.tryParse(rawId) ??
          (throw FormatException(
              'ID do usuário não é um número válido: $rawId'));
    } else {
      throw FormatException(
          'O campo "id" do usuário está faltando ou tem um tipo inesperado.');
    }

    return User(
      id: userId,
      name: json['name'] as String? ?? 'Nome Desconhecido',
      role: json['role'] as String? ?? 'N/A',
    );
  }
}

// ----------------------------------------------------
// MODELO DE TICKET COM GETTERS DE STATUS
// ----------------------------------------------------
class Ticket {
  final int id;
  final String title;
  final String status; // PENDING, APPROVED, REJECTED
  final String customerName;
  final String customerAddress;
  final String priority;
  final int? assignedToId;
  final String? assignedToName;
  final DateTime createdAt;

  Ticket({
    required this.id,
    required this.title,
    required this.status,
    required this.customerName,
    required this.customerAddress,
    required this.priority,
    this.assignedToId,
    this.assignedToName,
    required this.createdAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int ticketId;
    if (rawId is int) {
      ticketId = rawId;
    } else if (rawId is String) {
      ticketId = int.tryParse(rawId) ??
          (throw FormatException(
              'ID do ticket não é um número válido: $rawId'));
    } else {
      throw FormatException(
          'O campo "id" do ticket está faltando ou tem um tipo inesperado.');
    }

    // Data
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    // assignedToId
    final rawAssignedToId = json['assigned_to'];
    int? assignedToId;
    if (rawAssignedToId is int) {
      assignedToId = rawAssignedToId;
    } else if (rawAssignedToId is String) {
      assignedToId = int.tryParse(rawAssignedToId);
    }

    return Ticket(
      id: ticketId,
      title: json['title'] as String? ?? 'Sem Título',
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
      customerName: json['customer_name'] as String? ?? 'N/A',
      customerAddress: json['customer_address'] as String? ?? 'N/A',
      priority: json['priority'] as String? ?? 'N/A',
      assignedToId: assignedToId,
      assignedToName: json['assigned_to_name'] as String?,
      createdAt: parsedDate,
    );
  }

  // ------------------------
  // GETTERS DE UI
  // ------------------------
  Color get statusColor {
    switch (status) {
      case 'APPROVED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      case 'PENDING':
      default:
        return Colors.orange.shade700;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'PENDING':
      default:
        return Icons.pending_actions;
    }
  }

  String get statusText {
    switch (status) {
      case 'APPROVED':
        return 'APROVADO / ATRIBUÍDO';
      case 'REJECTED':
        return 'REPROVADO';
      case 'PENDING':
      default:
        return 'PENDENTE DE AVALIAÇÃO';
    }
  }

  String get formattedCreatedAt {
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year} às '
        '${createdAt.hour.toString().padLeft(2, '0')}:'
        '${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get priorityLabel {
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
}
