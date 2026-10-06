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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Today — ${DateTime.now().toLocal().toIso8601String().substring(0, 10)}',
                      style: const TextStyle(color: _onSurfaceVariant),
                    ),
                  ),
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
                  const _Section('Dashboard'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: WorkspaceHeader(
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDates,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _dateRange == null
                      ? 'All dates'
                      : '${_dateRange!.start.toIso8601String().substring(0, 10)} — ${_dateRange!.end.toIso8601String().substring(0, 10)}',
                ),
              ),
              if (_dateRange != null)
                TextButton(
                  onPressed: () => setState(() => _dateRange = null),
                  child: const Text('Clear dates'),
                ),
              FilterChip(
                label: const Text('POD pending'),
                selected: _pendingPodOnly,
                onSelected: (value) => setState(() => _pendingPodOnly = value),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No deliveries match the selected filters.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: _onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${freight['cases'] ?? 0} Cases · ${freight['weight_kg'] ?? 0} MT · ${(freight['status'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              operationalCopy(
                context,
                'Open truck checks and delivery details →',
                'ट्रक जाँच और डिलीवरी विवरण खोलें →',
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: Icons.fact_check_outlined,
                  label: 'Vehicle $vehicleStatus',
                ),
                _StatusChip(
                  icon: Icons.receipt_long_outlined,
                  label:
                      _hasReceivedPod(freight) ? 'POD received' : 'POD pending',
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

class _DispatchHeader extends StatelessWidget {
  const _DispatchHeader({required this.name, required this.manager});
  final String name;
  final String manager;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
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
    return Container(
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
            label,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
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
