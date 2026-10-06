import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';

void main() {
  test('supplied Bunge workbook CSV remains accepted', () {
    expect(
      validateLedgerCsv(
        File(
          'docs/Demo Data/Rajesh Anand - Bunge Apr.26.csv',
        ).readAsStringSync(),
      ),
      268,
    );
  });
  const header =
      'Bill Date,Party Name,Place,Invoice Number,Cases,Weight MT,Freight\n';
  test(
    'valid fractional metric tons and quoted party survive CSV validation',
    () {
      expect(
        validateLedgerCsv(
          '${header}01/Apr/26,"Party, Branch",Ludhiana,INV1,2,2.5,3400',
        ),
        1,
      );
    },
  );
  test('missing required row is reported rather than silently discarded', () {
    expect(
      () => validateLedgerCsv('${header}01/Apr/26,,Ludhiana,INV1,2,2.5,3400'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'row number',
          contains('row 2'),
        ),
      ),
    );
  });
  for (final value in ['abc', '-1', 'NaN', 'Infinity']) {
    test('reject invalid freight $value before import', () {
      expect(
        () => validateLedgerCsv(
          '${header}01/Apr/26,Party,Ludhiana,INV1,2,2.5,$value',
        ),
        throwsFormatException,
      );
    });
  }
  test('fractional case counts are not rounded', () {
    expect(
      () => validateLedgerCsv(
        '${header}01/Apr/26,Party,Ludhiana,INV1,2.5,2.5,3400',
      ),
      throwsFormatException,
    );
  });
  test('impossible date is not normalized into next month', () {
    expect(
      () => validateLedgerCsv(
        '${header}2026-02-31,Party,Ludhiana,INV1,2,2.5,3400',
      ),
      throwsFormatException,
    );
  });
  test('unterminated quotes reject whole upload', () {
    expect(
      () => validateLedgerCsv(
        '${header}01/Apr/26,"Party,Ludhiana,INV1,2,2.5,3400',
      ),
      throwsFormatException,
    );
  });
}
