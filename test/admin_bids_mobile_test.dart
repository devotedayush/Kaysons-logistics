import 'dart:async';
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
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/core/widgets/compact_mobile_navigation.dart';
import 'package:kaysons_logistics/core/widgets/responsive_tabbed_shell.dart';
import 'package:kaysons_logistics/core/widgets/date_window_bar.dart';
import 'package:kaysons_logistics/features/admin/admin_bids_body.dart';
import 'package:kaysons_logistics/features/admin/widgets/office_widgets.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, filename) in [
      ('Inter', 'Inter-Regular.ttf'),
      ('Inter', 'Inter-Bold.ttf'),
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
      url: 'https://sample.invalid',
      anonKey: 'sample-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      realtimeClientOptions: RealtimeClientOptions(
        transport: (_, __) => _SampleWebSocketChannel(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            for (var i = 0; i < 8; i++)
              {
                'id': 'sample-$i',
                'origin': 'Agartala',
                'destination_town': 'Agartala',
                'status': 'completed',
                'cases': 257,
                'weight_kg': 277.0,
                'created_at': DateTime.now().toIso8601String(),
              },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
  });
  tearDown(() async {
    await Supabase.instance.client.removeAllChannels();
    await Supabase.instance.client.realtime.disconnect();
  });

  for (final (width, height, locale, scale) in [
    (320.0, 640.0, 'en', 1.0),
    (390.0, 844.0, 'en', 1.0),
    (390.0, 844.0, 'hi', 1.0),
    (320.0, 640.0, 'hi', 1.5),
    (430.0, 932.0, 'en', 1.0),
    (1440.0, 1000.0, 'en', 1.0),
  ]) {
    testWidgets('bids layout $width $locale text $scale', (tester) async {
      tester.view
        ..physicalSize = Size(width, height)
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
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 24, bottom: 34),
                  ),
                  child: child!,
                ),
            home: ResponsiveTabbedShell(
              title: 'Admin',
              subtitle: '',
              icon: Icons.gavel,
              currentIndex: 2,
              onDestinationSelected: (_) {},
              pageView: const AdminBidsBody(),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.gavel),
                  label: Text('Bids'),
                ),
              ],
              mobileNavigation: CompactMobileNavigation(
                currentIndex: 2,
                destinations: const [
                  CompactMobileDestination(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard,
                    label: 'Home',
                  ),
                  CompactMobileDestination(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'Users',
                  ),
                  CompactMobileDestination(
                    icon: Icons.gavel,
                    selectedIcon: Icons.gavel,
                    label: 'Bids',
                  ),
                ],
                primaryIndices: const [0, 1, 2],
                onSelect: (_) {},
                onProfile: () {},
                onLogout: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      if (width < 600) {
        final list = find.byType(CustomScrollView);
        expect(list, findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(OfficeRecordCard).first).dy,
          lessThan(height * (scale == 1 ? .45 : .6)),
        );
        final l =
            AppLocalizations.of(tester.element(find.byType(AdminBidsBody)))!;
        final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
        for (final chip in chips) {
          expect(chip.labelStyle!.color!.computeLuminance(), lessThan(.15));
          expect(
            tester.getSize(find.byWidget(chip)).height,
            greaterThanOrEqualTo(48),
          );
        }
        if (scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final out = File(
              'output/qa/admin-bids-mobile/bids-${width.toInt()}-$locale.png',
            );
            await out.parent.create(recursive: true);
            await out.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final action =
            find
                .widgetWithText(
                  OutlinedButton,
                  locale == 'hi'
                      ? 'माल और प्रस्ताव देखें'
                      : 'Review load and offers',
                )
                .last;
        await tester.drag(list, const Offset(0, -1600));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(action), alignment: 1);
        await tester.pumpAndSettle();
        final nav = tester.getRect(find.byType(CompactMobileNavigation));
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(nav.top));
        // Reveal the controls again, then exercise every date preset.
        final menu = find.byType(PopupMenuButton<int>);
        await tester.drag(list, const Offset(0, 6000));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, l.adminOpen));
        await tester.pumpAndSettle();
        expect(find.byType(OfficeRecordCard), findsNothing);
        await tester.tap(find.widgetWithText(ChoiceChip, l.adminAll));
        await tester.pumpAndSettle();
        expect(find.byType(OfficeRecordCard), findsWidgets);
        for (final days in [7, 15, 30, 90]) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(
              CheckedPopupMenuItem<int>,
              l.dateWindowDays(days),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<DateWindowBar>(find.byType(DateWindowBar)).rangeDays,
            days,
          );
        }
        await tester.tap(find.text(l.dateWindowCustomDates));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(
          find.text(
            MaterialLocalizations.of(
              tester.element(find.byType(DatePickerDialog)),
            ).okButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l.dateWindowFrom), findsOneWidget);
        expect(find.text(l.dateWindowTo), findsOneWidget);
        await tester.tap(find.text(l.dateWindowTo));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(
          find.text(
            MaterialLocalizations.of(
              tester.element(find.byType(DatePickerDialog)),
            ).okButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<DateWindowBar>(find.byType(DateWindowBar)).customEnd,
          isNotNull,
        );
        await tester.ensureVisible(find.text(l.dateWindowUsePreset));
        await tester.tap(find.text(l.dateWindowUsePreset));
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, 6000));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DateWindowBar>(find.byType(DateWindowBar)).customStart,
          isNull,
        );
        await tester.enterText(find.byType(TextField), 'no matching load');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(OfficeRecordCard), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } else {
        expect(find.byType(DataTable), findsOneWidget);
        expect(
          tester.widget<DateWindowBar>(find.byType(DateWindowBar)).compact,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await Supabase.instance.client.removeAllChannels();
      await Supabase.instance.client.realtime.disconnect();
      await tester.pump(const Duration(seconds: 2));
    });
  }
}

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
