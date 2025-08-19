// lib/ui/widgets/service_card.dart
import 'package:flutter/material.dart';
import '../../models/service.dart';

class ServiceCard extends StatelessWidget {
  final ServiceStatus svc;

  // Actions
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final VoidCallback onIncidents;

  // NEW: optional config so the card can display reliability params
  final int? intervalSec;
  final int? timeoutMs;
  final int? retries;
  final int? retryBackoffMs;

  // NEW: highlight if there is an open incident for this service
  final bool hasOpenIncident;

  const ServiceCard({
    super.key,
    required this.svc,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
    required this.onIncidents,
    this.intervalSec,
    this.timeoutMs,
    this.retries,
    this.retryBackoffMs,
    this.hasOpenIncident = false,
  });

  @override
  Widget build(BuildContext context) {
    final ok = svc.status == 'OK';

    // Purple base with subtle variation for OK/FAIL
    final gradient = LinearGradient(
      colors: ok
          ? const [Color(0xFF6F42C1), Color(0xFF8E24AA)]
          : const [Color(0xFF4E3A7A), Color(0xFF5A2B7D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12), // tighter radius
        gradient: gradient,
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + status + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Open-incident beacon (if any)
              if (hasOpenIncident) ...[
                const _Beacon(),
                const SizedBox(width: 8),
              ],
              // Name
              Expanded(
                child: Text(
                  svc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _StatusChip(ok: ok),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history, color: Colors.white70),
                onPressed: onHistory,
              ),
              IconButton(
                tooltip: 'Incidents',
                icon: const Icon(Icons.warning_amber, color: Colors.white70),
                onPressed: onIncidents,
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ],
          ),

          const SizedBox(height: 6),

          // URL
          Text(
            svc.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          // NEW: Config chips row (only if values provided)
          if (intervalSec != null ||
              timeoutMs != null ||
              retries != null ||
              retryBackoffMs != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (intervalSec != null)
                  _MetaChip(label: 'Every', value: '${intervalSec}s'),
                if (timeoutMs != null)
                  _MetaChip(label: 'Timeout', value: '${timeoutMs}ms'),
                if (retries != null)
                  _MetaChip(label: 'Retries', value: '$retries'),
                if (retryBackoffMs != null)
                  _MetaChip(label: 'Backoff', value: '${retryBackoffMs}ms'),
              ],
            ),
          ],

          const Spacer(),

          // Bottom row: latency + timestamp
          Row(
            children: [
              Text(
                '${svc.responseMs} ms',
                style: const TextStyle(
                  color: Color(0xFFFFD700), // gold
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                svc.checkedAt.split('.').first.replaceAll('T', ' '),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool ok;
  const _StatusChip({required this.ok});

  @override
  Widget build(BuildContext context) {
    final bg = ok ? const Color(0x3322C55E) : const Color(0x33D14343);
    final border = ok ? const Color(0xFF22C55E) : const Color(0xFFFF6B6B);
    final text = ok ? const Color(0xFFC7F9CC) : const Color(0xFFFFD1D1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        ok ? 'OK' : 'FAIL',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Beacon extends StatefulWidget {
  const _Beacon();

  @override
  State<_Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<_Beacon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.9,
        end: 1.15,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: const Icon(Icons.circle, size: 10, color: Colors.redAccent),
    );
  }
}
