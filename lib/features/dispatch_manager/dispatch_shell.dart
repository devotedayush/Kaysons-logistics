import '../logistics_manager/widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/widgets/logistics_artwork.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/freights_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';

const _onSurface = Color(0xFF1D1B20);
const _onSurfaceVariant = Color(0xFF49454F);

class DispatchShell extends StatefulWidget {
  const DispatchShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<DispatchShell> createState() => _DispatchShellState();
}

class _DispatchShellState extends State<DispatchShell> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 1);
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _goto(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pc.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ResponsiveTabbedShell(
      role: AppRole.dispatchManager,
      title: l.dispatchManager,
      subtitle: l.dispatchSubtitle,
      icon: Icons.assignment_turned_in_outlined,
      currentIndex: _index,
      onDestinationSelected: _goto,
      pageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const ClampingScrollPhysics(),
        children: const [DispatchDashboardBody(), DispatchFleetBody()],
      ),
      mobilePageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const NeverScrollableScrollPhysics(),
        children: const [DispatchDashboardBody(), DispatchFleetBody()],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/dm/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      mobileNavigation: CompactMobileNavigation(
        currentIndex: _index,
        onSelect: _goto,
        primaryIndices: const [0, 1],
        destinations: [
          CompactMobileDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: l.today,
          ),
          CompactMobileDestination(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: l.deliveries,
          ),
        ],
        onProfile: () => context.push('/dm/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      destinations: [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text(l.dashboard),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text(l.fleet),
        ),
      ],
    );
  }
}

class DispatchDashboardBody extends StatefulWidget {
  const DispatchDashboardBody({super.key});

  @override
  State<DispatchDashboardBody> createState() => _DispatchDashboardBodyState();
}

