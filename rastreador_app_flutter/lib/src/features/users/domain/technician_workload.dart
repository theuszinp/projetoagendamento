class TechnicianWorkload {
  const TechnicianWorkload({
    required this.id,
    required this.name,
    required this.completedServices,
    required this.totalMinutes,
    required this.averageMinutes,
  });

  final int id;
  final String name;
  final int completedServices;
  final double totalMinutes;
  final double averageMinutes;

  factory TechnicianWorkload.fromJson(Map<String, dynamic> json) {
    return TechnicianWorkload(
      id: int.tryParse((json['tech_id'] ?? json['id'] ?? 0).toString()) ?? 0,
      name: (json['tech_name'] ?? json['name'] ?? 'Instalador').toString(),
      completedServices:
          int.tryParse((json['services_completed'] ?? 0).toString()) ?? 0,
      totalMinutes:
          double.tryParse((json['total_minutes'] ?? 0).toString()) ?? 0,
      averageMinutes:
          double.tryParse((json['avg_minutes'] ?? 0).toString()) ?? 0,
    );
  }
}
