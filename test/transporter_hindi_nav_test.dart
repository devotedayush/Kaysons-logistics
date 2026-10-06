import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/transporter/widgets/transporter_bottom_nav.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  testWidgets('transporter navigation renders Hindi on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          bottomNavigationBar: TransporterBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            onProfile: () {},
            onLogout: () async {},
          ),
        ),
      ),
    );

    expect(find.text('डैशबोर्ड'), findsOneWidget);
    expect(find.text('बोलियाँ'), findsOneWidget);
    expect(find.text('वाहन और ड्राइवर'), findsOneWidget);
    expect(find.text('अधिक'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
