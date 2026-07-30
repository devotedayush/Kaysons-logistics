import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/mobile_desktop_feature.dart';
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
      mobilePageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          LmDashboardBody(),
          LmBidsBody(),
          LmFleetBody(),
          MobileDesktopFeature(
            icon: Icons.receipt_long_outlined,
            title: 'Detailed ledger is on the web',
            description:
                'On mobile, stay focused on publishing loads, awarding bids, and tracking deliveries.',
            desktopFeatures: [
              'Invoice and POD reconciliation',
              'Multi-field filters and bulk ledger entry',
              'Monthly, route, and transporter reports',
            ],
          ),
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
      mobileNavigation: CompactMobileNavigation(
        currentIndex: _index,
        onSelect: _goto,
        primaryIndices: const [0, 1, 2],
        destinations: const [
          CompactMobileDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Home',
          ),
          CompactMobileDestination(
            icon: Icons.gavel_outlined,
            selectedIcon: Icons.gavel,
            label: 'Bids',
          ),
          CompactMobileDestination(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: 'Fleet',
          ),
          CompactMobileDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Ledger',
          ),
          CompactMobileDestination(
            icon: Icons.assignment_ind_outlined,
            selectedIcon: Icons.assignment_ind,
            label: 'Dispatch',
          ),
        ],
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
