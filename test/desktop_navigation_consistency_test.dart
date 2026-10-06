import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/supabase/auth_service.dart';
import 'package:kaysons_logistics/core/widgets/desktop_role_shell.dart';
import 'package:kaysons_logistics/core/widgets/desktop_shell_layout.dart';
import 'package:kaysons_logistics/core/widgets/responsive_tabbed_shell.dart';
import 'package:kaysons_logistics/core/widgets/role_nav_config.dart';
import 'package:kaysons_logistics/core/widgets/shell_settings_button.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  for (final locale in ['en', 'hi']) {
    for (final role in AppRole.values) {
      testWidgets('$role $locale keeps sidebar geometry on detail routes', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(1440, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(bool detail) => MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final config = RoleNavConfig.forRole(
                role,
                AppLocalizations.of(context)!,
              );
              if (detail) {
                // No Supabase initialization: shell rendering must not fetch auth.
                return DesktopRoleShell(
                  role: role,
                  currentIndex: 1,
                  child: const Scaffold(body: Text('Detail')),
                );
              }
              return ResponsiveTabbedShell(
                role: role,
                title: config.title,
                subtitle: config.subtitle,
                icon: config.icon,
                currentIndex: 1,
                onDestinationSelected: (_) {},
                pageView: const Scaffold(body: Text('Home')),
                mobileNavigation: const Text('Mobile navigation'),
                destinations: config.destinations,
                sidebarFooter: ShellSettingsButton(
                  onProfile: () {},
                  onLogout: () async {},
                ),
              );
            },
          ),
        );
        await tester.pumpWidget(app(false));
        await tester.pumpAndSettle();
        final sidebar = tester.getRect(
          find.byKey(const ValueKey('desktop-role-sidebar')),
        );
        final content = tester.getRect(
          find.byKey(const ValueKey('desktop-role-content')),
        );
        final labels =
            tester
                .widget<DesktopShellLayout>(find.byType(DesktopShellLayout))
                .destinations
                .map((d) => (d.label as Text).data)
                .toList();
        await tester.pumpWidget(app(true));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('desktop-role-sidebar'))),
          sidebar,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('desktop-role-content'))),
          content,
        );
        final layout = tester.widget<DesktopShellLayout>(
          find.byType(DesktopShellLayout),
        );
        expect(
          layout.destinations.map((d) => (d.label as Text).data).toList(),
          labels,
        );
        expect(layout.currentIndex, 1);
        expect(find.byType(ShellSettingsButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'both shells use the same breakpoint and scroll at large text sizes',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1024, 500)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Widget app() => MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const DesktopRoleShell(
          role: AppRole.logisticsManager,
          currentIndex: 1,
          child: Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(DesktopShellLayout), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(ShellSettingsButton),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShellSettingsButton).hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(1023, 500);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopShellLayout), findsNothing);
      expect(find.text('Detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
