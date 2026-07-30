import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/widgets/compact_mobile_navigation.dart';
import '../../core/widgets/mobile_desktop_feature.dart';
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
    return ResponsiveTabbedShell(
      title: 'Accountant',
      subtitle:
          'Manage ledgers, reports, and Clawd analysis without admin controls.',
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
        children: const [
          AdminLedgerBody(),
          AnalyticsBody(),
          MobileDesktopFeature(
            icon: Icons.psychology_alt_outlined,
            title: 'Clawd works best on the web',
            description:
                'The mobile accountant view stays focused on ledger checks and quick business metrics.',
            desktopFeatures: [
              'Expanded AI analysis and follow-up questions',
              'Saved report prompts and structured parameters',
              'Anomaly detection, review, and resolution',
            ],
          ),
        ],
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
        destinations: const [
          CompactMobileDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: 'Ledger',
          ),
          CompactMobileDestination(
            icon: Icons.analytics_outlined,
            selectedIcon: Icons.analytics,
            label: 'Insights',
          ),
          CompactMobileDestination(
            icon: Icons.psychology_alt_outlined,
            selectedIcon: Icons.psychology_alt,
            label: 'Clawd',
          ),
        ],
        onProfile: () => context.push('/acct/profile'),
        onLogout: () async {
          await AuthService.instance.signOut();
          if (context.mounted) context.go('/welcome');
        },
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Ledger'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: Text('Analytics'),
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
