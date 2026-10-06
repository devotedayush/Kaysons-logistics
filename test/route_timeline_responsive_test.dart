import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/core/widgets/route_timeline.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  for (final width in [320.0, 1100.0]) {
    for (final language in ['en', 'hi']) {
      testWidgets('all route stops are visible $width $language', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(20),
                  child: RouteTimeline(
                    points: [
                      RoutePoint(
                        label: 'A · Ludhiana central loading warehouse',
                        kind: RoutePointKind.origin,
                        meta: '50 MT · 50 cases',
                      ),
                      RoutePoint(
                        label: 'B · Jalandhar receiving warehouse',
                        kind: RoutePointKind.stop,
                        meta: '30 MT · 30 cases',
                      ),
                      RoutePoint(
                        label: 'C · Amritsar final receiving warehouse',
                        kind: RoutePointKind.destination,
                        meta: '20 MT · 20 cases',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsNothing);
        for (final initial in ['A ·', 'B ·', 'C ·']) {
          final stop = find.textContaining(initial);
          expect(stop, findsOneWidget);
          final bounds = tester.getRect(stop);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
          expect(bounds.bottom, lessThan(1000));
        }
        expect(
          find.text(language == 'hi' ? 'अंतिम डिलीवरी' : 'Final delivery'),
          findsOneWidget,
        );
      });
    }
  }
}
