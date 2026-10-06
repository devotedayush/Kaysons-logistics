import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ledger summary controls fit a 390px mobile layout', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 730)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LedgerSummaryControls(
            invoiceRows: 1,
            trips: 1,
            vehicles: 0,
            cases: 124,
            metricTons: 76,
            freight: 0,
            podPending: 1,
            presentation: LedgerPresentation.overview,
            onPresentationChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Invoice rows'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Vehicles'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Rows'), findsOneWidget);
  });
  testWidgets('ledger summary controls use Hindi when selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LedgerSummaryControls(
            invoiceRows: 1,
            trips: 1,
            vehicles: 0,
            cases: 124,
            metricTons: 76,
            freight: 0,
            podPending: 1,
            presentation: LedgerPresentation.overview,
            onPresentationChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('इनवॉइस पंक्तियाँ'), findsOneWidget);
    expect(find.text('चक्कर'), findsOneWidget);
    expect(find.text('सारांश'), findsOneWidget);
  });
  testWidgets('desktop summary scrollbars attach on both axes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 300,
            child: LedgerTableScroll(
              child: SizedBox(
                width: 1500,
                height: 900,
                child: Text('Large report'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final horizontal = find.byType(SingleChildScrollView).first;
    await tester.drag(horizontal, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
