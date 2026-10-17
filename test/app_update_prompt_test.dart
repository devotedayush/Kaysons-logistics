import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/theme/app_theme.dart';
import 'package:kaysons_logistics/core/updates/app_update_prompt.dart';
import 'package:kaysons_logistics/core/updates/app_updates.dart';
import 'package:kaysons_logistics/features/account/app_updates_screen.dart';
import 'package:kaysons_logistics/l10n/app_localizations.dart';

class _PreviewUpdates extends AppUpdates {
  _PreviewUpdates({
    AppUpdatePlatform platform = AppUpdatePlatform.android,
    AppUpdateStatus initialStatus = AppUpdateStatus.available,
  }) : super(platform: platform) {
    status = initialStatus;
    flexibleAllowed = true;
    availableVersionCode = 4008;
  }

  int starts = 0;
  int completions = 0;
  int deferrals = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> check({bool manual = false}) async => notifyListeners();

  @override
  Future<void> remindLater() async => deferrals++;

  @override
  Future<bool> startUpdate() async {
    starts++;
    status = AppUpdateStatus.downloading;
    notifyListeners();
    return true;
  }

  @override
  Future<void> completeUpdate() async => completions++;
}

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
      final data = await File('test/assets/fonts/$file').readAsBytes();
      await (FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(data)))).load();
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UPDATES')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('output/qa/app-updates/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget app({
    required Widget child,
    required GlobalKey<NavigatorState> navigatorKey,
    AppUpdates? updates,
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) => RepaintBoundary(
    key: const ValueKey('capture'),
    child: MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        final scaled = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
        return updates == null
            ? scaled
            : AppUpdatePrompt(
              navigatorKey: navigatorKey,
              updates: updates,
              child: scaled,
            );
      },
      home: child,
    ),
  );

  testWidgets('Later leaves the workspace usable without starting an update', (
    tester,
  ) async {
    final updates = _PreviewUpdates();
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      app(
        navigatorKey: GlobalKey<NavigatorState>(),
        updates: updates,
        child: const Scaffold(body: Text('Workspace')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Workspace'), findsOneWidget);
    expect(updates.starts, 0);
    expect(updates.deferrals, 1);
  });

  testWidgets('Update now downloads without restarting automatically', (
    tester,
  ) async {
    final updates = _PreviewUpdates();
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      app(
        navigatorKey: GlobalKey<NavigatorState>(),
        updates: updates,
        child: const Scaffold(body: Text('Workspace')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(updates.starts, 1);
    expect(updates.completions, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final language in ['en', 'hi']) {
    for (final largeText in [false, true]) {
      final scale = largeText ? 2.0 : 1.0;
      for (final (name, platform, status, prompt) in [
        (
          'android-settings',
          AppUpdatePlatform.android,
          AppUpdateStatus.upToDate,
          false,
        ),
        ('ios-settings', AppUpdatePlatform.ios, AppUpdateStatus.idle, false),
        (
          'available-prompt',
          AppUpdatePlatform.android,
          AppUpdateStatus.available,
          true,
        ),
        (
          'restart-prompt',
          AppUpdatePlatform.android,
          AppUpdateStatus.readyToInstall,
          true,
        ),
      ]) {
        testWidgets('$name $language at ${scale}x fits a narrow phone', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(780, 1688)
            ..devicePixelRatio = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final updates = _PreviewUpdates(
            platform: platform,
            initialStatus: status,
          );
          addTearDown(updates.dispose);
          await tester.pumpWidget(
            app(
              navigatorKey: GlobalKey<NavigatorState>(),
              updates: prompt ? updates : null,
              locale: Locale(language),
              textScale: scale,
              child:
                  prompt
                      ? const Scaffold(body: Text('Kaysons Logistics'))
                      : AppUpdatesScreen(updates: updates),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (prompt) expect(find.byType(AlertDialog), findsOneWidget);
          await capture(
            tester,
            '$name-$language-${largeText ? 'large' : 'normal'}',
          );
        });
      }
    }
  }
}
