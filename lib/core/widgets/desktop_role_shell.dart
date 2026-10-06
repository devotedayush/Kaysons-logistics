import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../supabase/auth_service.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import 'desktop_shell_layout.dart';
import 'role_nav_config.dart';
import 'shell_settings_button.dart';

class DesktopRoleShell extends StatelessWidget {
  const DesktopRoleShell({
    super.key,
    required this.role,
    required this.child,
    this.currentIndex,
    this.maxContentWidth = 1360,
  });

  final AppRole role;
  final Widget child;
  final int? currentIndex;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < DesktopShellLayout.breakpoint) return child;
        // The authenticated route provides the role. Rendering navigation must
        // not perform an auth fetch with side effects on a transient failure.
        final config = RoleNavConfig.forRole(
          role,
          AppLocalizations.of(context)!,
        );
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: DesktopShellLayout(
              title: config.title,
              subtitle: config.subtitle,
              currentIndex: currentIndex,
              destinations: config.destinations,
              onDestinationSelected:
                  (index) => context.go(config.items[index].route),
              maxWidth: maxContentWidth,
              footer: ShellSettingsButton(
                onProfile: () => context.push(config.profileRoute),
                onLogout: () async {
                  await AuthService.instance.signOut();
                  if (context.mounted) context.go('/welcome');
                },
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
