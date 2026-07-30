import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);
const _border = Color(0xFFE4E0E8);

class AdminDashboardBody extends StatefulWidget {
  const AdminDashboardBody({super.key});

  @override
  State<AdminDashboardBody> createState() => _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends State<AdminDashboardBody> {
  String _displayName = '';
  bool _loading = true;
  bool _showTrends = false;
  DateTime? _periodStart;
  DateTime? _periodEnd;
  _DashboardSnapshot? _snapshot;
  _DashboardSnapshot? _todaySnapshot;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadData();
  }

  Future<void> _loadName() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    final r =
        await supabase
            .from('profiles')
            .select('full_name, email')
            .eq('id', uid)
            .maybeSingle();
    if (!mounted || r == null) return;
    setState(() {
      _displayName =
          (r['full_name'] ?? (r['email'] as String?)?.split('@').first ?? '')
              .toString();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_periodStart != null && _periodEnd != null) {
        params['p_period_start'] = _dateKey(_periodStart!);
        params['p_period_end'] = _dateKey(_periodEnd!);
      }

      final today = DateTime.now();
      final results = await Future.wait([
        params.isEmpty
            ? supabase.rpc('clawd_admin_snapshot')
            : supabase.rpc('clawd_admin_snapshot', params: params),
        supabase.rpc(
          'clawd_admin_snapshot',
          params: {
            'p_period_start': _dateKey(today),
            'p_period_end': _dateKey(today),
          },
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _snapshot = _DashboardSnapshot.fromData(results[0]);
        _todaySnapshot = _DashboardSnapshot.fromData(results[1]);
        _periodStart = _snapshot?.periodStart;
        _periodEnd = _snapshot?.periodEnd;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final initial = _periodStart ?? DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(initial: initial),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _periodStart = DateTime(picked.year, picked.month);
      _periodEnd = DateTime(picked.year, picked.month + 1, 0);
    });
    _loadData();
  }

  void _useLatestPeriod() {
    setState(() {
      _periodStart = null;
      _periodEnd = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _AppBar(
            name: _displayName,
            openAlertCount: snapshot?.openAlerts ?? 0,
          ),
          const SizedBox(height: 12),
          _PeriodBar(
            label: snapshot?.periodLabel ?? 'Loading latest period',
            todayDispatches: _todaySnapshot?.dispatches ?? 0,
            onPickMonth: _pickMonth,
            onLatest: _useLatestPeriod,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snapshot == null)
            const _EmptyState()
          else ...[
            _KpiStrip(snapshot: snapshot),
            const SizedBox(height: 16),
            _NeedsAttention(snapshot: snapshot),
            const SizedBox(height: 16),
            _SummaryTables(snapshot: snapshot),
            const SizedBox(height: 16),
            _TrendSection(
              snapshot: snapshot,
              expanded: _showTrends,
              onToggle: () => setState(() => _showTrends = !_showTrends),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardSnapshot {
  const _DashboardSnapshot({
    required this.periodStart,
    required this.periodEnd,
    required this.totals,
    required this.riskSummary,
    required this.companyTotals,
    required this.transporters,
    required this.destinations,
    required this.routes,
    required this.podByTransporter,
    required this.podByDestination,
    required this.trend,
  });

  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Map<String, dynamic> totals;
  final Map<String, dynamic> riskSummary;
  final List<Map<String, dynamic>> companyTotals;
  final List<Map<String, dynamic>> transporters;
  final List<Map<String, dynamic>> destinations;
  final List<Map<String, dynamic>> routes;
  final List<Map<String, dynamic>> podByTransporter;
  final List<Map<String, dynamic>> podByDestination;
  final List<Map<String, dynamic>> trend;

  factory _DashboardSnapshot.fromData(dynamic data) {
    final map = _asMap(data);
    final period = _asMap(map['period']);
    final pod = _asMap(map['pod_aging']);
    return _DashboardSnapshot(
      periodStart: _parseDate(period['period_start']),
      periodEnd: _parseDate(period['period_end']),
      totals: _asMap(map['totals']),
      riskSummary: _asMap(map['risk_summary']),
      companyTotals: _asMapList(map['company_totals']),
      transporters: _asMapList(map['transporter_rankings']),
      destinations: _asMapList(map['destination_rankings']),
      routes: _asMapList(map['route_rankings']),
      podByTransporter: _asMapList(pod['by_transporter']),
      podByDestination: _asMapList(pod['by_destination']),
      trend: _asMapList(map['trend']),
    );
  }

  int get dispatches => _int(totals['dispatches']);
  int get cases => _int(totals['cases']);
  double get metricTons => _double(totals['metric_tons']);
  double get freight => _double(totals['freight']);
  int get podPending => _int(totals['pod_pending']);
  int get podReceived => _int(totals['pod_received']);
  double get reviewValue => _double(totals['review_value']);
  int get openAlerts => _int(riskSummary['open_alerts']);
  int get duplicateEwayRisks => _int(riskSummary['duplicate_eway_risks']);
  int get highExtraChargeRisks => _int(riskSummary['high_extra_charge_risks']);
  int get routeCostSpikeRisks => _int(riskSummary['route_cost_spike_risks']);

  String get periodLabel {
    final start = periodStart;
    final end = periodEnd;
    if (start == null || end == null) return 'Latest business period';
    if (start.year == end.year && start.month == end.month) {
      return '${_monthName(start.month)} ${start.year}';
    }
    return '${_shortDate(start)} to ${_shortDate(end)}';
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.name, required this.openAlertCount});

  final String name;
  final int openAlertCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name.isEmpty ? 'Admin Dashboard' : 'Welcome, $name',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/admin/notifications'),
          icon:
              openAlertCount > 0
                  ? Badge.count(
                    count: openAlertCount,
                    child: const Icon(Icons.notifications_outlined),
                  )
                  : const Icon(Icons.notifications_outlined),
        ),
      ],
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.label,
    required this.todayDispatches,
    required this.onPickMonth,
    required this.onLatest,
  });

  final String label;
  final int todayDispatches;
  final VoidCallback onPickMonth;
  final VoidCallback onLatest;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(icon: Icons.calendar_month_outlined, text: label, strong: true),
        if (todayDispatches > 0)
          _Pill(
            icon: Icons.today_outlined,
            text: 'Today: $todayDispatches dispatches',
          ),
        OutlinedButton.icon(
          onPressed: onPickMonth,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Month'),
        ),
        TextButton.icon(
          onPressed: onLatest,
          icon: const Icon(Icons.update, size: 18),
          label: const Text('Latest'),
        ),
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiData(
        'Dispatches',
        snapshot.dispatches.toString(),
        Icons.local_shipping_outlined,
      ),
      _KpiData('Cases', _fmtInt(snapshot.cases), Icons.inventory_2_outlined),
      _KpiData(
        'Metric Tons',
        '${_fmtDecimal(snapshot.metricTons)} MT',
        Icons.scale_outlined,
      ),
      _KpiData('Freight', _fmtMoney(snapshot.freight), Icons.currency_rupee),
      _KpiData(
        'POD Pending',
        snapshot.podPending.toString(),
        Icons.assignment_late_outlined,
        warning: snapshot.podPending > 0,
      ),
      _KpiData(
        'Review Value',
        _fmtMoney(snapshot.reviewValue),
        Icons.fact_check_outlined,
        warning: snapshot.reviewValue > 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1120
                ? 6
                : constraints.maxWidth >= 760
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              cards
                  .map(
                    (card) =>
                        SizedBox(width: width, child: _KpiCard(data: card)),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_AttentionItem>[];
    if (snapshot.podByTransporter.isNotEmpty) {
      final top = snapshot.podByTransporter.first;
      items.add(
        _AttentionItem(
          icon: Icons.assignment_late_outlined,
          title:
              '${top['transporter_name']} has ${_int(top['pending'])} POD pending',
          detail:
              '${_fmtMoney(_double(top['value']))} needs acknowledgement follow-up.',
          action: 'Open ledger',
          route: '/admin/ledger',
        ),
      );
    }
    if (snapshot.duplicateEwayRisks > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.copy_all_outlined,
          title: '${snapshot.duplicateEwayRisks} duplicate e-way risk(s)',
          detail: 'Review document-wise before payment release.',
          action: 'Ask Clawd',
          route: '/admin/clawd',
        ),
      );
    }
    if (snapshot.routeCostSpikeRisks > 0) {
      final route =
          snapshot.routes.isEmpty ? 'routes' : snapshot.routes.first['route'];
      items.add(
        _AttentionItem(
          icon: Icons.trending_up_outlined,
          title: '${snapshot.routeCostSpikeRisks} route cost spike(s)',
          detail: '$route needs freight/MT comparison.',
          action: 'Review routes',
          route: '/admin/ledger',
        ),
      );
    }
    if (snapshot.highExtraChargeRisks > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.receipt_long_outlined,
          title: '${snapshot.highExtraChargeRisks} high extra charge case(s)',
          detail: 'Check labour, detention, toll, and out-route charges.',
          action: 'Open Clawd',
          route: '/admin/clawd',
        ),
      );
    }

