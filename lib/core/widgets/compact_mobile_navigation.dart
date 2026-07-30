import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CompactMobileDestination {
  const CompactMobileDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class CompactMobileNavigation extends StatelessWidget {
  const CompactMobileNavigation({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.primaryIndices,
    required this.onSelect,
    required this.onProfile,
    required this.onLogout,
  });

  final int currentIndex;
  final List<CompactMobileDestination> destinations;
  final List<int> primaryIndices;
  final ValueChanged<int> onSelect;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final secondaryIndices = [
      for (var index = 0; index < destinations.length; index++)
        if (!primaryIndices.contains(index)) index,
    ];
    final moreSelected = secondaryIndices.contains(currentIndex);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x24000000),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9E1F1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (final index in primaryIndices)
                Expanded(
                  child: _NavigationItem(
                    destination: destinations[index],
                    selected: currentIndex == index,
                    onTap: () => onSelect(index),
                  ),
                ),
              Expanded(
                child: PopupMenuButton<String>(
                  tooltip: 'More options',
                  onSelected: (value) async {
                    if (value.startsWith('page:')) {
                      onSelect(int.parse(value.substring(5)));
                    } else if (value == 'profile') {
                      onProfile();
                    } else if (value == 'privacy' && context.mounted) {
                      context.push('/account/privacy');
                    } else if (value == 'logout') {
                      await onLogout();
                    }
                  },
                  itemBuilder:
                      (context) => [
                        for (final index in secondaryIndices)
                          PopupMenuItem(
                            value: 'page:$index',
                            child: _MenuRow(
                              icon: destinations[index].icon,
                              label: destinations[index].label,
                            ),
                          ),
                        if (secondaryIndices.isNotEmpty)
                          const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'profile',
                          child: _MenuRow(
                            icon: Icons.person_outline,
                            label: 'Profile',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'privacy',
                          child: _MenuRow(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Account & privacy',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: _MenuRow(icon: Icons.logout, label: 'Log out'),
                        ),
                      ],
                  child: _NavigationItem(
                    destination: const CompactMobileDestination(
                      icon: Icons.more_horiz,
                      selectedIcon: Icons.more_horiz,
                      label: 'More',
                    ),
                    selected: moreSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    this.onTap,
  });

  final CompactMobileDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFFE8DEF8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 22,
                  color: const Color(0xFF49454F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF49454F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
