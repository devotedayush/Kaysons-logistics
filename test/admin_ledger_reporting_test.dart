import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/admin/admin_ledger_body.dart';

void main() {
  group('ledger date selection', () {
    test('custom range clears the month filter', () {
      final start = DateTime(2026, 4, 3);
      final end = DateTime(2026, 4, 18);

      final startSelection = selectLedgerCustomDateRange(
        currentStart: null,
        currentEnd: null,
        pickedStart: start,
      );
      final rangeSelection = selectLedgerCustomDateRange(
        currentStart: startSelection.start,
        currentEnd: startSelection.end,
        pickedEnd: end,
      );

      expect(rangeSelection.month, isNull);
      expect(rangeSelection.start, start);
      expect(rangeSelection.end, end);
    });

    test('selecting a month clears a prior custom range', () {
      final selection = selectLedgerMonth(DateTime(2026, 7, 22));

      expect(selection.month, DateTime(2026, 7));
      expect(selection.start, isNull);
      expect(selection.end, isNull);
    });

    test('selecting an end date before the start makes a one-day range', () {
      final selectedEnd = DateTime(2026, 4, 3);
      final selection = selectLedgerCustomDateRange(
        currentStart: DateTime(2026, 4, 18),
        currentEnd: DateTime(2026, 4, 25),
        pickedEnd: selectedEnd,
      );

      expect(selection.month, isNull);
      expect(selection.start, selectedEnd);
      expect(selection.end, selectedEnd);
    });
  });

  test('invoice and E-Way searches stay on the matching invoice row', () {
    final firstInvoice = {
      'freight_id': 'dispatch-1',
      'invoice_number': 'INV-101',
      'invoice_numbers': 'INV-101, INV-202',
      'e_way_bill_number': 'EWB-1',
      'e_way_bill_numbers': 'EWB-1, EWB-2',
      '_invoice_eway_bill_numbers': ['EWB-1'],
    };
    final secondInvoice = {
      'freight_id': 'dispatch-1',
      'invoice_number': 'INV-202',
      'invoice_numbers': 'INV-101, INV-202',
      'e_way_bill_number': 'EWB-2',
      'e_way_bill_numbers': 'EWB-1, EWB-2',
      '_invoice_eway_bill_numbers': ['EWB-2'],
    };

    expect(
      ledgerRowMatchesInvoiceDocumentSearch(
        firstInvoice,
        invoiceQuery: 'INV-202',
        ewayQuery: '',
      ),
      isFalse,
    );
    expect(
      ledgerRowMatchesInvoiceDocumentSearch(
        secondInvoice,
        invoiceQuery: 'INV-202',
        ewayQuery: '',
      ),
      isTrue,
    );
    expect(
      ledgerRowMatchesInvoiceDocumentSearch(
        firstInvoice,
        invoiceQuery: '',
        ewayQuery: 'EWB-2',
      ),
      isFalse,
    );
    expect(
      ledgerRowMatchesInvoiceDocumentSearch(
        secondInvoice,
        invoiceQuery: '',
        ewayQuery: 'EWB-2',
      ),
      isTrue,
    );
  });

  test(
    'slash-joined historical E-Way values remain searchable individually',
    () {
      final row = {
        'invoice_number': 'INV-1',
        'e_way_bill_number': 'EWB-1 / EWB-2',
      };

      expect(
        ledgerRowMatchesInvoiceDocumentSearch(
          row,
          invoiceQuery: '',
          ewayQuery: 'EWB-2',
        ),
        isTrue,
      );
    },
  );

  test('E-Way display includes mapped documents for only this invoice', () {
    final row = {
      'invoice_number': 'INV-1',
      'e_way_bill_number': null,
      'e_way_bill_numbers': 'DISPATCH-EWB-1, DISPATCH-EWB-2',
      '_invoice_eway_bill_numbers': ['INV-EWB-2', 'INV-EWB-1'],
    };

    expect(ledgerInvoiceEwayBillDisplay(row), 'INV-EWB-1 / INV-EWB-2');
  });

  test('POD totals count one dispatch once across its invoices', () {
    final rows = [
      {'freight_id': 'dispatch-1', 'ack_status': 'pending'},
      {'freight_id': 'dispatch-1', 'ack_status': 'pending'},
      {'freight_id': 'dispatch-2', 'ack_status': 'received'},
      {'freight_id': 'dispatch-2', 'ack_status': 'received'},
    ];

    expect(
      countDistinctFreightRows(
        rows,
        where: (row) => row['ack_status'] != 'received',
      ),
      1,
    );
    expect(
      countDistinctFreightRows(
        rows,
        where: (row) => row['ack_status'] == 'received',
      ),
      1,
    );
  });

  test(
    'monthly settlement amounts and closing balance emit once per group',
    () {
      final allRows = [
        {
          'company_name': 'Bunge',
          'transporter_id': 'transporter-1',
          'period_month': '2026-04-01',
          'last_month_balance': 100,
          'payment_amount': 40,
          'settlement_deduction': 10,
          'total_freight': 300,
          'balance': 350,
        },
        {
          'company_name': 'Bunge',
          'transporter_id': 'transporter-1',
          'period_month': '2026-04-01',
          'last_month_balance': 100,
          'payment_amount': 40,
          'settlement_deduction': 10,
          'total_freight': 200,
          'balance': 250,
        },
      ];

      final normalized = normalizeLedgerSettlementFields(
        displayedRows: allRows,
        allRows: allRows,
      );

      expect(
        normalized.map((row) => row['last_month_balance']).whereType<num>().sum,
        100,
      );
      expect(
        normalized.map((row) => row['payment_amount']).whereType<num>().sum,
        40,
      );
      expect(
        normalized
            .map((row) => row['settlement_deduction'])
            .whereType<num>()
            .sum,
        10,
      );
      expect(normalized.map((row) => row['balance']).whereType<num>().sum, 550);
    },
  );

  test('filtered invoice can carry its full monthly settlement summary', () {
    final allRows = [
      {
        'company_name': 'Cargill',
        'transporter_id': 'transporter-2',
        'period_month': '2026-04-01',
        'last_month_balance': 50,
        'payment_amount': 5,
        'settlement_deduction': 3,
        'total_freight': 100,
      },
      {
        'company_name': 'Cargill',
        'transporter_id': 'transporter-2',
        'period_month': '2026-04-01',
        'last_month_balance': 50,
        'payment_amount': 5,
        'settlement_deduction': 3,
        'total_freight': 250,
      },
    ];

    final filtered = normalizeLedgerSettlementFields(
      displayedRows: [allRows.last],
      allRows: allRows,
    );

    expect(filtered.single['balance'], 392);
    expect(filtered.single['last_month_balance'], 50);
    expect(filtered.single['period_month'], '2026-04-01');
  });

  test('explicit imported vehicle capacity wins over weight inference', () {
    expect(
      ledgerVehicleCapacityForImport(
        explicitCategory: '6-9 MT',
        combinedMetricTons: 2.5,
      ),
      '6-9 MT',
    );
    expect(
      ledgerVehicleCapacityForImport(
        explicitCategory: null,
        combinedMetricTons: 2.5,
      ),
      'Up to 3 MT',
    );
  });
}

extension _NumIterableSum on Iterable<num> {
  num get sum => fold<num>(0, (total, value) => total + value);
}
