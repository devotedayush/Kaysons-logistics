import '../logistics_manager/widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/delivery_workflow_repo.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/widgets/storage_photo_viewer.dart';

String _t(BuildContext c, String en, String hi) =>
    Localizations.localeOf(c).languageCode == 'hi' ? hi : en;
String _errorText(BuildContext c, Object? error) {
  if (error is PostgrestException) return error.message;
  if (error is StorageException) return error.message;
  if (error is FormatException) return error.message;
  return _t(
    c,
    'Could not save or load these details. Please try again.',
    'विवरण सहेजे या लोड नहीं हो सके। फिर प्रयास करें।',
  );
}

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map? ?? const {});
List<String> _paths(dynamic value) =>
    (value as List? ?? const []).map((e) => e.toString()).toList();
String _date(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Receiving customers are separate from route stops. For example, two parties
/// in Moga share one stop, truck and accepted freight, but each has its own POD.
class DeliveryWorkflowPanel extends StatefulWidget {
  const DeliveryWorkflowPanel({
    super.key,
    required this.freight,
    this.office = false,
    this.readOnly = false,
    this.canEditPlan = true,
    this.canApproveExpenses = true,
    this.loadData,
  });
  final Map<String, dynamic> freight;
  final bool office;
  final bool readOnly;
  final bool canEditPlan;
  final bool canApproveExpenses;
  final Future<List<List<Map<String, dynamic>>>> Function()? loadData;
  @override
  State<DeliveryWorkflowPanel> createState() => _DeliveryWorkflowPanelState();
}

class _DeliveryWorkflowPanelState extends State<DeliveryWorkflowPanel> {
  final _repo = DeliveryWorkflowRepo.instance;
  late Future<List<List<Map<String, dynamic>>>> _data;
  String get _id => widget.freight['id'].toString();
  bool get _enabled => widget.freight['delivery_workflow_version'] == 1;
  bool get _started => const [
    'dispatched',
    'locked',
    'completed',
  ].contains(widget.freight['status']);
  List<String> get _towns {
    final details = widget.freight['stop_details'];
    if (details is List && details.isNotEmpty) {
      return details.map((e) => _map(e)['name'].toString()).toList();
    }
    return [
      ..._paths(widget.freight['stops']),
      widget.freight['destination_town']?.toString() ?? '',
    ].where((e) => e.trim().isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    _reload(set: false);
  }

  @override
  void didUpdateWidget(covariant DeliveryWorkflowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.freight['id'] != widget.freight['id'] ||
        oldWidget.freight['updated_at'] != widget.freight['updated_at'] ||
        oldWidget.freight['delivery_workflow_version'] !=
            widget.freight['delivery_workflow_version']) {
      _reload(set: false);
    }
  }

  void _reload({bool set = true}) {
    _data =
        !_enabled
            ? Future.value([[], [], []])
            : widget.loadData?.call() ??
                Future.wait([
                  _repo.fetchReceivers(_id),
                  _repo.fetchJourney(_id),
                  _repo.fetchExpenses(_id),
                ]);
    if (set && mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      if (widget.readOnly ||
          !widget.office ||
          !widget.canEditPlan ||
          widget.freight['record_origin'] == 'historical_import') {
        return const SizedBox.shrink();
      }
      return _card(
        title: _t(
          context,
          'Receiving customers',
          'माल प्राप्त करने वाले ग्राहक',
        ),
        icon: Icons.groups_outlined,
        children: [
          Text(
            _t(
              context,
              'Set up the customers at each stop before the transporter reports delivery. Existing trip history is preserved.',
              'डिलीवरी रिपोर्ट से पहले हर पड़ाव के ग्राहक जोड़ें। पुराना यात्रा विवरण सुरक्षित रहेगा।',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _run(() => _repo.ensurePlan(_id)),
            icon: const Icon(Icons.add_road),
            label: Text(
              _t(context, 'Set up delivery plan', 'डिलीवरी योजना बनाएँ'),
            ),
          ),
        ],
      );
    }
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return _card(
            title: _t(
              context,
              'Delivery details unavailable',
              'डिलीवरी विवरण उपलब्ध नहीं',
            ),
            icon: Icons.error_outline,
            children: [
              Text(_errorText(context, snap.error)),
              TextButton(
                onPressed: _reload,
                child: Text(_t(context, 'Retry', 'दोबारा प्रयास करें')),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final receivers = snap.data![0];
        final journey = snap.data![1];
        final expenses = snap.data![2];
        final reported =
            receivers
                .where((r) => _map(r['report'])['submitted_at'] != null)
                .length;
        final accepted =
            receivers.where((r) => r['pod_review_status'] == 'accepted').length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              title: _t(context, 'Delivery overview', 'डिलीवरी का सार'),
              icon: Icons.fact_check_outlined,
              action: IconButton(
                tooltip: _t(
                  context,
                  'Refresh delivery details',
                  'डिलीवरी विवरण फिर लोड करें',
                ),
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
              children: [
                GuidanceCard(
                  title:
                      widget.office
                          ? _t(
                            context,
                            'Next: review customer deliveries',
                            'अगला: ग्राहक डिलीवरी जाँचें',
                          )
                          : _t(
                            context,
                            'Next: record each customer handover',
                            'अगला: हर ग्राहक की डिलीवरी दर्ज करें',
                          ),
                  message:
                      widget.office
                          ? _t(
                            context,
                            'Check quantities and proof for each customer before accepting.',
                            'स्वीकार करने से पहले हर ग्राहक की मात्रा और प्रमाण जाँचें।',
                          )
                          : _t(
                            context,
                            'Record who received the goods and when. Upload proof separately when it is ready.',
                            'माल किसने और कब लिया, दर्ज करें। तैयार होने पर प्रमाण अपलोड करें।',
                          ),
                  tone:
                      accepted == receivers.length && receivers.isNotEmpty
                          ? WorkspaceTone.success
                          : WorkspaceTone.info,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: receivers.isEmpty ? 0 : accepted / receivers.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: _t(
                        context,
                        '$reported/${receivers.length} customers reported',
                        '$reported/${receivers.length} ग्राहकों की रिपोर्ट',
                      ),
                      tone: WorkspaceTone.neutral,
                    ),
                    StatusBadge(
                      label: _t(
                        context,
                        '$accepted/${receivers.length} PODs accepted',
                        '$accepted/${receivers.length} POD स्वीकृत',
                      ),
                      tone: WorkspaceTone.neutral,
                    ),
                  ],
                ),
                Text(
                  _t(
                    context,
                    'Delivery reports and office proof approval are separate steps.',
                    'डिलीवरी रिपोर्ट और कार्यालय की प्रमाण स्वीकृति अलग चरण हैं।',
                  ),
                ),
              ],
            ),
            _card(
              title: _t(context, 'Receiving customers & POD', 'ग्राहक और POD'),
              icon: Icons.inventory_2_outlined,
              children: [
                if (widget.office && !widget.readOnly && widget.canEditPlan)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed:
                          receivers.any((r) => _map(r['report']).isNotEmpty)
                              ? null
                              : () => _editPlan(receivers),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        _t(
                          context,
                          'Edit customers & references',
                          'ग्राहक और दस्तावेज़ बदलें',
                        ),
                      ),
                    ),
                  ),
                if (receivers.isEmpty)
                  Text(
                    _t(
                      context,
                      'No receiving customers yet. Ask the office to complete the delivery plan.',
                      'कार्यालय से डिलीवरी योजना पूरी करने को कहें।',
                    ),
                  ),
                OperationalCardGrid(
                  children: [
                    for (final receiver in receivers) _receiver(receiver),
                  ],
                ),
              ],
            ),
            _journeyCard(journey),
            _expensesCard(expenses, receivers),
          ],
        );
      },
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? action,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3DFEA)),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF60468B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _journeyCard(List<Map<String, dynamic>> rows) => _card(
    title: _t(
      context,
      'In transit · journey updates',
      'रास्ते में · यात्रा अपडेट',
    ),
    icon: Icons.route_outlined,
    children: [
      Text(
        _t(
          context,
          'Record the current location and next destination when there is an update. ETA is an estimate, not the actual delivery time.',
          'स्थिति बदलने पर वर्तमान स्थान और अगला पड़ाव दर्ज करें। ETA अनुमान है, वास्तविक डिलीवरी समय नहीं।',
        ),
      ),
      if (!widget.office && !widget.readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _started && _towns.isNotEmpty ? _addJourney : null,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(
              _t(context, 'Add journey update', 'यात्रा अपडेट जोड़ें'),
            ),
          ),
        ),
      if (!_started)
        Text(
          _t(
            context,
            'Available after vehicle dispatch.',
            'वाहन रवाना होने के बाद उपलब्ध।',
          ),
        ),
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _t(
              context,
              'No journey updates recorded.',
              'अभी कोई यात्रा अपडेट नहीं है।',
            ),
          ),
        ),
      for (final (index, row) in rows.indexed)
        ExpansionTile(
          initiallyExpanded: index == 0,
          tilePadding: EdgeInsets.zero,
          title: Text(
            '${row['location'] ?? '—'} → ${row['next_destination'] ?? '—'}',
          ),
          subtitle: Text(
            '${_t(context, 'Updated', 'अपडेट')} ${_date(row['submitted_at'])}',
          ),
          children: [
            _line(
              _t(context, 'Expected arrival', 'अनुमानित आगमन'),
              _date(row['eta']),
            ),
            if ((row['delay_reason'] ?? '').toString().isNotEmpty)
              _line(
                _t(context, 'Delay reason', 'देरी का कारण'),
                row['delay_reason'],
              ),
            if ((row['vehicle_number'] ?? '').toString().isNotEmpty)
              _line(
                _t(context, 'Vehicle observed', 'देखा गया वाहन'),
                row['vehicle_number'],
              ),
            for (final c in row['contractors'] as List? ?? const [])
              _line(
                _t(context, 'Route contractor', 'मार्ग ठेकेदार'),
                '${_map(c)['name']} · ${_map(c)['phone']}\n${_map(c)['from']} → ${_map(c)['to']}',
              ),
            _documents(
              _paths(row['photo_paths']),
              _t(context, 'Journey photo', 'यात्रा फोटो'),
            ),
          ],
        ),
    ],
  );

  Widget _receiver(Map<String, dynamic> row) {
    final report = _map(row['report']);
    final reported = report.isNotEmpty;
    final review = row['pod_review_status']?.toString() ?? 'pending';
    final proof = _paths(report['proof_paths']);
    final status =
        review == 'accepted'
            ? _t(
              context,
              'POD accepted by office',
              'कार्यालय ने POD स्वीकार किया',
            )
            : review == 'rejected'
            ? _t(context, 'Correction requested', 'सुधार आवश्यक')
            : proof.isNotEmpty
            ? _t(
              context,
              'POD uploaded · awaiting review',
              'POD अपलोड · जाँच बाकी',
            )
            : reported
            ? _t(
              context,
              'Delivery reported · POD pending',
              'डिलीवरी रिपोर्ट · POD बाकी',
            )
            : _t(context, 'Delivery not reported', 'डिलीवरी रिपोर्ट बाकी');
    final outcome = report['outcome']?.toString();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${(row['stop_index'] as num? ?? 0).toInt() + 1}. ${row['town']} · ${row['party_name']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          StatusBadge(
            label: status,
            tone:
                review == 'accepted'
                    ? WorkspaceTone.success
                    : review == 'rejected' ||
                        (outcome != null && outcome != 'full')
                    ? WorkspaceTone.warning
                    : WorkspaceTone.info,
          ),
          _line(
            _t(context, 'Planned quantity', 'निर्धारित मात्रा'),
            '${row['planned_cases'] ?? '—'} ${_t(context, 'cases', 'केस')} · ${row['planned_weight_mt'] ?? '—'} MT',
          ),
          if (row['planned_cases'] == null || row['planned_weight_mt'] == null)
            Text(
              _t(
                context,
                'The sheet does not allocate this quantity to a customer. The office can fill it when known.',
                'शीट में इस ग्राहक की अलग मात्रा नहीं है। जानकारी मिलने पर कार्यालय इसे भर सकता है।',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF62606A)),
            ),
          for (final (key, label) in [
            ('gr_numbers', 'GR'),
            ('lr_numbers', 'LR'),
            ('e_way_bill_numbers', 'E-way bill'),
          ])
            if (_paths(row[key]).isNotEmpty)
              _line(label, _paths(row[key]).join(', ')),
          if (reported) ...[
            _line(
              _t(context, 'Handover', 'माल सौंपना'),
              _outcome(outcome ?? 'full'),
            ),
            _line(
              _t(context, 'Actual delivery time', 'वास्तविक डिलीवरी समय'),
              _date(report['delivered_at']),
            ),
            _line(
              _t(context, 'Received by', 'प्राप्तकर्ता'),
              '${report['recipient_name']} ${report['recipient_phone'] ?? ''}',
            ),
            if (outcome != 'full') ...[
              _line(
                _t(context, 'Cases received', 'प्राप्त केस'),
                report['cases_received'],
              ),
              _line(
                _t(context, 'Weight received (MT)', 'प्राप्त वजन (MT)'),
                report['weight_received_mt'],
              ),
              if (report['cases_damaged'] != null)
                _line(
                  _t(context, 'Damaged cases', 'खराब केस'),
                  report['cases_damaged'],
                ),
              if (report['cases_rejected'] != null)
                _line(
                  _t(context, 'Rejected cases', 'अस्वीकृत केस'),
                  report['cases_rejected'],
                ),
              if (row['planned_cases'] != null &&
                  report['cases_received'] != null)
                _line(
                  _t(context, 'Cases not accepted', 'स्वीकार नहीं किए गए केस'),
                  (row['planned_cases'] as num) -
                      (report['cases_received'] as num),
                ),
              _line(
                _t(
                  context,
                  'Discrepancy / attempt reason',
                  'अंतर / प्रयास का कारण',
                ),
                report['discrepancy_reason'],
              ),
            ],
            _line(
              _t(context, 'Report submitted', 'रिपोर्ट दर्ज हुई'),
              _date(report['submitted_at']),
            ),
            _documents(proof, 'POD'),
            _documents(
              _paths(report['site_photo_paths']),
              _t(context, 'Delivery site photo', 'डिलीवरी स्थल फोटो'),
            ),
          ],
          if ((row['pod_review_note'] ?? '').toString().isNotEmpty)
            _line(
              _t(context, 'Office review note', 'कार्यालय की टिप्पणी'),
              row['pod_review_note'],
            ),
          const SizedBox(height: 8),
          if (!widget.office && !widget.readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed:
                    _started && review != 'accepted'
                        ? () => _report(row)
                        : null,
                icon: const Icon(Icons.assignment_outlined),
                label: Text(
                  _t(
                    context,
                    reported ? 'Update report / upload POD' : 'Report delivery',
                    reported
                        ? 'रिपोर्ट बदलें / POD जोड़ें'
                        : 'डिलीवरी रिपोर्ट करें',
                  ),
                ),
              ),
            ),
          if (widget.office &&
              !widget.readOnly &&
              reported &&
              review != 'accepted')
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      proof.isEmpty || outcome != 'full'
                          ? null
                          : () => _run(
                            () => _repo.reviewPod(row['id'], 'accepted'),
                          ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_t(context, 'Accept POD', 'POD स्वीकार करें')),
                ),
                OutlinedButton(
                  onPressed: () => _reviewNote(row['id'], pod: true),
                  child: Text(
                    _t(context, 'Request correction', 'सुधार माँगें'),
                  ),
                ),
              ],
            ),
          if (widget.office && reported && outcome != 'full')
            Text(
              _t(
                context,
                'Resolve the shortfall with the transporter before accepting this delivery.',
                'डिलीवरी स्वीकार करने से पहले ट्रांसपोर्टर के साथ कमी का समाधान करें।',
              ),
            ),
        ],
      ),
    );
  }

  String _outcome(String value) => switch (value) {
    'full' => _t(context, 'Full delivery', 'पूरी डिलीवरी'),
    'partial' => _t(context, 'Partial delivery', 'आंशिक डिलीवरी'),
    'refused' => _t(context, 'Refused by customer', 'ग्राहक ने मना किया'),
    _ => _t(context, 'Delivery attempted', 'डिलीवरी का प्रयास'),
  };
  Widget _line(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LayoutBuilder(
      builder: (context, size) {
        final content = Text(
          value == null || value.toString().isEmpty ? '—' : value.toString(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        );
        if (size.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              content,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
  Widget _documents(List<String> paths, String label) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final (i, path) in paths.indexed)
        OutlinedButton.icon(
          onPressed:
              () => showDeliveryDocumentPreview(
                context: context,
                title: '$label ${i + 1}',
                path: path,
              ),
          icon: Icon(
            path.toLowerCase().endsWith('.pdf')
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
          ),
          label: Text('$label ${i + 1}'),
        ),
    ],
  );

  Widget _expensesCard(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> receivers,
  ) => _card(
    title: _t(context, 'Extra expenses', 'अतिरिक्त खर्च'),
    icon: Icons.receipt_long_outlined,
    children: [
      Text(
        _t(
          context,
          'Submit actual trip costs separately from the awarded freight. Only approved claims enter the ledger.',
          'वास्तविक अतिरिक्त खर्च मूल भाड़े से अलग जमा करें। केवल स्वीकृत खर्च लेजर में जुड़ेंगे।',
        ),
      ),
      if (!widget.office && !widget.readOnly)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _started ? () => _expense(receivers) : null,
            icon: const Icon(Icons.add),
            label: Text(_t(context, 'Submit expense', 'खर्च जमा करें')),
          ),
        ),
      if (rows.isEmpty)
        Text(
          _t(
            context,
            'No extra expense claims.',
            'अतिरिक्त खर्च का कोई दावा नहीं।',
          ),
        ),
      for (final row in rows)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            '${_expenseLabel(row['kind'].toString())} · ₹${row['amount']}',
          ),
          subtitle: Text(
            _t(
              context,
              'Status: ${row['status']}',
              'स्थिति: ${_claimStatus(row['status'])}',
            ),
          ),
          children: [
            _line(_t(context, 'Reason', 'कारण'), row['reason']),
            _line(
              _t(context, 'Submitted', 'जमा किया'),
              _date(row['submitted_at']),
            ),
            if (row['receiver_id'] != null)
              _line(
                _t(context, 'Customer', 'ग्राहक'),
                receivers
                    .where((r) => r['id'] == row['receiver_id'])
                    .map((r) => '${r['party_name']} (${r['town']})')
                    .join(', '),
              ),
            _documents(
              _paths(row['receipt_paths']),
              _t(context, 'Receipt', 'रसीद'),
            ),
            if (row['review_note'] != null)
              _line(
                _t(context, 'Review note', 'जाँच की टिप्पणी'),
                row['review_note'],
              ),
            if (widget.office &&
                !widget.readOnly &&
                widget.canApproveExpenses &&
                row['status'] == 'pending')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        () => _run(
                          () => _repo.reviewExpense(row['id'], 'approved'),
                        ),
                    child: Text(
                      _t(context, 'Approve expense', 'खर्च स्वीकार करें'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _reviewNote(row['id'], pod: false),
                    child: Text(_t(context, 'Reject', 'अस्वीकार करें')),
                  ),
                ],
              ),
          ],
        ),
    ],
  );
  static const _expenseKinds = [
    'labour',
    'detention',
    'toll_tax',
    'point_charge',
    'extra_freight',
    'out_route',
    'other',
  ];
  String _expenseLabel(String k) => switch (k) {
    'labour' => _t(context, 'Labour', 'मज़दूरी'),
    'detention' => _t(context, 'Detention', 'रुकने का शुल्क'),
    'toll_tax' => _t(context, 'Toll', 'टोल'),
    'point_charge' => _t(context, 'Point charge', 'पॉइंट चार्ज'),
    'extra_freight' => _t(context, 'Extra freight', 'अतिरिक्त भाड़ा'),
    'out_route' => _t(context, 'Out of route', 'मार्ग से बाहर'),
    _ => _t(context, 'Other', 'अन्य'),
  };
  String _claimStatus(dynamic v) => switch (v) {
    'approved' => 'स्वीकृत',
    'rejected' => 'अस्वीकृत',
    _ => 'जाँच बाकी',
  };

  Future<void> _report(Map<String, dynamic> row) async {
    final saved = _map(row['report']);
    final name = TextEditingController(
      text: saved['recipient_name']?.toString(),
    );
    final phone = TextEditingController(
      text: saved['recipient_phone']?.toString(),
    );
    final cases = TextEditingController(
      text: saved['cases_received']?.toString(),
    );
    final weight = TextEditingController(
      text: saved['weight_received_mt']?.toString(),
    );
    final damaged = TextEditingController(
      text: saved['cases_damaged']?.toString(),
    );
    final rejected = TextEditingController(
      text: saved['cases_rejected']?.toString(),
    );
    final reason = TextEditingController(
      text: saved['discrepancy_reason']?.toString(),
    );
    var outcome = saved['outcome']?.toString() ?? 'full';
    var delivered =
        DateTime.tryParse(saved['delivered_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final proofs = _paths(saved['proof_paths']);
    final sites = _paths(saved['site_photo_paths']);
    await _editor(
      title: '${row['party_name']} · ${row['town']}',
      fields:
          (set) => [
            Text(
              _t(
                context,
                'Confirm what was handed over to this customer. You can upload the POD now or later.',
                'इस ग्राहक को सौंपे गए माल का विवरण दें। POD अभी या बाद में जोड़ सकते हैं।',
              ),
            ),
            _field(
              name,
              _t(context, 'Receiver name', 'प्राप्तकर्ता का नाम'),
              required: true,
            ),
            _field(
              phone,
              _t(
                context,
                'Receiver phone (optional)',
                'प्राप्तकर्ता फोन (वैकल्पिक)',
              ),
              phone: true,
            ),
            _dateField(
              _t(
                context,
                'Actual delivery / attempt time',
                'वास्तविक डिलीवरी / प्रयास समय',
              ),
              delivered,
              (d) => set(() => delivered = d),
            ),
            DropdownButtonFormField<String>(
              initialValue: outcome,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t(context, 'Delivery outcome', 'डिलीवरी का परिणाम'),
              ),
              items: [
                for (final k in ['full', 'partial', 'refused', 'attempted'])
                  DropdownMenuItem(value: k, child: Text(_outcome(k))),
              ],
              onChanged: (v) => set(() => outcome = v!),
            ),
            if (outcome == 'full')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _t(
                    context,
                    'Full delivery confirms the entire planned consignment. No quantities need to be typed again.',
                    'पूरी डिलीवरी का अर्थ है निर्धारित माल पूरा मिला। मात्रा दोबारा भरने की ज़रूरत नहीं।',
                  ),
                ),
              ),
            if (outcome != 'full') ...[
              _field(
                cases,
                _t(context, 'Cases accepted', 'स्वीकृत केस'),
                number: true,
                integer: true,
                required: true,
              ),
              _field(
                weight,
                _t(
                  context,
                  'Weight accepted (MT, if known)',
                  'स्वीकृत वजन (MT, यदि ज्ञात)',
                ),
                number: true,
              ),
              _field(
                damaged,
                _t(context, 'Damaged cases (optional)', 'खराब केस (वैकल्पिक)'),
                number: true,
                integer: true,
              ),
              _field(
                rejected,
                _t(
                  context,
                  'Rejected cases (optional)',
                  'अस्वीकृत केस (वैकल्पिक)',
                ),
                number: true,
                integer: true,
              ),
              _field(
                reason,
                _t(
                  context,
                  'Reason for shortfall / failed attempt',
                  'कमी / असफल प्रयास का कारण',
                ),
                required: true,
                multiline: true,
              ),
            ],
            _UploadFiles(
              freightId: _id,
              label: _t(
                context,
                'Proof of delivery (image or PDF)',
                'डिलीवरी प्रमाण (फोटो या PDF)',
              ),
              paths: proofs,
            ),
            _UploadFiles(
              freightId: _id,
              label: _t(
                context,
                'Delivery site photos (optional)',
                'डिलीवरी स्थल फोटो (वैकल्पिक)',
              ),
              paths: sites,
              imagesOnly: true,
            ),
          ],
      save:
          () => _repo.saveReport(row['id'], {
            'recipient_name': name.text.trim(),
            'recipient_phone': phone.text.trim(),
            'delivered_at': delivered.toUtc().toIso8601String(),
            'outcome': outcome,
            if (outcome != 'full') ...{
              'cases_received': int.tryParse(cases.text),
              'weight_received_mt': num.tryParse(weight.text),
              'cases_damaged': int.tryParse(damaged.text),
              'cases_rejected': int.tryParse(rejected.text),
              'discrepancy_reason': reason.text.trim(),
            },
            'proof_paths': proofs,
            'site_photo_paths': sites,
          }),
    );
    for (final c in [name, phone, cases, weight, damaged, rejected, reason]) {
      c.dispose();
    }
  }

  Future<void> _addJourney() async {
    final location = TextEditingController();
    final delay = TextEditingController();
    final vehicle = TextEditingController();
    String next = _towns.first;
    DateTime? eta;
    final photos = <String>[];
    final contractors = <_ContractorDraft>[];
    await _editor(
      title: _t(context, 'Add journey update', 'यात्रा अपडेट जोड़ें'),
      fields:
          (set) => [
            _field(
              location,
              _t(context, 'Current location', 'वर्तमान स्थान'),
              required: true,
            ),
            DropdownButtonFormField<String>(
              initialValue: next,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t(context, 'Next destination', 'अगला पड़ाव'),
              ),
              items: [
                for (final town in _towns.toSet())
                  DropdownMenuItem(value: town, child: Text(town)),
              ],
              onChanged: (v) => next = v!,
            ),
            _dateField(
              _t(
                context,
                'Expected arrival (optional)',
                'अनुमानित आगमन (वैकल्पिक)',
              ),
              eta,
              (d) => set(() => eta = d),
              clear: () => set(() => eta = null),
            ),
            OperationalOptional(
              title: _t(
                context,
                'Delay, vehicle notes and contractors',
                'देरी, वाहन टिप्पणी और ठेकेदार',
              ),
              children: [
                _field(
                  delay,
                  _t(
                    context,
                    'Delay reason (when delayed)',
                    'देरी का कारण (यदि देरी है)',
                  ),
                  multiline: true,
                ),
                _field(
                  vehicle,
                  _t(
                    context,
                    'Vehicle observation (optional)',
                    'वाहन विवरण (वैकल्पिक)',
                  ),
                ),
                Text(
                  _t(
                    context,
                    'This note does not replace the awarded vehicle assignment.',
                    'इस टिप्पणी से निर्धारित वाहन नहीं बदलता।',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    context,
                    'Route contractors (optional)',
                    'मार्ग ठेकेदार (वैकल्पिक)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final (i, c) in contractors.indexed)
                  Column(
                    children: [
                      _field(
                        c.name,
                        _t(context, 'Contractor name', 'ठेकेदार का नाम'),
                        required: true,
                      ),
                      _field(
                        c.phone,
                        _t(
                          context,
                          'Contractor phone (optional)',
                          'ठेकेदार फोन (वैकल्पिक)',
                        ),
                        phone: true,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: c.from,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(context, 'From', 'से'),
                        ),
                        items: [
                          for (final town
                              in {
                                widget.freight['origin'].toString(),
                                ..._towns,
                              }.toList())
                            DropdownMenuItem(value: town, child: Text(town)),
                        ],
                        onChanged: (v) => c.from = v!,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: c.to,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(context, 'To', 'तक'),
                        ),
                        items: [
                          for (final town in _towns.toSet())
                            DropdownMenuItem(value: town, child: Text(town)),
                        ],
                        onChanged: (v) => c.to = v!,
                      ),
                      TextButton(
                        onPressed:
                            () => set(() {
                              contractors.removeAt(i);
                              c.dispose();
                            }),
                        child: Text(
                          _t(context, 'Remove contractor', 'ठेकेदार हटाएँ'),
                        ),
                      ),
                    ],
                  ),
                TextButton.icon(
                  onPressed:
                      () => set(
                        () => contractors.add(
                          _ContractorDraft(
                            from: widget.freight['origin'].toString(),
                            to: next,
                          ),
                        ),
                      ),
                  icon: const Icon(Icons.add),
                  label: Text(_t(context, 'Add contractor', 'ठेकेदार जोड़ें')),
                ),
              ],
            ),
            _UploadFiles(
              freightId: _id,
              label: _t(
                context,
                'Journey photos (optional)',
                'यात्रा फोटो (वैकल्पिक)',
              ),
              paths: photos,
              imagesOnly: true,
            ),
          ],
      save:
          () => _repo.addJourney(_id, {
            'location': location.text.trim(),
            'next_destination': next,
            'eta': eta?.toUtc().toIso8601String(),
            'delay_reason': delay.text.trim(),
            'vehicle_number': vehicle.text.trim(),
            'photo_paths': photos,
            'contractors': [
              for (final c in contractors)
                {
                  'name': c.name.text.trim(),
                  'phone': c.phone.text.trim(),
                  'from': c.from,
                  'to': c.to,
                },
            ],
          }),
    );
    location.dispose();
    delay.dispose();
    vehicle.dispose();
    for (final c in contractors) {
      c.dispose();
    }
  }

  Future<void> _expense(List<Map<String, dynamic>> receivers) async {
    var kind = 'labour';
    String? receiverId;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final receipts = <String>[];
    await _editor(
      title: _t(context, 'Submit expense', 'खर्च जमा करें'),
      fields:
          (set) => [
            DropdownButtonFormField<String>(
              initialValue: kind,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t(context, 'Expense type', 'खर्च का प्रकार'),
              ),
              items: [
                for (final k in _expenseKinds)
                  DropdownMenuItem(value: k, child: Text(_expenseLabel(k))),
              ],
              onChanged: (v) => kind = v!,
            ),
            _field(
              amount,
              _t(context, 'Amount (₹)', 'राशि (₹)'),
              number: true,
              positive: true,
              required: true,
            ),
            _field(
              reason,
              _t(context, 'Reason', 'कारण'),
              required: true,
              multiline: true,
            ),
            DropdownButtonFormField<String>(
              initialValue: receiverId ?? '',
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t(
                  context,
                  'Expense applies to',
                  'खर्च लागू होता है',
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(_t(context, 'Whole trip', 'पूरी यात्रा')),
                ),
                for (final r in receivers)
                  DropdownMenuItem(
                    value: r['id'].toString(),
                    child: Text(
                      '${r['party_name']} · ${r['town']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => receiverId = v == '' ? null : v,
            ),
            _UploadFiles(
              freightId: _id,
              label: _t(context, 'Receipts (optional)', 'रसीदें (वैकल्पिक)'),
              paths: receipts,
            ),
          ],
      save:
          () => _repo.submitExpense(_id, {
            'kind': kind,
            'amount': num.parse(amount.text),
            'reason': reason.text.trim(),
            'receiver_id': receiverId,
            'receipt_paths': receipts,
          }),
    );
    amount.dispose();
    reason.dispose();
  }

  Future<void> _reviewNote(String id, {required bool pod}) async {
    final note = TextEditingController();
    await _editor(
      title: _t(
        context,
        pod ? 'Request POD correction' : 'Reject expense',
        pod ? 'POD में सुधार माँगें' : 'खर्च अस्वीकार करें',
      ),
      fields:
          (_) => [
            _field(
              note,
              _t(
                context,
                'Explain what needs to change',
                'बताएँ क्या बदलना है',
              ),
              required: true,
              multiline: true,
            ),
          ],
      save:
          () =>
              pod
                  ? _repo.reviewPod(id, 'rejected', note: note.text.trim())
                  : _repo.reviewExpense(id, 'rejected', note: note.text.trim()),
    );
    note.dispose();
  }

  Future<void> _editPlan(List<Map<String, dynamic>> existing) async {
    final drafts = existing.map((r) => _ReceiverDraft(r)).toList();
    await _editor(
      title: _t(
        context,
        'Customers & document references',
        'ग्राहक और दस्तावेज़',
      ),
      fields:
          (set) => [
            Text(
              _t(
                context,
                'Add each receiving customer at their stop. Keep unknown quantities blank; do not copy the whole trip quantity to every customer. Separate references with commas.',
                'हर पड़ाव के ग्राहक अलग जोड़ें। अज्ञात मात्रा खाली रखें; पूरी यात्रा की मात्रा हर ग्राहक को न दें। दस्तावेज़ संख्या अल्पविराम से अलग करें।',
              ),
            ),
            for (final (i, draft) in drafts.indexed)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE3DFEA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: draft.stopIndex,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _t(context, 'Route stop', 'मार्ग का पड़ाव'),
                      ),
                      items: [
                        for (final (index, town) in _towns.indexed)
                          DropdownMenuItem(
                            value: index,
                            child: Text('${index + 1}. $town'),
                          ),
                      ],
                      onChanged: (v) => draft.stopIndex = v!,
                    ),
                    _field(
                      draft.party,
                      _t(
                        context,
                        'Customer / party name',
                        'ग्राहक / पार्टी नाम',
                      ),
                      required: true,
                    ),
                    _field(
                      draft.cases,
                      _t(
                        context,
                        'Planned cases (if known)',
                        'निर्धारित केस (यदि ज्ञात)',
                      ),
                      number: true,
                      integer: true,
                    ),
                    _field(
                      draft.weight,
                      _t(
                        context,
                        'Planned weight (MT, if known)',
                        'निर्धारित वजन (MT, यदि ज्ञात)',
                      ),
                      number: true,
                    ),
                    _field(
                      draft.gr,
                      _t(
                        context,
                        'GR numbers (optional)',
                        'GR नंबर (वैकल्पिक)',
                      ),
                    ),
                    _field(
                      draft.lr,
                      _t(
                        context,
                        'LR numbers (optional)',
                        'LR नंबर (वैकल्पिक)',
                      ),
                    ),
                    _field(
                      draft.eway,
                      _t(
                        context,
                        'E-way bill numbers (optional)',
                        'ई-वे बिल नंबर (वैकल्पिक)',
                      ),
                    ),
                    TextButton(
                      onPressed:
                          drafts.length < 2
                              ? null
                              : () => set(() {
                                drafts.removeAt(i);
                                draft.dispose();
                              }),
                      child: Text(
                        _t(context, 'Remove customer', 'ग्राहक हटाएँ'),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed:
                  () =>
                      set(() => drafts.add(_ReceiverDraft({'stop_index': 0}))),
              icon: const Icon(Icons.person_add_alt),
              label: Text(_t(context, 'Add customer', 'ग्राहक जोड़ें')),
            ),
          ],
      save:
          () =>
              _repo.savePlan(_id, drafts.map((d) => d.toJson(_towns)).toList()),
    );
    for (final d in drafts) {
      d.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
    bool integer = false,
    bool positive = false,
    bool phone = false,
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType:
          number
              ? const TextInputType.numberWithOptions(decimal: true)
              : phone
              ? TextInputType.phone
              : multiline
              ? TextInputType.multiline
              : TextInputType.text,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 4 : 1,
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) {
          return required ? _t(context, 'Required', 'आवश्यक') : null;
        }
        if (number) {
          final value = num.tryParse(text);
          if (value == null ||
              !value.isFinite ||
              value < 0 ||
              (positive && value <= 0) ||
              (integer && value != value.roundToDouble())) {
            return _t(
              context,
              'Enter a valid ${integer ? 'whole ' : ''}number${positive ? ' greater than zero' : ''}',
              'सही मात्रा भरें',
            );
          }
        }
        if (phone && !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(text)) {
          return _t(context, 'Enter a valid phone number', 'सही फोन नंबर भरें');
        }
        return null;
      },
    ),
  );
  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> changed, {
    VoidCallback? clear,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text('$label: ${_date(value?.toIso8601String())}'),
          onPressed: () async {
            final initial = value ?? DateTime.now();
            final day = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (day == null || !mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            if (time != null) {
              changed(
                DateTime(day.year, day.month, day.day, time.hour, time.minute),
              );
            }
          },
        ),
        if (clear != null && value != null)
          TextButton(
            onPressed: clear,
            child: Text(_t(context, 'Clear', 'हटाएँ')),
          ),
      ],
    ),
  );
  Future<void> _editor({
    required String title,
    required List<Widget> Function(StateSetter) fields,
    required Future<void> Function() save,
  }) async {
    final form = GlobalKey<FormState>();
    bool busy = false;
    String? error;
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, set) => PopScope(
                  canPop: !busy,
                  child: Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GuidanceCard(
                              title: _t(
                                context,
                                'Complete the required details first',
                                'पहले ज़रूरी विवरण भरें',
                              ),
                              message: _t(
                                context,
                                'Check quantities and dates, then add clear photos or PDF proof. Your changes are saved only after you tap Save.',
                                'मात्रा और तारीख जाँचें, फिर साफ फोटो या PDF जोड़ें। सहेजें दबाने के बाद ही बदलाव जमा होंगे।',
                              ),
                              tone: WorkspaceTone.info,
                            ),
                            const SizedBox(height: 16),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Form(
                                  key: form,
                                  child: AbsorbPointer(
                                    absorbing: busy,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: fields(set),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: Color(0xFFB3261E),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed:
                                      busy
                                          ? null
                                          : () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                  child: Text(
                                    _t(context, 'Cancel', 'रद्द करें'),
                                  ),
                                ),
                                FilledButton(
                                  onPressed:
                                      busy
                                          ? null
                                          : () async {
                                            if (!form.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            set(() {
                                              busy = true;
                                              error = null;
                                            });
                                            try {
                                              await save();
                                              if (dialogContext.mounted) {
                                                Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                );
                                              }
                                            } catch (e) {
                                              if (dialogContext.mounted) {
                                                set(() {
                                                  busy = false;
                                                  error = _errorText(
                                                    context,
                                                    e,
                                                  );
                                                });
                                              }
                                            }
                                          },
                                  child:
                                      busy
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Text(_t(context, 'Save', 'सहेजें')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ),
    );
    if (success == true) _reload();
  }
}

