enum ScheduleStatus {
  pendingApproval,
  approved,
  scheduled,
  inService,
  completed,
  rejected,
  rescheduleRequested,
  cancelled,
  technicalIssue,
}

extension ScheduleStatusX on ScheduleStatus {
  String get label {
    switch (this) {
      case ScheduleStatus.pendingApproval:
        return 'Pendente';
      case ScheduleStatus.approved:
        return 'Aprovado';
      case ScheduleStatus.scheduled:
        return 'Agendado';
      case ScheduleStatus.inService:
        return 'Em atendimento';
      case ScheduleStatus.completed:
        return 'Concluído';
      case ScheduleStatus.rejected:
        return 'Reprovado';
      case ScheduleStatus.rescheduleRequested:
        return 'Reagendamento solicitado';
      case ScheduleStatus.cancelled:
        return 'Cancelado';
      case ScheduleStatus.technicalIssue:
        return 'Problema técnico';
    }
  }
}
