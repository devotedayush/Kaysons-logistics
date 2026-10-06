import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaysons_logistics/features/onboarding/onboarding_welcome_screen.dart';
import 'package:kaysons_logistics/features/auth/login_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, file) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File('test/assets/fonts/$file').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  for (final locale in ['en', 'hi']) {
    for (final desktop in [false, true]) {
      testWidgets('welcome and login $locale ${desktop ? "desktop" : "mobile"}', (
        tester,
      ) async {
        tester.view
          ..physicalSize =
              desktop ? const Size(1440, 1000) : const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final router = GoRouter(
          initialLocation: '/welcome',
          routes: [
            GoRoute(
              path: '/welcome',
              builder: (_, __) => const OnboardingWelcomeScreen(),
            ),
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(
              path: '/register',
              builder: (_, __) => const Scaffold(body: Text('Registration')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: buildAppTheme(),
              debugShowCheckedModeBanner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final asset in [
            'assets/branding/logistics-hero.png',
            'assets/branding/kaysons-app-icon.png',
          ]) {
            await precacheImage(
              AssetImage(asset),
              tester.element(find.byKey(key)),
            );
          }
        });
        await tester.pump();

        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => _capture(
            key,
            'welcome-$locale-${desktop ? "desktop" : "mobile"}',
          ),
        );
        final l =
            AppLocalizations.of(
              tester.element(find.byType(OnboardingWelcomeScreen)),
            )!;
        await tester.ensureVisible(find.text(l.loginEmailMobile));
        await tester.tap(find.text(l.loginEmailMobile));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text('Kaysons Sales Private Limited Logistics'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () =>
              _capture(key, 'login-$locale-${desktop ? "desktop" : "mobile"}'),
        );
        // Larger system text should scroll rather than overflow or hide controls.
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('tmp/qa/ui-refresh/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
