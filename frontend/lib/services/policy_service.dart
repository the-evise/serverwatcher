import 'dart:convert';
import 'package:http/http.dart' as http;

class IncidentPolicy {
  int openConsecutiveFails;
  int openSeconds;
  int closeConsecutiveOKs;
  int alertCooldownSec;

  IncidentPolicy({
    required this.openConsecutiveFails,
    required this.openSeconds,
    required this.closeConsecutiveOKs,
    required this.alertCooldownSec,
  });

  factory IncidentPolicy.fromJson(Map<String, dynamic> j) => IncidentPolicy(
    openConsecutiveFails: j['openConsecutiveFails'] as int,
    openSeconds: j['openSeconds'] as int,
    closeConsecutiveOKs: j['closeConsecutiveOKs'] as int,
    alertCooldownSec: j['alertCooldownSec'] as int,
  );

  Map<String, dynamic> toJson() => {
    'openConsecutiveFails': openConsecutiveFails,
    'openSeconds': openSeconds,
    'closeConsecutiveOKs': closeConsecutiveOKs,
    'alertCooldownSec': alertCooldownSec,
  };
}

class PolicyService {
  // Keep in sync with StatusService.baseUrl
  static const String baseUrl = 'http://localhost:8080';

  static Future<IncidentPolicy> fetchPolicy() async {
    final res = await http.get(Uri.parse('$baseUrl/policy'));
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch policy (${res.statusCode})');
    }
    return IncidentPolicy.fromJson(json.decode(res.body));
  }

  static Future<void> updatePolicy(IncidentPolicy policy) async {
    final res = await http.put(
      Uri.parse('$baseUrl/policy'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(policy.toJson()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update policy (${res.statusCode})');
    }
  }
}
