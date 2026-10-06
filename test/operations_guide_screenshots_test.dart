import 'package:kaysons_logistics/core/theme/app_theme.dart';
// Regenerate with: flutter test test/operations_guide_screenshots_test.dart --update-goldens
// These are real Flutter role screens backed only by an in-memory sample API.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';
import 'package:kaysons_logistics/features/dispatch_manager/dispatch_shell.dart';
import 'package:kaysons_logistics/features/logistics_manager/bid_management_screen.dart';
import 'package:kaysons_logistics/features/logistics_manager/bid_setup_screen.dart';
import 'package:kaysons_logistics/features/logistics_manager/invoice_link_screen.dart';
import 'package:kaysons_logistics/features/logistics_manager/lm_bodies.dart';
import 'package:kaysons_logistics/features/logistics_manager/lm_dispatch_team_body.dart';
import 'package:kaysons_logistics/features/logistics_manager/lm_track_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'package:kaysons_logistics/features/transporter/home_screen.dart';

const _bidId = '00000000-0000-4000-8000-000000000002';
const _dispatchId = '00000000-0000-4000-8000-000000000003';
const _multiStopId = '00000000-0000-4000-8000-000000000004';
const _transporterId = '00000000-0000-4000-8000-000000000005';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Future<void> loadFont(String family, String fileName) async {
      final bytes = await File('test/assets/fonts/$fileName').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont('Inter', 'Inter-Regular.ttf');
    await loadFont('Inter', 'Inter-Bold.ttf');
    await loadFont('Roboto', 'Roboto-Regular.ttf');
    await loadFont('Roboto', 'Roboto-Bold.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Bold.ttf');
    final iconBytes =
        await File(
          '/Users/ayushmansingh/.codex-toolcache/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
    await (FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (call) async => null,
        );
    await Supabase.initialize(
      url: 'https://sample.invalid',
      anonKey: 'sample-publishable-key',
      debug: false,
      realtimeClientOptions: RealtimeClientOptions(
        transport: (_, __) => _SampleWebSocketChannel(),
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        final single = (request.headers['accept'] ?? '').contains(
          'object+json',
        );
        Object body = <Object>[];
        if (path.endsWith('/freights')) {
          final rows = [_openBid, _dispatchFreight, _multiStopFreight];
          final id = request.url.queryParameters['id'];
          final selected =
              id == null
                  ? rows
                  : rows.where((row) => 'eq.${row['id']}' == id).toList();
          body =
              single
                  ? (selected.isEmpty ? <String, Object>{} : selected.first)
                  : selected;
        } else if (path.endsWith('/profiles')) {
          body = single ? _sampleProfile : [_sampleProfile];
        } else if (path.endsWith('/bids')) {
          body = <Object>[];
        } else if (path.endsWith('/admin_freight_ledger_view')) {
          body = [_sampleLedgerRow];
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'exp':
                  DateTime.now()
                      .add(const Duration(days: 2))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'sample.$payload.signature',
        'token_type': 'bearer',
        'user': {
          'id': '00000000-0000-4000-8000-000000000001',
          'email': 'reviewer@example.invalid',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });

  final screens = <(String, Widget)>[
    ('transporter-home-refresh', const TransporterHomeBody()),
    ('transporter-home-refresh-hi', const TransporterHomeBody()),
    ('logistics-dashboard', const LmDashboardBody()),
    ('logistics-bids', const LmBidsBody()),
    ('logistics-new-bid', const BidSetupScreen()),
    ('logistics-bid-detail', const BidManagementScreen(bidId: _bidId)),
    ('logistics-fleet', const LmFleetBody()),
    ('logistics-invoice-lock', const InvoiceLinkScreen(bidId: _dispatchId)),
    (
      'logistics-multi-invoice-saved',
      InvoiceLinkScreen(
        bidId: _dispatchId,
        invoiceStateLoader:
            (_) async => {
              'status': 'locked',
              'charges': <Map<String, dynamic>>[],
              'invoices': [
                {
                  'invoice_number': 'OIL-101',
                  'party_name': 'Sample Retailer',
                  'town': 'Karnal',
                  'gr_bilty_numbers': ['GR-101', 'GR-102'],
                  'e_way_bill_numbers': ['EWB-101', 'EWB-102'],
                },
                {
                  'invoice_number': 'VEG-202',
                  'party_name': 'Sample Retailer',
                  'town': 'Amritsar',
                  'gr_bilty_numbers': ['GR-202'],
                  'e_way_bill_numbers': ['EWB-202'],
                },
              ],
            },
      ),
    ),
    ('logistics-tracking', const LmTrackScreen(freightId: _dispatchId)),
    (
      'logistics-multi-stop-tracking',
      const LmTrackScreen(freightId: _multiStopId),
    ),
    ('logistics-dispatch-team', const LmDispatchTeamBody()),
    ('logistics-ledger', const AdminLedgerBody()),
    ('dispatch-today', const DispatchDashboardBody()),
    ('dispatch-deliveries', const DispatchFleetBody()),
    (
      'dispatch-tracking',
      const LmTrackScreen(freightId: _dispatchId, dispatchManagerMode: true),
    ),
    (
      'dispatch-multi-stop-tracking',
      const LmTrackScreen(freightId: _multiStopId, dispatchManagerMode: true),
    ),
  ];

  for (final (name, screen) in screens) {
    for (final desktop in [false, true]) {
      final captureName = '$name${desktop ? '-desktop' : ''}';

      testWidgets('$captureName screenshot with sample data', (tester) async {
        tester.view
          ..physicalSize =
              desktop
                  ? const Size(1440, 1000)
                  : name.endsWith('multi-stop-tracking')
                  ? const Size(780, 2200)
                  : const Size(780, 1688)
          ..devicePixelRatio = desktop ? 1 : 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale:
                name.endsWith('-hi') ? const Locale('hi') : const Locale('en'),
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: RepaintBoundary(
              key: key,
              child: Stack(
                children: [
                  Scaffold(body: screen),
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
        await tester.pump(const Duration(milliseconds: 500));
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

        await tester.pump(const Duration(milliseconds: 500));
        if (name.endsWith('multi-stop-tracking')) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -360));
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            Uri.file(
              '${Directory.current.path}/docs/guides/screenshots/operations/$captureName.png',
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await Supabase.instance.client.removeAllChannels();
        await Supabase.instance.client.realtime.disconnect();
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}

final _sampleProfile = {
  'id': _transporterId,
  'full_name': 'Sample Transporter',
  'business_name': 'Example Transport',
  'email': 'sample@example.invalid',
  'role': 'transporter',
  'status': 'approved',
};

final _openBid = {
  'id': _bidId,
  'record_origin': 'live',
  'created_at': DateTime.now().toIso8601String(),
  'bid_opens_at': null,
  'bid_closes_at': null,
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
  'status': 'dispatched',
  'winner_profile_id': _transporterId,
  'vehicle_number': 'DEMO-TRUCK-01',
  'driver_name': 'Sample Driver',
  'driver_phone': '0000000000',
  'delivery_stages': {
    'dispatched': {
      'lorry_number': 'DEMO-TRUCK-01',
      'driver_name': 'Sample Driver',
      'driver_phone': '0000000000',
    },
    'pickup': {'driver_phone': '0000000000'},
    'in_transit': {'last_location': 'Example Checkpoint'},
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
  'winner_profile_id': _transporterId,
  'vehicle_number': 'DEMO-TRUCK-01',
  'driver_name': 'Sample Driver',
  'driver_phone': '0000000000',
  'delivery_stages': {
    'dispatched': {
      'lorry_number': 'DEMO-TRUCK-01',
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

final _sampleLedgerRow = {
  'id': _dispatchId,
  'created_at': DateTime.now().toIso8601String(),
  'bill_date': DateTime.now().toIso8601String().substring(0, 10),
  'dispatch_date': DateTime.now().toIso8601String().substring(0, 10),
  'company_name': 'Example Company',
  'transporter_name': 'Sample Transporter',
  'town': 'Example Town',
  'origin': 'Sample Depot',
  'invoice_number': 'SAMPLE-001',
  'cases': 120,
  'weight_kg': 8,
  'total_freight': 12500,
  'balance': 2500,
  'pod_status': 'pending',
  'ack_status': 'pending',
  'status': 'dispatched',
};

class _SampleWebSocketChannel implements WebSocketChannel {
  final _events = StreamController<dynamic>.broadcast();
  late final WebSocketSink _sink = _SampleWebSocketSink(_events);
  @override
  Stream get stream => _events.stream;
  @override
  WebSocketSink get sink => _sink;
  @override
  Future<void> get ready => Future.value();
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SampleWebSocketSink implements WebSocketSink {
  _SampleWebSocketSink(this._events);
  final StreamController<dynamic> _events;
  @override
  void add(Object? data) {}
  @override
  Future<void> addStream(Stream stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _events.close();
  @override
  Future<void> get done => _events.done;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
