import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaysons_logistics/features/transporter/drivers_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final writes = <Map<String, dynamic>>[];
  var failSave = false;
  setUp(() {
    writes.clear();
    failSave = false;
  });
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    await Supabase.initialize(
      url: 'https://driver.test',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token':
                  'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': '11111111-1111-1111-1111-111111111111', 'role': 'authenticated', 'exp': 2000000000}))).replaceAll('=', '')}.signature',
              'refresh_token': 'test-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': '11111111-1111-1111-1111-111111111111',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 'driver@test.invalid',
                'created_at': '2026-10-05T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          if (failSave) {
            return http.Response(
              jsonEncode({
                'message': 'Driver save unavailable',
                'code': 'TEST',
              }),
              400,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '',
            201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(writes.map((row) => {...row, 'id': 'driver-1'}).toList()),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'driver@test.invalid',
      password: 'test',
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets(
    'transporter can save a driver with keyboard open on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DriversScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add driver'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'QA Driver');
      await tester.enterText(find.byType(TextField).at(2), '9876543210');
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Save driver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save driver'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single['phone'], '+919876543210');
      expect(find.byType(BottomSheet), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('QA Driver'), findsOneWidget);
    },
  );
  testWidgets(
    'validation and failed saves are visible in the form and allow retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DriversScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add driver'));
      await tester.pumpAndSettle();
      Future<void> save() async {
        await tester.ensureVisible(find.text('Save driver'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save driver'));
        await tester.pumpAndSettle();
      }

      await save();
      final error = find.byKey(const ValueKey('driver-save-error'));
      expect(error, findsOneWidget);
      expect(
        find.ancestor(of: error, matching: find.byType(BottomSheet)),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.enterText(find.byType(TextField).at(1), 'QA Driver');
      await tester.enterText(find.byType(TextField).at(2), '123');
      await save();
      expect(error, findsOneWidget);
      expect(writes, isEmpty);
      await tester.enterText(find.byType(TextField).at(2), '');
      failSave = true;
      await save();
      expect(find.textContaining('Driver save unavailable'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      failSave = false;
      await save();
      expect(writes, hasLength(1));
      expect(writes.single['phone'], isNull);
      expect(writes.single['licence_number'], isNull);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}
