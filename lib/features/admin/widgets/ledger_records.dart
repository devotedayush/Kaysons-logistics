import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_widgets.dart';
import 'office_widgets.dart';

enum LedgerProofState {
  missing,
  awaitingReview,
  accepted,
  correctionRequested,
  historicalReceived,
  unverified,
}

/// POD review belongs to a trip/customer, never to an invoice merely because
/// the compatibility ledger view repeats a freight acknowledgement on it.
LedgerProofState ledgerProofState(Map<String, dynamic> row) {
  final freight = row['_proof_freight'] as Map?;
  final origin = freight?['record_origin'] ?? row['record_origin'];
  if (origin == 'historical_import') {
    return row['ack_status'] == 'received'
        ? LedgerProofState.historicalReceived
        : LedgerProofState.missing;
  }
  if (freight?['delivery_workflow_version'] == 1) {
    if (row['_proof_receivers_loaded'] != true) {
      return LedgerProofState.unverified;
    }
    final receivers = (row['_proof_receivers'] as List? ?? const []);
    if (receivers.isEmpty) return LedgerProofState.missing;
    bool hasMissing = false, hasPending = false, hasRejected = false;
    for (final receiver in receivers) {
      final report = receiver['report'] as Map? ?? const {};
      final paths = report['proof_paths'] as List? ?? const [];
      final hasProof = paths.any((path) => path.toString().trim().isNotEmpty);
      if (receiver['pod_review_status'] == 'rejected') {
        hasRejected = true;
      } else if (!hasProof) {
        hasMissing = true;
      } else if (receiver['pod_review_status'] != 'accepted' ||
          report['outcome'] != 'full' ||
          receiver['reviewed_by'] == null ||
          receiver['reviewed_at'] == null) {
        hasPending = true;
      }
    }
    if (hasRejected) return LedgerProofState.correctionRequested;
    if (hasMissing) return LedgerProofState.missing;
    if (hasPending) return LedgerProofState.awaitingReview;
    return LedgerProofState.accepted;
  }
  // Legacy receipt metadata may be supplied by the transporter. It cannot
  // establish office acceptance; only receiver reviews do that.
  bool hasAttachment(dynamic value) {
    if (value is Map) {
      return value.entries.any(
        (entry) =>
            (const {'pod_photo_path', 'pod_file_path'}.contains(entry.key) &&
                entry.value is String &&
                entry.value.toString().trim().isNotEmpty) ||
            (entry.key == 'pod_documents' &&
                entry.value is List &&
                (entry.value as List).isNotEmpty) ||
            (entry.value is Map || entry.value is List) &&
                hasAttachment(entry.value),
      );
    }
    if (value is List) return value.any(hasAttachment);
    return false;
  }

  if ((row['pod_file_path'] ?? '').toString().trim().isNotEmpty ||
      (freight?['pod_file_path'] ?? '').toString().trim().isNotEmpty ||
      hasAttachment(freight?['delivery_stages'])) {
    return LedgerProofState.awaitingReview;
  }
  if (freight == null || row['ack_status'] == 'received') {
    return LedgerProofState.unverified;
  }
  return LedgerProofState.missing;
}

bool ledgerProofNeedsReview(Map<String, dynamic> row) =>
    !{
      LedgerProofState.accepted,
      LedgerProofState.historicalReceived,
    }.contains(ledgerProofState(row));

String ledgerProofExportLabel(Map<String, dynamic> row) =>
    switch (ledgerProofState(row)) {
      LedgerProofState.missing => 'Missing',
      LedgerProofState.awaitingReview => 'Awaiting review',
      LedgerProofState.accepted => 'Accepted',
      LedgerProofState.correctionRequested => 'Correction requested',
      LedgerProofState.historicalReceived => 'Received - historical record',
      LedgerProofState.unverified => 'Review not verified',
    };

