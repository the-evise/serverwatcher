// lib/models/analytics.dart
class Analytics {
  final int serviceId;
  final String windowStart; // ISO8601
  final String windowEnd; // ISO8601
  final int checks;
  final double uptimePercent; // 0..100
  final int avgResponseMs;
  final int failCount;
  final int incidentCount;
  final int mttrSeconds;

  // Optional extensions (safe if backend omits them)
  final int? p50Ms;
  final int? p95Ms;
  final int? downtimeSeconds; // total down time within window
  final double? errorRatePercent; // (failCount/checks*100)
  final double? sloTargetPercent; // e.g., 99.9
  final bool? sloBreached; // uptime < sloTargetPercent
  final String? lastIncidentStart; // ISO8601
  final String? lastIncidentEnd; // ISO8601 or null if open

  const Analytics({
    required this.serviceId,
    required this.windowStart,
    required this.windowEnd,
    required this.checks,
    required this.uptimePercent,
    required this.avgResponseMs,
    required this.failCount,
    required this.incidentCount,
    required this.mttrSeconds,
    this.p50Ms,
    this.p95Ms,
    this.downtimeSeconds,
    this.errorRatePercent,
    this.sloTargetPercent,
    this.sloBreached,
    this.lastIncidentStart,
    this.lastIncidentEnd,
  });

  factory Analytics.fromJson(Map<String, dynamic> j) => Analytics(
    serviceId: j['serviceId'] as int,
    windowStart: j['windowStart'] as String,
    windowEnd: j['windowEnd'] as String,
    checks: j['checks'] as int,
    uptimePercent: (j['uptimePercent'] as num).toDouble(),
    avgResponseMs: j['avgResponseMs'] as int,
    failCount: j['failCount'] as int,
    incidentCount: j['incidentCount'] as int,
    mttrSeconds: j['mttrSeconds'] as int,
    p50Ms: j['p50Ms'] as int?,
    p95Ms: j['p95Ms'] as int?,
    downtimeSeconds: j['downtimeSeconds'] as int?,
    errorRatePercent: (j['errorRatePercent'] as num?)?.toDouble(),
    sloTargetPercent: (j['sloTargetPercent'] as num?)?.toDouble(),
    sloBreached: j['sloBreached'] as bool?,
    lastIncidentStart: j['lastIncidentStart'] as String?,
    lastIncidentEnd: j['lastIncidentEnd'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'serviceId': serviceId,
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    'checks': checks,
    'uptimePercent': uptimePercent,
    'avgResponseMs': avgResponseMs,
    'failCount': failCount,
    'incidentCount': incidentCount,
    'mttrSeconds': mttrSeconds,
    if (p50Ms != null) 'p50Ms': p50Ms,
    if (p95Ms != null) 'p95Ms': p95Ms,
    if (downtimeSeconds != null) 'downtimeSeconds': downtimeSeconds,
    if (errorRatePercent != null) 'errorRatePercent': errorRatePercent,
    if (sloTargetPercent != null) 'sloTargetPercent': sloTargetPercent,
    if (sloBreached != null) 'sloBreached': sloBreached,
    if (lastIncidentStart != null) 'lastIncidentStart': lastIncidentStart,
    if (lastIncidentEnd != null) 'lastIncidentEnd': lastIncidentEnd,
  };

  // Convenience (safe even if optional fields are null)
  double get availabilityFraction => uptimePercent / 100.0;
  double get failureFraction => checks == 0 ? 0.0 : (failCount / checks);
}