    final visible = items.take(3).toList();
    return _Panel(
      title: 'Needs Attention',
      trailing: TextButton.icon(
        onPressed: () => context.push('/admin/clawd'),
        icon: const Icon(Icons.psychology_alt_outlined, size: 18),
        label: const Text('Clawd'),
      ),
      child:
          visible.isEmpty
              ? const Text(
                'No priority review items in this period.',
                style: TextStyle(color: _onSurfaceVariant),
              )
              : Column(
                children:
                    visible.map((item) => _AttentionRow(item: item)).toList(),
              ),
    );
  }
}

class _SummaryTables extends StatelessWidget {
  const _SummaryTables({required this.snapshot});

  final _DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final left = _Panel(
          title: 'Transporter Performance',
          child: _MiniTable(
            rows: snapshot.transporters.take(6).toList(),
            columns: const ['Transporter', 'Vehicles', 'MT', 'Freight', 'POD'],
            cells:
                (row) => [
                  row['transporter_name'].toString(),
                  _int(row['dispatches']).toString(),
                  _fmtDecimal(_double(row['metric_tons'])),
                  _fmtMoney(_double(row['freight'])),
                  _int(row['pod_pending']).toString(),
                ],
          ),
        );
        final right = _Panel(
          title: 'Routes & Destinations',
          child: Column(
            children: [
              _MiniTable(
                rows: snapshot.routes.take(5).toList(),
                columns: const ['Route', 'Vehicles', 'Freight/MT'],
                cells:
                    (row) => [
                      row['route'].toString(),
                      _int(row['dispatches']).toString(),
                      _fmtMoney(_double(row['freight_per_mt'])),
                    ],
              ),
              const Divider(height: 18),
              _MiniTable(
                rows: snapshot.destinations.take(5).toList(),
                columns: const ['Place', 'Vehicles', 'POD'],
                cells:
                    (row) => [
                      row['destination'].toString(),
                      _int(row['dispatches']).toString(),
                      _int(row['pod_pending']).toString(),
                    ],
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.snapshot,
    required this.expanded,
    required this.onToggle,
  });

  final _DashboardSnapshot snapshot;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Trends',
      trailing: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
        label: Text(expanded ? 'Hide' : 'Show'),
      ),
      child:
          expanded
              ? SizedBox(
                height: 180,
                child:
                    snapshot.trend.isEmpty
                        ? const Center(child: Text('No trend data'))
                        : CustomPaint(
                          painter: _LineChart(
                            snapshot.trend
                                .map((row) => _double(row['freight']))
                                .toList(),
                          ),
                          size: Size.infinite,
                        ),
              )
              : const Text(
                'Daily freight trend is available here, kept secondary so the cockpit stays focused on action.',
                style: TextStyle(color: _onSurfaceVariant),
              ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.warning ? const Color(0xFFFFF7E8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: data.warning ? const Color(0xFFE9C46A) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 20, color: _onSurfaceVariant),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _onSurface,
            ),
          ),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: const Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(item.route),
            child: Text(item.action),
          ),
        ],
      ),
    );
  }
}

