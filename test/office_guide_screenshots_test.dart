import 'package:kaysons_logistics/core/theme/app_theme.dart';
// Run with: flutter test test/office_guide_screenshots_test.dart --update-goldens
// Captures actual office widgets against an isolated, in-memory sample API.
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:kaysons_logistics/features/admin/accountant_shell.dart';
import 'package:kaysons_logistics/features/admin/admin_profile_screen.dart';
import 'package:kaysons_logistics/features/admin/admin_shell.dart';
import 'package:kaysons_logistics/features/admin/notifications_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const _directory = 'docs/guides/screenshots/office';
const _sampleId = '00000000-0000-4000-8000-000000000001';
String _sampleRole = 'admin';
bool _showPendingUser = false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<void> loadFont(String family, String fileName) async {
      final bytes = await File('test/assets/fonts/$fileName').readAsBytes();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }

    await loadFont('Inter', 'Inter-Regular.ttf');
    await loadFont('Inter', 'Inter-Bold.ttf');
    await loadFont('Roboto', 'Roboto-Regular.ttf');
    await loadFont('Roboto', 'Roboto-Bold.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Bold.ttf');
    final iconBytes =
        await File('test/assets/fonts/MaterialIcons-Regular.otf').readAsBytes();
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
        Object body = [];
        if (path.endsWith('/rpc/clawd_admin_snapshot')) {
          body = _sampleSnapshot;
        } else if (path.endsWith('/admin_freight_ledger_view')) {
          body = [_sampleLedgerRow];
        } else if (path.endsWith('/profiles')) {
          if (request.url.queryParameters['role'] == 'eq.transporter') {
            body = [
              {
                ..._sampleProfile,
                'id': '00000000-0000-4000-8000-000000000004',
                'full_name': 'Sample Transport',
                'role': 'transporter',
              },
            ];
          } else {
            body = [
              {..._sampleProfile, 'role': _sampleRole},
              if (_showPendingUser &&
                  !request.url.queryParameters.containsKey('id'))
                {
                  ..._sampleProfile,
                  'id': '00000000-0000-4000-8000-000000000005',
                  'full_name': 'Sample Pending User',
                  'role': 'transporter',
                  'status': 'pending',
                },
            ];
          }
        } else if (path.endsWith('/admin_alerts')) {
          body = [_sampleAlert];
        } else if (path.endsWith('/freights')) {
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
          'id': _sampleId,
          'email': 'reviewer@example.invalid',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });

  for (final locale in const [Locale('en'), Locale('hi')]) {
    for (final desktop in [false, true]) {
      final language = locale.languageCode;
      for (final (role, index, name) in <(String, int, String)>[
        ('administrator', 0, 'dashboard'),
        ('administrator', 1, 'users'),
        ('administrator', 2, 'bids'),
        ('administrator', 3, 'ledger'),
        ('administrator', 4, 'clawd'),
        ('accountant', 0, 'ledger'),
        ('accountant', 1, 'analytics'),
        ('accountant', 2, 'clawd'),
      ]) {
        testWidgets(
          '$role $name $language ${desktop ? 'desktop' : 'mobile'} sample screenshot',
          (tester) async {
            _sampleRole = role == 'administrator' ? 'admin' : 'accountant';
            tester.view
              ..physicalSize =
                  desktop ? const Size(1440, 1000) : const Size(780, 1688)
              ..devicePixelRatio = desktop ? 1 : 2;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final captureKey = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: RepaintBoundary(
                  key: captureKey,
                  child: Stack(
                    children: [
                      role == 'administrator'
                          ? AdminShell(initialIndex: index)
                          : AccountantShell(initialIndex: index),
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
                  tester.element(find.byKey(captureKey)),
                );
              }
            });
            await tester.pump();

            await tester.pump(const Duration(milliseconds: 500));
            if (name == 'ledger') {
              await tester.tap(
                find.text(language == 'hi' ? 'रिकॉर्ड' : 'Records').first,
              );
              await tester.pump(const Duration(milliseconds: 300));
            }
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(captureKey),
              matchesGoldenFile(
                Uri.file(
                  '${Directory.current.path}/$_directory/$role-$name-$language${desktop ? '-desktop' : ''}.png',
                ),
              ),
            );
            await tester.pumpWidget(const SizedBox.shrink());
            await Supabase.instance.client.removeAllChannels();
            await Supabase.instance.client.realtime.disconnect();
            await tester.pump(const Duration(seconds: 2));
          },
        );
      }
      for (final role in const ['administrator', 'accountant']) {
        for (final name in const ['notifications', 'profile']) {
          testWidgets(
            '$role $name $language ${desktop ? 'desktop' : 'mobile'} sample screenshot',
            (tester) async {
              _sampleRole = role == 'administrator' ? 'admin' : 'accountant';
              tester.view
                ..physicalSize =
                    desktop ? const Size(1440, 1000) : const Size(780, 1688)
                ..devicePixelRatio = desktop ? 1 : 2;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final captureKey = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  locale: locale,
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: RepaintBoundary(
                    key: captureKey,
                    child: Stack(
                      children: [
                        name == 'notifications'
                            ? const NotificationsScreen()
                            : const AdminProfileScreen(),
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
              await tester.pump(const Duration(milliseconds: 500));
              expect(tester.takeException(), isNull);
              await expectLater(
                find.byKey(captureKey),
                matchesGoldenFile(
                  Uri.file(
                    '${Directory.current.path}/$_directory/$role-$name-$language${desktop ? '-desktop' : ''}.png',
                  ),
                ),
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await Supabase.instance.client.removeAllChannels();
              await Supabase.instance.client.realtime.disconnect();
              await tester.pump(const Duration(seconds: 2));
            },
          );
        }
      }

      for (final role in const ['administrator', 'accountant']) {
        for (final feature in const ['entry', 'export-menu']) {
          testWidgets(
            '$role ledger $feature $language ${desktop ? 'desktop' : 'mobile'} sample screenshot',
            (tester) async {
              _sampleRole = role == 'administrator' ? 'admin' : 'accountant';
              _showPendingUser = false;
              tester.view
                ..physicalSize =
                    desktop ? const Size(1440, 1000) : const Size(780, 1688)
                ..devicePixelRatio = desktop ? 1 : 2;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final captureKey = GlobalKey();
              await tester.pumpWidget(
                RepaintBoundary(
                  key: captureKey,
                  child: MaterialApp(
                    locale: locale,
                    debugShowCheckedModeBanner: false,
                    theme: _captureTheme(),
                    supportedLocales: AppLocalizations.supportedLocales,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    home: Stack(
                      children: [
                        role == 'administrator'
                            ? const AdminShell(initialIndex: 3)
                            : const AccountantShell(initialIndex: 0),
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
              await tester.pump(const Duration(milliseconds: 500));
              if (feature == 'entry') {
                await tester.tap(
                  find
                      .text(language == 'hi' ? 'एंट्री जोड़ें' : 'Add entry')
                      .first,
                );
              } else {
                await tester.tap(
                  find.text(language == 'hi' ? 'रिपोर्ट' : 'Reports').first,
                );
                await tester.pump(const Duration(milliseconds: 300));
                await tester.tap(
                  find.byTooltip(
                    language == 'hi'
                        ? 'रिपोर्ट निर्यात करें'
                        : 'Export reports',
                  ),
                );
              }
              await tester.pump(const Duration(milliseconds: 500));
              await tester.pump(const Duration(milliseconds: 500));
              expect(tester.takeException(), isNull);
              await expectLater(
                find.byKey(captureKey),
                matchesGoldenFile(
                  Uri.file(
                    '${Directory.current.path}/$_directory/$role-ledger-$feature-$language${desktop ? '-desktop' : ''}.png',
                  ),
                ),
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await Supabase.instance.client.removeAllChannels();
              await Supabase.instance.client.realtime.disconnect();
              await tester.pump(const Duration(seconds: 2));
            },
          );
        }
      }

      testWidgets(
        'administrator pending user review $language ${desktop ? 'desktop' : 'mobile'} sample screenshot',
        (tester) async {
          _sampleRole = 'admin';
          _showPendingUser = true;
          tester.view
            ..physicalSize =
                desktop ? const Size(1440, 1000) : const Size(780, 1688)
            ..devicePixelRatio = desktop ? 1 : 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                locale: locale,
                debugShowCheckedModeBanner: false,
                theme: _captureTheme(),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Stack(
                  children: [
                    const AdminShell(initialIndex: 1),
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
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(find.byType(Tab).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sample Pending User'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(captureKey),
            matchesGoldenFile(
              Uri.file(
                '${Directory.current.path}/$_directory/administrator-user-review-$language${desktop ? '-desktop' : ''}.png',
              ),
            ),
          );
          _showPendingUser = false;
          await tester.pumpWidget(const SizedBox.shrink());
          await Supabase.instance.client.removeAllChannels();
          await Supabase.instance.client.realtime.disconnect();
          await tester.pump(const Duration(seconds: 2));
        },
      );
    }
  }
}

ThemeData _captureTheme() => buildAppTheme();

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

final _sampleProfile = {
  'id': _sampleId,
  'full_name': 'Sample Reviewer',
  'business_name': 'Example Transport',
  'email': 'reviewer@example.invalid',
  'role': 'admin',
  'status': 'approved',
  'manager_id': null,
};

final _sampleLedgerRow = {
  'id': _sampleId,
  'freight_id': _sampleId,
  'invoice_id': '00000000-0000-4000-8000-000000000002',
  'created_at': '2026-09-23T10:00:00+05:30',
  'bill_date': DateTime.now().toIso8601String().substring(0, 10),
  'dispatch_date': DateTime.now().toIso8601String().substring(0, 10),
  'company_name': 'Example Company',
  'transporter_name': 'Sample Transport',
  'town': 'Example Town',
  'origin': 'Sample Depot',
  'vehicle_number': 'SAMPLE-VEHICLE',
  'invoice_number': 'SAMPLE-001',
  'cases': 120,
  'weight_kg': 8.5,
  'total_freight': 12500,
  'balance': 2500,
  'pod_status': 'pending',
  'ack_status': 'pending',
  'status': 'completed',
};

final _sampleSnapshot = {
  'period': {
    'period_start': DateTime.now().toIso8601String().substring(0, 10),
    'period_end': DateTime.now().toIso8601String().substring(0, 10),
  },
  'totals': {
    'dispatches': 12,
    'cases': 120,
    'metric_tons': 8.5,
    'freight': 12500,
    'pod_pending': 2,
    'pod_received': 10,
    'review_value': 2500,
  },
  'risk_summary': {
    'open_alerts': 1,
    'duplicate_eway_risks': 0,
    'high_extra_charge_risks': 0,
    'route_cost_spike_risks': 0,
  },
  'company_totals': <Object>[],
  'transporter_rankings': <Object>[],
  'destination_rankings': <Object>[],
  'route_rankings': <Object>[],
  'pod_aging': {'by_transporter': <Object>[], 'by_destination': <Object>[]},
  'trend': <Object>[],
};

final _sampleAlert = {
  'id': '00000000-0000-4000-8000-000000000003',
  'freight_id': _sampleId,
  'invoice_id': null,
  'category': 'pod_pending',
  'severity': 'medium',
  'title': 'Sample POD reminder',
  'message': 'Review the sample delivery document.',
  'status': 'open',
  'created_at': '2026-09-23T10:00:00+05:30',
  'resolved_at': null,
};
