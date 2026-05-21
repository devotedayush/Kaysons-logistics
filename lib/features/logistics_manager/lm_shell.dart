import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';
import '../admin/admin_ledger_body.dart';
import 'lm_bodies.dart';
import 'lm_dispatch_team_body.dart';

class LogisticsShell extends StatefulWidget {
  const LogisticsShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<LogisticsShell> createState() => _LogisticsShellState();
}

class _LogisticsShellState extends State<LogisticsShell> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
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
      title: 'Logistics manager',
      subtitle:
          'Publish freights, monitor open bids, and track live deliveries in a single web workspace.',
      icon: Icons.work_outline,
      currentIndex: _index,
      onDestinationSelected: _goto,
      pageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const ClampingScrollPhysics(),
        children: const [
          LmDashboardBody(),
          LmBidsBody(),
          LmFleetBody(),
          AdminLedgerBody(),
          LmDispatchTeamBody(),
        ],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/lm/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      mobileNavigation: _LmBottomNav(
        currentIndex: _index,
        onTap: _goto,
        onProfile: () => context.push('/lm/profile'),
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
          icon: Icon(Icons.gavel_outlined),
          selectedIcon: Icon(Icons.gavel),
          label: Text('Bids'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text('Fleet'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Ledger'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_ind_outlined),
          selectedIcon: Icon(Icons.assignment_ind),
          label: Text('Dispatch'),
        ),
      ],
    );
  }
}

class _LmBottomNav extends StatelessWidget {
  const _LmBottomNav({
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
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDF7),
        borderRadius: BorderRadius.circular(80),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LmNavItem(
            icon: Icons.dashboard_outlined,
            label: 'Home',
            selected: currentIndex == 0,
            compact: compact,
            onTap: () => onTap(0),
          ),
          _LmNavItem(
            icon: Icons.gavel_outlined,
            label: 'Bids',
            selected: currentIndex == 1,
            compact: compact,
            onTap: () => onTap(1),
          ),
          _LmNavItem(
            icon: Icons.local_shipping_outlined,
            label: 'Fleet',
            selected: currentIndex == 2,
            compact: compact,
            onTap: () => onTap(2),
          ),
          _LmNavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Ledger',
            selected: currentIndex == 3,
            compact: compact,
            onTap: () => onTap(3),
          ),
          _LmNavItem(
            icon: Icons.assignment_ind_outlined,
            label: 'Dispatch',
            selected: currentIndex == 4,
            compact: compact,
            onTap: () => onTap(4),
          ),
          _LmMoreNavItem(
            compact: compact,
            onProfile: onProfile,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _LmNavItem extends StatelessWidget {
  const _LmNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1D1B20) : const Color(0xFF49454F);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 52,
                height: 30,
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFEADDFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LmMoreNavItem extends StatelessWidget {
  const _LmMoreNavItem({
    required this.compact,
    required this.onProfile,
    required this.onLogout,
  });

  final bool compact;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: compact ? 44 : 52,
                height: 30,
                child: const Icon(
                  Icons.account_circle_outlined,
                  size: 21,
                  color: Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'More',
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF49454F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
