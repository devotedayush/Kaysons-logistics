import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaysons_logistics/features/logistics_manager/widgets/transporter_audience_picker.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

const _transporters = <Map<String, dynamic>>[
  {'id': 'a', 'business_name': 'Example Transport'},
  {'id': 'b', 'business_name': 'Sample Freight Co.'},
  {'id': 'c', 'business_name': 'Demo Carriers'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<void> loadFont(String family, String fileName) async {
      final bytes = await File('test/assets/fonts/$fileName').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont('Inter', 'Inter-Regular.ttf');
    await loadFont('Inter', 'Inter-Bold.ttf');
    await loadFont('NotoSansDevanagariUI', 'NotoSansDevanagari-Regular.ttf');
    final iconBytes =
        await File(
          '/Users/ayushmansingh/.codex-toolcache/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes();
    await (FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
  });

  testWidgets('audience modes expose one clear list at mobile width', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const _PickerHarness()));
    expect(find.text('All approved transporters'), findsOneWidget);
    expect(find.text('Exclude transporters (optional)'), findsOneWidget);
    await tester.tap(find.text('Example Transport'));
    await tester.pump();
    expect(find.text('Excluded: 1'), findsOneWidget);

    await tester.tap(find.text('Only selected transporters'));
    await tester.pump();
    expect(find.text('Choose transporters'), findsOneWidget);
    expect(find.text('Selected: 0'), findsOneWidget);
    await tester.tap(find.text('Sample Freight Co.'));
    await tester.pump();
    expect(find.text('Selected: 1'), findsOneWidget);
    await tester.tap(find.text('Only selected transporters'));
    await tester.pump();
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hindi audience labels render without overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const _PickerHarness(), locale: 'hi'));
    expect(find.text('कौन बोली लगा सकता है?'), findsOneWidget);
    expect(find.text('सभी स्वीकृत ट्रांसपोर्टर'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('illustrated guide shows selected-only audience', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        RepaintBoundary(
          key: key,
          child: Stack(
            children: [
              const _PickerHarness(
                initialSelectedOnly: true,
                initialSelectedIds: {'a', 'b'},
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Color(0xFFFFF2CC),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile(
        Uri.file(
          '${Directory.current.path}/docs/guides/screenshots/operations/logistics-bid-audience.png',
        ),
      ),
    );
  });
}

Widget _app(Widget home, {String locale = 'en'}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['NotoSansDevanagariUI'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7955AF),
      primary: const Color(0xFF30234D),
      surface: const Color(0xFFF8F7FB),
    ),
  ),
  home: Scaffold(body: Center(child: home)),
);

class _PickerHarness extends StatefulWidget {
  const _PickerHarness({
    this.initialSelectedOnly = false,
    this.initialSelectedIds = const {},
  });

  final bool initialSelectedOnly;
  final Set<String> initialSelectedIds;

  @override
  State<_PickerHarness> createState() => _PickerHarnessState();
}

class _PickerHarnessState extends State<_PickerHarness> {
  late bool _selectedOnly = widget.initialSelectedOnly;
  late final Set<String> _selected = {...widget.initialSelectedIds};
  final Set<String> _excluded = {};

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 800),
    child: SingleChildScrollView(
      child: TransporterAudiencePicker(
        transporters: _transporters,
        selectedOnly: _selectedOnly,
        selectedIds: _selected,
        excludedIds: _excluded,
        onModeChanged:
            (value) => setState(() {
              _selectedOnly = value;
              _selected.clear();
              _excluded.clear();
            }),
        onTransporterChanged:
            (id, checked) => setState(() {
              final target = _selectedOnly ? _selected : _excluded;
              if (checked) {
                target.add(id);
              } else {
                target.remove(id);
              }
            }),
      ),
    ),
  );
}
