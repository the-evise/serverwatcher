import 'package:flutter/material.dart';
import '../services/policy_service.dart';

class IncidentPolicyCard extends StatefulWidget {
  const IncidentPolicyCard({super.key});

  @override
  State<IncidentPolicyCard> createState() => _IncidentPolicyCardState();
}

class _IncidentPolicyCardState extends State<IncidentPolicyCard> {
  late Future<IncidentPolicy> _futurePolicy;

  final _failCtrl = TextEditingController();
  final _secCtrl = TextEditingController();
  final _okCtrl = TextEditingController();
  final _cooldownCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futurePolicy = PolicyService.fetchPolicy();
  }

  @override
  void dispose() {
    _failCtrl.dispose();
    _secCtrl.dispose();
    _okCtrl.dispose();
    _cooldownCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IncidentPolicy>(
      future: _futurePolicy,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _ErrorBox(
            message: 'Failed to load policy: ${snap.error}',
            onRetry: () =>
                setState(() => _futurePolicy = PolicyService.fetchPolicy()),
          );
        }

        final p = snap.data!;
        _failCtrl.text = p.openConsecutiveFails.toString();
        _secCtrl.text = p.openSeconds.toString();
        _okCtrl.text = p.closeConsecutiveOKs.toString();
        _cooldownCtrl.text = p.alertCooldownSec.toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Incident Policy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                _numField('Fail count before OPEN', _failCtrl),
                _numField('Seconds before OPEN (0=off)', _secCtrl),
                _numField('OK count before CLOSE', _okCtrl),
                _numField('Notification cooldown (sec)', _cooldownCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => _futurePolicy = PolicyService.fetchPolicy(),
                      ),
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        final newP = IncidentPolicy(
                          openConsecutiveFails:
                              int.tryParse(_failCtrl.text.trim()) ??
                              p.openConsecutiveFails,
                          openSeconds:
                              int.tryParse(_secCtrl.text.trim()) ??
                              p.openSeconds,
                          closeConsecutiveOKs:
                              int.tryParse(_okCtrl.text.trim()) ??
                              p.closeConsecutiveOKs,
                          alertCooldownSec:
                              int.tryParse(_cooldownCtrl.text.trim()) ??
                              p.alertCooldownSec,
                        );
                        try {
                          await PolicyService.updatePolicy(newP);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Policy updated')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Update failed: $e')),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
