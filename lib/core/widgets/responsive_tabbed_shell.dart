import 'package:flutter/material.dart';

class ResponsiveTabbedShell extends StatelessWidget {
  const ResponsiveTabbedShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.pageView,
    required this.mobileNavigation,
    required this.destinations,
    this.mobilePageView,
    this.sidebarFooter,
    this.contentMaxWidth = 1360,
    this.wideBreakpoint = 1024,
    this.backgroundColor = const Color(0xFFF8F5FB),
    this.sidebarWidth = 248,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget pageView;
  final Widget? mobilePageView;
  final Widget mobileNavigation;
  final List<NavigationRailDestination> destinations;
  final Widget? sidebarFooter;
  final double contentMaxWidth;
  final double wideBreakpoint;
  final Color backgroundColor;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= wideBreakpoint;

        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Expanded(child: mobilePageView ?? pageView),
            mobileNavigation,
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final effectiveSidebarWidth = sidebarWidth.clamp(220, 280).toDouble();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: effectiveSidebarWidth,
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
                  Icon(icon, size: 30),
                  const SizedBox(height: 20),
                  Builder(
                    builder:
                        (context) => Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF6B6176),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView.separated(
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = destinations[index];
                        return _DesktopDestinationTile(
                          selected: currentIndex == index,
                          label: _destinationLabel(d.label),
                          icon: currentIndex == index ? d.selectedIcon : d.icon,
                          onTap: () => onDestinationSelected(index),
                        );
                      },
                    ),
                  ),
                  if (sidebarFooter != null) ...[
                    const SizedBox(height: 12),
                    sidebarFooter!,
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Material(color: Colors.white, child: pageView),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _destinationLabel(Widget label) {
    if (label is Text) return label.data ?? '';
    return label.toStringShort();
  }
}

class _DesktopDestinationTile extends StatelessWidget {
  const _DesktopDestinationTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Widget icon;
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
            IconTheme(
              data: IconThemeData(
                color:
                    selected
                        ? const Color(0xFF1D1B20)
                        : const Color(0xFF49454F),
                size: 22,
              ),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