class _MiniTable extends StatelessWidget {
  const _MiniTable({
    required this.rows,
    required this.columns,
    required this.cells,
  });

  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final List<String> Function(Map<String, dynamic> row) cells;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text(
        'No records in this period.',
        style: TextStyle(color: _onSurfaceVariant),
      );
    }
    return Table(
      columnWidths: {
        for (var i = 0; i < columns.length; i++)
          i: i == 0 ? const FlexColumnWidth(2.2) : const FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF7F2FA)),
          children: columns.map(_headerCell).toList(),
        ),
        ...rows.map((row) {
          final values = cells(row);
          return TableRow(children: values.map(_bodyCell).toList());
        }),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _onSurface,
        ),
      ),
    );
  }

  Widget _bodyCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: _onSurface),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFEFF4FF) : const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: _onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select month'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _year,
              items: [
                for (
                  var year = DateTime.now().year - 2;
                  year <= DateTime.now().year + 1;
                  year++
                )
                  DropdownMenuItem(value: year, child: Text(year.toString())),
              ],
              onChanged: (value) => setState(() => _year = value ?? _year),
              decoration: const InputDecoration(labelText: 'Year'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var month = 1; month <= 12; month++)
                  OutlinedButton(
                    onPressed:
                        () => Navigator.pop(context, DateTime(_year, month)),
                    child: Text(_monthName(month).substring(0, 3)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChart extends CustomPainter {
  const _LineChart(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    if (maxValue <= 0) return;

    final grid =
        Paint()
          ..color = const Color(0xFFE4E0E8)
          ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final paint =
        Paint()
          ..color = const Color(0xFF355CA8)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChart oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'No dashboard data found.',
          style: TextStyle(color: _onSurfaceVariant),
        ),
      ),
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.icon, {this.warning = false});

  final String label;
  final String value;
  final IconData icon;
  final bool warning;
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final String route;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  final list = value is List ? value : const [];
  return list
      .whereType<Object>()
      .map(_asMap)
      .where((row) => row.isNotEmpty)
      .toList();
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _fmtInt(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

String _fmtDecimal(double value) {
  if (value >= 100) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

String _fmtMoney(double value) {
  if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(2)} L';
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
  return '₹${value.toStringAsFixed(0)}';
}

String _shortDate(DateTime date) {
  return '${date.day} ${_monthName(date.month).substring(0, 3)} ${date.year}';
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}
