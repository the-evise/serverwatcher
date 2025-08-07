import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/ui/history_chart.dart';
import '../models/service.dart';
import '../services/status_service.dart';

class ServiceDashboard extends StatefulWidget {
  const ServiceDashboard({super.key});

  @override
  State<ServiceDashboard> createState() => _ServiceDashboardState();
}

class _ServiceDashboardState extends State<ServiceDashboard> {
  late Future<List<ServiceStatus>> _futureServices;
  Timer? _refreshTimer;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _intervalController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _futureServices = StatusService.fetchStatuses();
    });
  }

  Future<void> _addService() async {
    await StatusService.addService(
      name: _nameController.text,
      url: _urlController.text,
      interval: int.tryParse(_intervalController.text) ?? 10,
    );
    _nameController.clear();
    _urlController.clear();
    _intervalController.text = '10';
    _refresh();
  }

  Future<void> _deleteService(int id) async {
    await StatusService.deleteService(id);
    _refresh();
  }

  void _showHistoryDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$name – History'),
        content: FutureBuilder<List<ServiceStatus>>(
          future: StatusService.fetchHistory(id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('No history.');
            } else {
              final history = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HistoryChart(history: history),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 300,
                    height: 200,
                    child: ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, idx) {
                        final entry = history[idx];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${entry.status} (${entry.responseMs} ms)',
                          ),
                          subtitle: Text(entry.checkedAt),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add service form
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _intervalController,
                  decoration: const InputDecoration(labelText: 'Interval'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _addService),
            ],
          ),
        ),
        // Service list
        Expanded(
          child: FutureBuilder<List<ServiceStatus>>(
            future: _futureServices,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final services = snapshot.data!;
              if (services.isEmpty) {
                return const Center(child: Text('No services yet'));
              }
              return GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                padding: const EdgeInsets.all(12),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: services.map((svc) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 5,
                    color: svc.status == 'OK'
                        ? const Color(0xFF8E24AA)
                        : const Color(0xFFB287F8).withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                svc.status == 'OK'
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: svc.status == 'OK'
                                    ? const Color(0xFFFFD700)
                                    : Colors.redAccent,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  svc.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.history,
                                  color: Colors.white70,
                                ),
                                onPressed: () =>
                                    _showHistoryDialog(svc.id, svc.name),
                                tooltip: "Show history",
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteService(svc.id),
                                tooltip: "Delete service",
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            svc.url,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                '${svc.responseMs} ms',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                svc.checkedAt
                                    .split('.')
                                    .first
                                    .replaceAll('T', ' '),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
