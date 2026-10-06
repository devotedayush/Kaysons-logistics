import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaysons_logistics/core/supabase/auth_service.dart';
import 'package:kaysons_logistics/features/auth/enrollment_strings.dart';
import 'package:kaysons_logistics/features/auth/phone_registration_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

class FakeEnrollment implements PhoneRegistrationGateway {
  String status = 'pending';
  int sends = 0, verifies = 0, saves = 0, signOuts = 0;
  bool failSaveOnce = false;
  @override
  Future<void> send(String phone) async {
    sends++;
    expect(phone, '+919876543210');
  }

  @override
  Future<Map<String, dynamic>?> verify(String phone, String code) async {
    verifies++;
    return {'status': status};
  }

  @override
  Future<Map<String, dynamic>?> profile() async => {'status': status};
  @override
  Future<void> complete(String name, String email) async {
    saves++;
    if (failSaveOnce && saves == 1) throw StateError('temporary write failure');
  }

  @override
  Future<AppRole> approvedRole() async => AppRole.transporter;
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeEnrollment gateway, {
  String locale = 'en',
}) async {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, _) => PhoneRegistrationScreen(gateway: gateway),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Operations')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> send(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Test Transporter');
  await tester.enterText(find.byType(TextField).at(1), '9876543210');
  await tester.tap(find.byType(CheckboxListTile));
  await tester.ensureVisible(find.text('Send verification code'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send verification code'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '123456');
  await tester.tap(find.text('Complete registration'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('consent is required before sending SMS', (tester) async {
    final gateway = FakeEnrollment();
    await mount(tester, gateway);
    await tester.ensureVisible(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(gateway.sends, 0);
    expect(find.textContaining('accept the consent'), findsOneWidget);
  });
  testWidgets('retry after profile save failure reuses verified session', (
    tester,
  ) async {
    final gateway = FakeEnrollment()..failSaveOnce = true;
    await mount(tester, gateway);
    await send(tester);
    expect(gateway.verifies, 1);
    expect(gateway.saves, 1);
    await tester.tap(find.text('Complete registration'));
    await tester.pumpAndSettle();
    expect(gateway.verifies, 1);
    expect(gateway.saves, 2);
    expect(find.text('Registration submitted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'existing approved phone enters operations without writing registration',
    (tester) async {
      final gateway = FakeEnrollment()..status = 'approved';
      await mount(tester, gateway);
      await send(tester);
      expect(find.text('Operations'), findsOneWidget);
      expect(gateway.saves, 0);
    },
  );
  testWidgets('existing rejected phone signs out without resetting status', (
    tester,
  ) async {
    final gateway = FakeEnrollment()..status = 'rejected';
    await mount(tester, gateway);
    await send(tester);
    expect(gateway.signOuts, 1);
    expect(gateway.saves, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Hindi renders phone first enrollment', (tester) async {
    await mount(tester, FakeEnrollment(), locale: 'hi');
    expect(find.text('ट्रांसपोर्टर पंजीकरण'), findsOneWidget);
    expect(find.text('पूरा नाम'), findsOneWidget);
    expect(find.text('मोबाइल नंबर (+91)'), findsOneWidget);
  });
  test('optional contact email and complete bank details validation', () {
    expect(isValidContactEmail(''), isTrue);
    expect(isValidContactEmail('person@example.com'), isTrue);
    expect(isValidContactEmail('bad@'), isFalse);
    expect(isValidBankDetails('Holder', '12345678901', 'HDFC0001234'), isTrue);
    expect(isValidBankDetails('', '12345678901', 'HDFC0001234'), isFalse);
    expect(isValidBankDetails('Holder', '123', 'HDFC0001234'), isFalse);
    expect(isValidBankDetails('Holder', '12345678901', 'INVALID'), isFalse);
  });
}