class _ReceiverDraft {
  _ReceiverDraft(Map<String, dynamic> r)
    : id = r['id']?.toString(),
      stopIndex = (r['stop_index'] as num? ?? 0).toInt(),
      party = TextEditingController(text: r['party_name']?.toString()),
      cases = TextEditingController(text: r['planned_cases']?.toString()),
      weight = TextEditingController(text: r['planned_weight_mt']?.toString()),
      gr = TextEditingController(text: _paths(r['gr_numbers']).join(', ')),
      lr = TextEditingController(text: _paths(r['lr_numbers']).join(', ')),
      eway = TextEditingController(
        text: _paths(r['e_way_bill_numbers']).join(', '),
      );
  final String? id;
  int stopIndex;
  final TextEditingController party, cases, weight, gr, lr, eway;
  Map<String, dynamic> toJson(List<String> towns) => {
    if (id != null) 'id': id,
    'stop_index': stopIndex,
    'town': towns[stopIndex],
    'party_name': party.text.trim(),
    'planned_cases': int.tryParse(cases.text),
    'planned_weight_mt': num.tryParse(weight.text),
    'gr_numbers': _refs(gr.text),
    'lr_numbers': _refs(lr.text),
    'e_way_bill_numbers': _refs(eway.text),
  };
  static List<String> _refs(String value) =>
      value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
  void dispose() {
    for (final c in [party, cases, weight, gr, lr, eway]) {
      c.dispose();
    }
  }
}

