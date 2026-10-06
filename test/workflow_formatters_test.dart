import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/utils/workflow_formatters.dart';

void main() {
  test('shows clock times with AM and PM, including noon and midnight', () {
    expect(format12HourTime(DateTime(2026, 9, 26, 0, 5)), '12:05 AM');
    expect(format12HourTime(DateTime(2026, 9, 26, 12)), '12:00 PM');
    expect(format12HourTime(DateTime(2026, 9, 26, 14, 30)), '2:30 PM');
    expect(format12HourTime(DateTime(2026, 9, 26, 23, 59)), '11:59 PM');
  });

  group('metric ton formatting', () {
    test('keeps integer zeros when no decimal places are requested', () {
      expect(formatMetricTons(1000, maxDecimalPlaces: 0), '1000');
      expect(formatMetricTons(4.5, maxDecimalPlaces: 0), '5');
    });

    test('preserves useful fractional precision', () {
      expect(formatMetricTons(4.5), '4.5');
      expect(formatMetricTons(6.125), '6.125');
      expect(formatMetricTons(6.1259), '6.126');
    });
  });

  group('Indian phone normalization', () {
    test('normalizes local and +91 formatted input', () {
      expect(normalizeIndianPhone('98765 43210'), '+919876543210');
      expect(normalizeIndianPhone('+91 98765-43210'), '+919876543210');
    });

    test('rejects placeholders and hidden invalid characters', () {
      expect(normalizeIndianPhone('0000000000'), isNull);
      expect(normalizeIndianPhone('abc9876543210'), isNull);
      expect(normalizeIndianPhone('1234567890'), isNull);
    });
  });

  test('canonicalizes operational charge aliases', () {
    expect(canonicalChargeKind('toll'), 'toll_tax');
    expect(canonicalChargeKind('club'), 'point_charge');
    expect(canonicalChargeKind('dalla'), 'point_charge');
    expect(canonicalChargeKind('other'), 'other');
  });
}
