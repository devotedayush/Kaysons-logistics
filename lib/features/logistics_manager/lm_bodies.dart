import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/widgets/logistics_artwork.dart';
import 'dart:async';

import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/utils/bid_window.dart';
import '../../core/widgets/bid_window_countdown.dart';
import '../../core/widgets/bid_date_label.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

bool _isActiveBid(Map<String, dynamic> freight) {
  return bidWindowPhase(
        status: (freight['status'] ?? '').toString(),
        opensAt: bidTimestamp(freight['bid_opens_at']),
        closesAt: bidTimestamp(freight['bid_closes_at']),
      ) ==
      BidWindowPhase.live;
}

bool _isBiddingOrUpcoming(Map<String, dynamic> freight) {
  if (freight['status'] != 'bidding') return false;
  final closesAt = bidTimestamp(freight['bid_closes_at']);
  return closesAt == null || closesAt.isAfter(DateTime.now());
}

// =================== DASHBOARD ===================

class LmDashboardBody extends StatefulWidget {
  const LmDashboardBody({super.key});

  @override
  State<LmDashboardBody> createState() => _LmDashboardBodyState();
}

class _LmDashboardBodyState extends State<LmDashboardBody> {
  String _name = '';
  late final Stream<List<Map<String, dynamic>>> _freightsStream;
  late final Timer _clock;
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _freightsStream = FreightsRepo.instance.streamAllFreights();
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
    _loadName();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
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
      stream: _freightsStream,
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
              child: OperationalListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  WorkspaceHeader(
                    title: operationalCopy(
                      context,
                      'Plan today’s transport',
                      'आज का परिवहन तय करें',
                    ),
                    description: operationalCopy(
                      context,
                      'Start a request, compare quotes and check the vehicles that need attention.',
                      'अनुरोध बनाएँ, बोलियों की तुलना करें और ज़रूरी वाहन जाँच पूरी करें।',
                    ),
                    icon: Icons.dashboard_outlined,
                    summary: GuidanceCard(
                      title: operationalCopy(
                        context,
                        '$needsVehicleCheck vehicles need checking',
                        '$needsVehicleCheck वाहनों की जाँच बाकी',
                      ),
                      message: operationalCopy(
                        context,
                        'Check the arriving vehicle and driver before approving the next delivery step.',
                        'अगला डिलीवरी चरण स्वीकार करने से पहले आए वाहन और ड्राइवर की जाँच करें।',
                      ),
                      tone:
                          needsVehicleCheck > 0
                              ? WorkspaceTone.warning
                              : WorkspaceTone.success,
                    ),
                  ),
                  _Section(AppLocalizations.of(context)!.uiQuickLinks),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 680;
                        final links = [
                          _QuickLinkData(
                            icon: Icons.add_road_outlined,
                            title: AppLocalizations.of(context)!.opsPublishBid,
                            subtitle:
                                AppLocalizations.of(context)!.opsNewRequirement,
                            prominent: true,
                            onTap: () => context.push('/lm/bid/new'),
                          ),
                          _QuickLinkData(
                            icon: Icons.fact_check_outlined,
                            title:
                                AppLocalizations.of(
                                  context,
                                )!.opsConfirmVehicleArrived,
                            subtitle:
                                '${AppLocalizations.of(context)!.opsVehicleChecks}: $needsVehicleCheck',
                            prominent: true,
                            onTap: () => context.push('/lm/fleet'),
                          ),
                          _QuickLinkData(
                            icon: Icons.business_outlined,
                            title:
                                AppLocalizations.of(context)!.opsTransporters,
                            subtitle:
                                AppLocalizations.of(context)!.uiViewDirectory,
                            onTap: () => context.push('/lm/transporters'),
                          ),
                          _QuickLinkData(
                            icon: Icons.local_shipping_outlined,
                            title: AppLocalizations.of(context)!.opsVehicles,
                            subtitle:
                                AppLocalizations.of(context)!.uiReadOnlyList,
                            onTap: () => context.push('/lm/vehicles'),
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
                            label: AppLocalizations.of(context)!.opsActiveBids,
                            value: '${active.length}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label: AppLocalizations.of(context)!.opsInTransit,
                            value: '$won',
                          ),
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
                          child: _Kpi(
                            label: AppLocalizations.of(context)!.opsLockedDone,
                            value: '$locked',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label:
                                AppLocalizations.of(context)!.opsVehicleChecks,
                            value: '$needsVehicleCheck',
                          ),
                        ),
                      ],
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
                          unit: ' MT',
                        ),
                      ],
                    ),
                  ),
                  const _Section('Latest Bids'),
                  if (active.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
                        AppLocalizations.of(context)!.opsNoActiveBids,
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    )
                  else
                    ...active.take(3).map((f) {
                      final v = freightView(f);
                      return _BidPreview(
                        route: v['route'] as String,
                        summary:
                            '${v['cases']} Cases · ${formatMetricTons(v['weight_kg'])} MT',
                        minsLeft: v['minsLeft'] as int,
                        opensAt: v['opens'] as DateTime?,
                        closesAt: v['closes'] as DateTime?,
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
  late final Stream<List<Map<String, dynamic>>> _freightsStream;
  late final Timer _clock;
  String _query = '';
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _freightsStream = FreightsRepo.instance.streamOperationalFreights();
    _clock = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lm/bid/new'),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.opsPublishBid),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: WorkspaceHeader(
              title: operationalCopy(
                context,
                'Transport requests',
                'परिवहन अनुरोध',
              ),
              description: operationalCopy(
                context,
                'Find a route, compare live quotes or open the awarded trip.',
                'मार्ग खोजें, जारी बोलियाँ देखें या सौंपे गए ट्रिप खोलें।',
              ),
              icon: Icons.assignment_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged:
                  (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                labelText: operationalCopy(
                  context,
                  'Search pickup, destination or truck',
                  'पिकअप, गंतव्य या ट्रक खोजें',
                ),
                prefixIcon: const Icon(Icons.search),
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
              stream: _freightsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return WorkspaceEmptyState(
                    title: operationalCopy(
                      context,
                      'Requests could not load',
                      'अनुरोध लोड नहीं हुए',
                    ),
                    message: operationalCopy(
                      context,
                      'Check your connection and open this page again.',
                      'कनेक्शन जाँचें और यह पेज फिर खोलें।',
                    ),
                    icon: Icons.wifi_off,
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final freights =
                    snap.data!
                        .where(
                          (row) =>
                              _query.isEmpty ||
                              "${row['origin']} ${row['destination_town']} ${row['vehicle_number']}"
                                  .toLowerCase()
                                  .contains(_query),
                        )
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
                final active = freights.where(_isBiddingOrUpcoming).toList();
                final past =
                    freights.where((f) => !_isBiddingOrUpcoming(f)).toList();
                if (freights.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        AppLocalizations.of(context)!.opsNoBidsDate,
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
                      return _ListHeader(
                        'Live & upcoming bids (${active.length})',
                      );
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
                      summary:
                          '${v['cases']} Cases · ${formatMetricTons(v['weight_kg'])} MT',
                      status: v['status'] as String,
                      minsLeft: v['minsLeft'] as int,
                      opensAt: v['opens'] as DateTime?,
                      closesAt: v['closes'] as DateTime?,
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

class LmFleetBody extends StatefulWidget {
  const LmFleetBody({super.key});
  @override
  State<LmFleetBody> createState() => _LmFleetBodyState();
}

class _LmFleetBodyState extends State<LmFleetBody> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: WorkspaceHeader(
            title: operationalCopy(
              context,
              'Follow your deliveries',
              'अपनी डिलीवरी देखें',
            ),
            description: operationalCopy(
              context,
              'Open a route to check the truck, review customer proof and resolve missing details.',
              'ट्रक जाँचने, ग्राहक प्रमाण देखने और अधूरे विवरण ठीक करने के लिए मार्ग खोलें।',
            ),
            icon: Icons.local_shipping_outlined,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            onChanged:
                (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              labelText: operationalCopy(
                context,
                'Search route or truck',
                'मार्ग या ट्रक खोजें',
              ),
              prefixIcon: const Icon(Icons.search),
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
                        (row) =>
                            _query.isEmpty ||
                            "${row['origin']} ${row['destination_town']} ${row['vehicle_number']}"
                                .toLowerCase()
                                .contains(_query),
                      )
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
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      AppLocalizations.of(context)!.opsNoAwardedFreights,
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
          color: const Color(0xFFF3F5FA),
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
              '${freight['cases'] ?? 0} Cases · ${formatMetricTons(freight['weight_kg'])} MT',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            StatusBadge(
              label:
                  freight['ack_status'] == 'received'
                      ? operationalCopy(
                        context,
                        'Delivery proof accepted',
                        'डिलीवरी प्रमाण स्वीकृत',
                      )
                      : operationalCopy(
                        context,
                        'Customer proof needs review',
                        'ग्राहक प्रमाण की जाँच बाकी',
                      ),
              tone:
                  freight['ack_status'] == 'received'
                      ? WorkspaceTone.success
                      : WorkspaceTone.warning,
            ),
            const SizedBox(height: 12),
            Text(
              operationalCopy(
                context,
                'Open delivery details →',
                'डिलीवरी विवरण खोलें →',
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
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
        return 'Dispatch';
      case 'pickup':
        return 'Pickup';
      case 'in_transit':
        return 'Transit';
      case 'delivered':
        return 'Delivery';
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
      child: LogisticsArtwork(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                tooltip: AppLocalizations.of(context)!.opsNotifications,
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: _onSurface,
                ),
                onPressed: () => context.push('/lm/notifications'),
              ),
            ],
          ),
        ),
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
    this.prominent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool prominent;
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
        padding: EdgeInsets.all(link.prominent ? 16 : 12),
        decoration: BoxDecoration(
          color: link.prominent ? const Color(0xFFF2EAFA) : Colors.white,
          border: Border.all(
            color:
                link.prominent
                    ? const Color(0xFFBDA7DB)
                    : const Color(0xFFE4DCEB),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    link.prominent
                        ? const Color(0xFFE4D4F5)
                        : const Color(0xFFF3F5FA),
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
                    style: TextStyle(
                      fontSize: link.prominent ? 16 : 14,
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
            Text(
              AppLocalizations.of(context)!.opsNoDataDate,
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
    required this.opensAt,
    required this.closesAt,
    required this.date,
    required this.onTap,
  });
  final String route;
  final String summary;
  final int minsLeft;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? date;
  final VoidCallback onTap;

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
                color: const Color(0xFFF3F5FA),
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
                        BidWindowCountdown(
                          status: 'bidding',
                          opensAt: opensAt,
                          closesAt: closesAt,
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
    required this.opensAt,
    required this.closesAt,
    required this.date,
    required this.onTap,
  });
  final String route;
  final String summary;
  final String status;
  final int minsLeft;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? date;
  final VoidCallback onTap;

  String get _statusLabel {
    if (status == 'completed') return 'Status: Completed';
    switch (status) {
      case 'bidding':
        return 'Status: Expired';
      case 'awarded':
        return 'Status: Awarded';
      case 'dispatched':
        return 'Status: Dispatched';
      case 'locked':
        return 'Status: Locked';
      default:
        return 'Status: Closed';
    }
  }

  Color get _badgeColor {
    switch (status) {
      case 'bidding':
        return const Color(0xFFF3F5FA);
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
                      if (status == 'bidding')
                        BidWindowCountdown(
                          status: status,
                          opensAt: opensAt,
                          closesAt: closesAt,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _onSurfaceVariant,
                          ),
                        )
                      else
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
