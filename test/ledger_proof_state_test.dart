import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/features/admin/widgets/ledger_records.dart';

Map<String, dynamic> receiver({
  String outcome = 'full',
  String review = 'accepted',
  List<String> proof = const ['winner/trip/receiver/pod.pdf'],
  String? reviewer = 'office-reviewer',
  String? reviewedAt = '2026-10-05T08:00:00Z',
}) => {
  'report': {'outcome': outcome, 'proof_paths': proof},
  'pod_review_status': review,
  'reviewed_by': reviewer,
  'reviewed_at': reviewedAt,
};

Map<String, dynamic> workflowRow(
  List<Map<String, dynamic>> customers, {
  bool loaded = true,
}) => {
  'ack_status':
      'received', // Compatibility-view value must never override customers.
  '_proof_freight': {
    'record_origin': 'live',
    'delivery_workflow_version': 1,
    'ack_status': 'received',
  },
  '_proof_receivers_loaded': loaded,
  '_proof_receivers': customers,
};

void main() {
  test('search keeps sibling invoices and customers isolated', () {
    final shared = {
      'invoice_numbers': 'INV-101, INV-202',
      'party_names': 'Customer A, Customer B',
    };
    final first = {
      ...shared,
      'invoice_number': 'INV-101',
      'party_name': 'Customer A',
    };
    final second = {
      ...shared,
      'invoice_number': 'INV-202',
      'party_name': 'Customer B',
    };
    expect(ledgerMatchesSearch(first, 'INV-202'), isFalse);
    expect(ledgerMatchesSearch(second, 'inv-202'), isTrue);
    expect(ledgerMatchesSearch(first, 'Customer B'), isFalse);
    expect(ledgerMatchesSearch(second, 'customer b'), isTrue);
    expect(ledgerMatchesSearch(shared, 'INV-202'), isTrue);
  });
  group('compatibility acknowledgement is not review acceptance', () {
    test('POD notes and timestamps are not attachments', () {
      expect(
        ledgerProofState({
          'ack_status': 'pending',
          '_proof_freight': {
            'record_origin': 'live',
            'delivery_stages': {
              'delivered': {
                'pod_note': 'Customer will share it tomorrow',
                'pod_uploaded_at': '2026-10-05',
              },
            },
          },
        }),
        LedgerProofState.missing,
      );
    });
    test('derived received acknowledgement alone stays unverified', () {
      expect(
        ledgerProofState({'ack_status': 'received'}),
        LedgerProofState.unverified,
      );
    });
    test(
      'legacy file upload awaits review even when derived ack is received',
      () {
        expect(
          ledgerProofState({
            'ack_status': 'received',
            'pod_file_path': 'winner/trip/pod.pdf',
          }),
          LedgerProofState.awaitingReview,
        );
      },
    );
    test('freight and legacy stop proof uploads are recognised', () {
      for (final stages in [
        {
          'delivered': {'pod_photo_path': 'winner/trip/pod.png'},
        },
        {
          'delivered_stops': [
            {'stop_index': 0, 'pod_photo_path': 'winner/trip/stop.pdf'},
          ],
        },
      ]) {
        expect(
          ledgerProofState({
            'ack_status': 'pending',
            '_proof_freight': {
              'record_origin': 'live',
              'delivery_stages': stages,
            },
          }),
          LedgerProofState.awaitingReview,
        );
      }
    });
    test(
      'loaded live legacy freight without acknowledgement or proof is missing',
      () {
        expect(
          ledgerProofState({
            'ack_status': 'pending',
            '_proof_freight': {
              'record_origin': 'live',
              'ack_status': 'pending',
            },
          }),
          LedgerProofState.missing,
        );
      },
    );
    test(
      'office legacy acknowledgement without digital review stays unverified',
      () {
        expect(
          ledgerProofState({
            'ack_status': 'received',
            '_proof_freight': {
              'record_origin': 'live',
              'delivery_workflow_version': 0,
              'ack_status': 'received',
              'winner_profile_id': 'assigned-transporter',
              'pod_received_by': 'office-reviewer',
              'pod_received_date': '2026-10-05',
            },
          }),
          LedgerProofState.unverified,
        );
      },
    );
    test('legacy office acknowledgement with an attachment awaits review', () {
      expect(
        ledgerProofState({
          'ack_status': 'received',
          '_proof_freight': {
            'record_origin': 'live',
            'delivery_workflow_version': 0,
            'ack_status': 'received',
            'winner_profile_id': 'assigned-transporter',
            'pod_received_by': 'office-reviewer',
            'pod_received_date': '2026-10-05',
            'pod_file_path': 'assigned-transporter/trip/pod.pdf',
          },
        }),
        LedgerProofState.awaitingReview,
      );
    });
    test(
      'transporter legacy self-acknowledgement does not prove office review',
      () {
        expect(
          ledgerProofState({
            'ack_status': 'received',
            '_proof_freight': {
              'record_origin': 'live',
              'delivery_workflow_version': 0,
              'ack_status': 'received',
              'winner_profile_id': 'assigned-transporter',
              'pod_received_by': 'assigned-transporter',
              'pod_received_date': '2026-10-05',
              'pod_file_path': 'assigned-transporter/trip/pod.pdf',
            },
          }),
          LedgerProofState.awaitingReview,
        );
      },
    );
  });

  group('historical receipt stays distinct from digitally reviewed proof', () {
    test('received historical record is not labelled accepted', () {
      final row = {
        'ack_status': 'received',
        '_proof_freight': {
          'record_origin': 'historical_import',
          'ack_status': 'received',
          'pod_received_by': 'import-actor',
          'pod_received_date': '2026-04-30',
        },
      };
      expect(ledgerProofState(row), LedgerProofState.historicalReceived);
      expect(ledgerProofNeedsReview(row), isFalse);
    });
    test('historical pending receipt remains missing', () {
      expect(
        ledgerProofState({
          'ack_status': 'pending',
          'record_origin': 'historical_import',
        }),
        LedgerProofState.missing,
      );
    });
  });

  group('receiving workflow requires every customer proof and review', () {
    test('proof, full handover and reviewer audit establish acceptance', () {
      final row = workflowRow([receiver(), receiver()]);
      expect(ledgerProofState(row), LedgerProofState.accepted);
      expect(ledgerProofNeedsReview(row), isFalse);
    });
    test('no customer records is missing, not vacuously accepted', () {
      expect(ledgerProofState(workflowRow([])), LedgerProofState.missing);
    });
    test('unloaded customer review data remains unverified', () {
      expect(
        ledgerProofState(workflowRow([receiver()], loaded: false)),
        LedgerProofState.unverified,
      );
    });
    test('accepted flag without attachments remains missing', () {
      for (final paths in [
        <String>[],
        <String>['', '   '],
      ]) {
        expect(
          ledgerProofState(workflowRow([receiver(proof: paths)])),
          LedgerProofState.missing,
        );
      }
    });
    test('pending proof review awaits review', () {
      expect(
        ledgerProofState(workflowRow([receiver(review: 'pending')])),
        LedgerProofState.awaitingReview,
      );
    });
    test('partial, refused and attempted reports cannot be accepted', () {
      for (final outcome in ['partial', 'refused', 'attempted']) {
        expect(
          ledgerProofState(workflowRow([receiver(outcome: outcome)])),
          LedgerProofState.awaitingReview,
          reason: outcome,
        );
      }
    });
    test('missing reviewer or review date cannot establish acceptance', () {
      for (final customer in [
        receiver(reviewer: null),
        receiver(reviewedAt: null),
      ]) {
        expect(
          ledgerProofState(workflowRow([customer])),
          LedgerProofState.awaitingReview,
        );
      }
    });
    test('rejected customer proof requests correction', () {
      expect(
        ledgerProofState(workflowRow([receiver(review: 'rejected')])),
        LedgerProofState.correctionRequested,
      );
    });
    test('one pending customer prevents whole-trip acceptance', () {
      expect(
        ledgerProofState(
          workflowRow([receiver(), receiver(review: 'pending')]),
        ),
        LedgerProofState.awaitingReview,
      );
    });
    test('one missing customer proof prevents whole-trip acceptance', () {
      final row = workflowRow([receiver(), receiver(proof: [])]);
      expect(ledgerProofState(row), LedgerProofState.missing);
      expect(ledgerProofNeedsReview(row), isTrue);
    });
    test(
      'correction remains visible alongside accepted and missing customers',
      () {
        expect(
          ledgerProofState(
            workflowRow([
              receiver(),
              receiver(proof: []),
              receiver(review: 'rejected'),
            ]),
          ),
          LedgerProofState.correctionRequested,
        );
      },
    );
  });
}
