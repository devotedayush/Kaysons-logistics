import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';
import 'package:kaysons_logistics/features/admin/widgets/ledger_records.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ledgerFixtures = List<Map<String, dynamic>>.generate(3, (index) {
  final id = '11111111-1111-4111-8111-11111111111${index + 1}';
  return {
    'id': id,
    'freight_id': id,
    'invoice_id': 'invoice-${index + 1}',
    'created_at': DateTime.now().toIso8601String(),
    'bill_date': DateTime.now().toIso8601String(),
    'dispatch_date': DateTime.now().toIso8601String(),
    'company_name': ['Alpha Company', 'Beta Company', 'Gamma Company'][index],
    'transporter_name':
        ['North Transport', 'West Carriers', 'East Logistics'][index],
    'party_name': ['Alpha Customer', 'Beta Customer', 'Gamma Customer'][index],
    'party_names': ['Alpha Customer', 'Beta Customer', 'Gamma Customer'][index],
    'town': ['Lucknow', 'Jaipur', 'Patna'][index],
    'origin': 'Ludhiana',
    'vehicle_number': ['PB10AB1234', 'HR20CD5678', 'UP30EF9012'][index],
    'invoice_number': 'INV-00${index + 1}',
    'cases': 120 + index,
    'weight_kg': 8.5,
    'total_freight': 12500,
    'balance': 2500,
    'extras': 300,
    'deductions': 100,
    'advance': 10000,
    'e_way_bill_number': 'EWAY-00${index + 1}',
    'lr_gr_number': 'GR-00${index + 1}',
    'dispatch_gr_bilty_number': 'GR-00${index + 1}',
    'vehicle_type': 'Truck',
    'vehicle_capacity': 10,
    'ack_status': index == 1 ? 'received' : 'pending',
    'record_origin': index == 1 ? 'historical_import' : 'live',
    'pod_status': index == 1 ? 'received' : 'pending',
    'status': 'completed',
  };
});

List<Map<String, dynamic>> activeLedger = ledgerFixtures;

