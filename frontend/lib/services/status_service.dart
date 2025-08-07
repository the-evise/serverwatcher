import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service.dart';

class StatusService {
  static const String baseUrl = 'http://localhost:8080';

  static Future<List<ServiceStatus>> fetchStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/status'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ServiceStatus.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load service statuses');
    }
  }

  static Future<void> addService({
    required String name,
    required String url,
    required int interval,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/services/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'url': url, 'interval': interval}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add service');
    }
  }

  static Future<void> deleteService(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/services/delete?id=$id'),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete service');
    }
  }

  static Future<List<ServiceStatus>> fetchHistory(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services/history?id=$id'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ServiceStatus.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }
}
