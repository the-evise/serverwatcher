class ServiceStatus {
  final int id;
  final String name;
  final String url;
  final String status; // "OK" or "FAIL"
  final int responseMs; // Response time in ms
  final String checkedAt; // ISO 8601 timestamp

  ServiceStatus({
    required this.id,
    required this.name,
    required this.url,
    required this.status,
    required this.responseMs,
    required this.checkedAt,
  });

  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
      status: json['status'] as String,
      responseMs: json['responseMs'] as int,
      checkedAt: json['checkedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'status': status,
    'responseMs': responseMs,
    'checkedAt': checkedAt,
  };
}
