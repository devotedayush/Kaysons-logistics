import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
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
    final l = AppLocalizations.of(context)!;
    return ResponsiveTabbedShell(
      role: AppRole.logisticsManager,
      title: l.logisticsManager,
      subtitle: l.logisticsSubtitle,
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
      mobileNavigation: CompactMobileNavigation(
        currentIndex: _index,
        onSelect: _goto,
        primaryIndices: const [0, 1, 2],
        destinations: [
          CompactMobileDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: l.home,
          ),
          CompactMobileDestination(
            icon: Icons.gavel_outlined,
            selectedIcon: Icons.gavel,
            label: l.bids,
          ),
          CompactMobileDestination(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping,
            label: l.fleet,
          ),
          CompactMobileDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: l.ledger,
          ),
          CompactMobileDestination(
            icon: Icons.assignment_ind_outlined,
            selectedIcon: Icons.assignment_ind,
            label: l.dispatch,
          ),
        ],
        onProfile: () => context.push('/lm/profile'),
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
          icon: Icon(Icons.gavel_outlined),
          selectedIcon: Icon(Icons.gavel),
          label: Text(l.bids),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text(l.fleet),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text(l.ledger),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_ind_outlined),
          selectedIcon: Icon(Icons.assignment_ind),
          label: Text(l.dispatch),
        ),
      ],
    );
  }
}