class _DispatchDashboardBodyState extends State<DispatchDashboardBody> {
  String _name = '';
  String _manager = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
    try {
      final row =
          await supabase
              .from('profiles')
              .select('full_name, email, manager_id')
              .eq('id', uid)
              .maybeSingle();
      if (row == null) return;
      final managerId = row['manager_id'] as String?;
      String managerLabel = '';
      if (managerId != null) {
        final managerRow =
            await supabase
                .from('profiles')
                .select('full_name, email')
                .eq('id', managerId)
                .maybeSingle();
        managerLabel =
            (managerRow?['full_name'] ?? managerRow?['email'] ?? '').toString();
      }
      if (!mounted) return;
      setState(() {
        _name =
            (row['full_name'] ?? (row['email'] as String?)?.split('@').first)
                .toString();
        _manager = managerLabel;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FreightsRepo.instance.streamAcceptedDispatchFreights(),
      builder: (context, snap) {
        final compact = MediaQuery.sizeOf(context).width < 600;
        final freights = snap.data ?? const [];
        final vehicleChecks =
            freights.where((f) {
              final stages = Map<String, dynamic>.from(
                f['delivery_stages'] as Map? ?? const {},
              );
              return stages.containsKey('dispatched') &&
                  !stages.containsKey('vehicle_confirmation');
            }).length;
        final inTransit =
            freights.where((f) => f['status'] == 'dispatched').length;
        final completed =
            freights
                .where((f) => ['locked', 'completed'].contains(f['status']))
                .length;

        return Column(
          children: [
            _DispatchHeader(name: _name, manager: _manager),
            Expanded(
              child: OperationalListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      compact ? 0 : 12,
                      0,
                      compact ? 8 : 0,
                    ),
                    child: Text(
                      '${operationalCopy(context, 'Today', 'आज')} · ${DateTime.now().toLocal().toIso8601String().substring(0, 10)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (compact)
                    _DispatchAttention(count: vehicleChecks)
                  else
                    WorkspaceHeader(
                      title: operationalCopy(
                        context,
                        'Your dispatch checklist',
                        'आपकी डिस्पैच जाँच सूची',
                      ),
                      description: operationalCopy(
                        context,
                        'Check arriving trucks, follow active routes and report delivery issues to your manager.',
                        'आए ट्रक जाँचें, जारी यात्रा देखें और डिलीवरी की समस्या मैनेजर को बताएँ।',
                      ),
                      icon: Icons.fact_check_outlined,
                      summary: GuidanceCard(
                        title: operationalCopy(
                          context,
                          '$vehicleChecks vehicle checks waiting',
                          '$vehicleChecks वाहन जाँच बाकी',
                        ),
                        message: operationalCopy(
                          context,
                          'Open an assigned delivery to confirm the truck and driver details.',
                          'ट्रक और ड्राइवर की पुष्टि करने के लिए सौंपा गया ट्रिप खोलें।',
                        ),
                        tone:
                            vehicleChecks > 0
                                ? WorkspaceTone.warning
                                : WorkspaceTone.success,
                      ),
                    ),
                  if (!compact) const _Section('Dashboard'),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Kpi(
                            label: 'Accepted deliveries',
                            value: '${freights.length}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label: 'Vehicle checks',
                            value: '$vehicleChecks',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Kpi(label: 'In transit', value: '$inTransit'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label: 'Locked / completed',
                            value: '$completed',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Section('Needs attention'),
                  if (freights.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 0 : 16,
                        8,
                        compact ? 0 : 16,
                        16,
                      ),
                      child: const Text(
                        'No deliveries match the selected filters.',
                        style: TextStyle(color: _onSurfaceVariant),
                      ),
                    )
                  else
                    ...freights
                        .where((f) {
                          final stages = Map<String, dynamic>.from(
                            f['delivery_stages'] as Map? ?? const {},
                          );
                          return !stages.containsKey('vehicle_confirmation') ||
                              f['status'] == 'dispatched';
                        })
                        .take(5)
                        .map((f) => _DeliveryTile(freight: f)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class DispatchFleetBody extends StatefulWidget {
  const DispatchFleetBody({super.key});

  @override
  State<DispatchFleetBody> createState() => _DispatchFleetBodyState();
}

class _DispatchFleetBodyState extends State<DispatchFleetBody> {
  String _query = '';
  DateTimeRange? _dateRange;
  bool _pendingPodOnly = false;

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final filters = <Widget>[
      OutlinedButton.icon(
        onPressed: _pickDates,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        icon: const Icon(Icons.date_range),
        label: Text(
          _dateRange == null
              ? operationalCopy(context, 'All dates', 'सभी तारीखें')
              : '${_dateRange!.start.toIso8601String().substring(0, 10)} — ${_dateRange!.end.toIso8601String().substring(0, 10)}',
        ),
      ),
      if (_dateRange != null)
        TextButton(
          onPressed: () => setState(() => _dateRange = null),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: Text(operationalCopy(context, 'Clear dates', 'तारीख हटाएँ')),
        ),
      FilterChip(
        label: Text(operationalCopy(context, 'POD pending', 'POD बाकी')),
        selected: _pendingPodOnly,
        onSelected: (value) => setState(() => _pendingPodOnly = value),
      ),
    ];
    return Column(
      children: [
        _DispatchPageHeading(
          title: operationalCopy(
            context,
            'Your assigned deliveries',
            'आपको सौंपे गए ट्रिप',
          ),
          description: operationalCopy(
            context,
            'Filter by date or missing proof, then open a route to complete your checks.',
            'तारीख या बाकी प्रमाण से छाँटें और जाँच पूरी करने के लिए मार्ग खोलें।',
          ),
          icon: Icons.route_outlined,
        ),
        if (compact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < filters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  filters[i],
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 4, children: filters),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            8,
            compact ? 12 : 16,
            8,
          ),
          child: TextField(
            onChanged:
                (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              labelText: operationalCopy(
                context,
                'Search assigned route or truck',
                'सौंपा गया मार्ग या ट्रक खोजें',
              ),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FreightsRepo.instance.streamAcceptedDispatchFreights(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final freights =
                  snap.data!.where((f) {
                    if (_query.isNotEmpty &&
                        !"${f['origin']} ${f['destination_town']} ${f['vehicle_number']}"
                            .toLowerCase()
                            .contains(_query)) {
                      return false;
                    }
                    if (_pendingPodOnly && _hasReceivedPod(f)) return false;
                    if (_dateRange == null) return true;
                    final date = DateTime.tryParse(
                      (f['dispatch_date'] ??
                              f['dispatched_at'] ??
                              f['created_at'] ??
                              '')
                          .toString(),
                    );
                    if (date == null) return false;
                    final day = DateUtils.dateOnly(date.toLocal());
                    return !day.isBefore(_dateRange!.start) &&
                        !day.isAfter(_dateRange!.end);
                  }).toList();
              if (freights.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 16 : 32),
                    child: const Text(
                      'No deliveries match the selected filters.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  8,
                  compact ? 12 : 16,
                  16,
                ),
                itemCount: freights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _DeliveryTile(freight: freights[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.freight});
  final Map<String, dynamic> freight;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final stages = Map<String, dynamic>.from(
      freight['delivery_stages'] as Map? ?? const {},
    );
    final vehicleStatus =
        (stages['vehicle_confirmation'] as Map?)?['status']?.toString() ??
        'pending';
    final route = '${freight['origin']} → ${freight['destination_town']}';

    return InkWell(
      onTap: () => context.push('/dm/track/${freight['id']}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route,
                    style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w500,
                      color: _onSurface,
                    ),
                  ),
                ),
                if (compact)
                  const Icon(Icons.chevron_right, color: _onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${freight['cases'] ?? 0} Cases · ${freight['weight_kg'] ?? 0} MT · ${(freight['status'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            SizedBox(height: compact ? 8 : 12),
            if (!compact) ...[
              Text(
                operationalCopy(
                  context,
                  'Open truck checks and delivery details →',
                  'ट्रक जाँच और डिलीवरी विवरण खोलें →',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 4 : 8,
              children: [
                _StatusChip(
                  icon: Icons.fact_check_outlined,
                  label: operationalCopy(
                    context,
                    'Vehicle $vehicleStatus',
                    'वाहन $vehicleStatus',
                  ),
                ),
                _StatusChip(
                  icon: Icons.receipt_long_outlined,
                  label:
                      _hasReceivedPod(freight)
                          ? operationalCopy(context, 'POD received', 'POD मिला')
                          : operationalCopy(context, 'POD pending', 'POD बाकी'),
                ),
                if ((stages['in_transit'] as Map?)?['last_location'] != null)
                  _StatusChip(
                    icon: Icons.location_on_outlined,
                    label:
                        (stages['in_transit'] as Map)['last_location']
                            .toString(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchAttention extends StatelessWidget {
  const _DispatchAttention({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = count > 0 ? const Color(0xFF86530D) : const Color(0xFF146C4B);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.fact_check_outlined : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              operationalCopy(
                context,
                count > 0
                    ? '$count vehicle checks waiting'
                    : 'All vehicle checks complete',
                count > 0 ? '$count वाहनों की जाँच बाकी' : 'सभी वाहन जाँच पूरी',
              ),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchPageHeading extends StatelessWidget {
  const _DispatchPageHeading({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: WorkspaceHeader(
          title: title,
          description: description,
          icon: icon,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchHeader extends StatelessWidget {
  const _DispatchHeader({required this.name, required this.manager});
  final String name;
  final String manager;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: manager.isEmpty ? 44 : 54),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Welcome' : 'Welcome, $name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (manager.isNotEmpty)
                  Text(
                    '${operationalCopy(context, 'Reporting to', 'रिपोर्टिंग मैनेजर')}: $manager',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: LogisticsArtwork(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.person_outline, color: _onSurface),
                onPressed: () => context.push('/dm/profile'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Welcome' : 'Welcome, $name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: _onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (manager.isNotEmpty)
                      Text(
                        'Reporting to $manager',
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
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 0 : 16,
        compact ? 12 : 20,
        compact ? 0 : 16,
        compact ? 6 : 8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: compact ? 16 : 18,
          fontWeight: FontWeight.w700,
          color: _onSurface,
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4DCEB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

// Kept temporarily for backwards-compatible visual snapshots.
// ignore: unused_element
class _DispatchBottomNav extends StatelessWidget {
  const _DispatchBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onProfile,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDF7),
        borderRadius: BorderRadius.circular(80),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: l.dashboard,
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.local_shipping_outlined,
            label: l.fleet,
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: 'Profile and logout',
              onSelected: (value) async {
                if (value == 'profile') onProfile();
                if (value == 'logout') await onLogout();
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18),
                          SizedBox(width: 10),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 10),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 32,
                      child: Icon(
                        Icons.account_circle_outlined,
                        size: 22,
                        color: Color(0xFF49454F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF49454F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(48),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFFE8DEF8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color:
                        selected
                            ? const Color(0xFF1D192B)
                            : const Color(0xFF49454F),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      selected
                          ? const Color(0xFF1D192B)
                          : const Color(0xFF49454F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Delivery completion alone is not evidence that proof was received.
bool _hasReceivedPod(Map<String, dynamic> freight) {
  if (freight['record_origin'] == 'historical_import') {
    return freight['ack_status'] == 'received';
  }
  final stages = freight['delivery_stages'] as Map?;
  final delivered = stages?['delivered'] as Map?;
  final path =
      (freight['pod_file_path'] ?? delivered?['pod_photo_path'] ?? '')
          .toString()
          .trim();
  return path.isNotEmpty ||
      (freight['ack_status'] == 'received' &&
          freight['pod_received_by'] != null &&
          freight['pod_received_date'] != null);
}
