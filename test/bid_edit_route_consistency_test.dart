import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaysons_logistics/features/logistics_manager/bid_edit_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var mockStatus = 'awarded';
  Map<String, dynamic>? lastFreightUpdate;
  setUp(() {
    mockStatus = 'awarded';
    lastFreightUpdate = null;
  });
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://sample.invalid',
      anonKey: 'sample-publishable-key',
      debug: false,
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/freights') &&
            request.method == 'PATCH') {
          lastFreightUpdate = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode([
              {'id': 'sample-freight'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final body =
            request.url.path.endsWith('/freights')
                ? {
                  'origin': 'Delhi',
                  'destination_town': 'Amritsar',
                  'bid_closes_at': '2026-09-26T10:00:00Z',
                  'stops': ['Karnal'],
                  'stop_details': [
                    {'name': 'Karnal', 'cases': 8, 'weight_kg': 80},
                    {
                      'name': 'Amritsar',
                      'cases': 12,
                      'weight_kg': 120,
                      'kind': 'destination',
                    },
                  ],
                  'status': mockStatus,
                }
                : <Object>[];
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  test(
    'edited route retains quantities for matching stops and final delivery',
    () {
      final details = buildStopDetailsForEditedRoute(
        stops: ['Amritsar', 'Ludhiana'],
        destination: 'Jalandhar',
        existingDetails: [
          {'name': 'Karnal', 'cases': 10, 'weight_kg': 150},
          {'name': 'Amritsar', 'cases': 20, 'weight_kg': 300},
          {
            'name': 'Jalandhar',
            'cases': 30,
            'weight_kg': 450,
            'kind': 'destination',
          },
        ],
      );

      expect(details.map((row) => row['name']), [
        'Amritsar',
        'Ludhiana',
        'Jalandhar',
      ]);
      expect(details[0]['cases'], 20);
      expect(details[0]['weight_kg'], 300);
      expect(details[1].containsKey('cases'), isFalse);
      expect(details[1].containsKey('weight_kg'), isFalse);
      expect(details[2]['cases'], 30);
      expect(details[2]['weight_kg'], 450);
      expect(details[2]['kind'], 'destination');
    },
  );

  test('empty detail history still produces every delivery destination', () {
    final details = buildStopDetailsForEditedRoute(
      stops: ['Karnal'],
      destination: 'Amritsar',
      existingDetails: const [],
    );

    expect(details.map((row) => row['name']), ['Karnal', 'Amritsar']);
    expect(details.last['kind'], 'destination');
  });

  test('freight totals equal the sum of edited delivery quantities', () {
    final totals = editedRouteTotals([
      {'name': 'Karnal', 'cases': 9, 'weight_kg': 80.5},
      {'name': 'Ludhiana', 'cases': 4, 'weight_kg': 40.25},
      {'name': 'Amritsar', 'cases': 12, 'weight_kg': 130.0},
    ]);
    expect(totals.cases, 25);
    expect(totals.weight, 250.75);
  });

  test(
    'capacity inference uses MT brackets and preserves explicit choices',
    () {
      expect(inferVehicleCapacityCategory(0.5), 'Up to 1 MT');
      expect(inferVehicleCapacityCategory(2.5), 'Up to 3 MT');
      expect(inferVehicleCapacityCategory(4), '3-6 MT');
      expect(inferVehicleCapacityCategory(8), '6-9 MT');
      expect(inferVehicleCapacityCategory(11), '9-12 MT');
      expect(inferVehicleCapacityCategory(14), '12-15 MT');
      expect(inferVehicleCapacityCategory(16), '15+ MT');

      expect(
        shouldPreserveVehicleCapacityOverride(
          storedCategory: '6-9 MT',
          currentWeightMt: 2.5,
        ),
        isTrue,
      );
      expect(
        shouldPreserveVehicleCapacityOverride(
          storedCategory: 'Up to 3 MT',
          currentWeightMt: 2.5,
        ),
        isFalse,
      );
      expect(
        shouldPreserveVehicleCapacityOverride(
          storedCategory: '6-9 MT',
          currentWeightMt: 2.5,
          storedManualOverride: false,
        ),
        isFalse,
      );
      expect(
        shouldPreserveVehicleCapacityOverride(
          storedCategory: null,
          currentWeightMt: 2.5,
          storedManualOverride: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'legacy destination detail keeps its quantity without a kind marker',
    () {
      final details = buildStopDetailsForEditedRoute(
        stops: ['karnal'],
        destination: 'Amritsar',
        existingDetails: const [
          {'name': 'Karnal', 'cases': 8, 'weight_kg': 80},
          {'name': 'Amritsar', 'cases': 12, 'weight_kg': 120},
        ],
      );

      expect(details.first['cases'], 8);
      expect(details.last['cases'], 12);
      expect(details.last['kind'], 'destination');
    },
  );

  testWidgets('awarded bid shows route without add or save controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const BidEditScreen(bidId: 'sample-freight'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Karnal'), findsWidgets);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Add a stop and tap +'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('new stop requires quantities and saves consistent totals', (
    tester,
  ) async {
    mockStatus = 'bidding';
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const BidEditScreen(bidId: 'sample-freight'),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );
    await tester.scrollUntilVisible(
      field('Add a stop and tap +'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field('Add a stop and tap +'), 'Ludhiana');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Ludhiana',
      ),
      findsNothing,
    );

    await tester.enterText(field('Stop cases').last, '4');
    await tester.enterText(field('Stop metric ton').at(1), '40');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Ludhiana'), findsWidgets);
    await tester.enterText(field('Stop cases').first, '9');
    await tester.enterText(field('Stop metric ton').last, '130');
    expect(find.text('Automatic from MT · 15+ MT'), findsOneWidget);

    final capacityDropdown = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<String>,
    );
    await tester.tap(capacityDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6-9 MT').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Stop metric ton').last, '131');

    await tester.scrollUntilVisible(
      find.text('Save changes'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(lastFreightUpdate?['stops'], ['Karnal', 'Ludhiana']);
    expect(lastFreightUpdate?['cases'], 25);
    expect(lastFreightUpdate?['weight_kg'], 251);
    expect(lastFreightUpdate?['vehicle_capacity_category'], '6-9 MT');
    final details = lastFreightUpdate?['stop_details'] as List<dynamic>?;
    expect(details?.map((row) => row['name']), [
      'Karnal',
      'Ludhiana',
      'Amritsar',
    ]);
    expect(details?[1]['cases'], 4);
    expect(details?[1]['weight_kg'], 40);
    expect(details?[0]['cases'], 9);
    expect(details?[2]['weight_kg'], 131);
    expect(details?[2]['vehicle_capacity_manual_override'], isTrue);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('bid edit route quantities remain readable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      mockStatus = 'bidding';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
          home: const BidEditScreen(bidId: 'sample-freight'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update transport request'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Final destination: Amritsar'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Final destination: Amritsar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        lastFreightUpdate,
        isNull,
        reason: 'Layout review must not submit changes',
      );
    });
  }
}
