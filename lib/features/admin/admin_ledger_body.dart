import 'package:flutter/material.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/csv_downloader.dart';
import '../../core/widgets/date_window_bar.dart';

const _onSurfaceVariant = Color(0xFF49454F);

const _chargeKinds = [
  'freight',
  'extra_freight',
  'labour',
  'detention',
  'toll_tax',
  'point_charge',
  'out_route',
  'deduction',
  'other',
];

class AdminLedgerBody extends StatefulWidget {
  const AdminLedgerBody({super.key});

  @override
  State<AdminLedgerBody> createState() => _AdminLedgerBodyState();
}

class _AdminLedgerBodyState extends State<AdminLedgerBody> {
  int _rangeDays = 30;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _company;
  String? _transporter;
  String? _town;
  String? _ack;
  bool _delayedOnly = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase
          .from('admin_freight_ledger_view')
          .select()
          .order('bill_date', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _rows.where((row) {
      final date = _date(row['bill_date']) ?? _date(row['created_at']);
      if (!withinDateWindow(
        date,
        rangeDays: _rangeDays,
        customStart: _customStart,
        customEnd: _customEnd,
      )) {
        return false;
      }
      if (_company != null && row['company_name'] != _company) return false;
      if (_transporter != null && row['transporter_name'] != _transporter) {
        return false;
      }
      if (_town != null && row['town'] != _town) return false;
      if (_ack != null && row['ack_status'] != _ack) return false;
      if (_delayedOnly && ((_num(row['delay_days']) ?? 0) <= 0)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customStart = picked;
      _customEnd ??= picked;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      firstDate:
          _customStart ?? DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _customEnd ?? _customStart ?? DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
  }

  Future<void> _openEntryForm() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _LedgerEntryDialog(),
    );
    if (saved == true) await _load();
  }

  void _exportCsv() {
    final rows = _filtered;
    final headers = [
      'Company',
      'Bill Date',
      'Dispatch Date',
      'Delay',
      'Invoice',
      'E-Way Bill',
      'Party',
      'Town',
      'Cases',
      'MT',
      'Vehicle',
      'Vehicle Type',
      'LR/GR',
      'Transporter',
      'Freight',
      'Extra Freight',
      'Labour',
      'Detention',
      'Total Freight',
      'Ack Status',
      'Remarks',
    ];
    final body = rows.map((row) {
      return [
        row['company_name'],
        row['bill_date'],
        row['dispatch_date'],
        row['delay_days'],
        row['invoice_number'],
        row['e_way_bill_number'],
        row['party_name'],
        row['town'],
        row['cases'],
        row['weight_kg'],
        row['vehicle_number'],
        row['vehicle_type'],
        row['lr_gr_number'],
        row['transporter_name'],
        row['freight'],
        row['extra_freight'],
        row['labour'],
        row['detention'],
        row['total_freight'],
        row['ack_status'],
        row['remarks'],
      ].map(_csvCell).join(',');
    });
    final csv = [headers.map(_csvCell).join(','), ...body].join('\n');
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    try {
      downloadCsv('kaysons-freight-ledger-$stamp.csv', csv);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final companies = _options('company_name');
    final transporters = _options('transporter_name');
    final towns = _options('town');
    final acks = _options('ack_status');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Freight ledger',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Download CSV',
                onPressed: rows.isEmpty ? null : _exportCsv,
                icon: const Icon(Icons.download_outlined),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.icon(
                onPressed: _openEntryForm,
                icon: const Icon(Icons.add),
                label: const Text('Entry'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DateWindowBar(
            rangeDays: _rangeDays,
            customStart: _customStart,
            customEnd: _customEnd,
            onSelectRange:
                (days) => setState(() {
                  _rangeDays = days;
                  _customStart = null;
                  _customEnd = null;
                }),
            onPickStart: _pickStart,
            onPickEnd: _pickEnd,
            onClearCustom:
                () => setState(() {
                  _customStart = null;
                  _customEnd = null;
                }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterMenu(
                label: 'Company',
                value: _company,
                options: companies,
                onChanged: (v) => setState(() => _company = v),
              ),
              _FilterMenu(
                label: 'Transporter',
                value: _transporter,
                options: transporters,
                onChanged: (v) => setState(() => _transporter = v),
              ),
              _FilterMenu(
                label: 'Town',
                value: _town,
                options: towns,
                onChanged: (v) => setState(() => _town = v),
              ),
              _FilterMenu(
                label: 'Ack',
                value: _ack,
                options: acks,
                onChanged: (v) => setState(() => _ack = v),
              ),
              FilterChip(
                label: const Text('Delayed only'),
                selected: _delayedOnly,
                onSelected: (v) => setState(() => _delayedOnly = v),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                  : rows.isEmpty
                  ? const Center(
                    child: Text(
                      'No ledger rows match this filter.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  )
                  : Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF6EDFB),
                          ),
                          columns: const [
                            DataColumn(label: Text('Company')),
                            DataColumn(label: Text('Bill')),
                            DataColumn(label: Text('Dispatch')),
                            DataColumn(label: Text('Delay')),
                            DataColumn(label: Text('Invoice')),
                            DataColumn(label: Text('Party')),
                            DataColumn(label: Text('Town')),
                            DataColumn(label: Text('Cases')),
                            DataColumn(label: Text('MT')),
                            DataColumn(label: Text('Vehicle')),
                            DataColumn(label: Text('Transporter')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Ack')),
                          ],
                          rows: rows.map(_dataRow).toList(),
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  List<String> _options(String key) {
    return _rows
        .map((row) => (row[key] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  DataRow _dataRow(Map<String, dynamic> row) {
    return DataRow(
      cells: [
        DataCell(Text(_text(row['company_name']))),
        DataCell(Text(_shortDate(row['bill_date']))),
        DataCell(Text(_shortDate(row['dispatch_date']))),
        DataCell(Text(_num(row['delay_days'])?.toStringAsFixed(0) ?? '-')),
        DataCell(Text(_text(row['invoice_number']))),
        DataCell(Text(_text(row['party_name']))),
        DataCell(Text(_text(row['town']))),
        DataCell(Text(_number(row['cases']))),
        DataCell(Text(_number(row['weight_kg']))),
        DataCell(Text(_text(row['vehicle_number']))),
        DataCell(Text(_text(row['transporter_name']))),
        DataCell(Text(_money(row['total_freight']))),
        DataCell(Text(_text(row['ack_status']))),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          ...options.map(
            (option) =>
                DropdownMenuItem<String?>(value: option, child: Text(option)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _LedgerEntryDialog extends StatefulWidget {
  const _LedgerEntryDialog();

  @override
  State<_LedgerEntryDialog> createState() => _LedgerEntryDialogState();
}

class _LedgerEntryDialogState extends State<_LedgerEntryDialog> {
  final _company = TextEditingController();
  final _branch = TextEditingController(text: 'Manual Ledger');
  final _origin = TextEditingController(text: 'Manual Ledger');
  final _party = TextEditingController();
  final _vehicle = TextEditingController();
  final _vehicleType = TextEditingController();
  final _remarks = TextEditingController();
  String _ack = 'pending';
  String? _transporterId;
  bool _saving = false;
  List<Map<String, dynamic>> _transporters = const [];
  final _invoices = <_InvoiceDraft>[_InvoiceDraft()];
  final _charges = <_ChargeDraft>[_ChargeDraft(kind: 'freight')];
  final _products = <_ProductDraft>[];

  @override
  void initState() {
    super.initState();
    _loadTransporters();
  }

  @override
  void dispose() {
    _company.dispose();
    _branch.dispose();
    _origin.dispose();
    _party.dispose();
    _vehicle.dispose();
    _vehicleType.dispose();
    _remarks.dispose();
    for (final invoice in _invoices) {
      invoice.dispose();
    }
    for (final charge in _charges) {
      charge.dispose();
    }
    for (final product in _products) {
      product.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTransporters() async {
    final rows = await supabase
        .from('profiles')
        .select('id, full_name, business_name, email')
        .eq('role', 'transporter')
        .eq('status', 'approved')
        .order('business_name');
    if (!mounted) return;
    setState(() => _transporters = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _save() async {
    if (_saving) return;
    final company = _company.text.trim();
    final firstTown = _invoices.first.town.text.trim();
    if (company.isEmpty || firstTown.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company and first invoice town are required.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final invoiceRows =
          _invoices.map((invoice) => invoice.toInsert()).toList();
      final totalCases = invoiceRows.fold<int>(
        0,
        (sum, row) => sum + ((row['cases'] as int?) ?? 0),
      );
      final totalWeight = invoiceRows.fold<double>(
        0,
        (sum, row) => sum + ((row['weight_kg'] as double?) ?? 0),
      );
      final firstBillDate =
          invoiceRows
              .map((row) => row['bill_date'])
              .whereType<String>()
              .firstOrNull;
      final firstDispatchDate =
          invoiceRows
              .map((row) => row['dispatch_date'])
              .whereType<String>()
              .firstOrNull;
      final freight =
          await supabase
              .from('freights')
              .insert({
                'created_by': supabase.auth.currentUser!.id,
                'origin':
                    _origin.text.trim().isEmpty
                        ? 'Manual Ledger'
                        : _origin.text.trim(),
                'destination_town': firstTown,
                'company_name': company,
                'party_name':
                    _party.text.trim().isEmpty ? null : _party.text.trim(),
                'bill_date': firstBillDate,
                'dispatch_date': firstDispatchDate,
                'vehicle_number':
                    _vehicle.text.trim().isEmpty ? null : _vehicle.text.trim(),
                'vehicle_type':
                    _vehicleType.text.trim().isEmpty
                        ? null
                        : _vehicleType.text.trim(),
                'source_branch':
                    _branch.text.trim().isEmpty ? null : _branch.text.trim(),
                'ack_status': _ack,
                'ack_received_at':
                    _ack == 'received'
                        ? DateTime.now().toIso8601String()
                        : null,
                'winner_profile_id': _transporterId,
                'cases': totalCases,
                'weight_kg': totalWeight,
                'remarks':
                    _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
                'status': 'locked',
              })
              .select('id')
              .single();
      final freightId = freight['id'] as String;
      final invoiceInserts =
          invoiceRows
              .map(
                (row) => {
                  ...row,
                  'freight_id': freightId,
                  'transporter_id': _transporterId,
                  'party_name':
                      row['party_name'] ??
                      (_party.text.trim().isEmpty ? null : _party.text.trim()),
                  'vehicle_number':
                      row['vehicle_number'] ??
                      (_vehicle.text.trim().isEmpty
                          ? null
                          : _vehicle.text.trim()),
                  'vehicle_type':
                      row['vehicle_type'] ??
                      (_vehicleType.text.trim().isEmpty
                          ? null
                          : _vehicleType.text.trim()),
                  'validated': true,
                },
              )
              .toList();
      await supabase.from('invoices').insert(invoiceInserts);
      final charges =
          _charges
              .map((charge) => charge.toInsert(freightId))
              .where((row) => ((row['amount'] as double?) ?? 0) != 0)
              .toList();
      if (charges.isNotEmpty) {
        await supabase.from('freight_charges').insert(charges);
      }
      final products =
          _products
              .map((product) => product.toInsert(freightId))
              .where((row) => (row['product_name'] as String).isNotEmpty)
              .toList();
      if (products.isNotEmpty) {
        await supabase.from('freight_product_lines').insert(products);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New ledger entry',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _field(_company, 'Company *'),
                      _field(_party, 'Party'),
                      _field(_origin, 'Origin'),
                      _field(_branch, 'Branch'),
                      _field(_vehicle, 'Vehicle'),
                      _field(_vehicleType, 'Vehicle type'),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          initialValue: _transporterId,
                          decoration: const InputDecoration(
                            labelText: 'Transporter',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _transporters
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row['id'] as String,
                                      child: Text(_profileLabel(row)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => _transporterId = v),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _ack,
                          decoration: const InputDecoration(
                            labelText: 'Ack status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('Pending'),
                            ),
                            DropdownMenuItem(
                              value: 'received',
                              child: Text('Received'),
                            ),
                            DropdownMenuItem(
                              value: 'not_required',
                              child: Text('Not required'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => _ack = v ?? 'pending'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Invoice lines',
                    onAdd: () => setState(() => _invoices.add(_InvoiceDraft())),
                  ),
                  for (var i = 0; i < _invoices.length; i++)
                    _InvoiceDraftRow(
                      draft: _invoices[i],
                      onRemove:
                          _invoices.length == 1
                              ? null
                              : () => setState(
                                () => _invoices.removeAt(i).dispose(),
                              ),
                    ),
                  const SizedBox(height: 14),
                  _SectionHeader(
                    title: 'Charges',
                    onAdd:
                        () => setState(
                          () => _charges.add(_ChargeDraft(kind: 'other')),
                        ),
                  ),
                  for (var i = 0; i < _charges.length; i++)
                    _ChargeDraftRow(
                      draft: _charges[i],
                      onRemove:
                          _charges.length == 1
                              ? null
                              : () => setState(
                                () => _charges.removeAt(i).dispose(),
                              ),
                    ),
                  const SizedBox(height: 14),
                  _SectionHeader(
                    title: 'Products',
                    onAdd: () => setState(() => _products.add(_ProductDraft())),
                  ),
                  if (_products.isEmpty)
                    const Text(
                      'Optional product/category quantities for Karnal-style reports.',
                      style: TextStyle(color: _onSurfaceVariant),
                    ),
                  for (var i = 0; i < _products.length; i++)
                    _ProductDraftRow(
                      draft: _products[i],
                      onRemove:
                          () => setState(() => _products.removeAt(i).dispose()),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _remarks,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_outlined),
                    label: const Text('Save entry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _InvoiceDraft {
  final invoice = TextEditingController();
  final eWay = TextEditingController();
  final lr = TextEditingController();
  final town = TextEditingController();
  final billDate = TextEditingController();
  final dispatchDate = TextEditingController();
  final cases = TextEditingController();
  final weight = TextEditingController();
  final baseFreight = TextEditingController();

  Map<String, dynamic> toInsert() => {
    'invoice_number':
        invoice.text.trim().isEmpty
            ? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}'
            : invoice.text.trim(),
    'e_way_bill_number': eWay.text.trim().isEmpty ? null : eWay.text.trim(),
    'gr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'lr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'town': town.text.trim(),
    'bill_date': _dateText(billDate.text),
    'dispatch_date': _dateText(dispatchDate.text),
    'cases': int.tryParse(cases.text.trim()),
    'weight_kg': double.tryParse(weight.text.trim()),
    'base_freight': double.tryParse(baseFreight.text.trim()),
  };

  void dispose() {
    invoice.dispose();
    eWay.dispose();
    lr.dispose();
    town.dispose();
    billDate.dispose();
    dispatchDate.dispose();
    cases.dispose();
    weight.dispose();
    baseFreight.dispose();
  }
}

class _ChargeDraft {
  _ChargeDraft({required this.kind});
  String kind;
  final amount = TextEditingController();
  final remarks = TextEditingController();

  Map<String, dynamic> toInsert(String freightId) => {
    'freight_id': freightId,
    'kind': kind,
    'amount': double.tryParse(amount.text.trim()) ?? 0,
    'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
    'added_by': supabase.auth.currentUser?.id,
    'approved': true,
  };

  void dispose() {
    amount.dispose();
    remarks.dispose();
  }
}

class _ProductDraft {
  final name = TextEditingController();
  final quantity = TextEditingController();

  Map<String, dynamic> toInsert(String freightId) => {
    'freight_id': freightId,
    'product_name': name.text.trim(),
    'quantity': double.tryParse(quantity.text.trim()) ?? 0,
  };

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _InvoiceDraftRow extends StatelessWidget {
  const _InvoiceDraftRow({required this.draft, this.onRemove});

  final _InvoiceDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _field(draft.invoice, 'Invoice'),
            _field(draft.eWay, 'E-way bill'),
            _field(draft.lr, 'LR/GR'),
            _field(draft.town, 'Town *'),
            _field(draft.billDate, 'Bill date yyyy-mm-dd'),
            _field(draft.dispatchDate, 'Dispatch date yyyy-mm-dd'),
            _field(draft.cases, 'Cases', number: true),
            _field(draft.weight, 'MT/Weight', number: true),
            _field(draft.baseFreight, 'Base freight', number: true),
            IconButton(
              tooltip: 'Remove invoice',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargeDraftRow extends StatelessWidget {
  const _ChargeDraftRow({required this.draft, this.onRemove});

  final _ChargeDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: draft.kind,
                decoration: const InputDecoration(
                  labelText: 'Kind',
                  border: OutlineInputBorder(),
                ),
                items:
                    _chargeKinds
                        .map(
                          (kind) =>
                              DropdownMenuItem(value: kind, child: Text(kind)),
                        )
                        .toList(),
                onChanged: (v) => draft.kind = v ?? draft.kind,
              ),
            ),
            _field(draft.amount, 'Amount', number: true),
            _field(draft.remarks, 'Charge remarks'),
            IconButton(
              tooltip: 'Remove charge',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDraftRow extends StatelessWidget {
  const _ProductDraftRow({required this.draft, required this.onRemove});

  final _ProductDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _field(draft.name, 'Product'),
            _field(draft.quantity, 'Quantity', number: true),
            IconButton(
              tooltip: 'Remove product',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool number = false,
}) {
  return SizedBox(
    width: 220,
    child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

String _profileLabel(Map<String, dynamic> row) {
  return (row['business_name'] ?? row['full_name'] ?? row['email'] ?? 'Unnamed')
      .toString();
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _dateText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final date = DateTime.tryParse(trimmed);
  return date?.toIso8601String().substring(0, 10);
}

num? _num(dynamic value) {
  if (value is num) return value;
  return num.tryParse((value ?? '').toString());
}

String _text(dynamic value) {
  final text = (value ?? '').toString();
  return text.trim().isEmpty ? '-' : text;
}

String _shortDate(dynamic value) {
  final text = (value ?? '').toString();
  if (text.length >= 10) return text.substring(0, 10);
  return text.isEmpty ? '-' : text;
}

String _number(dynamic value) {
  final n = _num(value);
  if (n == null) return '-';
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2);
}

String _money(dynamic value) {
  final n = _num(value) ?? 0;
  return '₹${n.toStringAsFixed(0)}';
}

String _csvCell(dynamic value) {
  final raw = (value ?? '').toString();
  final escaped = raw.replaceAll('"', '""');
  return '"$escaped"';
}
