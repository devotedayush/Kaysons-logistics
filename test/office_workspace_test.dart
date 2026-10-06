import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';
import 'package:kaysons_logistics/features/admin/admin_users_body.dart';
import 'package:kaysons_logistics/features/admin/admin_ai_body.dart';
import 'package:kaysons_logistics/features/admin/admin_ai_service.dart';
import 'package:kaysons_logistics/features/admin/notifications_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const id = '11111111-1111-4111-8111-111111111111';
int alertReads = 0;
final sampleLedger = {
  'id': id,
  'freight_id': id,
  'invoice_id': 'invoice-1',
  'created_at': DateTime.now().toIso8601String(),
  'bill_date': DateTime.now().toIso8601String(),
  'dispatch_date': DateTime.now().toIso8601String(),
  'company_name': 'Example Company',
  'transporter_name': 'Sample Transport',
  'town': 'Lucknow',
  'origin': 'Ludhiana',
  'vehicle_number': 'PB10AB1234',
  'invoice_number': 'INV-001',
  'cases': 120,
  'weight_kg': 8.5,
  'total_freight': 12500,
  'balance': 2500,
  'pod_status': 'pending',
  'ack_status': 'pending',
  'status': 'completed',
};
final pendingPerson = {
  'id': id,
  'full_name': 'Sample Pending User',
  'role': 'transporter',
  'status': 'pending',
  'created_at': DateTime.now().toIso8601String(),
};

Future<void> mount(
  WidgetTester tester,
  Widget screen,
  Size size, {
  String locale = 'en',
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/qa/office-redesign/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Inter': ['Inter-Regular.ttf', 'Inter-Bold.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'MaterialIcons': ['MaterialIcons-Regular.otf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        final bytes = await File('test/assets/fonts/$name').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    await Supabase.initialize(
      url: 'https://office-test.invalid',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body = [];
        if (request.url.path.endsWith('/admin_freight_ledger_view')) {
          body = [sampleLedger];
        }
        if (request.url.path.endsWith('/profiles')) body = [pendingPerson];
        if (request.url.path.endsWith('/admin_alerts')) {
          alertReads++;
          body = [
            {
              'title': 'Missing delivery proof',
              'message': 'Review INV-001',
              'category': 'pod_pending',
              'severity': 'medium',
              'status': 'open',
              'created_at': DateTime.now().toIso8601String(),
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
  testWidgets(
    'phone ledger defaults to readable records with complete details one action away',
    (tester) async {
      await mount(tester, const AdminLedgerBody(), const Size(390, 844));
      expect(find.text('Records'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Edit ledger entry'), findsNothing);
      expect(find.text('Review delivery'), findsNothing);
      expect(find.textContaining('Ludhiana → Lucknow'), findsOneWidget);
      expect(find.textContaining('INV-001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'ledger-mobile-records');
      final action =
          find.text('Review').evaluate().isNotEmpty
              ? find.text('Review').first
              : find.text('Details').first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.textContaining('INV-001'), findsWidgets);
      expect(find.text('Edit ledger entry'), findsOneWidget);
      expect(find.text('Review delivery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('laptop records expose the full 29-column report through More', (
    tester,
  ) async {
    await mount(tester, const AdminLedgerBody(), const Size(1440, 1000));
    expect(find.text('Records'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    await capture(tester, 'ledger-laptop-records');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All columns'));
    await tester.pumpAndSettle();
    expect(tester.widget<DataTable>(find.byType(DataTable)).columns.length, 29);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'mobile manual entry and import forms fit with optional sections collapsed',
    (tester) async {
      await mount(tester, const AdminLedgerBody(), const Size(390, 844));
      await tester.ensureVisible(find.text('Add entry'));
      await tester.tap(find.text('Add entry'));
      await tester.pumpAndSettle();
      expect(find.text('Record the trip, then its invoices'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'ledger-mobile-entry');
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Import historical records'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'ledger-mobile-import');
    },
  );
  testWidgets('laptop user review table opens an actionable account dialog', (
    tester,
  ) async {
    await mount(tester, const AdminUsersBody(), const Size(1440, 1000));
    expect(find.byType(DataTable), findsOneWidget);
    await tester.tap(find.text('Review account'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'users-laptop-review');
  });
  testWidgets(
    'saved questions accept ordinary fields and preserve template inputs',
    (tester) async {
      final inputs = TextEditingController(text: '{"keep":42}');
      addTearDown(inputs.dispose);
      await mount(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: SavedQuestionInputs(
            template: const ClawdPromptTemplate(
              id: 'test',
              name: 'Review route',
              category: 'cost',
              templateText:
                  'Review {{route}} for {{company}}. Repeat {{route}}.',
            ),
            variables: inputs,
          ),
        ),
        const Size(390, 844),
      );
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Ludhiana to Lucknow',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Example Company',
      );
      expect(jsonDecode(inputs.text), {
        'keep': 42,
        'route': 'Ludhiana to Lucknow',
        'company': 'Example Company',
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('alert search and status filters reuse fetched records', (
    tester,
  ) async {
    await mount(tester, const NotificationsScreen(), const Size(390, 844));
    final reads = alertReads;
    await tester.enterText(find.byType(TextField), 'INV-001');
    await tester.pumpAndSettle();
    expect(find.text('Missing delivery proof'), findsOneWidget);
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();
    expect(alertReads, reads);
    expect(tester.takeException(), isNull);
    await capture(tester, 'alerts-mobile-filter');
  });
}
