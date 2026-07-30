import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return ResponsiveTabbedShell(
      title: 'Dispatch manager',
      subtitle:
          'Track accepted deliveries, verify arrivals, and keep movement details current.',
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
        destinations: const [
          CompactMobileDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Today',
          ),
          CompactMobileDestination(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: 'Deliveries',
          ),
        ],
        onProfile: () => context.push('/dm/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text('Fleet'),
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
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
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
                            label: 'Locked / done',
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
                        'No accepted deliveries assigned yet.',
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

class DispatchFleetBody extends StatelessWidget {
  const DispatchFleetBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Accepted deliveries',
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
            stream: FreightsRepo.instance.streamAcceptedDispatchFreights(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final freights = snap.data!;
              if (freights.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No accepted deliveries assigned yet.',
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
          color: const Color(0xFFF6EDFB),
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
              '${freight['cases'] ?? 0} Cases · ${freight['weight_kg'] ?? 0} Ton · ${(freight['status'] ?? '').toString().toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: Icons.fact_check_outlined,
                  label: 'Vehicle $vehicleStatus',
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
            label: 'Dashboard',
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.local_shipping_outlined,
            label: 'Fleet',
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
