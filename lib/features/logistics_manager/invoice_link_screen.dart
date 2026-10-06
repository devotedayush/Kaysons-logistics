import 'widgets/operational_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

const _invoiceFieldKeys = [
  'invoice_number',
  'gr_number',
  'lr_number',
  'e_way_bill_number',
  'delivery_reference',
  'party_name',
  'town',
  'cases',
  'weight_kg',
  'base_freight',
  'freight_share',
  'bill_date',
  'dispatch_date',
  'vehicle_number',
  'vehicle_type',
];

String? _strictIsoDate(String raw) {
  final value = raw.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final canonical = parsed.toIso8601String().substring(0, 10);
  return canonical == value ? value : null;
}

class _InvoiceDraft {
  _InvoiceDraft()
    : controllers = {
        for (final key in _invoiceFieldKeys) key: TextEditingController(),
      };

  final Map<String, TextEditingController> controllers;
  final List<TextEditingController> extraGrNumbers = [];
  final List<TextEditingController> extraEwayNumbers = [];

  TextEditingController operator [](String key) => controllers[key]!;

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final controller in [...extraGrNumbers, ...extraEwayNumbers]) {
      controller.dispose();
    }
  }

  Map<String, dynamic> toJson() => {
    for (final key in _invoiceFieldKeys)
      key: _invoiceValue(key, controllers[key]!.text),
    'gr_bilty_numbers': _documentNumbers('gr_number', extraGrNumbers),
    'e_way_bill_numbers': _documentNumbers(
      'e_way_bill_number',
      extraEwayNumbers,
    ),
  };

  List<String> _documentNumbers(
    String primaryKey,
    List<TextEditingController> extras,
  ) {
    final values = [
      controllers[primaryKey]!.text,
      ...extras.map((c) => c.text),
    ];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  dynamic _invoiceValue(String key, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (key == 'cases') return int.tryParse(value);
    if (const {'weight_kg', 'base_freight', 'freight_share'}.contains(key)) {
      return double.tryParse(value.replaceAll(',', ''));
    }
    if (const {'bill_date', 'dispatch_date'}.contains(key)) {
      return _strictIsoDate(value) ?? value;
    }
    return value;
  }
}

class _ChargeDraft {
  _ChargeDraft();

  String kind = 'toll_tax';
  String invoiceScope = 'all';
  final amount = TextEditingController();
  final remarks = TextEditingController();

  void dispose() {
    amount.dispose();
    remarks.dispose();
  }

  Map<String, dynamic> toJson() {
    final value = double.tryParse(amount.text.trim().replaceAll(',', ''));
    final index = int.tryParse(invoiceScope);
    return {
      'kind': canonicalChargeKind(kind),
      'amount': value,
      'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
      if (index != null && index >= 0) 'invoice_index': index,
    };
  }
}

class InvoiceLinkScreen extends StatefulWidget {
  const InvoiceLinkScreen({
    super.key,
    required this.bidId,
    this.adminMode = false,
    this.invoiceStateLoader,
  });

  final String bidId;
  final bool adminMode;
  final Future<Map<String, dynamic>> Function(String freightId)?
  invoiceStateLoader;

  @override
  State<InvoiceLinkScreen> createState() => _InvoiceLinkScreenState();
}

class _InvoiceLinkScreenState extends State<InvoiceLinkScreen> {
  final List<_InvoiceDraft> _invoices = [_InvoiceDraft()];
  final List<_ChargeDraft> _charges = [];
  bool _saving = false;
  late Future<Map<String, dynamic>> _invoiceState;

  @override
  void initState() {
    super.initState();
    _invoiceState = (widget.invoiceStateLoader ??
        FreightsRepo.instance.fetchInvoiceState)(widget.bidId);
  }

