import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';
import '../transporter/widgets/transporter_bottom_nav.dart';
import 'lm_bodies.dart';

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
    _index = widget.initialIndex.clamp(0, 2);
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
        children: const [LmDashboardBody(), LmBidsBody(), LmFleetBody()],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/lm/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      mobileNavigation: TransporterBottomNav(
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
      ],
    );
  }
}
