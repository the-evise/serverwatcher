// lib/ui/incident_policy_card.dart
import 'package:flutter/material.dart';
import '../models/incident_policy.dart';
import '../services/policy_service.dart';

class IncidentPolicyCard extends StatefulWidget {
  const IncidentPolicyCard({super.key});

  @override
  State<IncidentPolicyCard> createState() => _IncidentPolicyCardState();
}

class _IncidentPolicyCardState extends State<IncidentPolicyCard> {
  IncidentPolicy? _policy; // current server policy (loaded)
  bool _loading = true; // initial fetch
  bool _saving = false; // PUT in-flight
  String? _error; // fetch/update error

  // Inputs
  final _failCtrl = TextEditingController();
  final _secCtrl = TextEditingController();
  final _okCtrl = TextEditingController();
  final _cooldownCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPolicy();
  }

  @override
  void dispose() {
    _failCtrl.dispose();
    _secCtrl.dispose();
    _okCtrl.dispose();
    _cooldownCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPolicy() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await PolicyService.fetchPolicy();
      _policy = p;
      _applyToControllers(p);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load policy: $e';
      });
    }
  }

  void _applyToControllers(IncidentPolicy p) {
    _failCtrl.text = p.openConsecutiveFails.toString();
    _secCtrl.text = p.openSeconds.toString();
    _okCtrl.text = p.closeConsecutiveOKs.toString();
    _cooldownCtrl.text = p.alertCooldownSec.toString();
  }

  int _parseInt(TextEditingController c, int fallback) {
    final t = c.text.trim();
    final v = int.tryParse(t);
    return v ?? fallback;
  }

  Future<void> _save() async {
    if (_policy == null) return;
    final newP = IncidentPolicy(
      openConsecutiveFails: _parseInt(_failCtrl, _policy!.openConsecutiveFails),
      openSeconds: _parseInt(_secCtrl, _policy!.openSeconds),
      closeConsecutiveOKs: _parseInt(_okCtrl, _policy!.closeConsecutiveOKs),
      alertCooldownSec: _parseInt(_cooldownCtrl, _policy!.alertCooldownSec),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PolicyService.updatePolicy(newP);
      _policy = newP; // optimistic local update
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Policy updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Update failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _policy == null) {
      return _ErrorBox(message: _error!, onRetry: _fetchPolicy);
    }

    // Normal content
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _numField('Fail count before OPEN', _failCtrl),
            _numField('Seconds before OPEN (0=off)', _secCtrl),
            _numField('OK count before CLOSE', _okCtrl),
            _numField('Notification cooldown (sec)', _cooldownCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : _fetchPolicy, // reload from server
                  child: const Text('Reset'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
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
