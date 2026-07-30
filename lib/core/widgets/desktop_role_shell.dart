import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../supabase/auth_service.dart';

class DesktopRoleShell extends StatelessWidget {
  const DesktopRoleShell({
    super.key,
    required this.role,
    required this.child,
    this.currentIndex,
    this.maxContentWidth = 1120,
  });

  final AppRole role;
  final Widget child;
  final int? currentIndex;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return child;

        return FutureBuilder<AppRole>(
          future: AuthService.instance.fetchRole(),
          builder: (context, snapshot) {
            final effectiveRole = snapshot.data ?? role;
            return Scaffold(
              backgroundColor: const Color(0xFFF8F5FB),
              body: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoleSidebar(
                      role: effectiveRole,
                      currentIndex: currentIndex,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RoleSidebar extends StatelessWidget {
  const _RoleSidebar({required this.role, required this.currentIndex});

  final AppRole role;
  final int? currentIndex;

  @override
  Widget build(BuildContext context) {
    final config = _RoleNavConfig.forRole(role);
    return Container(
      width: 248,
      margin: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9E1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(config.icon, size: 30),
          const SizedBox(height: 20),
          Text(
            config.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            config.subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF6B6176),
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < config.items.length; i++) ...[
            _DesktopNavTile(
              selected: currentIndex == i,
              icon: config.items[i].icon,
              label: config.items[i].label,
              onTap: () => context.go(config.items[i].route),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          _DesktopNavTile(
            selected: false,
            icon: Icons.account_circle_outlined,
            label: 'Profile',
            onTap: () => context.push(config.profileRoute),
          ),
          const SizedBox(height: 8),
          _DesktopNavTile(
            selected: false,
            icon: Icons.privacy_tip_outlined,
            label: 'Account & privacy',
            onTap: () => context.push('/account/privacy'),
          ),
          const SizedBox(height: 8),
          _DesktopNavTile(
            selected: false,
            icon: Icons.logout,
            label: 'Logout',
            onTap: () async {
              await AuthService.instance.signOut();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

class _RoleNavConfig {
  const _RoleNavConfig({
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
  final List<_RoleNavItem> items;

  static _RoleNavConfig forRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const _RoleNavConfig(
          title: 'Admin console',
          subtitle: 'Review users, oversee freight activity, and manage ops.',
          icon: Icons.admin_panel_settings_outlined,
          profileRoute: '/admin/profile',
          items: [
            _RoleNavItem(Icons.dashboard_outlined, 'Dashboard', '/admin'),
            _RoleNavItem(Icons.people_outline, 'Users', '/admin/users'),
            _RoleNavItem(Icons.gavel_outlined, 'Bids', '/admin/bids'),
            _RoleNavItem(
              Icons.receipt_long_outlined,
              'Ledger',
              '/admin/ledger',
            ),
            _RoleNavItem(
              Icons.psychology_alt_outlined,
              'Clawd',
              '/admin/clawd',
            ),
          ],
        );
      case AppRole.logisticsManager:
        return const _RoleNavConfig(
          title: 'Logistics manager',
          subtitle: 'Publish freights, monitor bids, and track deliveries.',
          icon: Icons.work_outline,
          profileRoute: '/lm/profile',
          items: [
            _RoleNavItem(Icons.dashboard_outlined, 'Dashboard', '/lm/home'),
            _RoleNavItem(Icons.gavel_outlined, 'Bids', '/lm/bids'),
            _RoleNavItem(Icons.local_shipping_outlined, 'Fleet', '/lm/fleet'),
            _RoleNavItem(Icons.receipt_long_outlined, 'Ledger', '/lm/ledger'),
            _RoleNavItem(
              Icons.assignment_ind_outlined,
              'Dispatch',
              '/lm/dispatch',
            ),
          ],
        );
      case AppRole.dispatchManager:
        return const _RoleNavConfig(
          title: 'Dispatch manager',
          subtitle: 'Track accepted deliveries and verify dispatch updates.',
          icon: Icons.assignment_turned_in_outlined,
          profileRoute: '/dm/profile',
          items: [
            _RoleNavItem(Icons.dashboard_outlined, 'Dashboard', '/dm/home'),
            _RoleNavItem(Icons.local_shipping_outlined, 'Fleet', '/dm/fleet'),
          ],
        );
      case AppRole.accountant:
        return const _RoleNavConfig(
          title: 'Accountant',
          subtitle: 'Manage freight ledgers, reports, and Clawd analysis.',
          icon: Icons.calculate_outlined,
          profileRoute: '/acct/profile',
          items: [
            _RoleNavItem(Icons.receipt_long_outlined, 'Ledger', '/acct/ledger'),
            _RoleNavItem(
              Icons.analytics_outlined,
              'Analytics',
              '/acct/analytics',
            ),
            _RoleNavItem(Icons.psychology_alt_outlined, 'Clawd', '/acct/clawd'),
          ],
        );
      case AppRole.transporter:
        return const _RoleNavConfig(
          title: 'Transporter',
          subtitle: 'Manage bids, fleet, and delivery updates.',
          icon: Icons.local_shipping_outlined,
          profileRoute: '/profile',
          items: [
            _RoleNavItem(Icons.dashboard_outlined, 'Dashboard', '/home'),
            _RoleNavItem(Icons.gavel_outlined, 'Bids', '/bids'),
            _RoleNavItem(Icons.local_shipping_outlined, 'Fleet', '/fleet'),
          ],
        );
    }
  }
}

class _RoleNavItem {
  const _RoleNavItem(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6EDFB) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE1D2F8) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  selected ? const Color(0xFF1D1B20) : const Color(0xFF49454F),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected
                          ? const Color(0xFF1D1B20)
                          : const Color(0xFF49454F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
