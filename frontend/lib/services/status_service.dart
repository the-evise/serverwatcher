import 'dart:convert';
import 'package:frontend/models/analytics.dart';
import 'package:frontend/models/incident.dart';
import 'package:http/http.dart' as http;
import '../models/service.dart';

class StatusService {
  static const String baseUrl = 'http://localhost:8080';

  // NEW: API key plumbing for protected endpoints
  static String _apiKey = '';
  static void setApiKey(String key) => _apiKey = key.trim();

  static Map<String, String> _authHeaders() =>
      _apiKey.isEmpty ? {} : {'X-API-Key': _apiKey};

  static Future<List<ServiceStatus>> fetchStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/status'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load service statuses');
    }
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => ServiceStatus.fromJson(j)).toList();
  }

  // UPDATED: add reliability params + API key header
  static Future<void> addService({
    required String name,
    required String url,
    required int interval,
    int timeoutMs = 2500,
    int retries = 1,
    int retryBackoffMs = 300,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/services/add'),
      headers: {'Content-Type': 'application/json', ..._authHeaders()},
      body: json.encode({
        'name': name,
        'url': url,
        'interval': interval,
        'timeoutMs': timeoutMs,
        'retries': retries,
        'retryBackoffMs': retryBackoffMs,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add service (${response.statusCode})');
    }
  }

  static Future<void> deleteService(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/services/delete?id=$id'),
      headers: _authHeaders(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service (${response.statusCode})');
    }
  }

  // UPDATED: add reliability params + API key header
  static Future<void> updateService({
    required int id,
    required String name,
    required String url,
    required int interval,
    int timeoutMs = 2500,
    int retries = 1,
    int retryBackoffMs = 300,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/services/update'),
      headers: {'Content-Type': 'application/json', ..._authHeaders()},
      body: json.encode({
        'id': id,
        'name': name,
        'url': url,
        'interval': interval,
        'timeoutMs': timeoutMs,
        'retries': retries,
        'retryBackoffMs': retryBackoffMs,
      }),
    );
    if (res.statusCode != 204) {
      throw Exception('Failed to update service (${res.statusCode})');
    }
  }

  static Future<List<ServiceStatus>> fetchHistory(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/history?id=$id'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load history');
    }
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => ServiceStatus.fromJson(j)).toList();
  }

  static Future<List<Incident>> fetchIncidents(int serviceId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/services/incidents?id=$serviceId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load incidents');
    }
    final List data = json.decode(res.body);
    return data.map((j) => Incident.fromJson(j)).toList();
  }

  static Future<Analytics> fetchAnalytics(
    int serviceId, {
    int hours = 24,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/services/analytics?id=$serviceId&hours=$hours'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load analytics');
    }
    return Analytics.fromJson(json.decode(res.body));
  }
}
