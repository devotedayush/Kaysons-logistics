import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/supabase/auth_service.dart';

void main() {
  group('normalizeIndiaPhoneNumber', () {
    test('normalizes a ten-digit Indian mobile number', () {
      expect(normalizeIndiaPhoneNumber('98765 43210'), '+919876543210');
    });

    test('accepts +91 and 91 country-code forms', () {
      expect(normalizeIndiaPhoneNumber('+91 98765-43210'), '+919876543210');
      expect(normalizeIndiaPhoneNumber('91 (98765) 43210'), '+919876543210');
    });

    test('matches Supabase phone values with or without the plus prefix', () {
      expect(isSameIndiaPhoneNumber('919876543210', '+919876543210'), isTrue);
      expect(isSameIndiaPhoneNumber('9876543210', '+919876543210'), isTrue);
      expect(isSameIndiaPhoneNumber('9876543211', '+919876543210'), isFalse);
      expect(isSameIndiaPhoneNumber(null, '+919876543210'), isFalse);
    });

    test('rejects invalid lengths, prefixes, and misplaced plus signs', () {
      for (final input in [
        '1234567890',
        '987654321',
        '+1 9876543210',
        '91+9876543210',
      ]) {
        expect(
          () => normalizeIndiaPhoneNumber(input),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });
}
