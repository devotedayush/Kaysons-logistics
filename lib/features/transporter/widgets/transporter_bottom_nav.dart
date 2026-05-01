import 'package:flutter/material.dart';

class TransporterBottomNav extends StatelessWidget {
  const TransporterBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onProfile,
    this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onProfile;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDF7),
        borderRadius: BorderRadius.circular(80),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: currentIndex == 0,
            onTap: () => onTap(0),
            compact: compact,
          ),
          _NavItem(
            icon: Icons.gavel_outlined,
            label: 'Bids',
            selected: currentIndex == 1,
            onTap: () => onTap(1),
            compact: compact,
          ),
          _NavItem(
            icon: Icons.local_shipping_outlined,
            label: 'Fleet',
            selected: currentIndex == 2,
            onTap: () => onTap(2),
            compact: compact,
          ),
          if (onProfile != null || onLogout != null)
            _MoreNavItem(
              compact: compact,
              onProfile: onProfile,
              onLogout: onLogout,
            ),
        ],
      ),
    );
  }
}

class _MoreNavItem extends StatelessWidget {
  const _MoreNavItem({required this.compact, this.onProfile, this.onLogout});

  final bool compact;
  final VoidCallback? onProfile;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PopupMenuButton<String>(
        tooltip: 'Profile and logout',
        onSelected: (value) async {
          if (value == 'profile') onProfile?.call();
          if (value == 'logout') await onLogout?.call();
        },
        itemBuilder:
            (context) => [
              if (onProfile != null)
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Profile'),
                    ],
                  ),
                ),
              if (onLogout != null)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 10),
                      Text('Logout'),
                    ],
                  ),
                ),
            ],
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 12,
            horizontal: 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: compact ? 56 : 64,
                height: 32,
                child: const Icon(
                  Icons.account_circle_outlined,
                  size: 22,
                  color: Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'More',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF49454F),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 12,
            horizontal: 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 64,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFE8DEF8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color:
                      selected
                          ? const Color(0xFF1D1B20)
                          : const Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      selected
                          ? const Color(0xFF1D1B20)
                          : const Color(0xFF49454F),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
