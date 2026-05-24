import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class AdminDashboardBody extends StatefulWidget {
  const AdminDashboardBody({super.key});

  @override
  State<AdminDashboardBody> createState() => _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends State<AdminDashboardBody> {
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _displayName = '';
  bool _loading = true;

  double _avgFreightPerCase = 0;
  int _casesToday = 0;
  int _activeTransporters = 0;
  double _revenueToday = 0;
  List<double> _series = const [];
  List<_ManagerPerf> _managers = const [];
  List<_AdminAlert> _alerts = const [];
  List<_Insight> _insights = const [];

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadData();
  }

  Future<void> _loadName() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    final r = await supabase
        .from('profiles')
        .select('full_name, email')
        .eq('id', uid)
        .maybeSingle();
    if (!mounted || r == null) return;
    setState(() => _displayName = (r['full_name'] ??
            (r['email'] as String?)?.split('@').first ??
            '')
        .toString());
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 7)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customStart = picked;
      _customEnd ??= picked;
    });
    _loadData();
  }

  Future<void> _pickEnd() async {
    final base = _customEnd ?? _customStart ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: base,
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final rangeStart = _customStart == null
          ? now.subtract(Duration(days: _rangeDays))
          : DateTime.utc(
              _customStart!.year,
              _customStart!.month,
              _customStart!.day,
            );
      final rangeEnd = _customEnd == null
          ? null
          : DateTime.utc(
              _customEnd!.year,
              _customEnd!.month,
              _customEnd!.day,
              23,
              59,
              59,
            );
      final todayStart =
          DateTime.utc(now.year, now.month, now.day);

      final freightQuery = supabase
          .from('freights')
          .select(
              'id, created_by, origin, destination_town, cases, weight_kg, status, created_at, dispatched_at, winner_profile_id');
      final freights = await (rangeEnd == null
          ? freightQuery.gte('created_at', rangeStart.toIso8601String())
          : freightQuery
              .gte('created_at', rangeStart.toIso8601String())
              .lte('created_at', rangeEnd.toIso8601String()));

      final wonBids = await supabase
          .from('bids')
          .select('freight_id, amount, updated_at')
          .eq('state', 'won');

      final approvedTransporters = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'transporter')
          .eq('status', 'approved');

      final managers = await supabase
          .from('profiles')
          .select('id, full_name, business_name, email')
          .eq('role', 'logistics_manager');

      List<Map<String, dynamic>> alertRows = const [];
      try {
        final alertQuery = supabase
            .from('admin_alerts')
            .select('id, freight_id, category, severity, title, message, status, created_at');
        final fetchedAlerts = await (rangeEnd == null
            ? alertQuery.gte('created_at', rangeStart.toIso8601String())
            : alertQuery
                .gte('created_at', rangeStart.toIso8601String())
                .lte('created_at', rangeEnd.toIso8601String()));
        alertRows = (fetchedAlerts as List).cast<Map<String, dynamic>>();
      } catch (_) {
        alertRows = const [];
      }

      final winAmountByFreight = <String, double>{
        for (final b in wonBids)
          (b['freight_id'] as String): ((b['amount'] as num).toDouble())
      };

      // KPIs
      double totalRevRange = 0;
      int totalCasesRange = 0;
      int casesToday = 0;
      double revToday = 0;
      final freightsList =
          (freights as List).cast<Map<String, dynamic>>();

      for (final f in freightsList) {
        final fid = f['id'] as String;
        final c = (f['cases'] as int?) ?? 0;
        final rev = winAmountByFreight[fid] ?? 0;
        totalRevRange += rev;
        totalCasesRange += c;
        final created = DateTime.tryParse(f['created_at'] as String? ?? '');
        if (created != null && created.isAfter(todayStart)) {
          casesToday += c;
          revToday += rev;
        }
      }

      // Series: revenue per day over range
      final bucketDays = _rangeDays;
      final series = List<double>.filled(bucketDays, 0);
      for (final f in freightsList) {
        final fid = f['id'] as String;
        final rev = winAmountByFreight[fid] ?? 0;
        final created =
            DateTime.tryParse(f['created_at'] as String? ?? '')?.toUtc();
        if (created == null) continue;
        final daysAgo = now.difference(created).inDays;
        final idx = (bucketDays - 1) - daysAgo;
        if (idx >= 0 && idx < bucketDays) {
          series[idx] += rev;
        }
      }

      // Manager performance: bids per manager (count of freights they created)
      final byManager = <String, int>{};
      for (final f in freightsList) {
        final mid = f['created_by'] as String?;
        if (mid == null) continue;
        byManager[mid] = (byManager[mid] ?? 0) + 1;
      }
      final perfs = <_ManagerPerf>[];
      for (final m in (managers as List)) {
        final id = m['id'] as String;
        final label = (m['full_name'] ??
                m['business_name'] ??
                (m['email'] as String?)?.split('@').first ??
                'Unnamed')
            .toString();
        final count = byManager[id] ?? 0;
        perfs.add(_ManagerPerf(name: label, bidsHandled: count));
      }
      perfs.sort((a, b) => b.bidsHandled.compareTo(a.bidsHandled));
      final alerts = alertRows
          .map(
            (row) => _AdminAlert(
              title: (row['title'] ?? 'Alert').toString(),
              message: (row['message'] ?? '').toString(),
              category: (row['category'] ?? '').toString(),
              severity: (row['severity'] ?? 'medium').toString(),
              status: (row['status'] ?? 'open').toString(),
              createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
            ),
          )
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
      final insights = _buildInsights(
        freightsList: freightsList,
        winAmountByFreight: winAmountByFreight,
        alerts: alerts,
      );

      if (!mounted) return;
      setState(() {
        _avgFreightPerCase =
            totalCasesRange == 0 ? 0 : totalRevRange / totalCasesRange;
        _casesToday = casesToday;
        _revenueToday = revToday;
        _activeTransporters = (approvedTransporters as List).length;
        _series = series;
        _managers = perfs;
        _alerts = alerts;
        _insights = insights;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Insight> _buildInsights({
    required List<Map<String, dynamic>> freightsList,
    required Map<String, double> winAmountByFreight,
    required List<_AdminAlert> alerts,
  }) {
    final insights = <_Insight>[];
    if (freightsList.isEmpty) {
      return const [
        _Insight(
          title: 'AI insight waiting for data',
          detail:
              'No freight activity exists in the selected window yet, so the admin view cannot detect cost or compliance flaws.',
          tone: _InsightTone.neutral,
        ),
      ];
    }

    final openCount =
        freightsList.where((f) => f['status'] == 'bidding').length;
    final lockedCount = freightsList
        .where((f) => ['locked', 'completed'].contains(f['status']))
        .length;
    if (openCount > lockedCount && openCount >= 3) {
      insights.add(
        _Insight(
          title: 'Bid closures are lagging behind fresh demand',
          detail:
              '$openCount freights are still open while only $lockedCount are locked or completed in this window. Review slow awards or dispatch bottlenecks.',
          tone: _InsightTone.warning,
        ),
      );
    }

    final routeCounts = <String, int>{};
    for (final f in freightsList) {
      final route =
          '${f['origin'] ?? 'Unknown'} → ${f['destination_town'] ?? 'Unknown'}';
      routeCounts[route] = (routeCounts[route] ?? 0) + 1;
    }
    final duplicate = routeCounts.entries
        .where((e) => e.value > 1)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (duplicate.isNotEmpty) {
      final top = duplicate.first;
      insights.add(
        _Insight(
          title: 'Possible duplicate or repeated route booking',
          detail:
              '${top.key} appears ${top.value} times in the selected window. This is worth checking for duplicate requirements or route fragmentation.',
          tone: _InsightTone.warning,
        ),
      );
    }

    final wonValues = winAmountByFreight.values.toList()..sort();
    if (wonValues.length >= 3) {
      final spread = wonValues.last - wonValues.first;
      final baseline = wonValues.first == 0 ? 1 : wonValues.first;
      if (spread / baseline > 0.35) {
        insights.add(
          _Insight(
            title: 'Freight pricing is inconsistent across completed bids',
            detail:
                'Winning freight values vary from ${_fmtMoney(wonValues.first)} to ${_fmtMoney(wonValues.last)}. The spread is wide enough to suggest negotiation inconsistency or route-level anomalies.',
            tone: _InsightTone.warning,
          ),
        );
      }
    }

    final openAlerts = alerts.where((a) => a.status != 'resolved').toList();
    if (openAlerts.isNotEmpty) {
      final critical = openAlerts
          .where((a) => a.severity == 'high' || a.severity == 'critical')
          .length;
      final latePod = openAlerts.where((a) => a.category == 'late_pod').length;
      insights.add(
        _Insight(
          title:
              latePod > 0
                  ? 'Late POD review is open'
                  : 'Compliance friction needs active monitoring',
          detail:
              latePod > 0
                  ? '$latePod delivery proof alert(s) crossed the 3-day POD SLA. Review these with the receiver and transporter before treating them as normal delays.'
                  : '${openAlerts.length} alert(s) are still open${critical > 0 ? ', including $critical high-severity cases' : ''}. Focus first on mismatched documents and incomplete vehicle registration.',
          tone: critical > 0 ? _InsightTone.risk : _InsightTone.warning,
        ),
      );
    } else {
      insights.add(
        const _Insight(
          title: 'Operational controls look stable in this window',
          detail:
              'No unresolved mismatch or faulty-registration alerts were detected from the current dataset.',
          tone: _InsightTone.good,
        ),
      );
    }

    return insights.take(4).toList();
  }

  String _fmtMoney(double v) {
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)} L';
    if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _AppBar(
            name: _displayName,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DateWindowBar(
              rangeDays: _rangeDays,
              customStart: _customStart,
              customEnd: _customEnd,
              onSelectRange: (days) {
                setState(() {
                  _rangeDays = days;
                  _customStart = null;
                  _customEnd = null;
                });
                _loadData();
              },
              onPickStart: _pickStart,
              onPickEnd: _pickEnd,
              onClearCustom: () {
                setState(() {
                  _customStart = null;
                  _customEnd = null;
                });
                _loadData();
              },
            ),
          ),
          const SizedBox(height: 16),
          _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                              child: _Kpi(
                            value: _fmtMoney(_avgFreightPerCase),
                            label: 'Avg Freight / Case',
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Kpi(
                            value: _casesToday.toString(),
                            label: 'Cases Today',
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                              child: _Kpi(
                            value: _activeTransporters.toString(),
                            label: 'Active Transporters',
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _Kpi(
                            value: _fmtMoney(_revenueToday),
                            label: "Today's Revenue",
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text('Freight revenue trend',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _onSurface)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: _series.every((v) => v == 0)
                            ? const Center(
                                child: Text('No data in range',
                                    style: TextStyle(
                                        color: _onSurfaceVariant)),
                              )
                            : CustomPaint(
                                painter: _LineChart(_series),
                                size: Size.infinite,
                              ),
                              ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('AI operational insights',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _onSurface)),
                    ),
                    ..._insights.map((insight) => _InsightTile(insight: insight)),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Alert notifications',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: _onSurface)),
                          ),
                          if (_alerts.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0E0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_alerts.where((a) => a.status != 'resolved').length} open',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'No faulty or mismatch alerts were generated in this window.',
                          style: TextStyle(color: _onSurfaceVariant),
                        ),
                      )
                    else
                      ..._alerts.take(5).map((alert) => _AlertTile(alert: alert)),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Performances By Manager',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _onSurface)),
                    ),
                    if (_managers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                            'No logistics managers yet.',
                            style: TextStyle(color: _onSurfaceVariant)),
                      )
                    else
                      ..._managers.asMap().entries.map(
                            (e) => _ManagerRow(
                              perf: e.value,
                              rank: e.key,
                              total: _managers.length,
                            ),
                          ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.isEmpty ? 'Welcome' : 'Welcome, $name',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: _onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAlert {
  const _AdminAlert({
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.status,
    this.createdAt,
  });

  final String title;
  final String message;
  final String category;
  final String severity;
  final String status;
  final DateTime? createdAt;
}

enum _InsightTone { good, neutral, warning, risk }

class _Insight {
  const _Insight({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final _InsightTone tone;
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});
  final _Insight insight;

  Color get _bg {
    switch (insight.tone) {
      case _InsightTone.good:
        return const Color(0xFFEFFAF0);
      case _InsightTone.neutral:
        return const Color(0xFFEFF4FF);
      case _InsightTone.warning:
        return const Color(0xFFFDF5E6);
      case _InsightTone.risk:
        return const Color(0xFFFDEEEE);
    }
  }

  IconData get _icon {
    switch (insight.tone) {
      case _InsightTone.good:
        return Icons.check_circle_outline;
      case _InsightTone.neutral:
        return Icons.insights_outlined;
      case _InsightTone.warning:
        return Icons.auto_graph_outlined;
      case _InsightTone.risk:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: const Color(0xFF49454F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.detail,
                  style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final _AdminAlert alert;

  Color get _bg {
    switch (alert.severity) {
      case 'critical':
      case 'high':
        return const Color(0xFFFFE0E0);
      case 'medium':
        return const Color(0xFFFDF5E6);
      default:
        return const Color(0xFFEFF4FF);
    }
  }

  Color get _badgeColor {
    switch (alert.severity) {
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
    final dt = alert.createdAt?.toLocal();
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: _badgeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _badgeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (alert.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style:
                        const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${alert.category.replaceAll('_', ' ')}${_timeLabel.isEmpty ? '' : ' · $_timeLabel'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECE6F0),
        borderRadius: BorderRadius.circular(16),
      ),
      height: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 32, color: Color(0xFFB39DC8)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _onSurface)),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: _onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ManagerPerf {
  const _ManagerPerf({required this.name, required this.bidsHandled});
  final String name;
  final int bidsHandled;
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({
    required this.perf,
    required this.rank,
    required this.total,
  });
  final _ManagerPerf perf;
  final int rank;
  final int total;

  Color get _tint {
    if (total <= 1) return const Color(0xFFEFFAF0);
    final ratio = rank / (total - 1);
    if (ratio < 0.34) return const Color(0xFFEFFAF0); // green
    if (ratio < 0.67) return const Color(0xFFFDF5E6); // amber
    return const Color(0xFFFDEEEE); // red
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline,
                size: 22, color: Color(0xFFB39DC8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perf.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _onSurface)),
                Text('Handling: ${perf.bidsHandled} bids',
                    style: const TextStyle(
                        fontSize: 12, color: _onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends CustomPainter {
  _LineChart(this.data);
  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.fold<double>(0, (a, b) => math.max(a, b));
    if (maxVal == 0) return;

    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = size.width * (i / (data.length - 1).clamp(1, 9999));
      final y = size.height - (size.height * (data[i] / maxVal)) * 0.9 - 6;
      points.add(Offset(x, y));
    }

    // smooth path
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      if (i == points.length - 2) path.lineTo(p1.dx, p1.dy);
    }

    // axes
    final axis = Paint()
      ..color = const Color(0xFFCAC4D0)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 2),
        Offset(size.width, size.height - 2), axis);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height - 2), axis);

    // line
    final line = Paint()
      ..color = const Color(0xFF6750A4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LineChart old) => old.data != data;
}
