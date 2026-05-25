import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_bootstrap.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<List<_NotificationItem>>(
          future: _loadNotifications(),
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final items = snap.data ?? const <_NotificationItem>[];
            final visible =
                _filter == 'all'
                    ? items
                    : items.where((item) => item.status == _filter).toList();
            final openCount =
                items.where((item) => item.status != 'resolved').length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alert notifications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                    ),
                    if (openCount > 0)
                      Badge.count(
                        count: openCount,
                        child: const Icon(Icons.notifications_outlined),
                      )
                    else
                      const Icon(Icons.notifications_none_outlined),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Review POD, document mismatch, vehicle, and registration alerts from one place.',
                  style: TextStyle(fontSize: 13, color: _onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Open'),
                      selected: _filter == 'open',
                      onSelected: (_) => setState(() => _filter = 'open'),
                    ),
                    ChoiceChip(
                      label: const Text('Resolved'),
                      selected: _filter == 'resolved',
                      onSelected: (_) => setState(() => _filter = 'resolved'),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'No notifications here right now.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ...visible.map((item) => _NotificationTile(item: item)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<List<_NotificationItem>> _loadNotifications() async {
    final rows = await supabase
        .from('admin_alerts')
        .select(
          'id, freight_id, invoice_id, category, severity, title, message, status, created_at, resolved_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_NotificationItem.fromRow)
        .toList();
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.status,
    this.createdAt,
    this.resolvedAt,
  });

  final String title;
  final String message;
  final String category;
  final String severity;
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory _NotificationItem.fromRow(Map<String, dynamic> row) {
    return _NotificationItem(
      title: (row['title'] ?? 'Notification').toString(),
      message: (row['message'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      severity: (row['severity'] ?? 'medium').toString(),
      status: (row['status'] ?? 'open').toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
      resolvedAt: DateTime.tryParse((row['resolved_at'] ?? '').toString()),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItem item;

  Color get _bg {
    switch (item.severity) {
      case 'critical':
      case 'high':
        return const Color(0xFFFFE0E0);
      case 'medium':
        return const Color(0xFFFDF5E6);
      default:
        return const Color(0xFFEFF4FF);
    }
  }

  Color get _accent {
    switch (item.severity) {
      case 'critical':
      case 'high':
        return const Color(0xFFB3261E);
      case 'medium':
        return const Color(0xFF8A5A00);
      default:
        return const Color(0xFF355CA8);
    }
  }

  String get _timeLabel {
    final dt = item.createdAt?.toLocal();
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                    ),
                    _Pill(label: item.severity.toUpperCase(), color: _accent),
                  ],
                ),
                if (item.message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      label: item.category.replaceAll('_', ' '),
                      color: _onSurfaceVariant,
                    ),
                    _Pill(label: item.status, color: _onSurfaceVariant),
                    if (_timeLabel.isNotEmpty)
                      _Pill(label: _timeLabel, color: _onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
