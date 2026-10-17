import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/admin/admin_ai_body.dart';
import 'package:kaysons_logistics/features/admin/admin_dashboard_body.dart';
import 'package:kaysons_logistics/features/admin/admin_users_body.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

final _dashboardSnapshot = {
  'period': {'period_start': '2026-10-01', 'period_end': '2026-10-31'},
  'totals': {
    'dispatches': 254,
    'cases': 987654321,
    'metric_tons': 98765.432,
    'freight': 1234567890.0,
    'pod_pending': 123,
    'pod_received': 456,
    'review_value': 987654321.0,
  },
  'risk_summary': {
    'open_alerts': 4,
    'duplicate_eway_risks': 2,
    'route_cost_spike_risks': 3,
    'high_extra_charge_risks': 4,
  },
  'transporter_rankings': [
    {
      'transporter_name': 'Northern Cooperative Logistics',
      'dispatches': 254,
      'metric_tons': 98765.432,
      'freight': 1234567890.0,
      'pod_pending': 123,
    },
  ],
  'route_rankings': [
    {
      'route': 'Ludhiana to Agartala',
      'dispatches': 254,
      'freight_per_mt': 9876543.21,
    },
  ],
  'destination_rankings': [
    {'destination': 'Agartala', 'dispatches': 254, 'pod_pending': 123},
  ],
  'pod_aging': {
    'by_transporter': [
      {
        'transporter_name': 'Northern Cooperative Logistics',
        'pending': 123,
        'value': 987654321.0,
      },
    ],
    'by_destination': [],
  },
  'trend': [],
};

final _pendingProfile = {
  'id': '11111111-1111-4111-8111-111111111111',
  'full_name': 'Pending Transporter With A Long Name',
  'business_name': 'Northern Cooperative Logistics',
  'email': 'operations@example.test',
  'phone': '+91 98765 43210',
  'role': 'transporter',
  'status': 'pending',
  'manager_id': null,
  'created_at': '2026-10-17T10:00:00Z',
};

final _anomalies = [
  {
    'id': 'risk-1',
    'signal_type': 'duplicate_eway',
    'severity': 'high',
    'entity_type': 'route',
    'status': 'open',
    'company_name': 'Northern Cooperative Logistics',
    'route_key': 'Ludhiana to Agartala',
    'evidence': <String, dynamic>{},
    'metrics': <String, dynamic>{},
    'detected_at': '2026-10-17T10:00:00Z',
    'business_priority_score': 97,
  },
];

MockClient _offlineClient() => MockClient((request) async {
  final path = request.url.path;
  Object body = <String, dynamic>{};
  if (path.endsWith('/rpc/clawd_admin_snapshot')) {
    body = _dashboardSnapshot;
  } else if (path.endsWith('/profiles')) {
    body = [_pendingProfile];
  } else if (path.endsWith('/ai_prompt_templates') ||
      path.endsWith('/ai_reports')) {
    body = <Object>[];
  } else if (path.endsWith('/ai_anomaly_events')) {
    body = _anomalies;
  }
  return http.Response(
    jsonEncode(body),
    200,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
});

Future<void> _mount(WidgetTester tester, Widget body, String locale) async {
  tester.view
    ..physicalSize = const Size(320, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
      home: Scaffold(body: body),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _revealAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  final targetFinder = target.first;
  await tester.ensureVisible(targetFinder);
  await Scrollable.ensureVisible(
    tester.element(targetFinder),
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await tester.tap(targetFinder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, filename) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File('test/assets/fonts/$filename').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    await Supabase.initialize(
      url: 'https://offline-admin.invalid',
      anonKey: 'offline-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: _offlineClient(),
    );
  });

  tearDown(() async {
    await Supabase.instance.client.removeAllChannels();
    await Supabase.instance.client.realtime.disconnect();
  });

  for (final locale in ['en', 'hi']) {
    testWidgets('dashboard phone layout $locale at 150% text keeps totals', (
      tester,
    ) async {
      await _mount(tester, const AdminDashboardBody(), locale);
      expect(tester.takeException(), isNull);

      final month =
          AppLocalizations.of(
            tester.element(find.byType(AdminDashboardBody)),
          )!.adminMonth;
      expect(month, isNotEmpty);
      expect(
        find.byTooltip(locale == 'hi' ? 'अवधि बदलें' : 'Change period'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip(locale == 'hi' ? 'अवधि बदलें' : 'Change period'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(month).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month-picker-selection')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('month-picker-cancel')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('₹123.46 Cr'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('₹123.46 Cr'), findsWidgets);
      expect(tester.takeException(), isNull);

      final morePriorities = find.textContaining(
        locale == 'hi' ? 'अन्य ज़रूरतें' : 'More priorities',
      );
      if (morePriorities.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          morePriorities.first,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(morePriorities.first);
        await tester.tap(morePriorities.first);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('users phone review stays usable $locale at 150% text', (
      tester,
    ) async {
      await _mount(tester, const AdminUsersBody(), locale);
      expect(find.text('Pending Transporter With A Long Name'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Pending Transporter With A Long Name'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Clawd phone details expand without overflow $locale at 150%', (
      tester,
    ) async {
      await _mount(tester, const AdminAiBody(), locale);
      expect(tester.takeException(), isNull);

      final moreSignals = find.text(
        locale == 'hi' ? 'अन्य जोखिम संकेत' : 'More risk signals',
      );
      await _revealAndTap(tester, moreSignals);
      expect(tester.takeException(), isNull);

      final queueTitle = find.textContaining(
        locale == 'hi' ? 'खुली समीक्षा सूची' : 'Open review queue',
      );
      await _revealAndTap(tester, queueTitle);
      expect(
        find.textContaining(
          locale == 'hi' ? 'डुप्लिकेट ई-वे बिल जोखिम' : 'duplicate eway',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final toolsTitle = find.text(
        locale == 'hi'
            ? 'रिपोर्ट और सहेजे गए प्रश्न'
            : 'Reports & saved prompts',
      );
      await _revealAndTap(tester, toolsTitle);
      final advanced = find.text(
        locale == 'hi'
            ? 'सवाल की अतिरिक्त सेटिंग'
            : 'Advanced question settings',
      );
      await _revealAndTap(tester, advanced);
      expect(tester.takeException(), isNull);
    });
  }
}
