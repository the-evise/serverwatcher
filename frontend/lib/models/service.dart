class ServiceStatus {
  final int id;
  final String name;
  final String url;
  final String status; // "OK" or "FAIL"
  final int responseMs; // Response time in ms
  final String checkedAt; // ISO 8601 timestamp

  // NEW (optional): present only if your backend includes them in JSON
  final int? intervalSec; // backend may expose "interval" as seconds
  final int? timeoutMs; // reliability
  final int? retries;
  final int? retryBackoffMs;

  ServiceStatus({
    required this.id,
    required this.name,
    required this.url,
    required this.status,
    required this.responseMs,
    required this.checkedAt,
    this.intervalSec,
    this.timeoutMs,
    this.retries,
    this.retryBackoffMs,
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
      status: json['status'] as String,
      responseMs: json['responseMs'] as int,
      checkedAt: json['checkedAt'] as String,
      // Try to read optional fields if backend includes them
      intervalSec: (json['interval'] is int)
          ? json['interval'] as int
          : (json['intervalSec'] as int?) /* tolerate either key */,
      timeoutMs: json['timeoutMs'] as int?,
      retries: json['retries'] as int?,
      retryBackoffMs: json['retryBackoffMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'status': status,
    'responseMs': responseMs,
    'checkedAt': checkedAt,
    if (intervalSec != null) 'interval': intervalSec,
    if (timeoutMs != null) 'timeoutMs': timeoutMs,
    if (retries != null) 'retries': retries,
    if (retryBackoffMs != null) 'retryBackoffMs': retryBackoffMs,
  };
}