  @override
  void dispose() {
    for (final invoice in _invoices) {
      invoice.dispose();
    }
    for (final charge in _charges) {
      charge.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _saving = true);
    try {
      await FreightsRepo.instance.linkInvoiceAndLock(
        freightId: widget.bidId,
        invoices: _invoices.map((invoice) => invoice.toJson()).toList(),
        charges: _charges.map((charge) => charge.toJson()).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.opsInvoiceLocked)),
      );
      context.go('${widget.adminMode ? '/admin' : '/lm'}/bid/${widget.bidId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validate() {
    for (var i = 0; i < _invoices.length; i++) {
      final invoice = _invoices[i];
      if (invoice['invoice_number'].text.trim().isEmpty) {
        return 'Invoice number is required for invoice ${i + 1}';
      }
      if (invoice['gr_number'].text.trim().isEmpty) {
        return 'GR / Bilty number is required for invoice ${i + 1}';
      }
      if (invoice['e_way_bill_number'].text.trim().isEmpty) {
        return 'E-way bill number is required for invoice ${i + 1}';
      }
      if (invoice['town'].text.trim().isEmpty) {
        return 'Town is required for invoice ${i + 1}';
      }
      for (final key in const [
        'cases',
        'weight_kg',
        'base_freight',
        'freight_share',
      ]) {
        final raw = invoice[key].text.trim().replaceAll(',', '');
        final parsed =
            key == 'cases'
                ? int.tryParse(raw)?.toDouble()
                : double.tryParse(raw);
        if (raw.isNotEmpty &&
            (parsed == null || !parsed.isFinite || parsed < 0)) {
          return '${_invoiceLabel(key)} must be a non-negative number';
        }
      }
      for (final key in const ['bill_date', 'dispatch_date']) {
        final raw = invoice[key].text.trim();
        if (raw.isNotEmpty && _strictIsoDate(raw) == null) {
          return '${_invoiceLabel(key)} must be a valid date';
        }
      }
    }
    for (var i = 0; i < _charges.length; i++) {
      final amount = double.tryParse(
        _charges[i].amount.text.trim().replaceAll(',', ''),
      );
      if (amount == null || !amount.isFinite || amount <= 0) {
        return 'Charge ${i + 1} must have a positive amount';
      }
      final index = int.tryParse(_charges[i].invoiceScope);
      if (index != null && (index < 0 || index >= _invoices.length)) {
        return 'Choose an invoice or Whole dispatch for charge ${i + 1}';
      }
    }
    return null;
  }

