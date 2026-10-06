import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/responsive_tabbed_shell.dart';
import '../../core/widgets/shell_settings_button.dart';
import 'admin_ai_body.dart';
import 'admin_ledger_body.dart';
import 'analytics_screen.dart';

class AccountantShell extends StatefulWidget {
  const AccountantShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AccountantShell> createState() => _AccountantShellState();
}

class _AccountantShellState extends State<AccountantShell> {
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ResponsiveTabbedShell(
      role: AppRole.accountant,
      title: l.accountant,
      subtitle: l.accountantSubtitle,
      icon: Icons.calculate_outlined,
      currentIndex: _index,
      onDestinationSelected: _goto,
      pageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const ClampingScrollPhysics(),
        children: const [AdminLedgerBody(), AnalyticsBody(), AdminAiBody()],
      ),
      mobilePageView: PageView(
        controller: _pc,
        onPageChanged: (i) => setState(() => _index = i),
        physics: const NeverScrollableScrollPhysics(),
        children: const [AdminLedgerBody(), AnalyticsBody(), AdminAiBody()],
      ),
      sidebarFooter: ShellSettingsButton(
        onProfile: () => context.push('/acct/profile'),
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
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: l.ledger,
          ),
          CompactMobileDestination(
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics,
            label: l.insights,
          ),
          CompactMobileDestination(
            icon: Icons.psychology_alt_outlined,
            selectedIcon: Icons.psychology_alt,
            label: l.clawd,
          ),
        ],
        onProfile: () => context.push('/acct/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      destinations: [
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text(l.ledger),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: Text(l.analytics),
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
