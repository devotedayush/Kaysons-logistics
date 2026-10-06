import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared geometry keeps the workspace stable when a tab opens a detail route.
class DesktopShellLayout extends StatelessWidget {
  const DesktopShellLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.child,
    this.footer,
    this.maxWidth = 1360,
    this.sidebarWidth = 264,
  });

  static const breakpoint = 1024.0;
  final String title;
  final String subtitle;
  final int? currentIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const ValueKey('desktop-role-sidebar'),
              width: sidebarWidth.clamp(220, 280).toDouble(),
              margin: const EdgeInsets.fromLTRB(18, 18, 12, 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.outline),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C30234D),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              // One scroll region prevents the footer from overflowing on short
              // windows or when accessibility text sizes increase.
              child: ListView(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/branding/kaysons-app-icon.png',
                        width: 48,
                        height: 48,
                        semanticLabel: 'Kaysons logo',
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'KAYSONS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 12),
                  for (var index = 0; index < destinations.length; index++) ...[
                    _DestinationTile(
                      destination: destinations[index],
                      selected: currentIndex == index,
                      onTap: () => onDestinationSelected(index),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (footer != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
                child: Container(
                  key: const ValueKey('desktop-role-content'),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Material(color: AppColors.surface, child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final NavigationRailDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceTint : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  color:
                      selected ? AppColors.primary : AppColors.onSurfaceVariant,
                  size: 22,
                ),
                child: selected ? destination.selectedIcon : destination.icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                  ),
                  child: destination.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
