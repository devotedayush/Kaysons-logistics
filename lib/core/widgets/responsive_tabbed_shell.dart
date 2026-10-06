import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../supabase/auth_service.dart';
import '../../l10n/app_localizations.dart';
import 'desktop_shell_layout.dart';
import 'role_nav_config.dart';

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
    this.role,
    this.sidebarFooter,
    this.contentMaxWidth = 1360,
    this.wideBreakpoint = DesktopShellLayout.breakpoint,
    this.backgroundColor = AppColors.surface,
    this.sidebarWidth = 264,
  });

  final AppRole? role;
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
            child: isWide ? _buildDesktopLayout(context) : _buildMobileLayout(),
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

  Widget _buildDesktopLayout(BuildContext context) {
    final config =
        role == null
            ? null
            : RoleNavConfig.forRole(role!, AppLocalizations.of(context)!);
    return DesktopShellLayout(
      title: config?.title ?? title,
      subtitle: config?.subtitle ?? subtitle,
      currentIndex: currentIndex,
      destinations: config?.destinations ?? destinations,
      onDestinationSelected: onDestinationSelected,
      footer: sidebarFooter,
      maxWidth: contentMaxWidth,
      sidebarWidth: sidebarWidth,
      child: pageView,
    );
  }
}
