import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/delivery/delivery_workflow_panel.dart';
import 'package:kaysons_logistics/features/logistics_manager/invoice_link_screen.dart';
import 'package:kaysons_logistics/features/logistics_manager/widgets/operational_workspace.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'delivery_workflow_panel_test.dart' as sample;

void main() {
  setUpAll(() async {
    for (final (family, filename) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('Inter', 'Inter-Bold.ttf'),
      ('Roboto', 'Roboto-Regular.ttf'),
      ('Roboto', 'Roboto-Bold.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File('test/assets/fonts/$filename').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final width in [390.0, 1440.0]) {
    for (final action in [
      'Report delivery',
      'Add journey update',
      'Submit expense',
      'Edit customers & references',
    ]) {
      testWidgets('$action dialog usable at $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DeliveryWorkflowPanel(
                  freight: sample.freight,
                  office: action == 'Edit customers & references',
                  loadData:
                      () async => [sample.receivers(), [], sample.expenses],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.text(action).first;
        await tester.ensureVisible(button);
        await Scrollable.ensureVisible(tester.element(button), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.text('Complete the required details first'),
          findsOneWidget,
        );
        expect(find.text('Save'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final width in [390.0, 1440.0]) {
    for (final page in ['billing', 'customer-review']) {
      testWidgets('$page readable at $width with larger text', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.2)),
                  child: child!,
                ),
            home: RepaintBoundary(
              key: boundary,
              child:
                  page == 'billing'
                      ? InvoiceLinkScreen(
                        bidId: 'ui-only',
                        invoiceStateLoader:
                            (_) async => {
                              'status': 'dispatched',
                              'invoices': <Map<String, dynamic>>[],
                              'charges': <Map<String, dynamic>>[],
                            },
                      )
                      : Scaffold(
                        body: OperationalListView(
                          children: [
                            DeliveryWorkflowPanel(
                              freight: sample.freight,
                              office: true,
                              readOnly: true,
                              loadData:
                                  () async => [
                                    sample.receivers(reported: true),
                                    [],
                                    sample.expenses,
                                  ],
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (page == 'billing') {
          expect(find.text('Prepare transport billing'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Add another invoice'),
            400,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text('Add another invoice')),
            alignment: .5,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Add another invoice'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Invoice 2'),
            -300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Invoice 2'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } else {
          expect(find.text('40 cases · 1.2 MT'), findsOneWidget);
          expect(find.text('20 cases · 0.6 MT'), findsOneWidget);
          expect(find.text('— cases · — MT'), findsOneWidget);
        }
        // Rendered evidence is temporary; the shared screenshot matrix owns goldens.
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/kaysons-$page-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