String ledgerProofLabel(BuildContext context, LedgerProofState state) =>
    switch (state) {
      LedgerProofState.missing => officeCopy(context, 'Missing', 'प्रमाण बाकी'),
      LedgerProofState.awaitingReview => officeCopy(
        context,
        'Awaiting review',
        'जाँच बाकी',
      ),
      LedgerProofState.accepted => officeCopy(context, 'Accepted', 'स्वीकृत'),
      LedgerProofState.correctionRequested => officeCopy(
        context,
        'Correction requested',
        'सुधार आवश्यक',
      ),
      LedgerProofState.historicalReceived => officeCopy(
        context,
        'Received · historical',
        'प्राप्त · पुराना रिकॉर्ड',
      ),
      LedgerProofState.unverified => officeCopy(
        context,
        'Review not verified',
        'जाँच सत्यापित नहीं',
      ),
    };

class LedgerProofBadge extends StatelessWidget {
  const LedgerProofBadge({super.key, required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final state = ledgerProofState(row);
    return StatusBadge(
      label: ledgerProofLabel(context, state),
      tone: switch (state) {
        LedgerProofState.accepted => WorkspaceTone.success,
        LedgerProofState.historicalReceived => WorkspaceTone.neutral,
        LedgerProofState.correctionRequested => WorkspaceTone.danger,
        _ => WorkspaceTone.warning,
      },
    );
  }
}

bool ledgerMatchesSearch(Map<String, dynamic> row, String query) {
  final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
  dynamic ownValueOrFallback(String own, String aggregate) =>
      (row[own] ?? '').toString().trim().isNotEmpty ? row[own] : row[aggregate];
  final haystack =
      [
        ownValueOrFallback('invoice_number', 'invoice_numbers'),
        ownValueOrFallback('party_name', 'party_names'),
        for (final key in [
          'company_name',
          'origin',
          'town',
          'vehicle_number',
          'transporter_name',
          'delivery_reference',
          'e_way_bill_number',
          '_invoice_eway_bill_numbers',
          'lr_gr_number',
          'dispatch_gr_bilty_number',
        ])
          row[key] ?? '',
      ].join(' ').toLowerCase();
  return terms.every(haystack.contains);
}

/// A single, obvious action leads to the complete record. Desktop columns use
/// available width; phones display the same information as compact cards.
class LedgerRecordTile extends StatelessWidget {
  const LedgerRecordTile({
    super.key,
    required this.row,
    required this.freightLabel,
    required this.onOpen,
    required this.compact,
  });
  final Map<String, dynamic> row;
  final String freightLabel;
  final VoidCallback onOpen;
  final bool compact;
  String text(String key) => (row[key] ?? '—').toString();
  bool hasValue(String key) => (row[key] ?? '').toString().trim().isNotEmpty;
  @override
  Widget build(BuildContext context) {
    final invoice = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasValue('invoice_number')
              ? text('invoice_number')
              : officeCopy(context, 'Invoice not linked', 'इनवॉइस नहीं जुड़ा'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          hasValue('party_name')
              ? text('party_name')
              : officeCopy(
                context,
                'Customer not added',
                'ग्राहक नहीं जोड़ा गया',
              ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (hasValue('company_name'))
          Text(
            text('company_name'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
    final route = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${text('origin')} → ${text('town')}'),
        const SizedBox(height: 4),
        Text(
          hasValue('vehicle_number')
              ? text('vehicle_number')
              : officeCopy(
                context,
                'Vehicle not assigned',
                'वाहन नहीं चुना गया',
              ),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Text(
          text('transporter_name'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final proof = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerProofBadge(row: row),
        const SizedBox(height: 4),
        Text(
          officeCopy(context, 'Trip proof', 'चक्कर का प्रमाण'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final action = OutlinedButton(
      onPressed: onOpen,
      child: Text(
        ledgerProofNeedsReview(row)
            ? officeCopy(context, 'Review', 'जाँचें')
            : officeCopy(context, 'Details', 'विवरण'),
      ),
    );
    if (compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              invoice,
              const SizedBox(height: 12),
              route,
              const Divider(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    freightLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  proof,
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: action),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: invoice),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: route),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Text(
              freightLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: proof),
          const SizedBox(width: 16),
          SizedBox(width: 144, child: action),
        ],
      ),
    );
  }
}
