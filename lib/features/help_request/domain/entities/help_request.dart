class HelpRequestEntity {
  final String id;
  final String requesterId;
  final String title;
  final String description;
  final String category;
  final String urgency;
  final String? location;
  final String? preferredTime;
  final String status;
  final DateTime createdAt;

  const HelpRequestEntity({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    this.location,
    this.preferredTime,
    required this.status,
    required this.createdAt,
  });
}
