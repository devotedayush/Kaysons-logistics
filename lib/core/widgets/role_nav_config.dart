import 'package:flutter/material.dart';
import '../supabase/auth_service.dart';
import '../../l10n/app_localizations.dart';

class RoleNavConfig {
  const RoleNavConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.profileRoute,
    required this.items,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String profileRoute;
  final List<RoleNavItem> items;

  List<NavigationRailDestination> get destinations => [
    for (final item in items)
      NavigationRailDestination(
        icon: Icon(item.icon),
        selectedIcon: Icon(item.selectedIcon),
        label: Text(item.label),
      ),
  ];

  static RoleNavConfig forRole(AppRole role, AppLocalizations l) {
    switch (role) {
      case AppRole.admin:
        return RoleNavConfig(
          title: l.adminConsole,
          subtitle: l.adminSubtitle,
          icon: Icons.admin_panel_settings_outlined,
          profileRoute: '/admin/profile',
          items: [
            RoleNavItem(Icons.dashboard_outlined, l.dashboard, '/admin'),
            RoleNavItem(Icons.people_outline, l.users, '/admin/users'),
            RoleNavItem(Icons.gavel_outlined, l.bids, '/admin/bids'),
            RoleNavItem(Icons.receipt_long_outlined, l.ledger, '/admin/ledger'),
            RoleNavItem(Icons.psychology_alt_outlined, l.clawd, '/admin/clawd'),
          ],
        );
      case AppRole.logisticsManager:
        return RoleNavConfig(
          title: l.logisticsManager,
          subtitle: l.logisticsSubtitle,
          icon: Icons.work_outline,
          profileRoute: '/lm/profile',
          items: [
            RoleNavItem(Icons.dashboard_outlined, l.dashboard, '/lm/home'),
            RoleNavItem(Icons.gavel_outlined, l.bids, '/lm/bids'),
            RoleNavItem(Icons.local_shipping_outlined, l.fleet, '/lm/fleet'),
            RoleNavItem(Icons.receipt_long_outlined, l.ledger, '/lm/ledger'),
            RoleNavItem(
              Icons.assignment_ind_outlined,
              l.dispatch,
              '/lm/dispatch',
            ),
          ],
        );
      case AppRole.dispatchManager:
        return RoleNavConfig(
          title: l.dispatchManager,
          subtitle: l.dispatchSubtitle,
          icon: Icons.assignment_turned_in_outlined,
          profileRoute: '/dm/profile',
          items: [
            RoleNavItem(Icons.dashboard_outlined, l.dashboard, '/dm/home'),
            RoleNavItem(Icons.local_shipping_outlined, l.fleet, '/dm/fleet'),
          ],
        );
      case AppRole.accountant:
        return RoleNavConfig(
          title: l.accountant,
          subtitle: l.accountantSubtitle,
          icon: Icons.calculate_outlined,
          profileRoute: '/acct/profile',
          items: [
            RoleNavItem(Icons.receipt_long_outlined, l.ledger, '/acct/ledger'),
            RoleNavItem(
              Icons.analytics_outlined,
              l.analytics,
              '/acct/analytics',
            ),
            RoleNavItem(Icons.psychology_alt_outlined, l.clawd, '/acct/clawd'),
          ],
        );
      case AppRole.transporter:
        return RoleNavConfig(
          title: l.transporter,
          subtitle: l.transporterSubtitle,
          icon: Icons.local_shipping_outlined,
          profileRoute: '/profile',
          items: [
            RoleNavItem(Icons.dashboard_outlined, l.home, '/home'),
            RoleNavItem(Icons.gavel_outlined, l.bids, '/bids'),
            RoleNavItem(
              Icons.route_outlined,
              l.localeName.startsWith('hi') ? 'मेरी यात्राएँ' : 'My trips',
              '/fleet',
            ),
          ],
        );
    }
  }
}

class RoleNavItem {
  RoleNavItem(this.icon, this.label, this.route);

  IconData get selectedIcon => switch (icon) {
    Icons.dashboard_outlined => Icons.dashboard,
    Icons.people_outline => Icons.people,
    Icons.gavel_outlined => Icons.gavel,
    Icons.receipt_long_outlined => Icons.receipt_long,
    Icons.psychology_alt_outlined => Icons.psychology_alt,
    Icons.local_shipping_outlined => Icons.local_shipping,
    Icons.assignment_ind_outlined => Icons.assignment_ind,
    Icons.analytics_outlined => Icons.analytics,
    _ => icon,
  };
  final IconData icon;
  final String label;
  final String route;
}
