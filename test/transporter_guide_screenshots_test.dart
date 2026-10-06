import 'package:kaysons_logistics/core/theme/app_theme.dart';
// Regenerate with: flutter test test/transporter_guide_screenshots_test.dart --update-goldens
// Render actual transporter widgets against an in-memory sample API only.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kaysons_logistics/features/transporter/afterbid_screen.dart';
import 'package:kaysons_logistics/features/transporter/bid_detail_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const _bidId = '00000000-0000-4000-8000-000000000102';
const _dispatchId = '00000000-0000-4000-8000-000000000103';
const _deliveryId = '00000000-0000-4000-8000-000000000104';
const _multiStopId = '00000000-0000-4000-8000-000000000105';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    Future<void> loadFont(String family, String fileName) async {
      final bytes = await File('test/assets/fonts/$fileName').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont('Inter', 'Inter-Regular.ttf');
    await loadFont('Inter', 'Inter-Bold.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Bold.ttf');
    final iconBytes =
        await File(
          '/Users/ayushmansingh/.codex-toolcache/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
    await (FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://sample.invalid',
      anonKey: 'sample-publishable-key',
      debug: false,
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final single = (request.headers['accept'] ?? '').contains(
          'object+json',
        );
        Object body = <Object>[];
        if (path.endsWith('/freights')) {
          final rows = [
            _openBid,
            _dispatchFreight,
            _deliveryFreight,
            _multiStopFreight,
          ];
          final id = request.url.queryParameters['id'];
          final selected =
              id == null
                  ? rows
                  : rows.where((row) => 'eq.${row['id']}' == id).toList();
          body =
              single
                  ? (selected.isEmpty ? <String, Object>{} : selected.first)
                  : selected;
        } else if (path.endsWith('/bids') ||
            path.endsWith('/vehicles') ||
            path.endsWith('/drivers')) {
          body = <Object>[];
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  final screens = <(String, Widget Function(), Locale)>[
    (
      'bid-detail-sample-en',
      () => BidDetailScreen(
        bidId: _bidId,
        freightStream: Stream.value(_openBid),
        bidsStream: Stream.value(<Map<String, dynamic>>[]).asBroadcastStream(),
      ),
      const Locale('en'),
    ),
    (
      'bid-detail-sample-hi',
      () => BidDetailScreen(
        bidId: _bidId,
        freightStream: Stream.value(_openBid),
        bidsStream: Stream.value(<Map<String, dynamic>>[]).asBroadcastStream(),
      ),
      const Locale('hi'),
    ),
    (
      'bid-entry-sample-en',
      () => BidDetailScreen(
        bidId: _bidId,
        freightStream: Stream.value(_openBid),
        bidsStream: Stream.value(<Map<String, dynamic>>[]).asBroadcastStream(),
      ),
      const Locale('en'),
    ),
    (
      'bid-entry-sample-hi',
      () => BidDetailScreen(
        bidId: _bidId,
        freightStream: Stream.value(_openBid),
        bidsStream: Stream.value(<Map<String, dynamic>>[]).asBroadcastStream(),
      ),
      const Locale('hi'),
    ),
    (
      'dispatch-sample-en',
      () => AfterbidScreen(
        bidId: _dispatchId,
        freightStream: Stream.value(_dispatchFreight),
      ),
      const Locale('en'),
    ),
    (
      'dispatch-sample-hi',
      () => AfterbidScreen(
        bidId: _dispatchId,
        freightStream: Stream.value(_dispatchFreight),
      ),
      const Locale('hi'),
    ),
    (
      'delivery-sample-en',
      () => AfterbidScreen(
        bidId: _deliveryId,
        freightStream: Stream.value(_deliveryFreight),
      ),
      const Locale('en'),
    ),
    (
      'delivery-sample-hi',
      () => AfterbidScreen(
        bidId: _deliveryId,
        freightStream: Stream.value(_deliveryFreight),
      ),
      const Locale('hi'),
    ),
    (
      'multi-stop-delivery-en',
      () => AfterbidScreen(
        bidId: _multiStopId,
        freightStream: Stream.value(_multiStopFreight),
      ),
      const Locale('en'),
    ),
    (
      'multi-stop-delivery-hi',
      () => AfterbidScreen(
        bidId: _multiStopId,
        freightStream: Stream.value(_multiStopFreight),
      ),
      const Locale('hi'),
    ),
    (
      'multi-stop-documents-en',
      () => AfterbidScreen(
        bidId: _multiStopId,
        freightStream: Stream.value(_multiStopFreight),
      ),
      const Locale('en'),
    ),
  ];

  for (final (name, createScreen, locale) in screens) {
    for (final desktop in [false, true]) {
      final captureName = '$name${desktop ? '-desktop' : ''}';

      testWidgets('$captureName screenshot', (tester) async {
        final screen = createScreen();
        tester.view
          ..physicalSize =
              desktop
                  ? const Size(1440, 1000)
                  : name.startsWith('multi-stop-delivery')
                  ? const Size(780, 2400)
                  : const Size(780, 1688)
          ..devicePixelRatio = desktop ? 1 : 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            theme: buildAppTheme(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: RepaintBoundary(
              key: key,
              child: Stack(
                children: [
                  screen,
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      color: Color(0xFFFFF2CC),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          'SAMPLE DATA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        for (var attempt = 0; attempt < 50; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 250));
          if (find.textContaining('Sample Depot').evaluate().isNotEmpty) break;
        }
        expect(
          find.textContaining('Sample Depot'),
          findsWidgets,
          reason: 'Sample freight did not load for $name',
        );
        if (name.startsWith('bid-entry')) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -360));
          await tester.pump(const Duration(milliseconds: 300));
        }
        if (name.startsWith('multi-stop-delivery')) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -610));
          await tester.pump(const Duration(milliseconds: 300));
        }
        if (name == 'multi-stop-documents-en') {
          await tester.drag(find.byType(ListView).first, const Offset(0, -980));
          await tester.pump(const Duration(milliseconds: 300));
        }
        if (name.startsWith('multi-stop')) {
          expect(find.text('OIL-101'), findsNothing);
          expect(find.text('OIL-102'), findsNothing);
          expect(find.text('Goods invoice / challan numbers'), findsNothing);
          expect(
            find.text('Add Goods invoice / challan numbers'),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            Uri.file(
              '${Directory.current.path}/docs/guides/screenshots/transporter/$captureName.png',
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

final _openBid = {
  'id': _bidId,
  'record_origin': 'live',
  'created_at': DateTime.now().toIso8601String(),
  'bid_opens_at':
      DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
  'bid_closes_at':
      DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'origin': 'Sample Depot',
  'destination_town': 'Example Town',
  'cases': 120,
  'weight_kg': 8,
  'base_freight': 12500,
  'status': 'bidding',
  'delivery_stages': <String, Object>{},
};

final _dispatchFreight = {
  'id': _dispatchId,
  'record_origin': 'live',
  'created_at': DateTime.now().toIso8601String(),
  'origin': 'Sample Depot',
  'destination_town': 'Example Town',
  'cases': 120,
  'weight_kg': 8,
  'base_freight': 12500,
  'status': 'locked',
  'delivery_stages': <String, Object>{},
};

final _deliveryFreight = {
  'id': _deliveryId,
  'record_origin': 'live',
  'created_at': DateTime.now().toIso8601String(),
  'origin': 'Sample Depot',
  'destination_town': 'Example Town',
  'cases': 120,
  'weight_kg': 8,
  'base_freight': 12500,
  'status': 'dispatched',
  'vehicle_number': 'SAMPLE-TRUCK-01',
  'driver_name': 'Sample Driver',
  'driver_phone': '0000000000',
  'delivery_stages': {
    'dispatched': {
      'lorry_number': 'SAMPLE-TRUCK-01',
      'driver_name': 'Sample Driver',
      'driver_phone': '0000000000',
    },
    'vehicle_confirmation': {'status': 'confirmed'},
    'pickup': {'driver_phone': '0000000000'},
  },
};

final _multiStopFreight = {
  'id': _multiStopId,
  'record_origin': 'live',
  'created_at': DateTime.now().toIso8601String(),
  'origin': 'Sample Depot',
  'destination_town': 'Amritsar',
  'stop_details': [
    {'name': 'Karnal', 'cases': 60, 'weight_kg': 4},
    {'name': 'Amritsar', 'cases': 60, 'weight_kg': 4},
  ],
  'cases': 120,
  'weight_kg': 8,
  'base_freight': 12500,
  'status': 'dispatched',
  'vehicle_number': 'SAMPLE-TRUCK-01',
  'driver_name': 'Sample Driver',
  'driver_phone': '0000000000',
  'delivery_stages': {
    'dispatched': {
      'lorry_number': 'SAMPLE-TRUCK-01',
      'driver_name': 'Sample Driver',
      'driver_phone': '0000000000',
    },
    'vehicle_confirmation': {'status': 'confirmed'},
    'pickup': {'driver_phone': '0000000000'},
    'in_transit': {'last_location': 'Sample Checkpoint'},
    'delivered_stops': [
      {
        'stop_index': 0,
        'destination': 'Karnal',
        'receiver_name': 'Sample Receiver',
        'receiver_phone': '0000000000',
        'invoice_numbers': ['OIL-101', 'OIL-102'],
        'gr_numbers': ['GR-101', 'GR-102'],
        'e_way_bill_numbers': ['EWB-101', 'EWB-102'],
        'pod_photo_path': 'sample/pod-karnal.png',
        'submitted_at': DateTime.now().toIso8601String(),
      },
    ],
  },
};
