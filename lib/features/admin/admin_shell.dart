import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';
import 'admin_ai_body.dart';
import 'admin_bids_body.dart';
import 'admin_dashboard_body.dart';
import 'admin_ledger_body.dart';
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
      role: AppRole.admin,
      title: l.adminConsole,
      subtitle: l.adminSubtitle,
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
          AdminLedgerBody(),
          AdminAiBody(),
        ],
      ),
      mobilePageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          AdminDashboardBody(),
          AdminUsersBody(),
          AdminBidsBody(),
          AdminLedgerBody(),
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
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: l.users,
          ),
          CompactMobileDestination(
            icon: Icons.gavel_outlined,
            selectedIcon: Icons.gavel,
            label: l.bids,
          ),
          CompactMobileDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: l.ledger,
          ),
          CompactMobileDestination(
            icon: Icons.psychology_alt_outlined,
            selectedIcon: Icons.psychology_alt,
            label: l.clawd,
          ),
        ],
        onProfile: () => context.push('/admin/profile'),
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
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text(l.users),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.gavel_outlined),
          selectedIcon: Icon(Icons.gavel),
          label: Text(l.bids),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text(l.ledger),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.psychology_alt_outlined),
          selectedIcon: Icon(Icons.psychology_alt),
          label: Text(l.clawd),
        ),
      ],
    );
  }
}
