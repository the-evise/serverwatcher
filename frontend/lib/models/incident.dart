// lib/models/incident.dart
class Incident {
  final int id;
  final int serviceId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationS;

  // Optional: richer metadata (nullable for backward compat)
  final String? status; // e.g., "OPEN", "RESOLVED"
  final String? reason; // short reason for outage
  final String? details; // longer text / notes
  final String? createdBy; // if user-triggered
  final List<String>? tags; // e.g., ["network", "timeout"]

  const Incident({
    required this.id,
    required this.serviceId,
    required this.startedAt,
    required this.endedAt,
    required this.durationS,
    this.status,
    this.reason,
    this.details,
    this.createdBy,
    this.tags,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
    id: j['id'] as int,
    serviceId: j['serviceId'] as int,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: j['endedAt'] == null
        ? null
        : DateTime.parse(j['endedAt'] as String),
    durationS: j['durationS'] as int,
    status: j['status'] as String?,
    reason: j['reason'] as String?,
    details: j['details'] as String?,
    createdBy: j['createdBy'] as String?,
    tags: (j['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'durationS': durationS,
    if (status != null) 'status': status,
    if (reason != null) 'reason': reason,
    if (details != null) 'details': details,
    if (createdBy != null) 'createdBy': createdBy,
    if (tags != null) 'tags': tags,
  };

  bool get isOpen => endedAt == null;
  String get label => isOpen ? 'Outage (OPEN)' : 'Outage (RESOLVED)';
}
