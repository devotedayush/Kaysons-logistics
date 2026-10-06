import 'package:flutter/material.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/office_widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../l10n/app_localizations.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'open';
  String _search = '';
  late Future<List<_NotificationItem>> _notifications;
  @override
  void initState() {
    super.initState();
    _notifications = _loadNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _notifications = _loadNotifications());
    await _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(l.adminNotifications),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_NotificationItem>>(
          future: _notifications,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final items = snap.data ?? const <_NotificationItem>[];
            final visible =
                items
                    .where(
                      (item) =>
                          (_filter == 'all' || item.status == _filter) &&
                          '${item.title} ${item.message} ${item.category}'
                              .toLowerCase()
                              .contains(_search.toLowerCase()),
                    )
                    .toList();
            final openCount =
                items.where((item) => item.status != 'resolved').length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                WorkspaceHeader(
                  title: l.adminAlertNotifications,
                  description: officeCopy(
                    context,
                    'Read the reason for each alert and check the affected record. Use status filters to focus on work still open.',
                    'हर सूचना का कारण पढ़ें और संबंधित रिकॉर्ड जाँचें। बाकी काम देखने के लिए स्थिति का फ़िल्टर चुनें।',
                  ),
                  icon: Icons.notifications_outlined,
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.adminRefresh),
                  ),
                  summary: StatusBadge(
                    label: '$openCount ${l.adminOpen}',
                    tone:
                        openCount > 0
                            ? WorkspaceTone.warning
                            : WorkspaceTone.success,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: officeCopy(
                      context,
                      'Search alerts',
                      'सूचनाएँ खोजें',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.adminOpen),
                      selected: _filter == 'open',
                      onSelected: (_) => setState(() => _filter = 'open'),
                    ),
                    ChoiceChip(
                      label: Text(l.adminResolved),
                      selected: _filter == 'resolved',
                      onSelected: (_) => setState(() => _filter = 'resolved'),
                    ),
                    ChoiceChip(
                      label: Text(l.adminAll),
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
                else if (snap.hasError)
                  WorkspaceEmptyState(
                    title: officeCopy(
                      context,
                      'Alerts could not be loaded',
                      'सूचनाएँ लोड नहीं हुईं',
                    ),
                    message: officeCopy(
                      context,
                      'Check your connection and try again.',
                      'कनेक्शन जाँचें और फिर प्रयास करें।',
                    ),
                    icon: Icons.cloud_off_outlined,
                    action: OutlinedButton(
                      onPressed: _refresh,
                      child: Text(l.adminRetry),
                    ),
                  )
                else if (visible.isEmpty)
                  WorkspaceEmptyState(
                    title: l.adminNoNotifications,
                    message: officeCopy(
                      context,
                      'There are no alerts matching this search and status.',
                      'इस खोज और स्थिति की कोई सूचना नहीं है।',
                    ),
                    icon: Icons.task_alt_outlined,
                  )
                else if (MediaQuery.sizeOf(context).width >= 1000)
                  DataTable(
                    columnSpacing: 20,
                    dataRowMinHeight: 72,
                    dataRowMaxHeight: 92,
                    columns: [
                      DataColumn(
                        label: Text(officeCopy(context, 'Alert', 'सूचना')),
                      ),
                      DataColumn(
                        label: Text(
                          officeCopy(context, 'Priority', 'प्राथमिकता'),
                        ),
                      ),
                      DataColumn(label: Text(l.adminStatus)),
                      DataColumn(
                        label: Text(officeCopy(context, 'Details', 'जानकारी')),
                      ),
                    ],
                    rows:
                        visible
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 420,
                                      child: Text(item.title, maxLines: 3),
                                    ),
                                  ),
                                  DataCell(
                                    StatusBadge(
                                      label: item.severity,
                                      tone:
                                          item.severity == 'high'
                                              ? WorkspaceTone.danger
                                              : WorkspaceTone.warning,
                                    ),
                                  ),
                                  DataCell(
                                    StatusBadge(
                                      label:
                                          item.status == 'resolved'
                                              ? l.adminResolved
                                              : l.adminOpen,
                                      tone:
                                          item.status == 'resolved'
                                              ? WorkspaceTone.success
                                              : WorkspaceTone.info,
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton(
                                      onPressed:
                                          () => showDialog<void>(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  scrollable: true,
                                                  content: SizedBox(
                                                    width: 640,
                                                    child: _NotificationTile(
                                                      item: item,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: Text(
                                                        officeCopy(
                                                          context,
                                                          'Close',
                                                          'बंद करें',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          ),
                                      child: Text(
                                        officeCopy(
                                          context,
                                          'Read alert',
                                          'सूचना पढ़ें',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
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
    return '$day/$month/${dt.year} ${format12HourTime(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _bg),
        borderRadius: BorderRadius.circular(18),
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
                      fontSize: 14,
                      height: 1.5,
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
