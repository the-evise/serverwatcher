// ui/service_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/ui/history_chart.dart';
import '../models/service.dart';
import '../services/status_service.dart';
import 'widgets/service_card.dart';

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
      const Duration(seconds: 3),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final fut = StatusService.fetchStatuses(); // do async creation outside
    setState(() {
      _futureServices = fut; // assign Future synchronously
    });
  }

  Future<void> _addService() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final interval = int.tryParse(_intervalController.text.trim()) ?? 10;

    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and URL are required')),
      );
      return;
    }
    await StatusService.addService(name: name, url: url, interval: interval);
    _nameController.clear();
    _urlController.clear();
    _intervalController.text = '10';
    _refresh();
  }

  Future<void> _deleteService(int id) async {
    await StatusService.deleteService(id);
    _refresh();
  }

  Future<void> _editService(ServiceStatus svc) async {
    await _showEditDialog(svc);
  }

  Future<void> _showEditDialog(ServiceStatus svc) async {
    final nameCtrl = TextEditingController(text: svc.name);
    final urlCtrl = TextEditingController(text: svc.url);
    final intervalCtrl = TextEditingController(
      text: '10',
    ); // optional: wire actual interval if added to model

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: intervalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Interval (s)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final interval = int.tryParse(intervalCtrl.text.trim()) ?? 10;
              if (name.isEmpty || url.isEmpty) return;
              await StatusService.updateService(
                id: svc.id,
                name: name,
                url: url,
                interval: interval,
              );
              if (context.mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showHistorySheet(int id, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name – History',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<ServiceStatus>>(
                future: StatusService.fetchHistory(id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Expanded(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return const Expanded(
                      child: Center(child: Text('No history')),
                    );
                  }
                  return Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 140,
                          child: HistoryChart(history: history),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, i) {
                              final h = history[i];
                              return ListTile(
                                dense: true,
                                title: Text('${h.status} • ${h.responseMs} ms'),
                                subtitle: Text(
                                  h.checkedAt
                                      .split('.')
                                      .first
                                      .replaceAll('T', ' '),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serverwatcher'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          // Add form card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                      width: 110,
                      child: TextField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Interval (s)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addService,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Grid
          Expanded(
            child: FutureBuilder<List<ServiceStatus>>(
              future: _futureServices,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snapshot.data!
                  ..sort((a, b) => a.id.compareTo(b.id));
                if (services!.isEmpty)
                  return const Center(child: Text('No services yet'));

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final cross = w >= 1200
                        ? 4
                        : w >= 900
                        ? 3
                        : w >= 600
                        ? 2
                        : 1;

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: services.length,
                      itemBuilder: (context, i) {
                        final s = services[i];
                        return ServiceCard(
                          svc: s,
                          onEdit: () => _editService(s),
                          onDelete: () => _deleteService(s.id),
                          onHistory: () => _showHistorySheet(s.id, s.name),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