  String _invoiceLabel(String key) => switch (key) {
    'cases' => 'Cases',
    'weight_kg' => 'Metric tons',
    'base_freight' => 'Base freight',
    'freight_share' => 'Freight share',
    'bill_date' => 'Bill date',
    'dispatch_date' => 'Dispatch date',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(AppLocalizations.of(context)!.opsInvoicesGrLinking),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _invoiceState,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load invoices: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final state = snapshot.data!;
          final invoices =
              (state['invoices'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
          final charges =
              (state['charges'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
          if (invoices.isNotEmpty) {
            return _savedInvoiceView(invoices, charges);
          }
          final status = (state['status'] ?? '').toString();
          if (!const {'awarded', 'dispatched', 'completed'}.contains(status)) {
            return Center(
              child: Text(AppLocalizations.of(context)!.opsInvoiceUnavailable),
            );
          }
          return _entryForm(status);
        },
      ),
    );
  }

  Widget _entryForm(String status) {
    final l = AppLocalizations.of(context)!;
    return OperationalListView(
      padding: const EdgeInsets.all(16),
      children: [
        WorkspaceHeader(
          title: operationalCopy(
            context,
            'Prepare transport billing',
            'परिवहन बिल तैयार करें',
          ),
          description: operationalCopy(
            context,
            'Add each goods invoice and its delivery references. Check freight shares and charges before locking the records.',
            'हर माल बिल और डिलीवरी संदर्भ जोड़ें। रिकॉर्ड लॉक करने से पहले किराया हिस्से और खर्च जाँचें।',
          ),
          icon: Icons.receipt_long_outlined,
        ),
        OperationalStep(
          '1',
          operationalCopy(
            context,
            'Goods invoices and references',
            'माल बिल और संदर्भ',
          ),
          operationalCopy(
            context,
            'Use one card per invoice. Add extra GR or e-way references only when needed.',
            'हर बिल के लिए एक कार्ड रखें। ज़रूरत पर अतिरिक्त GR या ई-वे संदर्भ जोड़ें।',
          ),
        ),
        if (status == 'completed') ...[
          const SizedBox(height: 10),
          Text(
            l.opsCompletedInvoiceNote,
            style: const TextStyle(color: Color(0xFF49454F)),
          ),
        ],
        const SizedBox(height: 16),
        OperationalCardGrid(
          children:
              _invoices
                  .asMap()
                  .entries
                  .map((entry) => _invoiceCard(entry.key, entry.value))
                  .toList(),
        ),
        OutlinedButton.icon(
          onPressed:
              _saving
                  ? null
                  : () => setState(() => _invoices.add(_InvoiceDraft())),
          icon: const Icon(Icons.add),
          label: Text(l.opsAddAnotherInvoice),
        ),
        OperationalStep(
          '2',
          operationalCopy(context, 'Additional charges', 'अतिरिक्त खर्च'),
          operationalCopy(
            context,
            'Add only agreed charges and select which invoice they belong to.',
            'केवल सहमत खर्च जोड़ें और उनका संबंधित बिल चुनें।',
          ),
        ),
        const Divider(height: 36),
        Text(
          l.opsCharges,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l.opsChargeScopeHint,
          style: const TextStyle(fontSize: 12, color: Color(0xFF49454F)),
        ),
        const SizedBox(height: 10),
        ..._charges.asMap().entries.map(
          (entry) => _chargeCard(entry.key, entry.value),
        ),
        OutlinedButton.icon(
          onPressed:
              _saving
                  ? null
                  : () => setState(() => _charges.add(_ChargeDraft())),
          icon: const Icon(Icons.add),
          label: Text(l.opsAddCharge),
        ),
        const SizedBox(height: 24),
        OperationalStep(
          '3',
          operationalCopy(context, 'Check and lock', 'जाँचें और लॉक करें'),
          operationalCopy(
            context,
            'Confirm every invoice is present and the freight shares add up.',
            'पुष्टि करें कि सभी बिल मौजूद हैं और किराया हिस्से सही हैं।',
          ),
        ),
        PrimaryButton(
          label: _saving ? l.opsSaving : l.opsSubmitLockFreight,
          onPressed: _saving ? null : _submit,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _savedInvoiceView(
    List<Map<String, dynamic>> invoices,
    List<Map<String, dynamic>> charges,
  ) {
    final l = AppLocalizations.of(context)!;
    final labels = <String, String>{
      'invoice_number': l.opsInvoiceNumber,
      'lr_number': l.opsLrOptional,
      'delivery_reference': l.opsDeliveryRefOptional,
      'party_name': l.opsPartyName,
      'town': l.opsTown,
      'cases': l.opsCases,
      'weight_kg': l.opsMetricTons,
      'base_freight': l.opsBaseFreight,
      'freight_share': l.opsFreightShare,
      'bill_date': l.opsBillDate,
      'dispatch_date': l.opsDispatchDate,
      'vehicle_number': l.opsVehicleNumber,
      'vehicle_type': l.opsVehicleType,
    };
    return OperationalListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l.opsSavedInvoiceDetails,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          l.opsInvoiceReadOnlyNote,
          style: const TextStyle(color: Color(0xFF49454F)),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < invoices.length; index++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.opsInvoice} ${index + 1}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final field in labels.entries)
                    if (invoices[index][field.key] != null &&
                        invoices[index][field.key].toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${field.value}: ${invoices[index][field.key]}',
                        ),
                      ),
                  if (_savedDocumentNumbers(
                    invoices[index],
                    'gr_bilty_numbers',
                    'gr_number',
                  ).isNotEmpty)
                    Text(
                      '${l.opsGrBiltyNumber}: ${_savedDocumentNumbers(invoices[index], 'gr_bilty_numbers', 'gr_number').join(', ')}',
                    ),
                  if (_savedDocumentNumbers(
                    invoices[index],
                    'e_way_bill_numbers',
                    'e_way_bill_number',
                  ).isNotEmpty)
                    Text(
                      '${l.opsEwayBillNumber}: ${_savedDocumentNumbers(invoices[index], 'e_way_bill_numbers', 'e_way_bill_number').join(', ')}',
                    ),
                ],
              ),
            ),
          ),
        if (charges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l.opsCharges,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          for (final charge in charges)
            ListTile(
              title: Text(_chargeLabel((charge['kind'] ?? 'other').toString())),
              subtitle:
                  charge['remarks'] == null
                      ? null
                      : Text(charge['remarks'].toString()),
              trailing: Text(charge['amount']?.toString() ?? '—'),
            ),
        ],
      ],
    );
  }

  List<String> _savedDocumentNumbers(
    Map<String, dynamic> invoice,
    String listKey,
    String legacyKey,
  ) {
    final numbers =
        (invoice[listKey] as List? ?? const [])
            .map((number) => number.toString().trim())
            .where((number) => number.isNotEmpty)
            .toList();
    if (numbers.isNotEmpty) return numbers;
    final legacy = (invoice[legacyKey] ?? '').toString().trim();
    return legacy.isEmpty ? [] : [legacy];
  }

  Widget _invoiceCard(int index, _InvoiceDraft invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF8F9FC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.opsInvoice} ${index + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_invoices.length > 1)
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.opsRemoveInvoice,
                    onPressed: _saving ? null : () => _removeInvoice(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            _row(
              AppLocalizations.of(context)!.opsInvoiceNumber,
              invoice['invoice_number'],
              'INV-2026-0042',
            ),
            _row(
              AppLocalizations.of(context)!.opsGrBiltyNumber,
              invoice['gr_number'],
              'GR-7821',
            ),
            _extraDocumentFields(
              invoice.extraGrNumbers,
              AppLocalizations.of(context)!.opsGrBiltyNumber,
              AppLocalizations.of(context)!.opsAddAnotherGrBilty,
              'GR-7822',
            ),
            _row(
              AppLocalizations.of(context)!.opsEwayBillNumber,
              invoice['e_way_bill_number'],
              'EWB-1122334455',
            ),
            _extraDocumentFields(
              invoice.extraEwayNumbers,
              AppLocalizations.of(context)!.opsEwayBillNumber,
              AppLocalizations.of(context)!.opsAddAnotherEwayBill,
              'EWB-1122334456',
            ),
            _row(
              AppLocalizations.of(context)!.opsPartyName,
              invoice['party_name'],
              'Party / customer',
            ),
            _row(
              AppLocalizations.of(context)!.opsTown,
              invoice['town'],
              'Destination town',
            ),
            OperationalFields(
              children: [
                Expanded(
                  child: _row(
                    AppLocalizations.of(context)!.opsCases,
                    invoice['cases'],
                    '0',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _row(
                    AppLocalizations.of(context)!.opsMetricTons,
                    invoice['weight_kg'],
                    '0.000',
                  ),
                ),
              ],
            ),
            OperationalFields(
              children: [
                Expanded(
                  child: _row(
                    AppLocalizations.of(context)!.opsBaseFreight,
                    invoice['base_freight'],
                    '0',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _row(
                    AppLocalizations.of(context)!.opsFreightShare,
                    invoice['freight_share'],
                    '0',
                  ),
                ),
              ],
            ),
            OperationalOptional(
              title: operationalCopy(
                context,
                'Dates, vehicle and optional references',
                'तारीख, वाहन और वैकल्पिक संदर्भ',
              ),
              initiallyExpanded:
                  invoice['lr_number'].text.isNotEmpty ||
                  invoice['vehicle_number'].text.isNotEmpty,
              children: [
                _row(
                  AppLocalizations.of(context)!.opsLrOptional,
                  invoice['lr_number'],
                  'LR-7821',
                ),
                _row(
                  AppLocalizations.of(context)!.opsDeliveryRefOptional,
                  invoice['delivery_reference'],
                  'Dispatch reference',
                ),
                OperationalFields(
                  children: [
                    Expanded(
                      child: _row(
                        AppLocalizations.of(context)!.opsBillDate,
                        invoice['bill_date'],
                        'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _row(
                        AppLocalizations.of(context)!.opsDispatchDate,
                        invoice['dispatch_date'],
                        'YYYY-MM-DD',
                      ),
                    ),
                  ],
                ),
                OperationalFields(
                  children: [
                    Expanded(
                      child: _row(
                        AppLocalizations.of(context)!.opsVehicleNumber,
                        invoice['vehicle_number'],
                        'PB-08-AB-1234',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _row(
                        AppLocalizations.of(context)!.opsVehicleType,
                        invoice['vehicle_type'],
                        'Truck',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _extraDocumentFields(
    List<TextEditingController> controllers,
    String label,
    String addLabel,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < controllers.length; index++)
          OperationalFields(
            children: [
              Expanded(
                child: _row('$label ${index + 2}', controllers[index], hint),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.opsRemoveDocument,
                onPressed:
                    _saving
                        ? null
                        : () => setState(() {
                          final removed = controllers.removeAt(index);
                          removed.dispose();
                        }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        TextButton.icon(
          onPressed:
              _saving
                  ? null
                  : () =>
                      setState(() => controllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 18),
          label: Text(addLabel),
        ),
      ],
    );
  }

  void _removeInvoice(int index) {
    setState(() {
      final removed = _invoices.removeAt(index);
      removed.dispose();
      for (final charge in _charges) {
        final selected = int.tryParse(charge.invoiceScope);
        if (selected == null) continue;
        if (selected == index) {
          charge.invoiceScope = 'all';
        } else if (selected > index) {
          charge.invoiceScope = '${selected - 1}';
        }
      }
    });
  }

  String _invoiceOptionLabel(int index) {
    final number = _invoices[index]['invoice_number'].text.trim();
    return number.isEmpty
        ? '${AppLocalizations.of(context)!.opsInvoice} ${index + 1}'
        : '${AppLocalizations.of(context)!.opsInvoice} ${index + 1} · $number';
  }

  Widget _chargeCard(int index, _ChargeDraft charge) {
    final kinds = const [
      'toll_tax',
      'point_charge',
      'other',
      'extra_freight',
      'labour',
      'detention',
      'out_route',
      'deduction',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF8F9FC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: charge.kind,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.opsChargeType,
                    ),
                    items: [
                      for (final kind in kinds)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(_chargeLabel(kind)),
                        ),
                    ],
                    onChanged:
                        _saving
                            ? null
                            : (value) =>
                                setState(() => charge.kind = value ?? 'other'),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.opsRemoveCharge,
                  onPressed:
                      _saving
                          ? null
                          : () => setState(() {
                            final removed = _charges.removeAt(index);
                            removed.dispose();
                          }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            OperationalFields(
              children: [
                Expanded(
                  child: _row(
                    AppLocalizations.of(context)!.opsAmount,
                    charge.amount,
                    '0',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${identityHashCode(charge)}-${charge.invoiceScope}',
                    ),
                    initialValue: charge.invoiceScope,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.opsChargeAllocation,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          AppLocalizations.of(context)!.opsWholeDispatch,
                        ),
                      ),
                      for (
                        var invoiceIndex = 0;
                        invoiceIndex < _invoices.length;
                        invoiceIndex++
                      )
                        DropdownMenuItem(
                          value: '$invoiceIndex',
                          child: Text(
                            _invoiceOptionLabel(invoiceIndex),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        _saving
                            ? null
                            : (value) => setState(
                              () => charge.invoiceScope = value ?? 'all',
                            ),
                  ),
                ),
              ],
            ),
            _row(
              AppLocalizations.of(context)!.opsRemarksOptional,
              charge.remarks,
              'Reason or note',
            ),
          ],
        ),
      ),
    );
  }

  String _chargeLabel(String kind) {
    final l = AppLocalizations.of(context)!;
    return switch (kind) {
      'toll_tax' => l.opsTollTax,
      'point_charge' => l.opsPointCharge,
      'extra_freight' => l.opsExtraFreight,
      'labour' => l.opsLabour,
      'detention' => l.opsDetention,
      'out_route' => l.opsOutRoute,
      'deduction' => l.opsDeduction,
      _ => l.opsOther,
    };
  }

  Widget _row(String label, TextEditingController controller, String hint) {
    final l = AppLocalizations.of(context)!;
    final numeric = {
      l.opsCases,
      l.opsMetricTons,
      l.opsBaseFreight,
      l.opsFreightShare,
      l.opsAmount,
    }.contains(label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          PillTextField(
            controller: controller,
            hint: hint,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}
