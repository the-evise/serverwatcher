class Analytics {
  final int serviceId;
  final String windowStart;
  final String windowEnd;
  final int checks;
  final double uptimePercent;
  final int avgResponseMs;
  final int failCount;
  final int incidentCount;
  final int mttrSeconds;

  Analytics({
    required this.serviceId,
    required this.windowStart,
    required this.windowEnd,
    required this.checks,
    required this.uptimePercent,
    required this.avgResponseMs,
    required this.failCount,
    required this.incidentCount,
    required this.mttrSeconds,
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
  );
}