Future<void> mountLedger(
  WidgetTester tester,
  Size size,
  String language,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('ledger-capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
        home: const Scaffold(body: AdminLedgerBody()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> snapshot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('ledger-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/kaysons-ledger-declutter/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    for (final (family, path) in [
      ('Inter', 'assets/fonts/Inter-Regular.ttf'),
      ('Inter', 'assets/fonts/Inter-Bold.ttf'),
      ('NotoSansDevanagariUI', 'assets/fonts/NotoSansDevanagariUI-Regular.ttf'),
      ('MaterialIcons', 'test/assets/fonts/MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File(path).readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await Supabase.initialize(
      url: 'https://ledger-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body = [];
        if (request.url.path.endsWith('/admin_freight_ledger_view')) {
          body = activeLedger;
        }
        if (request.url.path.endsWith('/freights')) {
          body = [
            for (final row in activeLedger)
              {
                'id': row['freight_id'],
                'record_origin': row['record_origin'],
                'ack_status': row['ack_status'],
              },
          ];
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() => activeLedger = ledgerFixtures);
  testWidgets('two invoices on one trip remain two pending records', (
    tester,
  ) async {
    activeLedger = [
      ...ledgerFixtures,
      {
        ...ledgerFixtures.first,
        'invoice_id': 'invoice-4',
        'invoice_number': 'INV-004',
        'e_way_bill_number': 'EWAY-004',
      },
    ];
    await mountLedger(tester, const Size(1440, 1000), 'en');
    expect(find.textContaining('4 records'), findsOneWidget);
    await tester.tap(find.text('Pending proof'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 records'), findsOneWidget);
    expect(find.textContaining('2 trips need proof'), findsOneWidget);
    for (final invoice in ['INV-001', 'INV-003', 'INV-004']) {
      await tester.scrollUntilVisible(
        find.text(invoice),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(invoice), findsOneWidget);
    }
    expect(find.text('INV-002'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final language in ['en', 'hi']) {
    for (final (device, size) in [
      ('phone', const Size(390, 844)),
      ('laptop', const Size(1440, 1000)),
    ]) {
      String copy(String english, String hindi) =>
          language == 'hi' ? hindi : english;
      testWidgets(
        '$device $language records search and pending proof at 130% text',
        (tester) async {
          await mountLedger(tester, size, language);
          expect(find.text(copy('Records', 'रिकॉर्ड')), findsOneWidget);
          for (final number in ['INV-001', 'INV-002', 'INV-003']) {
            await tester.scrollUntilVisible(
              find.text(number),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text(number), findsOneWidget);
          }
          await tester.scrollUntilVisible(
            find.textContaining('1–3'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('1–3'), findsOneWidget);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 5000),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DataTable), findsNothing);
          expect(
            find.text(copy('Edit ledger entry', 'लेजर एंट्री बदलें')),
            findsNothing,
          );
          expect(
            find.text(copy('Review delivery', 'डिलीवरी देखें')),
            findsNothing,
          );
          expect(
            find.byTooltip(copy('Export reports', 'रिपोर्ट निर्यात करें')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await snapshot(tester, '$device-$language-records');
          final search = find.widgetWithText(
            TextField,
            copy('Search ledger', 'लेजर खोजें'),
          );
          for (final query in [
            'pb10ab1234',
            'north transport',
            'alpha customer',
          ]) {
            await tester.enterText(search, query);
            await tester.pumpAndSettle();
            expect(
              find.byType(LedgerRecordTile),
              findsOneWidget,
              reason: query,
            );
            expect(find.text('INV-001'), findsOneWidget);
            expect(find.text('INV-002'), findsNothing);
          }
          await tester.enterText(search, 'not a matching trip');
          await tester.pumpAndSettle();
          expect(find.byType(LedgerRecordTile), findsNothing);
          await tester.enterText(search, '');
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(copy('Pending proof', 'लंबित प्रमाण')),
          );
          await tester.tap(find.text(copy('Pending proof', 'लंबित प्रमाण')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.textContaining('1–2'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('1–2'), findsOneWidget);
          expect(find.text('INV-002'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        '$device $language complete details and reports at 130% text',
        (tester) async {
          await mountLedger(tester, size, language);
          final review = find.text(copy('Review', 'जाँचें')).first;
          await tester.ensureVisible(review);
          await tester.pumpAndSettle();
          await tester.tap(review);
          await tester.pumpAndSettle();
          for (final value in [
            'INV-001',
            'Alpha Customer',
            'EWAY-001',
            'PB10AB1234',
            'North Transport',
            'GR-001',
          ]) {
            final detailsScroll =
                find
                    .descendant(
                      of: find.byType(ListView).last,
                      matching: find.byType(Scrollable),
                    )
                    .first;
            await tester.drag(detailsScroll, const Offset(0, 5000));
            await tester.pumpAndSettle();
            for (
              var attempts = 0;
              find.textContaining(value).evaluate().isEmpty && attempts < 30;
              attempts++
            ) {
              await tester.drag(detailsScroll, const Offset(0, -180));
              await tester.pumpAndSettle();
            }
            expect(find.textContaining(value), findsWidgets);
            await tester.ensureVisible(find.textContaining(value).first);
            await tester.pumpAndSettle();
            expect(
              find.textContaining(value),
              findsWidgets,
              reason: 'Full record retains $value',
            );
          }
          expect(
            find.text(copy('Edit ledger entry', 'लेजर एंट्री बदलें')),
            findsOneWidget,
          );
          expect(
            find.text(copy('Review delivery', 'डिलीवरी देखें')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await snapshot(tester, '$device-$language-details');
          await tester.tap(
            find.byTooltip(copy('Close details', 'विवरण बंद करें')),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 5000),
          );
          await tester.pumpAndSettle();
          final reports = find.text(copy('Reports', 'रिपोर्ट'));
          await tester.ensureVisible(reports);
          await tester.pumpAndSettle();
          await tester.tap(reports);
          await tester.pumpAndSettle();
          expect(
            find.byTooltip(copy('Export reports', 'रिपोर्ट निर्यात करें')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await snapshot(tester, '$device-$language-reports');
          await tester.tap(find.byTooltip(copy('More', 'अधिक')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(copy('All columns', 'सभी कॉलम')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<DataTable>(find.byType(DataTable)).columns.length,
            29,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
