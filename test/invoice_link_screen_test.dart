import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/logistics_manager/invoice_link_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'removing a charged invoice resets allocation to whole dispatch',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvoiceLinkScreen(
            bidId: 'ui-only-no-server-write',
            invoiceStateLoader:
                (_) async => {
                  'status': 'awarded',
                  'invoices': <Map<String, dynamic>>[],
                  'charges': <Map<String, dynamic>>[],
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add another invoice'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add charge'));
      await tester.tap(find.text('Add charge'));
      await tester.pumpAndSettle();
      final allocation = find.byType(DropdownButtonFormField<String>).last;
      await tester.ensureVisible(allocation);
      await tester.tap(allocation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invoice 2').last);
      await tester.pumpAndSettle();
      final remove = find.byTooltip('Remove invoice').last;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Whole dispatch'), findsOneWidget);
    },
  );

  testWidgets('completed delivery still offers missing invoice entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceLinkScreen(
          bidId: 'completed-freight',
          invoiceStateLoader:
              (_) async => {
                'status': 'completed',
                'invoices': <Map<String, dynamic>>[],
                'charges': <Map<String, dynamic>>[],
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Delivery is complete. You can still add'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Save invoice details'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save invoice details'), findsOneWidget);
  });

  testWidgets('saved invoices remain visible after completion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceLinkScreen(
          bidId: 'completed-freight',
          invoiceStateLoader:
              (_) async => {
                'status': 'completed',
                'invoices': <Map<String, dynamic>>[
                  {
                    'invoice_number': 'INV-42',
                    'gr_number': 'GR-8',
                    'town': 'Jaipur',
                  },
                ],
                'charges': <Map<String, dynamic>>[],
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saved invoice details'), findsOneWidget);
    expect(find.text('Invoice number: INV-42'), findsOneWidget);
    expect(find.text('Save invoice details'), findsNothing);
  });

  testWidgets('one invoice can show several mapped transport documents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceLinkScreen(
          bidId: 'multi-document-freight',
          invoiceStateLoader: (_) async => {
            'status': 'locked',
            'invoices': <Map<String, dynamic>>[
              {
                'invoice_number': 'INV-42',
                'gr_number': 'GR-1',
                'e_way_bill_number': 'EWB-1',
                'gr_bilty_numbers': ['GR-1', 'GR-2'],
                'e_way_bill_numbers': ['EWB-1', 'EWB-2'],
              },
            ],
            'charges': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GR / Bilty number: GR-1, GR-2'), findsOneWidget);
    expect(find.text('E-way bill number: EWB-1, EWB-2'), findsOneWidget);
  });

  testWidgets('office can add a second e-way bill to one invoice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceLinkScreen(
          bidId: 'multi-document-freight',
          invoiceStateLoader: (_) async => {
            'status': 'awarded',
            'invoices': <Map<String, dynamic>>[],
            'charges': <Map<String, dynamic>>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another e-way bill'));
    await tester.pumpAndSettle();
    expect(find.text('E-way bill number 2'), findsOneWidget);
    expect(find.byTooltip('Remove document number'), findsOneWidget);
  });
}
