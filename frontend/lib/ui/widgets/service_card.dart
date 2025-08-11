// ui/widgets/service_card.dart
import 'package:flutter/material.dart';
import '../../models/service.dart';

class ServiceCard extends StatelessWidget {
  final ServiceStatus svc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;

  const ServiceCard({
    super.key,
    required this.svc,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final ok = svc.status == 'OK';
    final gradient = LinearGradient(
      colors: ok
          ? [const Color(0xFF7E57C2), const Color(0xFF8E24AA)]
          : [const Color(0xFF5C4A7D), const Color(0xFF3B2E5A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + status chip + actions
          Row(
            children: [
              Expanded(
                child: Text(
                  svc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
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
          const SizedBox(height: 8),
          Text(
            svc.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '${svc.responseMs} ms',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? const Color(0x33C5E1A5) : const Color(0x33EF9A9A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok ? const Color(0xFFB2FF59) : const Color(0xFFFF8A80),
          width: 1,
        ),
      ),
      child: Text(
        ok ? 'OK' : 'FAIL',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ok ? const Color(0xFFCCFF90) : const Color(0xFFFFAB91),
        ),
      ),
    );
  }
}
