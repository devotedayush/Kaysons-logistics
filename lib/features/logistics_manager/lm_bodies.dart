import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

bool _isActiveBid(Map<String, dynamic> freight) {
  if (freight['status'] != 'bidding') return false;
  final closesAt = DateTime.tryParse(
    (freight['bid_closes_at'] ?? '').toString(),
  );
  return closesAt != null && closesAt.isAfter(DateTime.now());
}

// =================== DASHBOARD ===================

class LmDashboardBody extends StatefulWidget {
  const LmDashboardBody({super.key});

  @override
  State<LmDashboardBody> createState() => _LmDashboardBodyState();
}

class _LmDashboardBodyState extends State<LmDashboardBody> {
  String _name = '';
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    try {
      final row =
          await supabase
              .from('profiles')
              .select('full_name, email')
              .eq('id', uid)
              .maybeSingle();
      if (!mounted || row == null) return;
      setState(
        () =>
            _name =
                (row['full_name'] ??
                        (row['email'] as String?)?.split('@').first ??
                        '')
                    .toString(),
      );
    } catch (_) {}
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FreightsRepo.instance.streamAllFreights(),
      builder: (context, snap) {
        final all = snap.data ?? const [];
        final filtered =
            all
                .where(
                  (f) => withinDateWindow(
                    DateTime.tryParse((f['created_at'] ?? '').toString()),
                    rangeDays: _rangeDays,
                    customStart: _customStart,
                    customEnd: _customEnd,
                  ),
                )
                .toList();
        final active = filtered.where(_isActiveBid).toList();
        final won =
            filtered
                .where((f) => ['awarded', 'dispatched'].contains(f['status']))
                .length;
        final locked =
            filtered
                .where((f) => ['locked', 'completed'].contains(f['status']))
                .length;
        final needsVehicleCheck =
            filtered.where((f) {
              final stages = Map<String, dynamic>.from(
                f['delivery_stages'] as Map? ?? const {},
              );
              return stages.containsKey('dispatched') &&
                  !stages.containsKey('vehicle_confirmation');
            }).length;
        final byStatus = <String, int>{};
        final byRoute = <String, double>{};
        for (final row in filtered) {
          final status = (row['status'] ?? 'unknown').toString();
          byStatus[status] = (byStatus[status] ?? 0) + 1;
          final route =
              '${row['origin'] ?? '-'} → ${row['destination_town'] ?? '-'}';
          byRoute[route] =
              (byRoute[route] ?? 0) +
              ((row['weight_kg'] as num?)?.toDouble() ?? 0);
        }

        return Column(
          children: [
            _AppBar(name: _name),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const _Section('Dashboard'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: DateWindowBar(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Kpi(
                            label: 'Active bids',
                            value: '${active.length}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(label: 'In transit', value: '$won'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Kpi(label: 'Locked / done', value: '$locked'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label: 'Vehicle checks',
                            value: '$needsVehicleCheck',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Section('Quick links'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 560;
                        final links = [
                          _QuickLinkData(
                            icon: Icons.add_road_outlined,
                            title: 'Publish bid',
                            subtitle: 'Create freight',
                            onTap: () => context.push('/lm/bid/new'),
                          ),
                          _QuickLinkData(
                            icon: Icons.fact_check_outlined,
                            title: 'Confirm arrivals',
                            subtitle: '$needsVehicleCheck pending',
                            onTap: () => context.push('/lm/fleet'),
                          ),
                          _QuickLinkData(
                            icon: Icons.business_outlined,
                            title: 'Transporters',
                            subtitle: 'View directory',
                            onTap: () => context.push('/lm/profile'),
                          ),
                          _QuickLinkData(
                            icon: Icons.local_shipping_outlined,
                            title: 'Vehicles',
                            subtitle: 'Read-only list',
                            onTap: () => context.push('/lm/profile'),
                          ),
                        ];
                        if (narrow) {
                          return Column(
                            children:
                                links
                                    .map(
                                      (link) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _QuickLink(link: link),
                                      ),
                                    )
                                    .toList(),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              links
                                  .map(
                                    (link) => SizedBox(
                                      width: (constraints.maxWidth - 8) / 2,
                                      child: _QuickLink(link: link),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    ),
                  ),
                  const _Section('Relevant charts'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _MiniChart(
                          title: 'Freights by status',
                          values: byStatus,
                        ),
                        const SizedBox(height: 8),
                        _MiniChart(
                          title: 'Route weight',
                          values: byRoute.map(
                            (key, value) =>
                                MapEntry(key, value.round().clamp(0, 999999)),
                          ),
                          unit: ' Ton',
                        ),
                      ],
                    ),
                  ),
                  const _Section('Latest Bids'),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
                        'No active bids right now.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    )
                  else
                    ...active.take(3).map((f) {
                      final v = freightView(f);
                      return _BidPreview(
                        route: v['route'] as String,
                        summary: '${v['cases']} Cases · ${v['weight_kg']} Ton',
                        minsLeft: v['minsLeft'] as int,
                        date: v['created'] as DateTime?,
                        onTap: () => context.push('/lm/bid/${v['id']}'),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// =================== BIDS ===================

class LmBidsBody extends StatefulWidget {
  const LmBidsBody({super.key});

  @override
  State<LmBidsBody> createState() => _LmBidsBodyState();
}

class _LmBidsBodyState extends State<LmBidsBody> {
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lm/bid/new'),
        icon: const Icon(Icons.add),
        label: const Text('Publish bid'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All bids',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: _onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DateWindowBar(
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
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FreightsRepo.instance.streamOperationalFreights(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final freights =
                    snap.data!
                        .where(
                          (row) => withinDateWindow(
                            DateTime.tryParse(
                              (row['created_at'] ?? '').toString(),
                            ),
                            rangeDays: _rangeDays,
                            customStart: _customStart,
                            customEnd: _customEnd,
                          ),
                        )
                        .toList();
                final active = freights.where(_isActiveBid).toList();
                final past = freights.where((f) => !_isActiveBid(f)).toList();
                if (freights.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No bids found for this date window.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: active.length + past.length + 2,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _ListHeader('Active bids (${active.length})');
                    }
                    if (i == active.length + 1) {
                      return _ListHeader('Past bids (${past.length})');
                    }
                    final row =
                        i <= active.length
                            ? active[i - 1]
                            : past[i - active.length - 2];
                    final v = freightView(row);
                    return _FreightTile(
                      route: v['route'] as String,
                      summary: '${v['cases']} Cases · ${v['weight_kg']} Ton',
                      status: v['status'] as String,
                      minsLeft: v['minsLeft'] as int,
                      date: v['created'] as DateTime?,
                      onTap: () => context.push('/lm/bid/${v['id']}'),
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

// =================== FLEET ===================

class LmFleetBody extends StatelessWidget {
  const LmFleetBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Fleet — deliveries',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FreightsRepo.instance.streamOperationalFreights(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final active =
                  snap.data!
                      .where(
                        (f) => [
                          'awarded',
                          'dispatched',
                          'locked',
                          'completed',
                        ].contains(f['status']),
                      )
                      .toList();
              if (active.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No awarded freights yet.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: active.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _FleetTile(freight: active[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FleetTile extends StatelessWidget {
  const _FleetTile({required this.freight});
  final Map<String, dynamic> freight;

  @override
  Widget build(BuildContext context) {
    final stages = Map<String, dynamic>.from(
      freight['delivery_stages'] as Map? ?? {},
    );
    final steps = ['dispatched', 'pickup', 'in_transit', 'delivered'];
    final done = steps.where(stages.containsKey).length;

    return InkWell(
      onTap: () => context.push('/lm/track/${freight['id']}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EDFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${freight['origin']} → ${freight['destination_town']}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${freight['cases'] ?? 0} Cases · ${freight['weight_kg'] ?? 0} Ton · ${(freight['status'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _StepDot(label: _stepLabel(steps[i]), done: i < done),
                  if (i != steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color:
                            i < done - 1
                                ? const Color(0xFF14A33A)
                                : const Color(0xFFCAC4D0),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _stepLabel(String k) {
    switch (k) {
      case 'dispatched':
        return 'Disp.';
      case 'pickup':
        return 'Pickup';
      case 'in_transit':
        return 'Transit';
      case 'delivered':
        return 'Deliv.';
      default:
        return k;
    }
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF14A33A) : Colors.white,
            border: Border.all(
              color: done ? const Color(0xFF14A33A) : const Color(0xFFCAC4D0),
              width: 1.5,
            ),
            shape: BoxShape.circle,
          ),
          child:
              done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
        ),
      ],
    );
  }
}

// =================== SHARED WIDGETS ===================

class _AppBar extends StatelessWidget {
  const _AppBar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: _onSurface),
            onPressed: () => context.push('/lm/profile'),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name.isEmpty ? 'Welcome' : 'Welcome, $name',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined, color: _onSurface),
            onPressed: () => context.push('/lm/notifications'),
          ),
        ],
      ),
    );
  }
}

class _QuickLinkData {
  const _QuickLinkData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.link});
  final _QuickLinkData link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: link.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4DCEB)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(link.icon, color: const Color(0xFF6750A4)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                    ),
                  ),
                  Text(
                    link.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.title, required this.values, this.unit = ''});

  final String title;
  final Map<String, int> values;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final entries =
        values.entries.where((e) => e.value > 0).take(5).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final max =
        entries.isEmpty
            ? 1
            : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4DCEB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'No data in this date window.',
              style: TextStyle(fontSize: 12, color: _onSurfaceVariant),
            )
          else
            ...entries.map((entry) {
              final factor = entry.value / max;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${entry.value}$unit',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: factor,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFECE6F0),
                        color: const Color(0xFF6750A4),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: _onSurface,
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECE6F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BidPreview extends StatelessWidget {
  const _BidPreview({
    required this.route,
    required this.summary,
    required this.minsLeft,
    required this.date,
    required this.onTap,
  });
  final String route;
  final String summary;
  final int minsLeft;
  final DateTime? date;
  final VoidCallback onTap;

  String get _label {
    if (minsLeft <= 0) return 'Closed';
    if (minsLeft >= 60) return '${minsLeft ~/ 60} hr ${minsLeft % 60} min left';
    return '$minsLeft min left';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = minsLeft > 0 && minsLeft < 30;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BidDateLabel(date: date),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EDFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 24,
                      color: Color(0xFFB39DC8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _label,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                urgent
                                    ? const Color(0xFFB3261E)
                                    : _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _onSurface),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreightTile extends StatelessWidget {
  const _FreightTile({
    required this.route,
    required this.summary,
    required this.status,
    required this.minsLeft,
    required this.date,
    required this.onTap,
  });
  final String route;
  final String summary;
  final String status;
  final int minsLeft;
  final DateTime? date;
  final VoidCallback onTap;

  String get _statusLabel {
    if (status == 'completed') return 'Status: Completed';
    if (status == 'bidding' && minsLeft > 0) return 'Status: Open';
    return 'Status: Closed';
  }

  Color get _badgeColor {
    switch (status) {
      case 'bidding':
        return const Color(0xFFF6EDFB);
      case 'awarded':
      case 'dispatched':
        return const Color(0xFFE1F5E1);
      case 'locked':
      case 'completed':
        return const Color(0xFFECE6F0);
      default:
        return const Color(0xFFF3F3F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BidDateLabel(date: date),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: Color(0xFFB39DC8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _onSurface,
                        ),
                      ),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _onSurface),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
