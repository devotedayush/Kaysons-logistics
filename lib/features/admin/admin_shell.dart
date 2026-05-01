import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';
import 'admin_ai_body.dart';
import 'admin_bids_body.dart';
import 'admin_bottom_nav.dart';
import 'admin_dashboard_body.dart';
import 'admin_users_body.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
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
      title: 'Admin console',
      subtitle:
          'Review users, oversee freight activity, and keep the network healthy from the browser.',
      icon: Icons.admin_panel_settings_outlined,
      currentIndex: _index,
      onDestinationSelected: _goto,
      pageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const ClampingScrollPhysics(),
        children: const [
          AdminDashboardBody(),
          AdminUsersBody(),
          AdminBidsBody(),
          AdminAiBody(),
        ],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/admin/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      mobileNavigation: AdminBottomNav(
        currentIndex: _index,
        onTap: _goto,
        onProfile: () => context.push('/admin/profile'),
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
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Users'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.gavel_outlined),
          selectedIcon: Icon(Icons.gavel),
          label: Text('Bids'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.psychology_alt_outlined),
          selectedIcon: Icon(Icons.psychology_alt),
          label: Text('Clawd'),
        ),
      ],
    );
  }
}