class _ContractorDraft {
  _ContractorDraft({required this.from, required this.to});
  final name = TextEditingController();
  final phone = TextEditingController();
  String from, to;
  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

class _UploadFiles extends StatefulWidget {
  const _UploadFiles({
    required this.freightId,
    required this.label,
    required this.paths,
    this.imagesOnly = false,
  });
  final String freightId, label;
  final List<String> paths;
  final bool imagesOnly;
  @override
  State<_UploadFiles> createState() => _UploadFilesState();
}

class _UploadFilesState extends State<_UploadFiles> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => FormField<bool>(
    validator:
        (_) =>
            _busy
                ? _t(
                  context,
                  'Wait for the upload to finish.',
                  'फ़ाइल अपलोड होने तक प्रतीक्षा करें।',
                )
                : null,
    builder:
        (state) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  context,
                  'Up to 20 files. Each image or PDF must be under 10 MB.',
                  'अधिकतम 20 फ़ाइलें। हर फोटो या PDF 10 MB से छोटी हो।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.paths.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _t(
                      context,
                      'No proof attached yet',
                      'अभी प्रमाण नहीं जोड़ा गया',
                    ),
                  ),
                ),
              for (final (i, path) in widget.paths.indexed)
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed:
                            () => showDeliveryDocumentPreview(
                              context: context,
                              title: widget.label,
                              path: path,
                            ),
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          '${_t(context, 'Attachment', 'फ़ाइल')} ${i + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _t(context, 'Remove attachment', 'फ़ाइल हटाएँ'),
                      onPressed:
                          _busy
                              ? null
                              : () => setState(() => widget.paths.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _upload,
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.upload_file),
                  label: Text(
                    _t(
                      context,
                      'Choose photos or PDF to upload',
                      'अपलोड के लिए फोटो या PDF चुनें',
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
              if (state.errorText != null)
                Text(
                  state.errorText!,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
            ],
          ),
        ),
  );
  Future<void> _upload() async {
    final invalidMessage = _t(
      context,
      'Choose an image or PDF smaller than 10 MB.',
      '10 MB से छोटी फोटो या PDF चुनें।',
    );
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        if (!widget.imagesOnly) 'pdf',
      ],
      withData: true,
      allowMultiple: true,
    );
    if (files == null || !mounted) return;
    if (widget.paths.length + files.files.length > 20) {
      setState(
        () =>
            _error = _t(
              context,
              'Add up to 20 attachments.',
              'अधिकतम 20 फ़ाइलें जोड़ें।',
            ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      for (final (i, file) in files.files.indexed) {
        if (!mounted) return;
        final ext = (file.extension ?? '').toLowerCase();
        if (file.bytes == null ||
            file.size > 10 * 1024 * 1024 ||
            file.size == 0 ||
            ![
              'jpg',
              'jpeg',
              'png',
              'webp',
              if (!widget.imagesOnly) 'pdf',
            ].contains(ext)) {
          throw FormatException(invalidMessage);
        }
        final path =
            '$uid/${widget.freightId}/receiving/${DateTime.now().microsecondsSinceEpoch}-$i.$ext';
        await supabase.storage
            .from('delivery-documents')
            .uploadBinary(
              path,
              file.bytes!,
              fileOptions: FileOptions(
                contentType:
                    ext == 'pdf'
                        ? 'application/pdf'
                        : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
              ),
            );
        widget.paths.add(path);
      }
    } catch (e) {
      if (!mounted) return;
      _error = _errorText(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }
}
