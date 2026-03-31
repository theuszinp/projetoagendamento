class ScheduleAttachment {
  const ScheduleAttachment({
    required this.id,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.createdAt,
    this.uploadedByName,
  });

  final int id;
  final String url;
  final String fileName;
  final String contentType;
  final DateTime createdAt;
  final String? uploadedByName;
}
