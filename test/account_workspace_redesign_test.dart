import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/account/account_privacy_screen.dart';
import 'package:kaysons_logistics/features/admin/admin_profile_screen.dart';
import 'package:kaysons_logistics/features/auth/phone_link_screen.dart';
import 'package:kaysons_logistics/features/auth/phone_registration_screen.dart';
import 'package:kaysons_logistics/features/transporter/profile_screen.dart';
import 'package:kaysons_logistics/features/logistics_manager/lm_profile_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const sampleId = '00000000-0000-4000-8000-000000000101';
String sampleRole = 'transporter';
int directoryReads = 0;
final sampleProfile = <String, dynamic>{
  'id': sampleId,
  'full_name': 'Sample Manager',
  'business_name': 'Sample Transport',
  'email': 'sample@example.invalid',
  'status': 'approved',
  'phone': '+919876543210',
  'coverage_area': 'Karnal, Haryana',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, file) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('Inter', 'Inter-Bold.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagari-Bold.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File('test/assets/fonts/$file').readAsBytes();
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
      url: 'https://sample.invalid',
      anonKey: 'sample-key',
      debug: false,
      httpClient: MockClient((request) async {
        final single = (request.headers['accept'] ?? '').contains(
          'object+json',
        );
        Object? body = <Object>[];
        if (request.url.path.endsWith('/profiles')) {
          final row = {...sampleProfile, 'role': sampleRole};
          if (request.url.queryParameters.containsKey('id')) {
            body = single ? row : [row];
          } else {
            directoryReads++;
            body = [
              for (var i = 0; i < 20; i++)
                {
                  ...row,
                  'id': '$sampleId-$i',
                  'business_name': 'Transport $i',
                  'full_name': 'Driver Contact $i',
                },
            ];
          }
        } else if (request.url.path.endsWith('/vehicles')) {
          body = [
            for (var i = 0; i < 20; i++)
              {
                'id': 'sample-vehicle-$i',
                'registration_number': 'HR45 $i',
                'profile_id': sampleId,
                'vehicle_type': 'Truck',
                'capacity_qt': 50,
                'capacity_weight_kg': 2.5,
                'status': 'active',
              },
          ];
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
          'id': sampleId,
          'email': 'sample@example.invalid',
          'phone': '+919876543210',
          'phone_confirmed_at': '2026-10-01T00:00:00Z',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  final pages = <(String, String, Widget Function())>[
    (
      'transporter-profile',
      'transporter',
      () => const TransporterProfileScreen(),
    ),
    ('manager-profile', 'logistics_manager', () => const LmProfileScreen()),
    ('dispatch-profile', 'dispatch_manager', () => const LmProfileScreen()),
    ('admin-profile', 'admin', () => const AdminProfileScreen()),
    ('accountant-profile', 'accountant', () => const AdminProfileScreen()),
    (
      'transporter-directory',
      'logistics_manager',
      () => const LmTransporterDirectoryScreen(),
    ),
    (
      'vehicle-directory',
      'logistics_manager',
      () => const LmVehicleDirectoryScreen(),
    ),
    ('account-privacy', 'transporter', () => const AccountPrivacyScreen()),
    ('phone-settings', 'transporter', () => const PhoneLinkScreen()),
    (
      'phone-registration',
      'transporter',
      () => const PhoneRegistrationScreen(),
    ),
  ];
  for (final (name, role, page) in pages) {
    for (final language in ['en', 'hi']) {
      for (final desktop in [false, true]) {
        testWidgets(
          '$name $language ${desktop ? 'laptop' : 'phone'} readable task layout',
          (tester) async {
            sampleRole = role;
            tester.view
              ..physicalSize =
                  desktop ? const Size(1440, 1000) : const Size(390, 844)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            final router = GoRouter(
              initialLocation: '/sample',
              routes: [
                GoRoute(path: '/sample', builder: (_, _) => page()),
                GoRoute(
                  path: '/account/phone',
                  builder: (_, _) => const PhoneLinkScreen(),
                ),
                GoRoute(
                  path: '/welcome',
                  builder: (_, _) => const Scaffold(body: Text('Welcome')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp.router(
                  routerConfig: router,
                  theme: buildAppTheme(),
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  debugShowCheckedModeBanner: false,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (name == 'transporter-directory') {
              final reads = directoryReads;
              await tester.enterText(find.byType(TextField), 'Transport 19');
              await tester.pumpAndSettle();
              expect(
                find.byWidgetPredicate(
                  (w) => w is Text && w.data == 'Transport 19',
                ),
                findsOneWidget,
              );
              expect(find.text('Transport 0'), findsNothing);
              expect(
                directoryReads,
                reads,
                reason: 'typing should filter the cached directory',
              );
            }
            if (name == 'transporter-profile') {
              await tester.ensureVisible(
                find.text(
                  language == 'hi'
                      ? 'बैंक जानकारी (वैकल्पिक)'
                      : 'Bank details (optional)',
                ),
              );
              await tester.tap(
                find.text(
                  language == 'hi'
                      ? 'बैंक जानकारी (वैकल्पिक)'
                      : 'Bank details (optional)',
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.text(language == 'hi' ? 'खाताधारक' : 'Account holder'),
                findsOneWidget,
              );
            }
            await tester.runAsync(
              () => capture(
                key,
                '$name-$language-${desktop ? 'laptop' : 'phone'}',
              ),
            );
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}

Future<void> capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('output/ui-redesign/accounts/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}
