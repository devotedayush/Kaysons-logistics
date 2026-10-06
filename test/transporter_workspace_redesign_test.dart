import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/features/transporter/home_screen.dart';
import 'package:kaysons_logistics/features/transporter/bids_screen.dart';
import 'package:kaysons_logistics/features/transporter/fleet_screen.dart';
import 'package:kaysons_logistics/features/transporter/vehicles_screen.dart';
import 'package:kaysons_logistics/features/transporter/drivers_screen.dart';
import 'package:kaysons_logistics/features/transporter/bid_detail_screen.dart';
import 'package:kaysons_logistics/features/transporter/afterbid_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

final open = <String, dynamic>{
  'id': 'sample-load',
  'origin': 'Delhi',
  'destination_town': 'Moga',
  'cases': 100,
  'weight_kg': 8,
  'status': 'bidding',
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'bid_opens_at':
      DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
  'bid_closes_at':
      DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
};
final trips = [
  <String, dynamic>{
    ...open,
    'status': 'awarded',
    'vehicle_number': '',
    'driver_name': '',
  },
  <String, dynamic>{
    ...open,
    'id': 'finished',
    'origin': 'Karnal',
    'destination_town': 'Ludhiana',
    'status': 'completed',
    'vehicle_number': 'PB10AB1234',
    'driver_name': 'Gurpreet',
  },
  <String, dynamic>{
    ...open,
    'id': 'financially-locked',
    'origin': 'Panipat',
    'destination_town': 'Moga',
    'status': 'locked',
    'vehicle_number': 'HR01AB0001',
    'driver_name': 'Sample Driver',
  },
];
const vehicles = [
  <String, dynamic>{
    'id': 'v-1',
    'registration_number': 'PB10AB1234',
    'vehicle_type': 'Truck',
    'capacity_qt': 120,
    'capacity_weight_kg': 10,
    'status': 'active',
  },
  <String, dynamic>{
    'id': 'v-2',
    'registration_number': 'HR20XY9876',
    'vehicle_type': 'Trailer',
    'status': 'active',
  },
];
const drivers = [
  <String, dynamic>{
    'id': 'd-1',
    'name': 'Gurpreet Singh',
    'phone': '9876543210',
    'licence_number': 'PB20260012',
  },
  <String, dynamic>{'id': 'd-2', 'name': 'Ravi Sharma', 'phone': '9123456780'},
];

