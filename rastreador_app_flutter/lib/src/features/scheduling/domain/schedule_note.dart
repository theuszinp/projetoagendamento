class ScheduleNote {
  const ScheduleNote({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorRole,
  });

  final int id;
  final String type;
  final String content;
  final DateTime createdAt;
  final String? authorName;
  final String? authorRole;

  String get typeLabel {
    switch (type.trim().toLowerCase()) {
      case 'internal':
        return 'Interna';
      case 'technical':
        return 'Técnica';
      case 'seller':
        return 'Comercial';
      default:
        return type;
    }
  }
}
