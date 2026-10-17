import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/updates/app_updates.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _updatesChannel = MethodChannel(
  'com.kaysons.kaysons_logistics/app_updates',
);
const _eventsChannel = EventChannel(
  'com.kaysons.kaysons_logistics/app_update_events',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String, int>{};
  var checkInfo = <String, dynamic>{
    'availableVersionCode': 4007,
    'available': true,
    'flexibleAllowed': true,
  };
  Object? checkFailure;
  Object? startFailure;
  var startAccepted = true;
  var now = DateTime.utc(2026, 10, 17, 12);
  late Completer<MockStreamHandlerEventSink> eventSinkReady;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    checkInfo = {
      'availableVersionCode': 4007,
      'available': true,
      'flexibleAllowed': true,
    };
    checkFailure = null;
    startFailure = null;
    startAccepted = true;
    now = DateTime.utc(2026, 10, 17, 12);
    eventSinkReady = Completer<MockStreamHandlerEventSink>();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_updatesChannel, (call) async {
      calls.update(call.method, (count) => count + 1, ifAbsent: () => 1);
      switch (call.method) {
        case 'checkForUpdate':
          if (checkFailure case final failure?) throw failure;
          return checkInfo;
        case 'startFlexibleUpdate':
          if (startFailure case final failure?) throw failure;
          return startAccepted;
        case 'completeUpdate':
          return null;
        default:
          throw MissingPluginException('Unexpected method ${call.method}');
      }
    });
    messenger.setMockStreamHandler(
      _eventsChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          if (!eventSinkReady.isCompleted) eventSinkReady.complete(sink);
        },
      ),
    );
  });

  AppUpdates createController({
    Future<SharedPreferences> Function()? preferences,
  }) {
    final controller = AppUpdates(
      platform: AppUpdatePlatform.android,
      channel: _updatesChannel,
      events: _eventsChannel,
      preferences: preferences ?? SharedPreferences.getInstance,
      now: () => now,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('AppUpdates', () {
    test(
      'an eligible update becomes a prompt after checking the store',
      () async {
        final updates = createController();

        expect(updates.shouldPrompt, isFalse);
        await updates.check();

        expect(calls['checkForUpdate'], 1);
        expect(updates.status, AppUpdateStatus.available);
        expect(updates.availableVersionCode, 4007);
        expect(updates.flexibleAllowed, isTrue);
        expect(updates.shouldPrompt, isTrue);

        updates.markPromptShown();
        expect(updates.shouldPrompt, isFalse);
      },
    );

    test(
      'Later defers this version for 24 hours across controller recreation',
      () async {
        final first = createController();
        await first.check();
        expect(first.shouldPrompt, isTrue);

        await first.remindLater();
        expect(first.shouldPrompt, isFalse);

        now = now.add(const Duration(hours: 23, minutes: 59));
        final recreated = createController();
        await recreated.check(manual: true);
        expect(recreated.availableVersionCode, 4007);
        expect(recreated.shouldPrompt, isFalse);

        now = now.add(const Duration(minutes: 1));
        expect(recreated.shouldPrompt, isTrue);
      },
    );

    test(
      'a different available version bypasses an existing deferral',
      () async {
        final updates = createController();
        await updates.check();
        await updates.remindLater();

        checkInfo = {
          'availableVersionCode': 4008,
          'available': true,
          'flexibleAllowed': false,
        };
        await updates.check(manual: true);

        expect(updates.availableVersionCode, 4008);
        expect(updates.shouldPrompt, isTrue);
      },
    );

    test(
      'reminder preference persists and only suppresses automatic checks',
      () async {
        final first = createController();
        await first.setRemindersEnabled(false);
        expect(first.remindersEnabled, isFalse);
        expect(calls['checkForUpdate'], isNull);

        await first.check();
        expect(calls['checkForUpdate'], isNull);

        final recreated = createController();
        await recreated.initialize();
        expect(recreated.remindersEnabled, isFalse);
        await recreated.check();
        expect(calls['checkForUpdate'], isNull);

        await recreated.check(manual: true);
        expect(calls['checkForUpdate'], 1);
        expect(recreated.status, AppUpdateStatus.available);
        expect(recreated.shouldPrompt, isFalse);

        await recreated.setRemindersEnabled(true);
        expect(recreated.remindersEnabled, isTrue);
        expect(calls['checkForUpdate'], 2);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(AppUpdates.reminderPreference), isTrue);
      },
    );

    test('automatic checks are throttled for six hours', () async {
      final updates = createController();

      await updates.check();
      await updates.check();
      expect(calls['checkForUpdate'], 1);

      now = now.add(const Duration(hours: 5, minutes: 59));
      await updates.check();
      expect(calls['checkForUpdate'], 1);

      now = now.add(const Duration(minutes: 1));
      await updates.check();
      expect(calls['checkForUpdate'], 2);
    });

    test(
      'preference and store failures do not escape initialization or check',
      () async {
        final updates = createController(
          preferences: () async => throw StateError('preferences unavailable'),
        );
        checkFailure = PlatformException(
          code: 'STORE_UNAVAILABLE',
          message: 'Play Store is unavailable',
        );

        await expectLater(updates.initialize(), completes);
        await expectLater(updates.check(manual: true), completes);
        expect(calls['checkForUpdate'], 1);
        expect(updates.status, AppUpdateStatus.unavailable);
      },
    );

    test(
      'declining or failing a flexible update does not leave it busy',
      () async {
        final updates = createController();
        await updates.check(manual: true);
        startAccepted = false;

        expect(await updates.startUpdate(), isFalse);
        expect(updates.status, AppUpdateStatus.available);
        expect(updates.busy, isFalse);

        startFailure = PlatformException(
          code: 'UPDATE_FAILED',
          message: 'Play update flow failed',
        );
        expect(await updates.startUpdate(), isFalse);
        expect(updates.status, AppUpdateStatus.unavailable);
        expect(updates.busy, isFalse);

        startFailure = null;
        await updates.check(manual: true);
        expect(updates.status, AppUpdateStatus.available);
        expect(updates.busy, isFalse);
      },
    );

    test('a downloaded update is ready for an optional restart', () async {
      final updates = createController();
      checkInfo = {
        'availableVersionCode': 4007,
        'available': true,
        'downloaded': true,
      };

      await updates.check(manual: true);

      expect(updates.status, AppUpdateStatus.readyToInstall);
      expect(updates.shouldPrompt, isTrue);
    });

    test('a foreground downloaded event makes restart available', () async {
      final updates = createController();
      final ready = Completer<void>();
      updates.addListener(() {
        if (updates.status == AppUpdateStatus.readyToInstall &&
            !ready.isCompleted) {
          ready.complete();
        }
      });

      await updates.initialize();
      final sink = await eventSinkReady.future.timeout(
        const Duration(seconds: 1),
      );
      sink.success({
        'availableVersionCode': 4007,
        'available': true,
        'downloaded': true,
      });
      await ready.future.timeout(const Duration(seconds: 1));

      expect(calls['checkForUpdate'], isNull);
      expect(updates.status, AppUpdateStatus.readyToInstall);
      expect(updates.availableVersionCode, 4007);
      expect(updates.shouldPrompt, isTrue);
    });
  });
}