Future<void> capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final directory = Directory('/tmp/kaysons-transporter-redesign')
    ..createSync(recursive: true);
  File(
    '${directory.path}/$name.png',
  ).writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
    );
    final iconData =
        await File('test/assets/fonts/MaterialIcons-Regular.otf').readAsBytes();
    await (FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconData)))).load();
    for (final (family, file) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('Inter', 'Inter-Bold.ttf'),
      ('NotoSansDevanagariUI', 'NotoSansDevanagariUI-Regular.ttf'),
    ]) {
      final data = await File('assets/fonts/$file').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(data)))).load();
    }
  });
  final screens = <String, Widget Function()>{
    'home':
        () => TransporterHomeBody(
          displayName: 'Sample Transporter',
          openFreightsStream: Stream.value([open]),
          wonFreightsFuture: Future.value(trips),
        ),
    'bids':
        () => BidsBody(
          openFreightsStream: Stream.value([open]),
          historyFuture: Future.value([trips[1]]),
        ),
    'fleet': () => FleetBody(loadData: () async => trips),
    'vehicles': () => VehiclesScreen(loadData: () async => vehicles),
    'drivers': () => DriversScreen(loadData: () async => drivers),
    'bid-detail':
        () => BidDetailScreen(
          bidId: 'sample-load',
          freightStream: Stream.value(open),
          bidsStream: Stream.value([
            {'amount': 15000, 'transporter_id': 'another-user'},
          ]),
        ),
    'delivery':
        () => AfterbidScreen(
          bidId: 'sample-load',
          freightStream: Stream.value({
            ...open,
            'status': 'dispatched',
            'delivery_stages': {
              'dispatched': <String, dynamic>{},
              'pickup': <String, dynamic>{},
              'in_transit': <String, dynamic>{},
            },
            'stop_details': [
              {'name': 'Moga'},
            ],
          }),
        ),
  };
  for (final locale in ['en', 'hi']) {
    for (final wide in [false, true]) {
      for (final entry in screens.entries) {
        testWidgets(
          '${entry.key} $locale ${wide ? 'laptop' : 'phone'} renders and exposes the next action',
          (tester) async {
            tester.view
              ..physicalSize =
                  wide ? const Size(1280, 960) : const Size(390, 844)
              ..devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(),
                  locale: Locale(locale),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: Scaffold(body: entry.value()),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(
              () => capture(
                key,
                '${entry.key}-$locale-${wide ? 'laptop' : 'phone'}',
              ),
            );
            if (['vehicles', 'drivers', 'fleet', 'bids'].contains(entry.key)) {
              final search = find.byType(TextField).first;
              await tester.ensureVisible(search);
              await tester.enterText(search, 'zzzz-no-match');
              await tester.pumpAndSettle();
              expect(
                find.text(
                  entry.key == 'fleet'
                      ? (locale == 'en'
                          ? 'No trips match this search'
                          : 'इस खोज में कोई यात्रा नहीं')
                      : entry.key == 'bids'
                      ? (locale == 'en'
                          ? 'No matching routes'
                          : 'कोई मिलता हुआ मार्ग नहीं')
                      : locale == 'en'
                      ? 'No matching ${entry.key}'
                      : 'कोई मेल नहीं मिला',
                ),
                findsOneWidget,
              );
              await tester.enterText(search, '');
              await tester.pumpAndSettle();
            }
            if (['vehicles', 'drivers'].contains(entry.key)) {
              final add =
                  find
                      .widgetWithText(
                        FilledButton,
                        entry.key == 'vehicles'
                            ? locale == 'en'
                                ? 'Add vehicle'
                                : 'वाहन जोड़ें'
                            : locale == 'en'
                            ? 'Add driver'
                            : 'ड्राइवर जोड़ें',
                      )
                      .first;
              await tester.ensureVisible(add);
              await tester.tap(add);
              await tester.pumpAndSettle();
              expect(find.byType(BottomSheet), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.runAsync(
                () => capture(
                  key,
                  '${entry.key}-form-$locale-${wide ? 'laptop' : 'phone'}',
                ),
              );
              await tester.tap(find.byIcon(Icons.close).last);
              await tester.pumpAndSettle();
              final edit =
                  find
                      .text(
                        entry.key == 'vehicles'
                            ? locale == 'en'
                                ? 'Edit vehicle'
                                : 'वाहन की जानकारी बदलें'
                            : locale == 'en'
                            ? 'Edit'
                            : 'बदलें',
                      )
                      .first;
              await tester.ensureVisible(edit);
              await tester.tap(edit);
              await tester.pumpAndSettle();
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      w is TextField &&
                      w.controller?.text ==
                          (entry.key == 'vehicles'
                              ? 'PB10AB1234'
                              : 'Gurpreet Singh'),
                ),
                findsOneWidget,
              );
              await tester.runAsync(
                () => capture(
                  key,
                  '${entry.key}-edit-$locale-${wide ? 'laptop' : 'phone'}',
                ),
              );
              await tester.tap(find.byIcon(Icons.close).last);
              await tester.pumpAndSettle();
            }
            if (entry.key == 'fleet' || entry.key == 'bids') {
              final filter = find.text(
                entry.key == 'fleet'
                    ? locale == 'en'
                        ? 'Finished trips'
                        : 'पूरी यात्राएँ'
                    : locale == 'en'
                    ? 'Bid history'
                    : 'बोली का इतिहास',
              );
              await tester.ensureVisible(filter);
              await tester.tap(filter);
              await tester.pumpAndSettle();
              expect(find.text('Delhi → Moga'), findsNothing);
              expect(
                find.text('Panipat → Moga'),
                findsNothing,
                reason:
                    'Financial finalization does not mean delivery is complete',
              );
              expect(find.text('Karnal → Ludhiana'), findsOneWidget);
            }
            if (entry.key == 'bid-detail') {
              final quote = find.byType(TextField).first;
              await tester.ensureVisible(quote);
              await tester.enterText(quote, '0');
              final submit = find.text(
                locale == 'en' ? 'Place bid' : 'बोली लगाएँ',
              );
              await tester.ensureVisible(submit);
              await tester.tap(submit);
              await tester.pumpAndSettle();
              expect(
                find.text(
                  locale == 'en'
                      ? 'Enter a freight amount greater than zero.'
                      : 'शून्य से अधिक भाड़ा भरें।',
                ),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
