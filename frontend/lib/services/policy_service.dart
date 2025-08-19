import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incident_policy.dart';

class PolicyService {
  static const String baseUrl = 'http://localhost:8080';

  static Future<IncidentPolicy> fetchPolicy() async {
    final res = await http.get(Uri.parse('$baseUrl/policy'));
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch policy: ${res.body}');
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
      throw Exception('Failed to update policy: ${res.body}');
    }
  }
}
