import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/utils/csv_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'CSV export passes its name and UTF-8 content to the native save dialog',
    () async {
      MethodCall? savedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            savedCall = call;
            return '/tmp/kaysons-report.csv';
          });

      await downloadCsv('kaysons-report.csv', 'नाम,राशि\nअजय,१००\n');

      expect(savedCall?.method, 'save');
      final args = savedCall!.arguments as Map<Object?, Object?>;
      expect(args['fileName'], 'kaysons-report.csv');
      expect(args['fileType'], 'custom');
      expect(args['allowedExtensions'], ['csv']);
      expect(utf8.decode(args['bytes'] as Uint8List), 'नाम,राशि\nअजय,१००\n');
    },
  );
}
