import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/role_nav_config.dart';
import '../../core/widgets/shell_settings_button.dart';
import 'bids_screen.dart';
import 'fleet_screen.dart';
import 'home_screen.dart';

class TransporterShell extends StatefulWidget {
  const TransporterShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TransporterShell> createState() => _TransporterShellState();
}

class _TransporterShellState extends State<TransporterShell> {
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
    final l = AppLocalizations.of(context)!;
    return ResponsiveTabbedShell(
      role: AppRole.transporter,
      title: l.transporter,
      subtitle: l.transporterSubtitle,
      icon: Icons.local_shipping_outlined,
      currentIndex: _index,
      onDestinationSelected: _goto,
      pageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const ClampingScrollPhysics(),
        children: const [TransporterHomeBody(), BidsBody(), FleetBody()],
      ),
      mobilePageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const NeverScrollableScrollPhysics(),
        children: const [TransporterHomeBody(), BidsBody(), FleetBody()],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/profile'),
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
            label: RoleNavConfig.forRole(AppRole.transporter, l).items[2].label,
          ),
        ],
        onProfile: () => context.push('/profile'),
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
          label: Text(
            RoleNavConfig.forRole(AppRole.transporter, l).items[2].label,
          ),
        ),
      ],
    );
  }
}
