class CompletedServicesReport {
  const CompletedServicesReport({
    required this.from,
    required this.to,
    required this.summary,
    required this.items,
  });

  final DateTime from;
  final DateTime to;
  final CompletedServicesSummary summary;
  final List<CompletedServiceItem> items;
}

class CompletedServicesSummary {
  const CompletedServicesSummary({
    required this.totalServices,
    required this.totalMinutes,
    required this.averageMinutes,
    required this.techniciansInvolved,
    required this.servicesWithPhotos,
  });

  final int totalServices;
  final double totalMinutes;
  final double averageMinutes;
  final int techniciansInvolved;
  final int servicesWithPhotos;
}

class CompletedServiceItem {
  const CompletedServiceItem({
    required this.ticketId,
    required this.title,
    required this.customerName,
    required this.customerAddress,
    required this.sellerName,
    required this.technicianName,
    required this.completedAt,
    required this.attachmentsCount,
    this.startedAt,
    this.durationMinutes = 0,
  });

  final int ticketId;
  final String title;
  final String customerName;
  final String customerAddress;
  final String sellerName;
  final String technicianName;
  final DateTime completedAt;
  final DateTime? startedAt;
  final int attachmentsCount;
  final double durationMinutes;
}
