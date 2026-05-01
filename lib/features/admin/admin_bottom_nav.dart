import 'package:flutter/material.dart';

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onLogout,
    this.onProfile,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Future<void> Function() onLogout;
  final VoidCallback? onProfile;

  static const _items = [
    (Icons.dashboard_outlined, 'Dashboard'),
    (Icons.people_outline, 'Users'),
    (Icons.gavel_outlined, 'Bids'),
    (Icons.psychology_alt_outlined, 'Clawd'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDF7),
        borderRadius: BorderRadius.circular(80),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              selected: currentIndex == i,
              onTap: () => onTap(i),
            ),
          _SettingsNavItem(onLogout: onLogout, onProfile: onProfile),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({required this.onLogout, this.onProfile});

  final Future<void> Function() onLogout;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Settings',
      onSelected: (value) async {
        if (value == 'profile') onProfile?.call();
        if (value == 'logout') await onLogout();
      },
      itemBuilder:
          (context) => [
            if (onProfile != null)
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 22,
                color: Color(0xFF49454F),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'More',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF49454F),
                letterSpacing: 0.5,
              ),
            ),
          ],
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8DEF8) : Colors.transparent,
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
                fontSize: 12,
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
    );
  }
}
