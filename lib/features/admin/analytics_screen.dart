import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

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
        title: const Text('Analytics'),
      ),
      body: const AnalyticsBody(),
    );
  }
}

class AnalyticsBody extends StatefulWidget {
  const AnalyticsBody({super.key});

  @override
  State<AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends State<AnalyticsBody> {
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('admin_freight_ledger_view')
          .select()
          .order('bill_date', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _rows.where((row) {
      final date = _date(row['bill_date']) ?? _date(row['created_at']);
      return withinDateWindow(
        date,
        rangeDays: _rangeDays,
        customStart: _customStart,
        customEnd: _customEnd,
      );
    }).toList();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customStart = picked;
      _customEnd ??= picked;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _customEnd ?? _customStart ?? DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final totalFreight = _sum(rows, 'total_freight');
    final totalCases = _sum(rows, 'cases');
    final totalWeight = _sum(rows, 'weight_kg');
    final pendingAck =
        rows.where((row) => row['ack_status'] != 'received').length;
    final pmt = totalWeight == 0 ? 0 : totalFreight / totalWeight;
    final transporters = _topGroups(rows, 'transporter_name', 'total_freight');
    final companies = _topGroups(rows, 'company_name', 'total_freight');
    final towns = _topGroups(rows, 'town', 'total_freight');
    final delayed =
        rows.where((row) => ((_num(row['delay_days']) ?? 0) > 0)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Analytics',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            icon: const Icon(Icons.refresh),
                            onPressed: _loading ? null : _load,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DateWindowBar(
                        rangeDays: _rangeDays,
                        customStart: _customStart,
                        customEnd: _customEnd,
                        onSelectRange:
                            (days) => setState(() {
                              _rangeDays = days;
                              _customStart = null;
                              _customEnd = null;
                            }),
                        onPickStart: _pickStart,
                        onPickEnd: _pickEnd,
                        onClearCustom:
                            () => setState(() {
                              _customStart = null;
                              _customEnd = null;
                            }),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatCard(
                            label: 'Total freight',
                            value: _money(totalFreight),
                          ),
                          _StatCard(
                            label: 'Cases',
                            value: totalCases.toStringAsFixed(0),
                          ),
                          _StatCard(
                            label: 'MT / Weight',
                            value: totalWeight.toStringAsFixed(2),
                          ),
                          _StatCard(
                            label: 'PMT',
                            value: _money(pmt),
                            positive: true,
                          ),
                          _StatCard(
                            label: 'Pending acknowledgements',
                            value: '$pendingAck',
                            warning: pendingAck > 0,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 820;
                          final sections = [
                            _SummarySection(
                              title: 'Transporter business volume',
                              rows: transporters,
                              total: totalFreight,
                            ),
                            _SummarySection(
                              title: 'Company-wise freight',
                              rows: companies,
                              total: totalFreight,
                            ),
                            _SummarySection(
                              title: 'Town-wise freight',
                              rows: towns,
                              total: totalFreight,
                            ),
                            _DelaySection(rows: delayed),
                          ];
                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  sections
                                      .map(
                                        (child) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 24,
                                          ),
                                          child: child,
                                        ),
                                      )
                                      .toList(),
                            );
                          }
                          return Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            children:
                                sections
                                    .map(
                                      (child) => SizedBox(
                                        width: (constraints.maxWidth - 24) / 2,
                                        child: child,
                                      ),
                                    )
                                    .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.positive = false,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool positive;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color =
        warning
            ? const Color(0xFFB3261E)
            : positive
            ? const Color(0xFF146C2E)
            : _onSurface;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 230),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECE6F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.rows,
    required this.total,
  });

  final String title;
  final List<(String, double)> rows;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        if (rows.isEmpty)
          const Text(
            'No data in range',
            style: TextStyle(color: _onSurfaceVariant),
          )
        else
          ...rows.map(
            (row) => _BarRow(
              label: row.$1,
              value: _money(row.$2),
              percent: total <= 0 ? 0 : row.$2 / total,
            ),
          ),
      ],
    );
  }
}

class _DelaySection extends StatelessWidget {
  const _DelaySection({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final top = rows.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Delay and acknowledgement alerts'),
        if (top.isEmpty)
          const Text(
            'No delayed dispatch rows in this window.',
            style: TextStyle(color: _onSurfaceVariant),
          )
        else
          ...top.map(
            (row) => _AlertTile(
              title:
                  '${_text(row['company_name'])} · ${_text(row['town'])} delayed ${_num(row['delay_days'])?.toStringAsFixed(0) ?? '0'} day(s)',
              subtitle:
                  'Invoice ${_text(row['invoice_number'])}, ack ${_text(row['ack_status'])}',
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final String value;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 8,
              backgroundColor: const Color(0xFFECE6F0),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFB3261E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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

List<(String, double)> _topGroups(
  List<Map<String, dynamic>> rows,
  String labelKey,
  String valueKey,
) {
  final totals = <String, double>{};
  for (final row in rows) {
    final label = _text(row[labelKey]);
    totals[label] =
        (totals[label] ?? 0) + (_num(row[valueKey]) ?? 0).toDouble();
  }
  final list =
      totals.entries.map((e) => (e.key, e.value)).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
  return list.take(8).toList();
}

double _sum(List<Map<String, dynamic>> rows, String key) {
  return rows.fold(0, (sum, row) => sum + ((_num(row[key]) ?? 0).toDouble()));
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

num? _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse((value ?? '').toString());
}

String _text(dynamic value) {
  final text = (value ?? '').toString();
  return text.trim().isEmpty ? 'Unassigned' : text;
}

String _money(num value) {
  if (value.abs() >= 10000000) {
    return '₹${(value / 10000000).toStringAsFixed(2)} Cr';
  }
  if (value.abs() >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(2)} L';
  }
  return '₹${value.toStringAsFixed(0)}';
}
