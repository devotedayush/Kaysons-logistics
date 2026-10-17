import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/core/widgets/compact_mobile_navigation.dart';
import 'package:kaysons_logistics/core/widgets/responsive_tabbed_shell.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('Inter', 'Inter-Bold.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf'),
    ]) {
      final bytes = await File('test/assets/fonts/$file').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final language in ['en', 'hi']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'phone navigation $language at $scale reserves one safe inset',
        (tester) async {
          tester.view
            ..physicalSize = const Size(320, 640)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int? selected;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(),
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 24, bottom: 34),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
              home: Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return ResponsiveTabbedShell(
                    title: l.adminConsole,
                    subtitle: '',
                    icon: Icons.dashboard,
                    currentIndex: 0,
                    onDestinationSelected: (_) {},
                    pageView: const ColoredBox(
                      key: Key('content'),
                      color: Colors.white,
                    ),
                    destinations: const [],
                    mobileNavigation: CompactMobileNavigation(
                      currentIndex: 0,
                      destinations: [
                        for (final label in [l.home, l.users, l.bids, l.ledger])
                          CompactMobileDestination(
                            icon: Icons.home_outlined,
                            selectedIcon: Icons.home,
                            label: label,
                          ),
                      ],
                      primaryIndices: const [0, 2, 3],
                      onSelect: (value) => selected = value,
                      onProfile: () {},
                      onLogout: () async {},
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final navRect = tester.getRect(find.byType(CompactMobileNavigation));
          final bodyRect = tester.getRect(find.byKey(const Key('content')));
          expect(navRect.bottom, 640);
          expect(bodyRect.top, 24);
          expect(bodyRect.bottom, navRect.top);
          expect(
            navRect.height,
            lessThanOrEqualTo(scale == 1 ? 100 : 80 + 30 * scale),
          );
          final l =
              AppLocalizations.of(
                tester.element(find.byType(CompactMobileNavigation)),
              )!;
          await tester.tap(find.text(l.ledger));
          expect(selected, 3);
          await tester.tap(find.text(l.more));
          await tester.pumpAndSettle();
          expect(find.text(l.profile), findsOneWidget);
          await tester.tap(find.text(l.users));
          await tester.pumpAndSettle();
          expect(selected, 1);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(find.byType(CompactMobileNavigation), findsNothing);
          expect(tester.getRect(find.byKey(const Key('content'))).bottom, 340);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
