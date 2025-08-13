class Incident {
  final int id;
  final int serviceId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationS;

  Incident({
    required this.id,
    required this.serviceId,
    required this.startedAt,
    required this.endedAt,
    required this.durationS,
  });

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
    id: j['id'] as int,
    serviceId: j['serviceId'] as int,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: j['endedAt'] == null
        ? null
        : DateTime.parse(j['endedAt'] as String),
    durationS: j['durationS'] as int,
  );
}
