import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/transporter/afterbid_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _freight({
  Map<String, dynamic>? stages,
  bool multi = true,
}) {
  return {
    'id': 'sample-freight',
    'origin': 'Delhi',
    'destination_town': multi ? 'Amritsar' : 'Karnal',
    'stop_details':
        multi
            ? [
              {'name': 'Karnal', 'kind': 'stop'},
              {'name': 'Amritsar', 'kind': 'destination'},
            ]
            : [
              {'name': 'Karnal', 'kind': 'destination'},
            ],
    'status': 'dispatched',
    'delivery_stages': stages ?? {'in_transit': <String, dynamic>{}},
  };
}

Widget _app(
  Map<String, dynamic> freight, {
  Locale locale = const Locale('en'),
  Stream<Map<String, dynamic>?>? freightStream,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: AfterbidScreen(
    bidId: 'sample-freight',
    freightStream: freightStream ?? Stream.value(freight),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    );
  });
  testWidgets(
    'multi-stop forms hide invoice references but retain GR and e-way fields',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(_freight()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Delivered · Karnal'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Delivered · Karnal'), findsOneWidget);
      expect(find.text('Add Goods invoice / challan numbers'), findsNothing);
      expect(find.text('Goods invoice / challan numbers'), findsNothing);
      expect(find.text('Add GR / Bilty number'), findsNWidgets(2));
      expect(find.text('Add E-way bill number'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('Add GR / Bilty number').first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add GR / Bilty number').first);
      await tester.pump();
      expect(find.text('GR / Bilty number 2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Delivered · Amritsar'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Delivered · Amritsar'), findsOneWidget);
    },
  );

  testWidgets('one delivered stop leaves the trip in transit', (tester) async {
    await tester.pumpWidget(
      _app(
        _freight(
          stages: {
            'in_transit': <String, dynamic>{},
            'delivered_stops': [
              {
                'stop_index': 0,
                'destination': 'Karnal',
                'submitted_at': '2026-09-26T10:00:00Z',
                'receiver_name': 'Receiver One',
                'pod_photo_path': 'pod/one.jpg',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN TRANSIT'), findsOneWidget);
    expect(find.text('DELIVERED'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Delivered · Amritsar'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delivered · Amritsar'), findsOneWidget);
  });

  testWidgets('single destination keeps legacy delivery form', (tester) async {
    await tester.pumpWidget(_app(_freight(multi: false)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delivered'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Delivered · Karnal'), findsNothing);
    expect(find.text('Add Goods invoice / challan numbers'), findsNothing);
  });

  testWidgets('saved stop refreshes from stream without overwriting a draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final updates = StreamController<Map<String, dynamic>?>();
    addTearDown(updates.close);
    final first = _freight(
      stages: {
        'in_transit': <String, dynamic>{},
        'delivered_stops': [
          {
            'stop_index': 0,
            'destination': 'Karnal',
            'receiver_name': 'Receiver One',
            'invoice_numbers': ['INV-1'],
            'submitted_at': '2026-09-26T10:00:00Z',
          },
        ],
      },
    );
    await tester.pumpWidget(_app(first, freightStream: updates.stream));
    updates.add(first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delivered · Karnal'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Delivered · Karnal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivered · Karnal'));
    await tester.pumpAndSettle();

    Finder fieldWith(String value) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == value,
    );
    expect(fieldWith('Receiver One'), findsOneWidget);
    expect(fieldWith('INV-1'), findsNothing);

    updates.add(
      _freight(
        stages: {
          'in_transit': <String, dynamic>{},
          'delivered_stops': [
            {
              'stop_index': 0,
              'destination': 'Karnal',
              'receiver_name': 'Receiver Two',
              'invoice_numbers': ['INV-2'],
              'submitted_at': '2026-09-26T11:00:00Z',
            },
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldWith('Receiver Two'), findsOneWidget);
    expect(fieldWith('INV-2'), findsNothing);

    await tester.enterText(fieldWith('Receiver Two'), 'Draft Receiver');
    updates.add(
      _freight(
        stages: {
          'in_transit': <String, dynamic>{},
          'delivered_stops': [
            {
              'stop_index': 0,
              'destination': 'Karnal',
              'receiver_name': 'Receiver Three',
              'invoice_numbers': ['INV-3'],
              'submitted_at': '2026-09-26T12:00:00Z',
            },
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldWith('Draft Receiver'), findsOneWidget);
    expect(fieldWith('Receiver Three'), findsNothing);
    expect(fieldWith('INV-3'), findsNothing);
  });

  testWidgets('delivery cannot be submitted without a receiver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_freight()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Share delivery details').first,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share delivery details').first);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Enter receiver name'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('each stop has its own saved POD and Hindi document labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        _freight(
          stages: {
            'in_transit': <String, dynamic>{},
            'delivered_stops': [
              {
                'stop_index': 0,
                'destination': 'Karnal',
                'receiver_name': 'Receiver One',
                'pod_photo_path': 'pod/karnal.jpg',
                'submitted_at': '2026-09-26T10:00:00Z',
              },
              {
                'stop_index': 1,
                'destination': 'Amritsar',
                'receiver_name': 'Receiver Two',
                'pod_photo_path': 'pod/amritsar.jpg',
                'submitted_at': '2026-09-26T11:00:00Z',
              },
            ],
          },
        ),
        locale: const Locale('hi'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('रास्ते में'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('रास्ते में'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('रास्ते में'));
    await tester.pumpAndSettle();
    expect(find.text('माल के इनवॉइस / चालान नंबर'), findsNothing);
    expect(find.text('माल के इनवॉइस / चालान नंबर जोड़ें'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('डिलीवर किया · Karnal'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('डिलीवर किया · Karnal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('डिलीवर किया · Karnal'));
    await tester.pumpAndSettle();
    expect(find.text('माल के इनवॉइस / चालान नंबर'), findsNothing);
    expect(find.text('माल के इनवॉइस / चालान नंबर जोड़ें'), findsNothing);
    final firstPod =
        tester.widget(find.byKey(const ValueKey('delivery-pod-0'))) as dynamic;
    expect(firstPod.initialPath, 'pod/karnal.jpg');
    expect(firstPod.kind, '0-pod');

    await tester.scrollUntilVisible(
      find.text('डिलीवर किया · Amritsar'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('डिलीवर किया · Amritsar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('डिलीवर किया · Amritsar'));
    await tester.pumpAndSettle();
    final secondPod =
        tester.widget(find.byKey(const ValueKey('delivery-pod-1'))) as dynamic;
    expect(secondPod.initialPath, 'pod/amritsar.jpg');
    expect(secondPod.kind, '1-pod');
  });
}
