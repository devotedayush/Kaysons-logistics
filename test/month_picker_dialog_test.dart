import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/core/widgets/month_picker_dialog.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

Future<void> mount(
  WidgetTester tester, {
  DateTime? initial,
  List<int> years = const [2025, 2026, 2027],
  Size size = const Size(390, 844),
  String locale = 'en',
  double scale = 1,
  ValueChanged<DateTime?>? onResult,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected = initial ?? DateTime(2026, 2, 28);
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Center(
                  child: TextButton(
                    onPressed: () async {
                      final result = await showDialog<DateTime>(
                        context: context,
                        builder:
                            (_) => MonthPickerDialog(
                              initialMonth: selected,
                              years: years,
                            ),
                      );
                      if (result != null) selected = result;
                      onResult?.call(result);
                    },
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder control(String name) => find.byKey(ValueKey('month-picker-$name'));

Future<void> tap(WidgetTester tester, String name) async {
  await tester.ensureVisible(control(name));
  await tester.pumpAndSettle();
  await tester.tap(control(name));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Inter', 'assets/fonts/Inter-Regular.ttf'),
      ('Inter', 'assets/fonts/Inter-Bold.ttf'),
      ('NotoSansDevanagariUI', 'assets/fonts/NotoSansDevanagariUI-Regular.ttf'),
      ('MaterialIcons', 'test/assets/fonts/MaterialIcons-Regular.otf'),
    ]) {
      final bytes = await File(path).readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets('draft selection applies once and persists on reopen', (
    tester,
  ) async {
    final results = <DateTime?>[];
    await mount(tester, onResult: results.add);
    expect(find.text('February 2026'), findsOneWidget);
    await tap(tester, '12');
    expect(find.byType(MonthPickerDialog), findsOneWidget);
    expect(results, isEmpty);
    await tap(tester, 'next-year');
    await tap(tester, '1');
    expect(find.text('January 2027'), findsOneWidget);
    await tap(tester, 'apply');
    expect(results, [DateTime(2027, 1)]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
    await tap(tester, 'previous-year');
    await tap(tester, '12');
    await tap(tester, 'apply');
    expect(results.last, DateTime(2026, 12));
  });

  for (final dismissal in ['cancel', 'barrier', 'back']) {
    testWidgets('$dismissal discards month and year changes', (tester) async {
      final results = <DateTime?>[];
      await mount(tester, onResult: results.add);
      await tap(tester, 'next-year');
      await tap(tester, '11');
      if (dismissal == 'cancel') {
        await tap(tester, 'cancel');
      } else if (dismissal == 'barrier') {
        await tester.tapAt(const Offset(2, 2));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(results, [null]);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
    });
  }

  testWidgets(
    'year choices include historical selection and skip absent years',
    (tester) async {
      await mount(
        tester,
        initial: DateTime(2020, 2, 29),
        years: [2026, 2024, 2026],
      );
      expect(
        tester.widget<IconButton>(control('previous-year')).onPressed,
        isNull,
      );
      await tap(tester, 'next-year');
      expect(find.text('February 2024'), findsOneWidget);
      await tester.tap(control('year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(control('next-year')).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, height, locale, scale) in [
    (320.0, 640.0, 'en', 1.0),
    (390.0, 844.0, 'en', 1.0),
    (430.0, 932.0, 'hi', 1.0),
    (320.0, 640.0, 'hi', 1.5),
    (320.0, 640.0, 'en', 2.0),
    (844.0, 390.0, 'en', 1.0),
  ]) {
    testWidgets('readable months $width x $height $locale scale $scale', (
      tester,
    ) async {
      await mount(
        tester,
        size: Size(width, height),
        locale: locale,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(locale == 'hi' ? 'फ़रवरी' : 'February'), findsOneWidget);
      for (var month = 1; month <= 12; month++) {
        final button = control('$month');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final rect = tester.getRect(button);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
        final label = find.descendant(of: button, matching: find.byType(Text));
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.getRect(label).height, greaterThan(14));
        expect(tester.getRect(label).top, greaterThanOrEqualTo(rect.top));
        expect(tester.getRect(label).bottom, lessThanOrEqualTo(rect.bottom));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tap(tester, '2');
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(MonthPickerDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'output/qa/month-picker/picker-${width.toInt()}x${height.toInt()}-$locale-$scale.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(
        tester.getRect(control('apply')).bottom,
        lessThanOrEqualTo(height),
      );
      await tap(tester, 'apply');
      expect(find.byType(MonthPickerDialog), findsNothing);
    });
  }
}
