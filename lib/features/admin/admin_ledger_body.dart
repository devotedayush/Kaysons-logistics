import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'widgets/office_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/utils/csv_downloader.dart';
import '../../core/widgets/date_window_bar.dart';
import 'widgets/ledger_records.dart';
import '../../l10n/app_localizations.dart';

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

const _vehicleCapacityCategories = [
  'Up to 1 MT',
  'Up to 3 MT',
  '3-6 MT',
  '6-9 MT',
  '9-12 MT',
  '12-15 MT',
  '15+ MT',
];

enum _ReportExportType {
  transporterMonthly,
  placeWise,
  invoiceWise,
  podPending,
  vehicleTonnage,
  routeWise,
}

enum LedgerPresentation { overview, rows }

enum _OverviewSummary { transporter, destination, route, vehicle }

class AdminLedgerBody extends StatefulWidget {
  const AdminLedgerBody({super.key});

  @override
  State<AdminLedgerBody> createState() => _AdminLedgerBodyState();
}

class _AdminLedgerBodyState extends State<AdminLedgerBody> {
  int _rangeDays = 90;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _company;
  String? _transporter;
  String? _destination;
  DateTime? _month;
  String? _status;
  String? _podAck;
  String? _tonnageCategory;
  bool _delayedOnly = false;
  bool _latePodOnly = false;
  bool _showAdvancedFilters = false;
  bool _fullColumns = false;
  bool _pendingProofOnly = false;
  LedgerPresentation _presentation = LedgerPresentation.rows;
  _OverviewSummary _overviewSummary = _OverviewSummary.transporter;
  int _ledgerPage = 0;
  final int _ledgerPageSize = 75;
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  final _placeSearch = TextEditingController();
  final _invoiceSearch = TextEditingController();
  final _ewaySearch = TextEditingController();
  final _ledgerHorizontalScroll = ScrollController();
  final _ledgerVerticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _placeSearch.dispose();
    _invoiceSearch.dispose();
    _ewaySearch.dispose();
    _ledgerHorizontalScroll.dispose();
    _ledgerVerticalScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _loadAllLedgerRows();
      final ewayBillsFuture = _loadInvoiceEwayBills(rows);
      final proofContextsFuture = _loadProofContexts(rows);
      final ewayBillsByInvoice = await ewayBillsFuture;
      final proofContexts = await proofContextsFuture;
      final rowsWithDocuments = [
        for (final source in rows)
          {
            ...source,
            ...?proofContexts[source['freight_id']?.toString()],
            '_invoice_eway_bill_numbers':
                {
                  ..._documentNumbers(source['e_way_bill_number']),
                  ...(ewayBillsByInvoice[source['invoice_id']?.toString()] ??
                      const <String>{}),
                }.toList(),
          },
      ];
      if (!mounted) return;
      setState(() {
        _rows = rowsWithDocuments;
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

  Future<List<Map<String, dynamic>>> _loadAllLedgerRows() async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      final page = await supabase
          .from('admin_freight_ledger_view')
          .select()
          .order('bill_date', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .order('invoice_id', ascending: true, nullsFirst: false)
          .range(offset, offset + pageSize - 1);
      final rows = (page as List).cast<Map<String, dynamic>>();
      result.addAll(rows);
      if (rows.length < pageSize) return result;
    }
  }

  /// Existing RLS remains the authority for these read-only trip records.
  /// Optional receiving data can be unavailable on older installations; that
  /// leaves review unverified instead of asserting acceptance or missing POD.
  Future<Map<String, Map<String, dynamic>>> _loadProofContexts(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids =
        rows
            .map((row) => row['freight_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    final contexts = <String, Map<String, dynamic>>{};
    for (var start = 0; start < ids.length; start += 50) {
      final chunk = ids.skip(start).take(50).toList();
      List<Map<String, dynamic>> freights;
      try {
        // select() tolerates installations without the new workflow-version
        // column while still allowing its presence to identify receiver trips.
        freights = List<Map<String, dynamic>>.from(
          await supabase.from('freights').select().inFilter('id', chunk),
        );
      } catch (_) {
        continue;
      }
      final receiverIds = <String>[];
      for (final freight in freights) {
        final id = freight['id'].toString();
        contexts[id] = {
          '_proof_freight': freight,
          if (freight['record_origin'] != null)
            'record_origin': freight['record_origin'],
        };
        if (freight['delivery_workflow_version'] == 1) receiverIds.add(id);
      }
      if (receiverIds.isEmpty) continue;
      try {
        final receivers = <Map<String, dynamic>>[];
        for (var offset = 0; ; offset += 500) {
          final page = List<Map<String, dynamic>>.from(
            await supabase
                .from('freight_delivery_receivers')
                .select(
                  'id,freight_id,town,party_name,report,pod_review_status,pod_review_note,reviewed_by,reviewed_at',
                )
                .inFilter('freight_id', receiverIds)
                .order('id')
                .range(offset, offset + 499),
          );
          receivers.addAll(page);
          if (page.length < 500) break;
        }
        for (final id in receiverIds) {
          contexts[id]!['_proof_receivers_loaded'] = true;
          contexts[id]!['_proof_receivers'] =
              receivers
                  .where((receiver) => receiver['freight_id'] == id)
                  .toList();
        }
      } catch (_) {
        // Retain usable ledger records; the badge explicitly says unverified.
      }
    }
    return contexts;
  }

  Future<Map<String, Set<String>>> _loadInvoiceEwayBills(
    List<Map<String, dynamic>> rows,
  ) async {
    const invoiceChunkSize = 50;
    const pageSize = 500;
    final invoiceIds =
        rows
            .map((row) => row['invoice_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    final result = <String, Set<String>>{};
    for (var start = 0; start < invoiceIds.length; start += invoiceChunkSize) {
      final ids = invoiceIds.skip(start).take(invoiceChunkSize).toList();
      for (var offset = 0; ; offset += pageSize) {
        final page = await supabase
            .from('invoice_documents')
            .select('invoice_id, document_number')
            .eq('document_kind', 'e_way_bill')
            .inFilter('invoice_id', ids)
            .order('invoice_id')
            .order('document_number')
            .range(offset, offset + pageSize - 1);
        final documents = (page as List).cast<Map<String, dynamic>>();
        for (final document in documents) {
          final invoiceId = document['invoice_id']?.toString() ?? '';
          final number = document['document_number']?.toString() ?? '';
          if (invoiceId.isEmpty || number.trim().isEmpty) continue;
          result.putIfAbsent(invoiceId, () => <String>{}).add(number.trim());
        }
        if (documents.length < pageSize) break;
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _filtered {
    final filtered =
        _rows.where((row) {
          final date = _reportDate(row);
          if (_month == null) {
            if (!withinDateWindow(
              date,
              rangeDays: _rangeDays,
              customStart: _customStart,
              customEnd: _customEnd,
            )) {
              return false;
            }
          }
          if (_company != null && row['company_name'] != _company) return false;
          if (_transporter != null && row['transporter_name'] != _transporter) {
            return false;
          }
          if (_destination != null && row['town'] != _destination) return false;
          if (_month != null && !_sameMonth(_reportDate(row), _month!)) {
            return false;
          }
          if (_status != null && _dispatchStatusLabel(row) != _status) {
            return false;
          }
          if (_podAck != null && _podAckLabel(row) != _podAck) return false;
          if (_tonnageCategory != null &&
              _rowTonnageCategory(row) != _tonnageCategory) {
            return false;
          }
          if (!_containsAny(_placeSearch.text, [
            row['origin'],
            row['town'],
            row['party_name'],
          ])) {
            return false;
          }
          if (!ledgerMatchesSearch(row, _invoiceSearch.text)) return false;
          if (_pendingProofOnly && !ledgerProofNeedsReview(row)) return false;
          if (!ledgerRowMatchesInvoiceDocumentSearch(
            row,
            invoiceQuery: '',
            ewayQuery: _ewaySearch.text,
          )) {
            return false;
          }
          if (_delayedOnly && ((_num(row['delay_days']) ?? 0) <= 0)) {
            return false;
          }
          if (_latePodOnly &&
              !_flag(row['pod_late_flag']) &&
              !_flag(row['pod_missing_overdue_flag'])) {
            return false;
          }
          return true;
        }).toList();
    return normalizeLedgerSettlementFields(
      displayedRows: filtered,
      allRows: _rows,
    );
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
    final selection = selectLedgerCustomDateRange(
      currentStart: _customStart,
      currentEnd: _customEnd,
      pickedStart: picked,
    );
    setState(() {
      _ledgerPage = 0;
      _month = selection.month;
      _customStart = selection.start;
      _customEnd = selection.end;
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
    final selection = selectLedgerCustomDateRange(
      currentStart: _customStart,
      currentEnd: _customEnd,
      pickedEnd: picked,
    );
    setState(() {
      _ledgerPage = 0;
      _month = selection.month;
      _customStart = selection.start;
      _customEnd = selection.end;
    });
  }

  Future<void> _pickMonth() async {
    final availableYears =
        {
            DateTime.now().year,
            ..._rows
                .map(_reportDate)
                .whereType<DateTime>()
                .map((date) => date.year),
          }.toList()
          ..sort((a, b) => b.compareTo(a));
    final picked = await showDialog<DateTime>(
      context: context,
      builder:
          (_) => _MonthYearPickerDialog(
            initialMonth: _month ?? _customStart ?? DateTime.now(),
            years: availableYears,
          ),
    );
    if (picked == null || !mounted) return;
    final selection = selectLedgerMonth(picked);
    setState(() {
      _rangeDays = 90;
      _ledgerPage = 0;
      _month = selection.month;
      _customStart = selection.start;
      _customEnd = selection.end;
    });
  }

  Future<void> _openEntryForm([Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LedgerEntryDialog(row: row),
    );
    if (saved == true) await _load();
  }

  Future<void> _uploadLedgerCsv() async {
    if (_uploading) return;
    final options = await showDialog<_CsvUploadOptions>(
      context: context,
      builder: (_) => const _CsvUploadDialog(),
    );
    if (options == null) return;
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Could not read selected CSV file.');
      }
      final result = await _importLedgerCsv(
        csvText: utf8.decode(bytes, allowMalformed: true),
        companyName: options.companyName,
        sourceBranch: options.sourceBranch,
      );
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _CsvUploadResultDialog(result: result),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminCsvUploadFailed}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<_CsvUploadResult> _importLedgerCsv({
    required String csvText,
    required String companyName,
    required String sourceBranch,
  }) async {
    final parsed = _parseLedgerCsv(csvText);
    if (parsed.isEmpty) {
      throw Exception('No valid ledger rows found in the CSV.');
    }
    final profiles = await supabase
        .from('profiles')
        .select('id, full_name, business_name, email')
        .eq('role', 'transporter')
        .eq('status', 'approved');
    final transporterIds = <String, String>{};
    for (final raw in (profiles as List).cast<Map<String, dynamic>>()) {
      final id = raw['id']?.toString();
      if (id == null) continue;
      for (final key in [
        raw['business_name'],
        raw['full_name'],
        raw['email'],
      ].map(_normalizeLookup)) {
        if (key.isNotEmpty) transporterIds[key] = id;
      }
    }

    final createdBy = supabase.auth.currentUser?.id;
    if (createdBy == null) throw Exception('You must be signed in to upload.');
    final freightsById = <String, Map<String, dynamic>>{};
    final invoices = <Map<String, dynamic>>[];
    final charges = <Map<String, dynamic>>[];
    final missingTransporters = <String>{};
    final explicitVehicleCapacityByFreight = <String, String>{};

    for (final row in parsed) {
      final transporterId = transporterIds[_normalizeLookup(row.transporter)];
      if (row.transporter.isNotEmpty && transporterId == null) {
        missingTransporters.add(row.transporter);
      }
      final reportDate = row.dispatchDate ?? row.billDate;
      final ackReceivedAt =
          row.ackReceived && reportDate != null
              ? '${reportDate}T12:00:00+00:00'
              : null;
      final remarks = [
        if (row.remarks.isNotEmpty) row.remarks,
        if (transporterId == null && row.transporter.isNotEmpty)
          'Transporter: ${row.transporter}',
        'Uploaded from $sourceBranch',
      ].join(' | ');
      final freight = freightsById.putIfAbsent(
        row.freightId,
        () => {
          'id': row.freightId,
          'created_by': createdBy,
          'origin': row.origin.isEmpty ? 'CSV Upload' : row.origin,
          'destination_town': row.town,
          'cases': 0,
          'weight_kg': 0.0,
          'internal_calling_bid': 0.0,
          'status': row.ackReceived ? 'completed' : 'locked',
          'winner_profile_id': transporterId,
          'vehicle_number':
              row.vehicleNumber.isEmpty ? null : row.vehicleNumber,
          'gr_bilty_number': row.lrNumber.isEmpty ? null : row.lrNumber,
          'vehicle_capacity_category':
              row.vehicleCapacityExplicit ? row.vehicleCapacityCategory : null,
          'dispatched_at':
              reportDate == null ? null : '${reportDate}T09:00:00+00:00',
          'locked_at':
              reportDate == null ? null : '${reportDate}T18:00:00+00:00',
          'remarks': remarks,
          'delivery_stages':
              row.ackReceived && reportDate != null
                  ? {
                    'delivered': {
                      'submitted_at': '${reportDate}T12:00:00+00:00',
                    },
                  }
                  : {},
          'company_name':
              row.companyName.isEmpty ? companyName : row.companyName,
          'party_name': row.partyName,
          'bill_date': row.billDate,
          'dispatch_date': row.dispatchDate,
          'vehicle_type': row.vehicleType.isEmpty ? null : row.vehicleType,
          'source_branch': sourceBranch,
          'ack_status': row.ackReceived ? 'received' : 'pending',
          'ack_received_at': ackReceivedAt,
          'pod_received_date': row.ackReceived ? reportDate : null,
          'pod_received_by': row.ackReceived ? createdBy : null,
        },
      );
      freight['cases'] = ((freight['cases'] as int?) ?? 0) + row.cases;
      freight['weight_kg'] =
          ((freight['weight_kg'] as double?) ?? 0) + row.weight;
      freight['internal_calling_bid'] =
          ((freight['internal_calling_bid'] as double?) ?? 0) + row.freight;
      if (row.vehicleCapacityExplicit) {
        explicitVehicleCapacityByFreight.putIfAbsent(
          row.freightId,
          () => row.vehicleCapacityCategory,
        );
      }
      freight['vehicle_capacity_category'] = ledgerVehicleCapacityForImport(
        explicitCategory: explicitVehicleCapacityByFreight[row.freightId],
        combinedMetricTons: (freight['weight_kg'] as double?) ?? row.weight,
      );
      if (freight['gr_bilty_number'] == null && row.lrNumber.isNotEmpty) {
        freight['gr_bilty_number'] = row.lrNumber;
      }
      if (!row.ackReceived) {
        freight['status'] = 'locked';
        freight['ack_status'] = 'pending';
        freight['ack_received_at'] = null;
        freight['pod_received_date'] = null;
        freight['pod_received_by'] = null;
        freight['delivery_stages'] = {};
      }
      invoices.add({
        'id': row.invoiceId,
        'freight_id': row.freightId,
        'invoice_number':
            row.invoiceNumber.isNotEmpty ? row.invoiceNumber : row.billNumber,
        'gr_number': row.lrNumber.isEmpty ? null : row.lrNumber,
        'transporter_id': transporterId,
        'town': row.town,
        'weight_kg': row.weight,
        'cases': row.cases,
        'base_freight': row.freight,
        'freight_share': row.freight,
        'validated': true,
        'e_way_bill_number': row.ewayNumber.isEmpty ? null : row.ewayNumber,
        'party_name': row.partyName,
        'bill_date': row.billDate,
        'dispatch_date': row.dispatchDate,
        'lr_number': row.lrNumber.isEmpty ? null : row.lrNumber,
        'vehicle_number': row.vehicleNumber.isEmpty ? null : row.vehicleNumber,
        'vehicle_type': row.vehicleType.isEmpty ? null : row.vehicleType,
        'remarks': remarks,
        'delivery_reference': row.billNumber.isEmpty ? null : row.billNumber,
      });
      for (final charge in [
        ('extra_freight', row.extraFreight),
        ('labour', row.labour),
        ('detention', row.detention),
      ]) {
        if (charge.$2 == 0) continue;
        charges.add({
          'freight_id': row.freightId,
          'invoice_id': row.invoiceId,
          'kind': charge.$1,
          'amount': charge.$2,
          'remarks': remarks,
          'added_by': createdBy,
          'approved': true,
        });
      }
    }

    final result = await supabase.rpc(
      'import_historical_ledger_csv',
      params: {
        'p_source_csv': csvText,
        'p_source_name': '$companyName / $sourceBranch',
        'p_freights': freightsById.values.toList(),
        'p_invoices': invoices,
        'p_charges': charges,
      },
    );
    if (result is Map && result['already_imported'] == true) {
      throw Exception('This CSV was already imported. No records were added.');
    }
    return _CsvUploadResult(
      rowsImported: parsed.length,
      chargesImported: charges.length,
      missingTransporters: missingTransporters.toList()..sort(),
      sourceBranch: sourceBranch,
    );
  }

  Future<void> _exportReport(_ReportExportType type) async {
    final report = _buildExportReport(type);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = '${report.slug}-$stamp.csv';
    final content = _tableCsv(report.headers, report.rows);
    try {
      await downloadCsv(fileName, content);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.adminExportFailed}: $e',
          ),
        ),
      );
    }
  }

  _ExportReport _buildExportReport(_ReportExportType type) {
    final rows = _filtered;
    switch (type) {
      case _ReportExportType.transporterMonthly:
        return _ExportReport(
          title: 'Transporter-wise monthly report',
          slug: 'kaysons-transporter-wise-monthly-report',
          headers: const [
            'Transporter',
            'Trips',
            'Vehicles',
            'Cases',
            'MT',
            'Freight',
            'Freight/MT',
            'Freight/Case',
            'POD Pending',
            'POD Received',
          ],
          rows:
              _transporterSummaries(rows)
                  .map(
                    (summary) => [
                      summary.transporter,
                      summary.totalTrips,
                      summary.totalVehicles,
                      summary.totalCases,
                      summary.totalMetricTons,
                      summary.totalFreight,
                      summary.freightPerMetricTon,
                      summary.freightPerCase,
                      summary.podPending,
                      summary.podReceived,
                    ],
                  )
                  .toList(),
        );
      case _ReportExportType.placeWise:
        return _movementExportReport(
          title: 'Place-wise report',
          slug: 'kaysons-place-wise-report',
          firstColumn: 'Destination',
          summaries: _movementSummaries(rows, (row) {
            final town = (row['town'] ?? '').toString().trim();
            return town.isEmpty ? 'Unknown' : town;
          }),
          includeBreakup: true,
        );
      case _ReportExportType.invoiceWise:
        return _invoiceWiseExportReport(rows);
      case _ReportExportType.podPending:
        return _podPendingExportReport(rows);
      case _ReportExportType.vehicleTonnage:
        return _movementExportReport(
          title: 'Vehicle tonnage report',
          slug: 'kaysons-vehicle-tonnage-report',
          firstColumn: 'Vehicle Capacity',
          summaries: _movementSummaries(rows, (row) {
            return _rowTonnageCategory(row);
          }),
          includeBreakup: false,
        );
      case _ReportExportType.routeWise:
        return _movementExportReport(
          title: 'Route-wise freight report',
          slug: 'kaysons-route-wise-freight-report',
          firstColumn: 'Route',
          summaries: _movementSummaries(rows, (row) {
            final origin = (row['origin'] ?? '').toString().trim();
            final town = (row['town'] ?? '').toString().trim();
            return '${origin.isEmpty ? 'Unknown' : origin} -> '
                '${town.isEmpty ? 'Unknown' : town}';
          }),
          includeBreakup: false,
        );
    }
  }

  _ExportReport _movementExportReport({
    required String title,
    required String slug,
    required String firstColumn,
    required List<_MovementSummary> summaries,
    required bool includeBreakup,
  }) {
    return _ExportReport(
      title: title,
      slug: slug,
      headers: [
        firstColumn,
        'Trips',
        'Vehicles',
        'Cases',
        'MT',
        'Freight',
        'Avg Freight/MT',
        if (includeBreakup) 'Transporter Breakup',
      ],
      rows:
          summaries
              .map(
                (summary) => [
                  summary.label,
                  summary.totalTrips,
                  summary.totalVehicles,
                  summary.totalCases,
                  summary.totalMetricTons,
                  summary.totalFreight,
                  summary.freightPerMetricTon,
                  if (includeBreakup) summary.transporterBreakup,
                ],
              )
              .toList(),
    );
  }

  _ExportReport _invoiceWiseExportReport(List<Map<String, dynamic>> rows) {
    final headers = [
      'Company',
      'Bill Date',
      'Dispatch Date',
      'Delay',
      'Invoice',
      'Invoice Count',
      'All Invoices',
      'E-Way Bill',
      'E-Way Bill Count',
      'All E-Way Bills',
      'DEL Ref',
      'Party',
      'Party Count',
      'All Parties',
      'Origin',
      'Town',
      'Cases',
      'Ton',
      'Vehicle',
      'Vehicle Type',
      'Vehicle Capacity',
      'LR/GR',
      'Dispatch GR/Bilty',
      'Transporter',
      'Freight',
      'Extra Freight',
      'Labour',
      'Detention',
      'Toll Tax',
      'Point Charge',
      'Out Route',
      'Deduction',
      'Total Freight',
      'Settlement Month',
      'Monthly Opening Balance',
      'Monthly Payment',
      'Monthly Deduction',
      'Monthly Closing Balance',
      'Ack Status',
      'POD Received Date',
      'POD File',
      'POD Remark',
      'POD Received By',
      'POD Risk',
      'Remarks',
      'Other Charges',
      'Trip Proof Review',
    ];
    return _ExportReport(
      title: 'Invoice-wise freight report',
      slug: 'kaysons-invoice-wise-freight-report',
      headers: headers,
      rows: rows.map(_invoiceExportRow).toList(),
    );
  }

  _ExportReport _podPendingExportReport(List<Map<String, dynamic>> rows) {
    final pendingRows = rows.where(ledgerProofNeedsReview).toList();
    return _ExportReport(
      title: 'POD pending report',
      slug: 'kaysons-pod-pending-report',
      headers: const [
        'Company',
        'Invoice',
        'E-Way Bill',
        'Party',
        'Origin',
        'Destination',
        'Transporter',
        'Vehicle',
        'Dispatch Date',
        'POD Status',
        'POD Risk',
        'POD Remark',
        'Freight',
        'Trip Proof Review',
      ],
      rows:
          pendingRows
              .map(
                (row) => [
                  row['company_name'],
                  row['invoice_number'],
                  ledgerInvoiceEwayBillDisplay(row),
                  row['party_name'],
                  row['origin'],
                  row['town'],
                  row['transporter_name'],
                  row['vehicle_number'],
                  row['dispatch_date'],
                  _podAckLabel(row),
                  _podRiskLabel(row),
                  row['pod_remark'],
                  row['total_freight'],
                  ledgerProofExportLabel(row),
                ],
              )
              .toList(),
    );
  }

  List<dynamic> _invoiceExportRow(Map<String, dynamic> row) => [
    row['company_name'],
    row['bill_date'],
    row['dispatch_date'],
    row['delay_days'],
    row['invoice_number'],
    row['invoice_count'],
    row['invoice_numbers'],
    ledgerInvoiceEwayBillDisplay(row),
    row['e_way_bill_count'],
    row['e_way_bill_numbers'],
    row['delivery_reference'],
    row['party_name'],
    row['party_count'],
    row['party_names'],
    row['origin'],
    row['town'],
    row['cases'],
    row['weight_kg'],
    row['vehicle_number'],
    row['vehicle_type'],
    row['vehicle_capacity_category'],
    row['lr_gr_number'],
    row['dispatch_gr_bilty_number'],
    row['transporter_name'],
    row['freight'],
    row['extra_freight'],
    row['labour'],
    row['detention'],
    row['toll_tax'],
    row['point_charge'],
    row['out_route'],
    row['deduction'],
    row['total_freight'],
    row['period_month'],
    row['last_month_balance'],
    row['payment_amount'],
    row['settlement_deduction'],
    row['balance'],
    _podAckLabel(row),
    _podReceivedDate(row),
    (row['pod_file_path'] ?? '').toString().trim().isEmpty
        ? ''
        : row['pod_file_path'],
    row['pod_remark'],
    row['pod_received_by_name'],
    _podRiskLabel(row),
    row['remarks'],
    row['other'],
    ledgerProofExportLabel(row),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rows = _filtered;
    final compact =
        MediaQuery.sizeOf(context).width < 1050 ||
        MediaQuery.textScalerOf(context).scale(14) > 19;
    final filterCount =
        [
          _company != null,
          _transporter != null,
          _destination != null,
          _status != null,
          _podAck != null,
          _tonnageCategory != null,
          _placeSearch.text.trim().isNotEmpty,
          _ewaySearch.text.trim().isNotEmpty,
          _delayedOnly,
          _latePodOnly,
        ].where((active) => active).length;
    final pageCount = math.max(1, (rows.length / _ledgerPageSize).ceil());
    final page = _ledgerPage.clamp(0, pageCount - 1);
    final start = page * _ledgerPageSize;
    final end = math.min(start + _ledgerPageSize, rows.length);
    final visible = rows.sublist(start, end);
    final period =
        _month != null
            ? '${_month!.month}/${_month!.year}'
            : _customStart != null
            ? '${_shortDate(_customStart)} – ${_shortDate(_customEnd)}'
            : l.dateWindowDays(_rangeDays);
    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: compact ? double.infinity : 350,
          child: TextField(
            controller: _invoiceSearch,
            decoration: InputDecoration(
              labelText: officeCopy(context, 'Search ledger', 'लेजर खोजें'),
              hintText: officeCopy(
                context,
                'Invoice, customer, vehicle or transporter',
                'इनवॉइस, ग्राहक, वाहन या ट्रांसपोर्टर',
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _invoiceSearch.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: l.adminClearFilters,
                        onPressed:
                            () => setState(() {
                              _invoiceSearch.clear();
                              _ledgerPage = 0;
                            }),
                        icon: const Icon(Icons.close),
                      ),
            ),
            onChanged: (_) => setState(() => _ledgerPage = 0),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: officeCopy(context, 'Period', 'अवधि'),
          onSelected: (value) async {
            if (value == 'month') {
              await _pickMonth();
            } else if (value == 'custom') {
              await _pickStart();
              if (mounted) await _pickEnd();
            } else {
              setState(() {
                _rangeDays = int.parse(value);
                _month = null;
                _customStart = null;
                _customEnd = null;
                _ledgerPage = 0;
              });
            }
          },
          itemBuilder:
              (_) => [
                for (final days in [7, 15, 30, 90])
                  PopupMenuItem(
                    value: '$days',
                    child: Text(l.dateWindowDays(days)),
                  ),
                PopupMenuItem(
                  value: 'month',
                  child: Text(
                    officeCopy(context, 'Choose month', 'महीना चुनें'),
                  ),
                ),
                PopupMenuItem(
                  value: 'custom',
                  child: Text(l.dateWindowCustomDates),
                ),
              ],
          child: _toolbarLabel(Icons.calendar_month_outlined, period),
        ),
        OutlinedButton.icon(
          onPressed:
              () =>
                  setState(() => _showAdvancedFilters = !_showAdvancedFilters),
          icon: Icon(
            _showAdvancedFilters ? Icons.expand_less : Icons.tune_outlined,
            size: 18,
          ),
          label: Text(
            filterCount == 0
                ? l.adminFilters
                : '${l.adminFilters} ($filterCount)',
          ),
        ),
        PopupMenuButton<String>(
          tooltip: officeCopy(context, 'More', 'अधिक'),
          onSelected: (action) {
            if (action == 'import') {
              _uploadLedgerCsv();
            }
            if (action == 'columns') {
              setState(() {
                _fullColumns = !_fullColumns;
                _presentation = LedgerPresentation.rows;
              });
            }
            if (action == 'refresh') {
              _load();
            }
            if (action == 'clear') {
              _clearFilters();
            }
          },
          itemBuilder:
              (_) => [
                PopupMenuItem(
                  value: 'import',
                  enabled: !_uploading,
                  child: Text(l.adminUploadCsv),
                ),
                PopupMenuItem(
                  value: 'columns',
                  child: Text(
                    _fullColumns
                        ? officeCopy(
                          context,
                          'Essential columns',
                          'ज़रूरी कॉलम',
                        )
                        : officeCopy(context, 'All columns', 'सभी कॉलम'),
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  enabled: !_loading,
                  child: Text(l.adminRefresh),
                ),
                PopupMenuItem(value: 'clear', child: Text(l.adminClearFilters)),
              ],
          child: _toolbarLabel(
            Icons.more_horiz,
            officeCopy(context, 'More', 'अधिक'),
          ),
        ),
      ],
    );
    return ChipTheme(
      data: Theme.of(context).chipTheme.copyWith(
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          l.adminFreightLedger,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _openEntryForm,
                        icon: const Icon(Icons.add),
                        label: Text(
                          officeCopy(context, 'Add entry', 'एंट्री जोड़ें'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    officeCopy(
                      context,
                      'Find an invoice and see what needs attention.',
                      'इनवॉइस खोजें और बाकी काम देखें.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<LedgerPresentation>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: LedgerPresentation.rows,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text(officeCopy(context, 'Records', 'रिकॉर्ड')),
                      ),
                      ButtonSegment(
                        value: LedgerPresentation.overview,
                        icon: const Icon(Icons.bar_chart_outlined),
                        label: Text(officeCopy(context, 'Reports', 'रिपोर्ट')),
                      ),
                    ],
                    selected: {_presentation},
                    onSelectionChanged:
                        (values) => setState(() {
                          _presentation = values.first;
                          _fullColumns = false;
                        }),
                  ),
                  const SizedBox(height: 16),
                  toolbar,
                  if (_showAdvancedFilters) ...[
                    const SizedBox(height: 12),
                    _advancedFilters(),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text(
                          officeCopy(context, 'All records', 'सभी रिकॉर्ड'),
                        ),
                        selected: !_pendingProofOnly,
                        onSelected:
                            (_) => setState(() {
                              _pendingProofOnly = false;
                              _ledgerPage = 0;
                            }),
                      ),
                      ChoiceChip(
                        label: Text(
                          officeCopy(context, 'Pending proof', 'लंबित प्रमाण'),
                        ),
                        selected: _pendingProofOnly,
                        onSelected:
                            (_) => setState(() {
                              _pendingProofOnly = true;
                              _ledgerPage = 0;
                            }),
                      ),
                      if (filterCount > 0 ||
                          _month != null ||
                          _invoiceSearch.text.isNotEmpty ||
                          _rangeDays != 90 ||
                          _customStart != null ||
                          _pendingProofOnly)
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text(l.adminClearFilters),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_loading && _error == null)
                    Text(
                      officeCopy(
                        context,
                        '${rows.length} records · ${_money(rows.fold<num>(0, (sum, row) => sum + (_num(row['total_freight']) ?? 0)))} freight · ${countDistinctFreightRows(rows, where: ledgerProofNeedsReview)} trips need proof',
                        '${rows.length} रिकॉर्ड · ${_money(rows.fold<num>(0, (sum, row) => sum + (_num(row['total_freight']) ?? 0)))} भाड़ा · ${countDistinctFreightRows(rows, where: ledgerProofNeedsReview)} चक्करों का प्रमाण बाकी',
                      ),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null || rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: WorkspaceEmptyState(
                title:
                    _error != null
                        ? officeCopy(
                          context,
                          'Ledger could not be loaded',
                          'लेजर लोड नहीं हुआ',
                        )
                        : l.adminNoLedgerRows,
                message:
                    _error != null
                        ? officeCopy(
                          context,
                          'Retry to fetch the latest records.',
                          'नई जानकारी पाने के लिए फिर प्रयास करें।',
                        )
                        : officeCopy(
                          context,
                          'Try a wider period or clear the filters.',
                          'बड़ी अवधि चुनें या फ़िल्टर हटाएँ।',
                        ),
                icon:
                    _error != null
                        ? Icons.cloud_off_outlined
                        : Icons.receipt_long_outlined,
                action: OutlinedButton(
                  onPressed: _error != null ? _load : _clearFilters,
                  child: Text(
                    _error != null ? l.adminRetry : l.adminClearFilters,
                  ),
                ),
              ),
            )
          else if (_presentation == LedgerPresentation.overview)
            SliverFillRemaining(hasScrollBody: true, child: _reports(rows))
          else if (_fullColumns)
            SliverFillRemaining(
              hasScrollBody: true,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _fullColumns = false),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          officeCopy(
                            context,
                            'Back to records',
                            'रिकॉर्ड पर वापस',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LedgerTableScroll(
                      child: DataTable(
                        columns: [
                          for (final label in _detailLabels())
                            DataColumn(label: Text(label)),
                        ],
                        rows: visible.map(_dataRow).toList(),
                      ),
                    ),
                  ),
                  _pagination(start, end, rows.length, page, pageCount),
                ],
              ),
            )
          else ...[
            if (!compact)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          officeCopy(
                            context,
                            'Invoice / customer',
                            'इनवॉइस / ग्राहक',
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: Text(
                          officeCopy(
                            context,
                            'Route / vehicle',
                            'मार्ग / वाहन',
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: Text(l.adminFreight)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Text(
                          officeCopy(
                            context,
                            'Delivery proof',
                            'डिलीवरी प्रमाण',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 144,
                        child: Text(officeCopy(context, 'Action', 'काम')),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder:
                    (_, index) => LedgerRecordTile(
                      row: visible[index],
                      freightLabel: _money(visible[index]['total_freight']),
                      compact: compact,
                      onOpen: () => _openDetails(visible[index]),
                    ),
              ),
            ),
            SliverToBoxAdapter(
              child: _pagination(start, end, rows.length, page, pageCount),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolbarLabel(IconData icon, String label) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label)),
      ],
    ),
  );

  void _applyFilter(VoidCallback change) => setState(() {
    _ledgerPage = 0;
    change();
  });

  Widget _advancedFilters() {
    final l = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FilterMenu(
              label: l.adminCompany,
              value: _company,
              options: _options('company_name'),
              onChanged: (v) => _applyFilter(() => _company = v),
            ),
            _FilterMenu(
              label: l.transporter,
              value: _transporter,
              options: _options('transporter_name'),
              onChanged: (v) => _applyFilter(() => _transporter = v),
            ),
            _FilterMenu(
              label: l.adminDestinationPlace,
              value: _destination,
              options: _options('town'),
              onChanged: (v) => _applyFilter(() => _destination = v),
            ),
            _FilterMenu(
              label: l.adminStatus,
              value: _status,
              options: const ['Open', 'Closed', 'Completed'],
              onChanged: (v) => _applyFilter(() => _status = v),
            ),
            _FilterMenu(
              label: officeCopy(
                context,
                'Original POD receipt',
                'मूल POD प्राप्ति',
              ),
              value: _podAck,
              options: const ['Received', 'Pending'],
              onChanged: (v) => _applyFilter(() => _podAck = v),
            ),
            _FilterMenu(
              label: l.adminVehicleTonnage,
              value: _tonnageCategory,
              options: _vehicleCapacityCategories,
              onChanged: (v) => _applyFilter(() => _tonnageCategory = v),
            ),
            _SearchFilter(
              label: l.adminPlaceSearch,
              hint: l.adminOriginDestinationParty,
              controller: _placeSearch,
              onChanged: () => _applyFilter(() => _ledgerPage = 0),
            ),
            _SearchFilter(
              label: l.adminEwayNumber,
              hint: l.adminSearchEway,
              controller: _ewaySearch,
              onChanged: () => _applyFilter(() => _ledgerPage = 0),
            ),
            FilterChip(
              label: Text(l.adminDelayedOnly),
              selected: _delayedOnly,
              onSelected: (v) => _applyFilter(() => _delayedOnly = v),
            ),
            FilterChip(
              label: Text(l.adminLatePod),
              selected: _latePodOnly,
              onSelected: (v) => _applyFilter(() => _latePodOnly = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagination(int start, int end, int total, int page, int pageCount) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${l.adminShowing} ${start + 1}–$end ${l.adminOf} $total'),
          IconButton.outlined(
            tooltip: l.adminPreviousPage,
            onPressed:
                page == 0 ? null : () => setState(() => _ledgerPage = page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton.outlined(
            tooltip: l.adminNextPage,
            onPressed:
                page >= pageCount - 1
                    ? null
                    : () => setState(() => _ledgerPage = page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _reports(List<Map<String, dynamic>> rows) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final summary in _OverviewSummary.values)
                  ChoiceChip(
                    label: Text(switch (summary) {
                      _OverviewSummary.transporter => l.transporter,
                      _OverviewSummary.destination => l.adminPlace,
                      _OverviewSummary.route => l.adminRoute,
                      _OverviewSummary.vehicle => l.adminVehicle,
                    }),
                    selected: summary == _overviewSummary,
                    onSelected:
                        (_) => setState(() => _overviewSummary = summary),
                  ),
                PopupMenuButton<_ReportExportType>(
                  tooltip: l.adminExportReports,
                  onSelected: _exportReport,
                  itemBuilder:
                      (_) => [
                        _exportMenuItem(
                          _ReportExportType.transporterMonthly,
                          l.adminTransporterMonthlyCsv,
                        ),
                        _exportMenuItem(
                          _ReportExportType.placeWise,
                          l.adminPlaceWiseCsv,
                        ),
                        _exportMenuItem(
                          _ReportExportType.invoiceWise,
                          l.adminInvoiceWiseCsv,
                        ),
                        _exportMenuItem(
                          _ReportExportType.podPending,
                          l.adminPodPendingCsv,
                        ),
                        _exportMenuItem(
                          _ReportExportType.vehicleTonnage,
                          l.adminVehicleTonnageCsv,
                        ),
                        _exportMenuItem(
                          _ReportExportType.routeWise,
                          l.adminRouteWiseCsv,
                        ),
                      ],
                  child: _toolbarLabel(
                    Icons.download_outlined,
                    l.adminExportReports,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _OverviewSummaryBody(
            summary: _overviewSummary,
            transporterSummaries: _transporterSummaries(rows),
            vehicleCapacitySummaries: _movementSummaries(
              rows,
              _rowTonnageCategory,
            ),
            destinationSummaries: _movementSummaries(
              rows,
              (row) => _text(row['town']),
            ),
            routeSummaries: _movementSummaries(
              rows,
              (row) => '${_text(row['origin'])} -> ${_text(row['town'])}',
            ),
          ),
        ),
      ],
    );
  }

  List<String> _detailLabels() {
    final l = AppLocalizations.of(context)!;
    return [
      l.adminCompany,
      officeCopy(context, 'Action', 'काम'),
      l.adminBill,
      l.adminDispatch,
      l.adminDelay,
      l.adminInvoiceShort,
      l.adminInvoiceCount,
      l.adminEway,
      l.adminEwayCount,
      l.adminDel,
      l.adminParty,
      l.adminPartyCount,
      l.adminOrigin,
      l.adminTown,
      l.adminCases,
      l.adminTon,
      l.adminVehicle,
      l.adminCapacity,
      l.adminDispatchGr,
      l.transporter,
      l.adminStatus,
      l.adminTotal,
      officeCopy(
        context,
        '${l.adminBalance} (monthly closing)',
        '${l.adminBalance} (महीने के अंत में)',
      ),
      l.adminPodStatus,
      l.adminPodDate,
      l.adminPodFile,
      l.adminPodRemark,
      l.adminReceivedBy,
      'POD',
    ];
  }

  Future<void> _openDetails(Map<String, dynamic> row) async {
    final l = AppLocalizations.of(context)!;
    Widget detail(BuildContext detailContext) {
      final cells = _dataRow(row).cells;
      final labels = _detailLabels();
      Widget section(String title, List<int> indices) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final index in indices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        labels[index],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: cells[index].child),
                  ],
                ),
              ),
          ],
        ),
      );
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            officeCopy(context, 'Record details', 'रिकॉर्ड का विवरण'),
          ),
          actions: [
            IconButton(
              tooltip: officeCopy(context, 'Close details', 'विवरण बंद करें'),
              onPressed: () => Navigator.pop(detailContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _text(row['invoice_number']),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${_text(row['origin'])} → ${_text(row['town'])}'),
            const SizedBox(height: 16),
            LedgerProofBadge(row: row),
            const SizedBox(height: 8),
            Text(
              officeCopy(
                context,
                'This proof status covers the whole trip. Delivery completion and office acceptance are tracked separately. Historical receipt is taken from the original ledger.',
                'यह प्रमाण स्थिति पूरे चक्कर की है। डिलीवरी पूरी होना और कार्यालय की स्वीकृति अलग हैं। पुराने रिकॉर्ड की प्राप्ति मूल लेजर से है।',
              ),
            ),
            const SizedBox(height: 24),
            if ((row['_proof_receivers'] as List? ?? const []).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  officeCopy(
                    context,
                    'Customer proof reviews',
                    'ग्राहकों के प्रमाण की जाँच',
                  ),
                ),
                children: [
                  for (final receiver in row['_proof_receivers'] as List)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_text(receiver['party_name'])} · ${_text(receiver['town'])}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LedgerProofBadge(
                            row: {
                              ...row,
                              '_proof_receivers': [receiver],
                            },
                          ),
                          if ((receiver['pod_review_note'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Text(receiver['pod_review_note'].toString()),
                        ],
                      ),
                    ),
                ],
              ),
            section(
              officeCopy(context, 'Invoice & customer', 'इनवॉइस और ग्राहक'),
              [0, 5, 10, 2, 7, 8, 9, 6, 11],
            ),
            section(
              officeCopy(context, 'Trip & delivery', 'चक्कर और डिलीवरी'),
              [12, 13, 16, 19, 17, 18, 3, 4, 14, 15, 20],
            ),
            section(
              officeCopy(context, 'Freight & settlement', 'भाड़ा और भुगतान'),
              [21, 22],
            ),
            for (final key in [
              'freight',
              'extra_freight',
              'labour',
              'detention',
              'toll_tax',
              'point_charge',
              'out_route',
              'other',
              'deduction',
              'last_month_balance',
              'payment_amount',
              'settlement_deduction',
              'period_month',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(_chargeFieldLabel(key))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        key == 'period_month'
                            ? _text(row[key])
                            : _money(row[key]),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              officeCopy(
                context,
                'Settlement values belong to a transporter’s month and appear once in filtered records. They are not per-invoice outstanding amounts.',
                'भुगतान के आंकड़े ट्रांसपोर्टर के पूरे महीने के हैं और चुने रिकॉर्ड में एक बार दिखते हैं। ये प्रति इनवॉइस बकाया नहीं हैं।',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            section(
              officeCopy(context, 'Original POD record', 'मूल POD रिकॉर्ड'),
              [23, 24, 25, 26, 27, 28],
            ),
            Text(
              officeCopy(context, 'Notes', 'टिप्पणी'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_text(row['remarks'])),
            const SizedBox(height: 16),
            SelectableText(
              '${officeCopy(context, 'Trip ID', 'चक्कर ID')}: ${_text(row['freight_id'])}',
            ),
            SelectableText(
              '${officeCopy(context, 'Invoice ID', 'इनवॉइस ID')}: ${_text(row['invoice_id'])}',
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(detailContext, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l.adminEditLedgerEntry),
                ),
                if (row['freight_id'] != null &&
                    row['record_origin'] != 'historical_import')
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(detailContext, 'delivery'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                      officeCopy(context, 'Review delivery', 'डिलीवरी देखें'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final phone = MediaQuery.sizeOf(context).width < 700;
    final action =
        phone
            ? await Navigator.of(context).push<String>(
              MaterialPageRoute(fullscreenDialog: true, builder: detail),
            )
            : await showDialog<String>(
              context: context,
              builder:
                  (c) => Dialog(
                    alignment: Alignment.centerRight,
                    insetPadding: const EdgeInsets.all(16),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 600,
                      height: MediaQuery.sizeOf(c).height - 32,
                      child: detail(c),
                    ),
                  ),
            );
    if (!mounted) return;
    if (action == 'edit') await _openEntryForm(row);
    if (action == 'delivery') {
      final role = await AuthService.instance.fetchRole();
      if (!mounted) return;
      final prefix =
          role == AppRole.admin
              ? '/admin'
              : role == AppRole.accountant
              ? '/acct'
              : '/lm';
      await context.push('$prefix/track/${row['freight_id']}');
      if (mounted) await _load();
    }
  }

  String _chargeFieldLabel(String key) => officeCopy(
    context,
    const {
          'freight': 'Base freight',
          'extra_freight': 'Extra freight',
          'labour': 'Labour',
          'detention': 'Detention',
          'toll_tax': 'Toll tax',
          'point_charge': 'Point charge',
          'out_route': 'Out route',
          'other': 'Other charges',
          'deduction': 'Freight deduction',
          'last_month_balance': 'Opening balance',
          'payment_amount': 'Monthly payments',
          'settlement_deduction': 'Monthly deduction',
          'period_month': 'Settlement month',
        }[key] ??
        key,
    const {
          'freight': 'मूल भाड़ा',
          'extra_freight': 'अतिरिक्त भाड़ा',
          'labour': 'मज़दूरी',
          'detention': 'रोक शुल्क',
          'toll_tax': 'टोल टैक्स',
          'point_charge': 'पॉइंट शुल्क',
          'out_route': 'अतिरिक्त मार्ग',
          'other': 'अन्य शुल्क',
          'deduction': 'भाड़ा कटौती',
          'last_month_balance': 'शुरू का बकाया',
          'payment_amount': 'मासिक भुगतान',
          'settlement_deduction': 'मासिक कटौती',
          'period_month': 'भुगतान का महीना',
        }[key] ??
        key,
  );

  void _clearFilters() {
    setState(() {
      _rangeDays = 90;
      _pendingProofOnly = false;
      _ledgerPage = 0;
      _customStart = null;
      _customEnd = null;
      _company = null;
      _transporter = null;
      _destination = null;
      _month = null;
      _status = null;
      _podAck = null;
      _tonnageCategory = null;
      _delayedOnly = false;
      _latePodOnly = false;
      _showAdvancedFilters = false;
      _placeSearch.clear();
      _invoiceSearch.clear();
      _ewaySearch.clear();
    });
  }

  List<String> _options(String key) {
    return _rows
        .map((row) => (row[key] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<_TransporterSummary> _transporterSummaries(
    List<Map<String, dynamic>> rows,
  ) {
    final summaries = <String, _TransporterSummary>{};
    for (final row in rows) {
      final transporter = (row['transporter_name'] ?? '').toString().trim();
      final key = transporter.isEmpty ? 'Unassigned' : transporter;
      final summary = summaries.putIfAbsent(
        key,
        () => _TransporterSummary(key),
      );
      summary.add(row);
    }
    return summaries.values.toList()
      ..sort((a, b) => b.totalFreight.compareTo(a.totalFreight));
  }

  List<_MovementSummary> _movementSummaries(
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic> row) keyFor,
  ) {
    final summaries = <String, _MovementSummary>{};
    for (final row in rows) {
      final key = keyFor(row);
      final summary = summaries.putIfAbsent(key, () => _MovementSummary(key));
      summary.add(row);
    }
    return summaries.values.toList()
      ..sort((a, b) => b.totalFreight.compareTo(a.totalFreight));
  }

  DataRow _dataRow(Map<String, dynamic> row) {
    return DataRow(
      cells: [
        DataCell(Text(_text(row['company_name']))),
        DataCell(
          OutlinedButton(
            onPressed: () => _openDetails(row),
            child: Text(
              ledgerProofNeedsReview(row)
                  ? officeCopy(context, 'Review', 'जाँचें')
                  : officeCopy(context, 'Details', 'विवरण'),
            ),
          ),
        ),
        DataCell(Text(_shortDate(row['bill_date']))),
        DataCell(Text(_shortDate(row['dispatch_date']))),
        DataCell(Text(_num(row['delay_days'])?.toStringAsFixed(0) ?? '-')),
        DataCell(Text(_text(row['invoice_number']))),
        DataCell(Text(_number(row['invoice_count']))),
        DataCell(Text(ledgerInvoiceEwayBillDisplay(row))),
        DataCell(Text(_number(row['e_way_bill_count']))),
        DataCell(Text(_text(row['delivery_reference']))),
        DataCell(Text(_text(row['party_name']))),
        DataCell(Text(_number(row['party_count']))),
        DataCell(Text(_text(row['origin']))),
        DataCell(Text(_text(row['town']))),
        DataCell(Text(_number(row['cases']))),
        DataCell(Text(_number(row['weight_kg']))),
        DataCell(Text(_text(row['vehicle_number']))),
        DataCell(Text(_text(row['vehicle_capacity_category']))),
        DataCell(Text(_text(row['dispatch_gr_bilty_number']))),
        DataCell(Text(_text(row['transporter_name']))),
        DataCell(Text(_dispatchStatusLabel(row))),
        DataCell(Text(_money(row['total_freight']))),
        DataCell(Text(_money(row['balance']))),
        DataCell(Text(_podAckLabel(row))),
        DataCell(Text(_shortDate(_podReceivedDate(row)))),
        DataCell(
          Text(_text(row['pod_file_path']).trim() == '-' ? '-' : 'Uploaded'),
        ),
        DataCell(Text(_text(row['pod_remark']))),
        DataCell(Text(_text(row['pod_received_by_name']))),
        DataCell(Text(_podRiskLabel(row))),
      ],
    );
  }
}

typedef LedgerDateSelection =
    ({DateTime? month, DateTime? start, DateTime? end});

@visibleForTesting
LedgerDateSelection selectLedgerCustomDateRange({
  required DateTime? currentStart,
  required DateTime? currentEnd,
  DateTime? pickedStart,
  DateTime? pickedEnd,
}) {
  var start = pickedStart ?? currentStart;
  var end = pickedEnd ?? currentEnd;
  if (pickedStart != null && (end == null || end.isBefore(pickedStart))) {
    end = pickedStart;
  }
  if (pickedEnd != null && (start == null || start.isAfter(pickedEnd))) {
    start = pickedEnd;
  }
  start ??= end;
  end ??= start;
  return (month: null, start: start, end: end);
}

@visibleForTesting
LedgerDateSelection selectLedgerMonth(DateTime picked) => (
  month: DateTime(picked.year, picked.month),
  start: null,
  end: null,
);

@visibleForTesting
bool ledgerRowMatchesInvoiceDocumentSearch(
  Map<String, dynamic> row, {
  required String invoiceQuery,
  required String ewayQuery,
}) {
  final invoice = (row['invoice_number'] ?? '').toString();
  if (!_containsAny(invoiceQuery, [invoice])) return false;
  final ewayNumbers = <String>{
    ..._documentNumbers(row['_invoice_eway_bill_numbers']),
    ..._documentNumbers(row['e_way_bill_number']),
  };
  return _containsAny(ewayQuery, ewayNumbers.toList());
}

@visibleForTesting
String ledgerInvoiceEwayBillDisplay(Map<String, dynamic> row) {
  final values =
      <String>{
          ..._documentNumbers(row['_invoice_eway_bill_numbers']),
          ..._documentNumbers(row['e_way_bill_number']),
        }.toList()
        ..sort();
  return values.join(' / ');
}

Set<String> _documentNumbers(dynamic value) {
  final values = value is Iterable && value is! String ? value : [value];
  return values
      .where((item) => item != null)
      .expand((item) => item.toString().split(' / '))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

@visibleForTesting
int countDistinctFreightRows(
  Iterable<Map<String, dynamic>> rows, {
  required bool Function(Map<String, dynamic> row) where,
}) {
  final ids = <String>{};
  var rowsWithoutId = 0;
  for (final row in rows) {
    if (!where(row)) continue;
    final id = (row['freight_id'] ?? '').toString().trim();
    if (id.isEmpty) {
      rowsWithoutId++;
    } else {
      ids.add(id);
    }
  }
  return ids.length + rowsWithoutId;
}

class _LedgerSettlementTotals {
  double openingBalance = 0;
  double payment = 0;
  double deduction = 0;
  double freight = 0;
  bool initialized = false;

  void add(Map<String, dynamic> row) {
    if (!initialized) {
      openingBalance = (_num(row['last_month_balance']) ?? 0).toDouble();
      payment = (_num(row['payment_amount']) ?? 0).toDouble();
      deduction = (_num(row['settlement_deduction']) ?? 0).toDouble();
      initialized = true;
    }
    freight += (_num(row['total_freight']) ?? 0).toDouble();
  }

  double get closingBalance => openingBalance + freight - payment - deduction;
}

String _ledgerSettlementGroupKey(Map<String, dynamic> row) {
  final company = (row['company_name'] ?? 'Unassigned').toString().trim();
  final transporter =
      (row['transporter_id'] ?? row['transporter_name'] ?? 'Unassigned')
          .toString()
          .trim();
  final period = (row['period_month'] ?? '').toString().trim();
  final date = period.isNotEmpty ? period : _reportDate(row)?.toIso8601String();
  final monthKey =
      date == null || date.length < 7 ? 'Unknown' : date.substring(0, 7);
  return '$company\u0000$transporter\u0000$monthKey';
}

@visibleForTesting
List<Map<String, dynamic>> normalizeLedgerSettlementFields({
  required List<Map<String, dynamic>> displayedRows,
  required List<Map<String, dynamic>> allRows,
}) {
  final totalsByGroup = <String, _LedgerSettlementTotals>{};
  for (final row in allRows) {
    totalsByGroup
        .putIfAbsent(
          _ledgerSettlementGroupKey(row),
          _LedgerSettlementTotals.new,
        )
        .add(row);
  }

  final emittedGroups = <String>{};
  return displayedRows.map((source) {
    final row =
        Map<String, dynamic>.from(source)
          ..['last_month_balance'] = null
          ..['payment_amount'] = null
          ..['settlement_deduction'] = null
          ..['balance'] = null;
    final key = _ledgerSettlementGroupKey(source);
    final totals = totalsByGroup[key];
    if (totals != null && emittedGroups.add(key)) {
      row['last_month_balance'] = totals.openingBalance;
      row['payment_amount'] = totals.payment;
      row['settlement_deduction'] = totals.deduction;
      row['balance'] = totals.closingBalance;
    }
    return row;
  }).toList();
}

bool _flag(dynamic value) {
  return value == true || value?.toString().toLowerCase() == 'true';
}

String _podRiskLabel(Map<String, dynamic> row) {
  final delay = _num(row['pod_delay_days'])?.toStringAsFixed(0);
  if (_flag(row['pod_late_flag'])) {
    return delay == null ? 'Late POD' : 'Late POD ${delay}d';
  }
  if (_flag(row['pod_missing_overdue_flag'])) {
    return 'POD overdue';
  }
  return _podAckLabel(row) == 'Received' ? 'OK' : 'Pending POD';
}

DateTime? _reportDate(Map<String, dynamic> row) {
  return _date(row['bill_date']) ??
      _date(row['dispatch_date']) ??
      _date(row['created_at']);
}

bool _sameMonth(DateTime? value, DateTime month) {
  if (value == null) return false;
  final local = value.toLocal();
  return local.year == month.year && local.month == month.month;
}

bool _containsAny(String query, List<dynamic> values) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return values.any((value) {
    final haystack = (value ?? '').toString().toLowerCase();
    return haystack.contains(needle);
  });
}

String _dispatchStatusLabel(Map<String, dynamic> row) {
  final status = (row['status'] ?? '').toString().toLowerCase();
  if (status == 'completed') return 'Completed';
  if (status == 'locked' || status == 'closed') return 'Closed';
  return 'Open';
}

String _podAckLabel(Map<String, dynamic> row) {
  final ack = (row['ack_status'] ?? '').toString().toLowerCase();
  return ack == 'received' ? 'Received' : 'Pending';
}

String _rowTonnageCategory(Map<String, dynamic> row) {
  final stored = _normalizeVehicleCapacityCategory(
    (row['vehicle_capacity_category'] ?? '').toString(),
  );
  return stored ??
      _suggestVehicleCapacityCategory(_num(row['weight_kg'])?.toDouble() ?? 0);
}

dynamic _podReceivedDate(Map<String, dynamic> row) {
  if (_podAckLabel(row) != 'Received') return null;
  return row['pod_received_date'] ?? row['ack_received_at'];
}

String _suggestVehicleCapacityCategory(double weightMt) {
  if (weightMt <= 1) return 'Up to 1 MT';
  if (weightMt <= 3) return 'Up to 3 MT';
  if (weightMt <= 6) return '3-6 MT';
  if (weightMt <= 9) return '6-9 MT';
  if (weightMt <= 12) return '9-12 MT';
  if (weightMt <= 15) return '12-15 MT';
  return '15+ MT';
}

@visibleForTesting
String ledgerVehicleCapacityForImport({
  required String? explicitCategory,
  required double combinedMetricTons,
}) =>
    _normalizeVehicleCapacityCategory(explicitCategory ?? '') ??
    _suggestVehicleCapacityCategory(combinedMetricTons);

String? _normalizeVehicleCapacityCategory(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return null;
  for (final category in _vehicleCapacityCategories) {
    if (category.toLowerCase() == normalized) return category;
  }
  final compact = normalized.replaceAll(' ', '').replaceAll('ton', 'mt');
  if (compact == '1mt' || compact == 'upto1mt' || compact == '0-1mt') {
    return 'Up to 1 MT';
  }
  if (compact == '3mt' || compact == 'upto3mt' || compact == '1-3mt') {
    return 'Up to 3 MT';
  }
  if (compact == '6mt' || compact == '3-6mt') return '3-6 MT';
  if (compact == '9mt' || compact == '6-9mt') return '6-9 MT';
  if (compact == '12mt' || compact == '9-12mt') return '9-12 MT';
  if (compact == '15mt' || compact == '12-15mt') return '12-15 MT';
  if (compact == '15+mt' || compact == 'above15mt') return '15+ MT';
  return null;
}

class _TransporterSummary {
  _TransporterSummary(this.transporter);

  final String transporter;
  final Set<String> trips = <String>{};
  final Set<String> vehicles = <String>{};
  double totalCases = 0;
  double totalMetricTons = 0;
  double totalFreight = 0;
  final List<Map<String, dynamic>> _podRows = [];

  void add(Map<String, dynamic> row) {
    _podRows.add(row);
    final trip = (row['freight_id'] ?? '').toString().trim();
    if (trip.isNotEmpty) trips.add(trip);
    final vehicle = (row['vehicle_number'] ?? '').toString().trim();
    if (vehicle.isNotEmpty) vehicles.add(vehicle);
    totalCases += (_num(row['cases']) ?? 0).toDouble();
    totalMetricTons += (_num(row['weight_kg']) ?? 0).toDouble();
    totalFreight += (_num(row['total_freight']) ?? 0).toDouble();
  }

  int get totalTrips => trips.length;
  int get totalVehicles => vehicles.length;
  double get freightPerMetricTon =>
      totalMetricTons == 0 ? 0 : totalFreight / totalMetricTons;
  double get freightPerCase => totalCases == 0 ? 0 : totalFreight / totalCases;
  int get podPending => countDistinctFreightRows(
    _podRows,
    where: ledgerProofNeedsReview,
  );
  int get podReceived => countDistinctFreightRows(
    _podRows,
    where: (row) => !ledgerProofNeedsReview(row),
  );
}

class _TransporterSummaryTable extends StatelessWidget {
  const _TransporterSummaryTable({required this.summaries, this.framed = true});

  final List<_TransporterSummary> summaries;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (summaries.isEmpty) return const SizedBox.shrink();
    if (MediaQuery.sizeOf(context).width < 900) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children:
            summaries
                .map(
                  (summary) => OfficeRecordCard(
                    title: summary.transporter,
                    values: {
                      l.adminTrips: '${summary.totalTrips}',
                      l.adminVehicles: '${summary.totalVehicles}',
                      l.adminCases: _number(summary.totalCases),
                      'MT': _number(summary.totalMetricTons),
                      l.adminFreight: _money(summary.totalFreight),
                      l.adminFreightPerMt: _money(summary.freightPerMetricTon),
                      l.adminPodPending: '${summary.podPending}',
                      l.adminPodReceived: '${summary.podReceived}',
                    },
                  ),
                )
                .toList(),
      );
    }
    return Container(
      width: double.infinity,
      margin:
          framed ? const EdgeInsets.fromLTRB(16, 0, 16, 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        border:
            framed
                ? Border.all(color: const Color(0xFFCAC4D0))
                : Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (framed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                l.adminTransporterSummary,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: LedgerTableScroll(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF6EDFB),
                ),
                columns: [
                  DataColumn(label: Text(l.transporter)),
                  DataColumn(label: Text(l.adminTrips), numeric: true),
                  DataColumn(label: Text(l.adminVehicles), numeric: true),
                  DataColumn(label: Text(l.adminCases), numeric: true),
                  const DataColumn(label: Text('MT'), numeric: true),
                  DataColumn(label: Text(l.adminFreight), numeric: true),
                  DataColumn(label: Text(l.adminFreightPerMt), numeric: true),
                  DataColumn(label: Text(l.adminFreightPerCase), numeric: true),
                  DataColumn(label: Text(l.adminPodPending), numeric: true),
                  DataColumn(label: Text(l.adminPodReceived), numeric: true),
                ],
                rows: summaries.map(_row).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(_TransporterSummary summary) {
    return DataRow(
      cells: [
        DataCell(Text(summary.transporter)),
        DataCell(Text(summary.totalTrips.toString())),
        DataCell(Text(summary.totalVehicles.toString())),
        DataCell(Text(_number(summary.totalCases))),
        DataCell(Text(_number(summary.totalMetricTons))),
        DataCell(Text(_money(summary.totalFreight))),
        DataCell(Text(_money(summary.freightPerMetricTon))),
        DataCell(Text(_money(summary.freightPerCase))),
        DataCell(Text(summary.podPending.toString())),
        DataCell(Text(summary.podReceived.toString())),
      ],
    );
  }
}

class _MovementSummary {
  _MovementSummary(this.label);

  final String label;
  final Set<String> trips = <String>{};
  final Set<String> vehicles = <String>{};
  final Map<String, Set<String>> transporterVehicles = <String, Set<String>>{};
  final Map<String, int> transporterRows = <String, int>{};
  double totalCases = 0;
  double totalMetricTons = 0;
  double totalFreight = 0;

  void add(Map<String, dynamic> row) {
    final trip = (row['freight_id'] ?? '').toString().trim();
    if (trip.isNotEmpty) trips.add(trip);
    final vehicle = (row['vehicle_number'] ?? '').toString().trim();
    if (vehicle.isNotEmpty) vehicles.add(vehicle);
    final transporter = (row['transporter_name'] ?? '').toString().trim();
    final transporterKey = transporter.isEmpty ? 'Unassigned' : transporter;
    transporterRows[transporterKey] =
        (transporterRows[transporterKey] ?? 0) + 1;
    if (vehicle.isNotEmpty) {
      transporterVehicles
          .putIfAbsent(transporterKey, () => <String>{})
          .add(vehicle);
    }
    totalCases += (_num(row['cases']) ?? 0).toDouble();
    totalMetricTons += (_num(row['weight_kg']) ?? 0).toDouble();
    totalFreight += (_num(row['total_freight']) ?? 0).toDouble();
  }

  int get totalTrips => trips.length;
  int get totalVehicles => vehicles.length;
  double get freightPerMetricTon =>
      totalMetricTons == 0 ? 0 : totalFreight / totalMetricTons;

  String get transporterBreakup {
    final entries =
        transporterRows.keys
            .map(
              (transporter) => MapEntry(
                transporter,
                transporterVehicles[transporter]?.length ??
                    transporterRows[transporter] ??
                    0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount == 0 ? a.key.compareTo(b.key) : byCount;
          });
    if (entries.isEmpty) return '-';
    final visible = entries
        .take(3)
        .map((entry) => '${entry.key} ${entry.value}');
    final hidden = entries.length - 3;
    return hidden > 0 ? '${visible.join(', ')} +$hidden' : visible.join(', ');
  }
}

class _MovementSummaryTable extends StatelessWidget {
  const _MovementSummaryTable({
    required this.title,
    required this.firstColumn,
    required this.summaries,
    required this.showBreakup,
    this.framed = true,
  });

  final String title;
  final String firstColumn;
  final List<_MovementSummary> summaries;
  final bool showBreakup;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (summaries.isEmpty) return const SizedBox.shrink();
    if (MediaQuery.sizeOf(context).width < 900) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children:
            summaries
                .map(
                  (summary) => OfficeRecordCard(
                    title: summary.label,
                    values: {
                      l.adminTrips: '${summary.totalTrips}',
                      l.adminVehicles: '${summary.totalVehicles}',
                      l.adminCases: _number(summary.totalCases),
                      'MT': _number(summary.totalMetricTons),
                      l.adminFreight: _money(summary.totalFreight),
                      l.adminFreightPerMt: _money(summary.freightPerMetricTon),
                      if (showBreakup)
                        l.adminTransporterBreakup: summary.transporterBreakup,
                    },
                  ),
                )
                .toList(),
      );
    }
    return Container(
      width: double.infinity,
      margin:
          framed ? const EdgeInsets.fromLTRB(16, 0, 16, 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        border:
            framed
                ? Border.all(color: const Color(0xFFCAC4D0))
                : Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (framed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: LedgerTableScroll(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF6EDFB),
                ),
                columns: [
                  DataColumn(label: Text(firstColumn)),
                  DataColumn(label: Text(l.adminTrips), numeric: true),
                  DataColumn(label: Text(l.adminVehicles), numeric: true),
                  DataColumn(label: Text(l.adminCases), numeric: true),
                  const DataColumn(label: Text('MT'), numeric: true),
                  DataColumn(label: Text(l.adminFreight), numeric: true),
                  DataColumn(
                    label: Text(l.adminAvgFreightPerMt),
                    numeric: true,
                  ),
                  if (showBreakup)
                    DataColumn(label: Text(l.adminTransporterBreakup)),
                ],
                rows: summaries.map(_row).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(_MovementSummary summary) {
    return DataRow(
      cells: [
        DataCell(Text(summary.label)),
        DataCell(Text(summary.totalTrips.toString())),
        DataCell(Text(summary.totalVehicles.toString())),
        DataCell(Text(_number(summary.totalCases))),
        DataCell(Text(_number(summary.totalMetricTons))),
        DataCell(Text(_money(summary.totalFreight))),
        DataCell(Text(_money(summary.freightPerMetricTon))),
        if (showBreakup) DataCell(Text(summary.transporterBreakup)),
      ],
    );
  }
}

class _ExportReport {
  const _ExportReport({
    required this.title,
    required this.slug,
    required this.headers,
    required this.rows,
  });

  final String title;
  final String slug;
  final List<String> headers;
  final List<List<dynamic>> rows;
}

class _OverviewSummaryBody extends StatelessWidget {
  const _OverviewSummaryBody({
    required this.summary,
    required this.transporterSummaries,
    required this.vehicleCapacitySummaries,
    required this.destinationSummaries,
    required this.routeSummaries,
  });

  final _OverviewSummary summary;
  final List<_TransporterSummary> transporterSummaries;
  final List<_MovementSummary> vehicleCapacitySummaries;
  final List<_MovementSummary> destinationSummaries;
  final List<_MovementSummary> routeSummaries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = switch (summary) {
      _OverviewSummary.transporter => l.adminTransporterWiseSummary,
      _OverviewSummary.destination => l.adminPlaceWiseSummary,
      _OverviewSummary.route => l.adminRouteWiseSummary,
      _OverviewSummary.vehicle => l.adminVehicleTonnageSummary,
    };
    final subtitle = switch (summary) {
      _OverviewSummary.transporter => l.adminTransporterSummaryHelp,
      _OverviewSummary.destination => l.adminPlaceSummaryHelp,
      _OverviewSummary.route => l.adminRouteSummaryHelp,
      _OverviewSummary.vehicle => l.adminVehicleSummaryHelp,
    };
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCAC4D0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            compact
                ? SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryHeading(title, subtitle),
                      const Divider(height: 1),
                      _mobileSummary(context),
                    ],
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryHeading(title, subtitle),
                    const Divider(height: 1),
                    Expanded(child: _tableForSummary(context)),
                  ],
                ),
      ),
    );
  }

  Widget _summaryHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _mobileSummary(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cards = switch (summary) {
      _OverviewSummary.transporter =>
        transporterSummaries
            .map(
              (item) => _MobileSummaryCard(
                label: item.transporter,
                trips: item.totalTrips,
                vehicles: item.totalVehicles,
                cases: item.totalCases,
                metricTons: item.totalMetricTons,
                freight: item.totalFreight,
                detail:
                    'POD ${item.podReceived} received · ${item.podPending} pending',
              ),
            )
            .toList(),
      _OverviewSummary.destination =>
        destinationSummaries.map((item) => _movementCard(item)).toList(),
      _OverviewSummary.route =>
        routeSummaries.map((item) => _movementCard(item)).toList(),
      _OverviewSummary.vehicle =>
        vehicleCapacitySummaries.map((item) => _movementCard(item)).toList(),
    };
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(l.adminNoRecordsPeriod),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: cards),
    );
  }

  _MobileSummaryCard _movementCard(_MovementSummary item) {
    return _MobileSummaryCard(
      label: item.label,
      trips: item.totalTrips,
      vehicles: item.totalVehicles,
      cases: item.totalCases,
      metricTons: item.totalMetricTons,
      freight: item.totalFreight,
    );
  }

  Widget _tableForSummary(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return switch (summary) {
      _OverviewSummary.transporter => _TransporterSummaryTable(
        summaries: transporterSummaries,
        framed: false,
      ),
      _OverviewSummary.destination => _MovementSummaryTable(
        title: l.adminDestinationSummary,
        firstColumn: l.adminDestination,
        summaries: destinationSummaries,
        showBreakup: true,
        framed: false,
      ),
      _OverviewSummary.route => _MovementSummaryTable(
        title: l.adminRouteSummary,
        firstColumn: l.adminFromTo,
        summaries: routeSummaries,
        showBreakup: false,
        framed: false,
      ),
      _OverviewSummary.vehicle => _MovementSummaryTable(
        title: l.adminVehicleTonnageSummary,
        firstColumn: l.adminCategory,
        summaries: vehicleCapacitySummaries,
        showBreakup: false,
        framed: false,
      ),
    };
  }
}

class _MobileSummaryCard extends StatelessWidget {
  const _MobileSummaryCard({
    required this.label,
    required this.trips,
    required this.vehicles,
    required this.cases,
    required this.metricTons,
    required this.freight,
    this.detail,
  });

  final String label;
  final int trips;
  final int vehicles;
  final double cases;
  final double metricTons;
  final double freight;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        border: Border.all(color: const Color(0xFFE4E0E8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _summaryMetric(l.adminTrips, trips.toString()),
              _summaryMetric(l.adminVehicles, vehicles.toString()),
              _summaryMetric(l.adminCases, _number(cases)),
              _summaryMetric('MT', _number(metricTons)),
              _summaryMetric(l.adminFreight, _money(freight)),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
        children: [
          TextSpan(text: '$label\n'),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF1D1B20),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerStatChip extends StatelessWidget {
  const _LedgerStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCAC4D0)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFFAF8FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Summary controls shared by the desktop and narrow ledger layouts.
class LedgerSummaryControls extends StatelessWidget {
  const LedgerSummaryControls({
    super.key,
    required this.invoiceRows,
    required this.trips,
    required this.vehicles,
    required this.cases,
    required this.metricTons,
    required this.freight,
    required this.podPending,
    required this.presentation,
    required this.onPresentationChanged,
  });

  final int invoiceRows;
  final int trips;
  final int vehicles;
  final num cases;
  final num metricTons;
  final num freight;
  final int podPending;
  final LedgerPresentation presentation;
  final ValueChanged<LedgerPresentation> onPresentationChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LedgerStatChip(label: l.adminInvoiceRows, value: _number(invoiceRows)),
        _LedgerStatChip(label: l.adminTrips, value: _number(trips)),
        _LedgerStatChip(label: l.adminVehicles, value: _number(vehicles)),
        _LedgerStatChip(label: l.adminCases, value: _number(cases)),
        _LedgerStatChip(label: 'MT', value: _number(metricTons)),
        _LedgerStatChip(label: l.adminFreight, value: _money(freight)),
        _LedgerStatChip(label: l.adminPodPending, value: _number(podPending)),
        SegmentedButton<LedgerPresentation>(
          segments: [
            ButtonSegment(
              value: LedgerPresentation.overview,
              icon: const Icon(Icons.dashboard_outlined),
              label: Text(l.adminOverview),
            ),
            ButtonSegment(
              value: LedgerPresentation.rows,
              icon: const Icon(Icons.table_rows_outlined),
              label: Text(l.adminRows),
            ),
          ],
          selected: {presentation},
          onSelectionChanged: (selection) {
            onPresentationChanged(selection.first);
          },
        ),
      ],
    );
  }
}

PopupMenuItem<_ReportExportType> _exportMenuItem(
  _ReportExportType type,
  String label,
) {
  return PopupMenuItem(
    value: type,
    child: Row(
      children: [
        const Icon(Icons.description_outlined, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    ),
  );
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
    final l = AppLocalizations.of(context)!;
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
          DropdownMenuItem<String?>(value: null, child: Text(l.adminAll)),
          ...options.map(
            (option) => DropdownMenuItem<String?>(
              value: option,
              child: Text(switch (option) {
                'Open' => l.adminOpen,
                'Closed' => l.adminClosed,
                'Completed' => l.adminCompleted,
                'Received' => l.adminReceived,
                'Pending' => l.adminPending,
                _ => option,
              }),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.years,
  });

  final DateTime initialMonth;
  final List<int> years;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) {
    final years =
        widget.years.contains(_year)
            ? widget.years
            : ([...widget.years, _year]..sort((a, b) => b.compareTo(a)));
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.adminSelectMonth),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.adminYear,
                border: const OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _year,
                  isDense: true,
                  isExpanded: true,
                  items:
                      years
                          .map(
                            (year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _year = value ?? _year),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.7,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected =
                    widget.initialMonth.year == _year &&
                    widget.initialMonth.month == month;
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected ? const Color(0xFFE8DEF8) : null,
                  ),
                  onPressed:
                      () => Navigator.of(context).pop(DateTime(_year, month)),
                  child: Text(_monthName(month)),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.adminCancel),
        ),
      ],
    );
  }
}

class _SearchFilter extends StatelessWidget {
  const _SearchFilter({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon:
              controller.text.isEmpty
                  ? const Icon(Icons.search, size: 18)
                  : IconButton(
                    tooltip: 'Clear $label',
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

class _CsvUploadOptions {
  const _CsvUploadOptions({
    required this.companyName,
    required this.sourceBranch,
  });

  final String companyName;
  final String sourceBranch;
}

class _CsvUploadDialog extends StatefulWidget {
  const _CsvUploadDialog();

  @override
  State<_CsvUploadDialog> createState() => _CsvUploadDialogState();
}

class _CsvUploadDialogState extends State<_CsvUploadDialog> {
  final _company = TextEditingController();
  final _source = TextEditingController(text: 'CSV Upload');

  @override
  void dispose() {
    _company.dispose();
    _source.dispose();
    super.dispose();
  }

  void _submit() {
    final company = _company.text.trim();
    if (company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adminCompanyRequired),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _CsvUploadOptions(
        companyName: company,
        sourceBranch:
            _source.text.trim().isEmpty ? 'CSV Upload' : _source.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l.adminUploadLedgerCsv),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GuidanceCard(
              title: officeCopy(
                context,
                'Import historical records',
                'पुराने रिकॉर्ड आयात करें',
              ),
              message: officeCopy(
                context,
                'Choose the company, then a CSV file. Keep the original file so you can check the import result.',
                'कंपनी चुनें, फिर CSV फ़ाइल। आयात का परिणाम जाँचने के लिए मूल फ़ाइल रखें।',
              ),
              icon: Icons.upload_file_outlined,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _company,
              decoration: InputDecoration(
                labelText: l.adminCompanySheetName,
                hintText: 'Bunge, Cargill, Ludhiana',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _source,
              decoration: InputDecoration(
                labelText: l.adminUploadTag,
                hintText: 'CSV Upload',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.adminCsvHelp,
              style: const TextStyle(color: _onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.adminCancel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l.adminChooseCsv),
        ),
      ],
    );
  }
}

class _CsvUploadResult {
  const _CsvUploadResult({
    required this.rowsImported,
    required this.chargesImported,
    required this.missingTransporters,
    required this.sourceBranch,
  });

  final int rowsImported;
  final int chargesImported;
  final List<String> missingTransporters;
  final String sourceBranch;
}

class _CsvUploadResultDialog extends StatelessWidget {
  const _CsvUploadResultDialog({required this.result});

  final _CsvUploadResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.adminCsvUploadComplete),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l.adminRowsImported}: ${result.rowsImported}'),
            Text('${l.adminChargeRowsImported}: ${result.chargesImported}'),
            Text('${l.adminUploadTag}: ${result.sourceBranch}'),
            if (result.missingTransporters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l.adminMissingTransportersHelp,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(result.missingTransporters.take(12).join(', ')),
              if (result.missingTransporters.length > 12)
                Text(
                  '+${result.missingTransporters.length - 12} ${l.adminMore}',
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.adminDone),
        ),
      ],
    );
  }
}

class _LedgerCsvRow {
  _LedgerCsvRow({
    required this.freightId,
    required this.companyName,
    required this.billNumber,
    required this.invoiceNumber,
    required this.ewayNumber,
    required this.partyName,
    required this.town,
    required this.transporter,
    required this.cases,
    required this.weight,
    required this.freight,
    required this.extraFreight,
    required this.labour,
    required this.detention,
    required this.ackReceived,
    required this.billDate,
    required this.dispatchDate,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleCapacityCategory,
    required this.vehicleCapacityExplicit,
    required this.lrNumber,
    required this.remarks,
    required this.origin,
  }) : invoiceId = _uuid();

  final String freightId;
  final String invoiceId;
  final String companyName;
  final String billNumber;
  final String invoiceNumber;
  final String ewayNumber;
  final String partyName;
  final String town;
  final String transporter;
  final int cases;
  final double weight;
  final double freight;
  final double extraFreight;
  final double labour;
  final double detention;
  final bool ackReceived;
  final String? billDate;
  final String? dispatchDate;
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleCapacityCategory;
  final bool vehicleCapacityExplicit;
  final String lrNumber;
  final String remarks;
  final String origin;
}

/// Validates an entire upload before any database write.
@visibleForTesting
int validateLedgerCsv(String csvText) => _parseLedgerCsv(csvText).length;

List<_LedgerCsvRow> _parseLedgerCsv(String csvText) {
  final rawRows = _parseCsvRows(csvText);
  final headerIndex = rawRows.indexWhere(
    (row) => row.any((cell) => _canonicalHeader(cell) == 'billdate'),
  );
  if (headerIndex < 0) {
    throw Exception('Could not find a header row with Bill Date.');
  }
  final headers = rawRows[headerIndex].map(_canonicalHeader).toList();
  String cell(List<String> row, List<String> names) {
    for (final name in names) {
      final index = headers.indexOf(name);
      if (index >= 0 && index < row.length) return _cleanCell(row[index]);
    }
    return '';
  }

  final rows = <_LedgerCsvRow>[];
  final dispatchIds = <String, String>{};
  var rowNumber = headerIndex + 1;
  for (final raw in rawRows.skip(headerIndex + 1)) {
    rowNumber++;
    if (raw.every((cell) => _cleanCell(cell).isEmpty)) continue;
    final billDate = _parseUploadDate(cell(raw, const ['billdate']));
    final party = cell(raw, const ['partyname', 'customerparty', 'customer']);
    final town = cell(raw, const ['place', 'town', 'destination']);
    final invoice = cell(raw, const ['invoicenumber', 'invoiceno']);
    final weight = _parseUploadNumber(
      cell(raw, const [
        'weightmt',
        'netweightinmt',
        'metricton',
        'mt',
        'weight',
      ]),
    );
    final rawCapacity = cell(raw, const [
      'vehiclecapacitycategory',
      'vehiclecategory',
      'capacitycategory',
      'tonnagecategory',
    ]);
    final explicitCapacity = _normalizeVehicleCapacityCategory(rawCapacity);
    final billNumber = cell(raw, const [
      'billnumber',
      'billno',
      'billinvoicereference',
      'deliveryreference',
    ]);
    final dispatchReference = cell(raw, const [
      'dispatchid',
      'dispatchreference',
      'dispatchno',
      'dispatchnumber',
      'grbilty',
      'grbiltynumber',
    ]);
    if (billDate == null ||
        party.isEmpty ||
        town.isEmpty ||
        (invoice.isEmpty && billNumber.isEmpty)) {
      throw FormatException(
        'CSV row $rowNumber requires Bill Date, Party, '
        'Place and Invoice Number (or Bill Number). No rows were imported.',
      );
    }
    final freightId =
        dispatchReference.isEmpty
            ? _uuid()
            : dispatchIds.putIfAbsent(
              _normalizeLookup(dispatchReference),
              _uuid,
            );
    rows.add(
      _LedgerCsvRow(
        freightId: freightId,
        companyName: cell(raw, const ['company', 'companyname', 'sheet']),
        billNumber: billNumber,
        invoiceNumber: invoice.isEmpty ? billNumber : invoice,
        ewayNumber: cell(raw, const [
          'ewaybill',
          'ewaybillnumber',
          'ewaynumber',
          'eway',
        ]),
        partyName: party,
        town: town,
        transporter: cell(raw, const [
          'transporter',
          'transportername',
          'transportname',
        ]),
        cases: _parseUploadCases(cell(raw, const ['cases', 'case'])),
        weight: weight,
        freight: _parseUploadNumber(
          cell(raw, const ['freight', 'freightamount']),
        ),
        extraFreight: _parseUploadNumber(
          cell(raw, const ['extrafreight', 'extra']),
        ),
        labour: _parseUploadNumber(cell(raw, const ['labour', 'labor'])),
        detention: _parseUploadNumber(cell(raw, const ['detention'])),
        ackReceived: _isAckReceived(
          cell(raw, const [
            'podacknowledgement',
            'acknowledgementstatus',
            'acknwoledgementstatus',
            'podstatus',
            'ackstatus',
          ]),
        ),
        billDate: billDate,
        dispatchDate: _parseUploadDate(cell(raw, const ['dispatchdate'])),
        vehicleNumber: cell(raw, const ['vehiclenumber', 'vehicle']),
        vehicleType: cell(raw, const ['vehicletype']),
        vehicleCapacityCategory:
            explicitCapacity ?? _suggestVehicleCapacityCategory(weight),
        vehicleCapacityExplicit: explicitCapacity != null,
        lrNumber: cell(raw, const ['lrno', 'lrnumber', 'lrgr', 'grnumber']),
        remarks: cell(raw, const ['remarks', 'remark']),
        origin: cell(raw, const ['origin', 'from', 'branch']),
      ),
    );
  }
  return rows;
}

List<List<String>> _parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(cell.toString());
      cell.clear();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (quoted) {
    throw const FormatException('CSV contains an unclosed quoted field.');
  }
  row.add(cell.toString());
  if (row.any((cell) => cell.trim().isNotEmpty)) rows.add(row);
  return rows;
}

String _canonicalHeader(String value) {
  return _cleanCell(value).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _cleanCell(String value) {
  return value.replaceAll('\ufeff', '').replaceAll('\u00a0', ' ').trim();
}

double _parseUploadNumber(String value) {
  final text = _cleanCell(value).replaceAll(',', '');
  if (text.isEmpty || text == '-' || text == '--') return 0;
  final amount = double.tryParse(text);
  if (amount == null || !amount.isFinite || amount < 0) {
    throw FormatException('Invalid non-negative number in CSV: $value');
  }
  return amount;
}

int _parseUploadCases(String value) {
  final cases = _parseUploadNumber(value);
  if (cases != cases.roundToDouble()) {
    throw FormatException('Cases must be a whole number: $value');
  }
  return cases.toInt();
}

String? _parseUploadDate(String value) {
  final text = _cleanCell(value);
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) {
    final parts = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (parts != null) {
      return _isoDate(
        int.parse(parts.group(1)!),
        int.parse(parts.group(2)!),
        int.parse(parts.group(3)!),
      );
    }
    return iso.toIso8601String().substring(0, 10);
  }
  final monthPattern = RegExp(r'^(\d{1,2})/([A-Za-z]{3})/(\d{2,4})$');
  final monthMatch = monthPattern.firstMatch(text);
  if (monthMatch != null) {
    final day = int.parse(monthMatch.group(1)!);
    final month = _monthNumber(monthMatch.group(2)!);
    final year = _fullYear(monthMatch.group(3)!);
    return _isoDate(year, month, day);
  }
  final numericPattern = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$');
  final numericMatch = numericPattern.firstMatch(text);
  if (numericMatch != null) {
    final day = int.parse(numericMatch.group(1)!);
    final month = int.parse(numericMatch.group(2)!);
    final year = _fullYear(numericMatch.group(3)!);
    return _isoDate(year, month, day);
  }
  throw Exception('Unsupported date format: $text');
}

int _monthNumber(String value) {
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[value.toLowerCase()];
  if (month == null) throw Exception('Unsupported month: $value');
  return month;
}

int _fullYear(String value) {
  final year = int.parse(value);
  return year < 100 ? 2000 + year : year;
}

String _isoDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Invalid calendar date: $day/$month/$year');
  }
  return date.toIso8601String().substring(0, 10);
}

bool _isAckReceived(String value) {
  final text = _cleanCell(value).toLowerCase();
  return text == 'received' ||
      text == 'recd' ||
      text == 'yes' ||
      text == 'pod received';
}

String _normalizeLookup(dynamic value) {
  return (value ?? '')
      .toString()
      .replaceAll('\u00a0', ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _uuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _LedgerEntryDialog extends StatefulWidget {
  const _LedgerEntryDialog({this.row});

  final Map<String, dynamic>? row;

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
  final _dispatchGrBilty = TextEditingController();
  final _remarks = TextEditingController();
  final _lastMonthBalance = TextEditingController();
  final _payment = TextEditingController();
  final _settlementDeduction = TextEditingController();
  final _settlementRemarks = TextEditingController();
  final _podReceivedDate = TextEditingController();
  final _podRemark = TextEditingController();
  final _duplicateOverrideReason = TextEditingController();
  final _duplicateOverrideRemark = TextEditingController();
  String _ack = 'pending';
  String? _existingAckReceivedAt;
  String? _podFilePath;
  _PickedPodFile? _podPendingFile;
  String? _vehicleCapacityCategory;
  bool _vehicleCapacityEdited = false;
  bool _duplicateOverrideApproved = false;
  bool _isAdmin = false;
  String? _transporterId;
  bool _saving = false;
  bool _loadingExisting = false;
  List<Map<String, dynamic>> _transporters = const [];
  List<_DuplicateInvoiceMatch> _duplicateMatches = const [];
  final _invoices = <_InvoiceDraft>[_InvoiceDraft()];
  final _charges = <_ChargeDraft>[_ChargeDraft(kind: 'freight')];
  final _products = <_ProductDraft>[];
  bool get _editing => widget.row != null;

  @override
  void initState() {
    super.initState();
    _loadTransporters();
    if (_editing) _loadExisting();
  }

  @override
  void dispose() {
    _company.dispose();
    _branch.dispose();
    _origin.dispose();
    _party.dispose();
    _vehicle.dispose();
    _vehicleType.dispose();
    _dispatchGrBilty.dispose();
    _remarks.dispose();
    _lastMonthBalance.dispose();
    _payment.dispose();
    _settlementDeduction.dispose();
    _settlementRemarks.dispose();
    _podReceivedDate.dispose();
    _podRemark.dispose();
    _duplicateOverrideReason.dispose();
    _duplicateOverrideRemark.dispose();
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
    final uid = supabase.auth.currentUser?.id;
    var isAdmin = false;
    if (uid != null) {
      final profile =
          await supabase
              .from('profiles')
              .select('role')
              .eq('id', uid)
              .maybeSingle();
      isAdmin = profile?['role']?.toString() == 'admin';
    }
    if (!mounted) return;
    setState(() {
      _transporters = (rows as List).cast<Map<String, dynamic>>();
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadExisting() async {
    final row = widget.row!;
    final freightId = row['freight_id']?.toString();
    if (freightId == null || freightId.isEmpty) return;
    setState(() => _loadingExisting = true);
    try {
      final freight =
          await supabase.from('freights').select().eq('id', freightId).single();
      final settlementCompany =
          (freight['company_name'] ?? row['company_name'] ?? '').toString();
      final settlementTransporterId =
          (row['transporter_id'] ?? freight['winner_profile_id'])?.toString();
      final settlementMonth = _monthStart(
        (row['period_month'] ?? row['bill_date'] ?? row['dispatch_date'])
            ?.toString(),
      );
      final settlements = await supabase
          .from('transporter_ledger_settlements')
          .select(
            'transporter_id, last_month_balance, payment_amount, deduction_amount, remarks',
          )
          .eq('company_name', settlementCompany)
          .eq('period_month', settlementMonth);
      final settlement =
          (settlements as List)
              .cast<Map<String, dynamic>>()
              .where(
                (item) =>
                    item['transporter_id']?.toString() ==
                    settlementTransporterId,
              )
              .firstOrNull;
      final invoices = await supabase
          .from('invoices')
          .select()
          .eq('freight_id', freightId)
          .order('created_at');
      final invoiceIds =
          invoices.map((invoice) => invoice['id'].toString()).toList();
      final documents =
          invoiceIds.isEmpty
              ? <Map<String, dynamic>>[]
              : await supabase
                  .from('invoice_documents')
                  .select('invoice_id, document_kind, document_number')
                  .inFilter('invoice_id', invoiceIds);
      final invoicesWithDocuments = [
        for (final invoice in invoices)
          {
            ...invoice,
            'e_way_bill_numbers': [
              for (final document in documents)
                if (document['invoice_id'] == invoice['id'] &&
                    document['document_kind'] == 'e_way_bill')
                  document['document_number'],
            ],
            'gr_bilty_numbers': [
              for (final document in documents)
                if (document['invoice_id'] == invoice['id'] &&
                    document['document_kind'] == 'gr_bilty')
                  document['document_number'],
            ],
          },
      ];
      final charges = await supabase
          .from('freight_charges')
          .select()
          .eq('freight_id', freightId)
          .order('created_at');
      final products = await supabase
          .from('freight_product_lines')
          .select()
          .eq('freight_id', freightId)
          .order('product_name');
      if (!mounted) return;
      setState(() {
        _company.text = (freight['company_name'] ?? '').toString();
        _branch.text = (freight['source_branch'] ?? '').toString();
        _origin.text = (freight['origin'] ?? '').toString();
        _party.text = (freight['party_name'] ?? '').toString();
        _vehicle.text = (freight['vehicle_number'] ?? '').toString();
        _vehicleType.text = (freight['vehicle_type'] ?? '').toString();
        _dispatchGrBilty.text =
            (freight['gr_bilty_number'] ??
                    row['dispatch_gr_bilty_number'] ??
                    '')
                .toString();
        _vehicleCapacityCategory =
            _normalizeVehicleCapacityCategory(
              freight['vehicle_capacity_category']?.toString() ?? '',
            ) ??
            _suggestVehicleCapacityCategory(
              (_num(freight['weight_kg']) ?? 0).toDouble(),
            );
        _vehicleCapacityEdited = freight['vehicle_capacity_category'] != null;
        _remarks.text = (freight['remarks'] ?? '').toString();
        _ack = (freight['ack_status'] ?? 'pending').toString();
        _existingAckReceivedAt = freight['ack_received_at']?.toString();
        _podReceivedDate.text = _shortDate(
          freight['pod_received_date'] ?? freight['ack_received_at'],
        );
        if (_podReceivedDate.text == '-') _podReceivedDate.clear();
        _podFilePath =
            (freight['pod_file_path'] ?? '').toString().trim().isEmpty
                ? null
                : freight['pod_file_path'].toString();
        _podRemark.text = (freight['pod_remark'] ?? '').toString();
        _transporterId = freight['winner_profile_id']?.toString();
        _lastMonthBalance.text = _editNumber(
          settlement?['last_month_balance'] ?? row['last_month_balance'],
        );
        _payment.text = _editNumber(
          settlement?['payment_amount'] ?? row['payment_amount'],
        );
        _settlementDeduction.text = _editNumber(
          settlement?['deduction_amount'] ?? row['settlement_deduction'],
        );
        _settlementRemarks.text =
            (settlement?['remarks'] ?? row['settlement_remarks'] ?? '')
                .toString();
        for (final invoice in _invoices) {
          invoice.dispose();
        }
        _invoices
          ..clear()
          ..addAll(
            invoicesWithDocuments.map(
              (item) =>
                  _InvoiceDraft.fromMap(Map<String, dynamic>.from(item as Map)),
            ),
          );
        if (_invoices.isEmpty) _invoices.add(_InvoiceDraft.fromLedgerRow(row));
        for (final charge in _charges) {
          charge.dispose();
        }
        _charges
          ..clear()
          ..addAll(
            (charges as List).map(
              (item) =>
                  _ChargeDraft.fromMap(Map<String, dynamic>.from(item as Map)),
            ),
          );
        if (_charges.isEmpty) _charges.add(_ChargeDraft(kind: 'freight'));
        for (final product in _products) {
          product.dispose();
        }
        _products
          ..clear()
          ..addAll(
            (products as List).map(
              (item) =>
                  _ProductDraft.fromMap(Map<String, dynamic>.from(item as Map)),
            ),
          );
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExisting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.adminLoadFailed}: $e'),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final company = _company.text.trim();
    final firstTown = _invoices.first.town.text.trim();
    if (company.isEmpty || firstTown.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adminCompanyTownRequired),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    String? newPodPath;
    try {
      final invoiceRows =
          _invoices.map((invoice) => invoice.toInsert()).toList();
      final currentFreightId =
          _editing ? widget.row!['freight_id'] as String : null;
      final duplicateMatches = await _findDuplicateInvoiceMatches(
        invoiceRows,
        currentFreightId,
      );
      if (!mounted) return;
      if (duplicateMatches.isNotEmpty) {
        final reason = _duplicateOverrideReason.text.trim();
        final remark = _duplicateOverrideRemark.text.trim();
        if (!_duplicateOverrideApproved) {
          setState(() {
            _duplicateMatches = duplicateMatches;
            _saving = false;
          });
          _showDuplicateSnackBar(duplicateMatches);
          return;
        }
        if (!_isAdmin || reason.isEmpty || remark.isEmpty) {
          setState(() {
            _duplicateMatches = duplicateMatches;
            _saving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Admin override requires approval, reason, and remark.',
              ),
            ),
          );
          return;
        }
      } else if (_duplicateMatches.isNotEmpty) {
        setState(() => _duplicateMatches = const []);
      }
      final totalCases = invoiceRows.fold<int>(
        0,
        (sum, row) => sum + ((row['cases'] as int?) ?? 0),
      );
      final totalWeight = invoiceRows.fold<double>(
        0,
        (sum, row) => sum + ((row['weight_kg'] as double?) ?? 0),
      );
      final vehicleCapacityCategory =
          _vehicleCapacityCategory ??
          _suggestVehicleCapacityCategory(totalWeight);
      final podHasFile =
          _podPendingFile != null || (_podFilePath ?? '').trim().isNotEmpty;
      final podStatus = podHasFile && _ack != 'received' ? 'received' : _ack;
      final podReceivedDate =
          podStatus == 'received'
              ? (_dateText(_podReceivedDate.text) ??
                  DateTime.now().toIso8601String().substring(0, 10))
              : null;
      final ackReceivedAt =
          podStatus == 'received'
              ? (_existingAckReceivedAt ?? DateTime.now().toIso8601String())
              : null;
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
      final firstGrBilty =
          _dispatchGrBilty.text.trim().isNotEmpty
              ? _dispatchGrBilty.text.trim()
              : invoiceRows
                  .map((row) => row['lr_number'])
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .firstOrNull;
      final freightPayload = {
        'origin':
            _origin.text.trim().isEmpty ? 'Manual Ledger' : _origin.text.trim(),
        'destination_town': firstTown,
        'company_name': company,
        'party_name': _party.text.trim().isEmpty ? null : _party.text.trim(),
        'bill_date': firstBillDate,
        'dispatch_date': firstDispatchDate,
        'vehicle_number':
            _vehicle.text.trim().isEmpty ? null : _vehicle.text.trim(),
        'vehicle_type':
            _vehicleType.text.trim().isEmpty ? null : _vehicleType.text.trim(),
        'gr_bilty_number': firstGrBilty,
        'vehicle_capacity_category': vehicleCapacityCategory,
        'source_branch':
            _branch.text.trim().isEmpty ? null : _branch.text.trim(),
        'ack_status': podStatus,
        'ack_received_at': ackReceivedAt,
        'pod_received_date': podReceivedDate,
        'pod_file_path': _podFilePath,
        'pod_remark':
            _podRemark.text.trim().isEmpty ? null : _podRemark.text.trim(),
        'pod_received_by':
            podStatus == 'received' ? supabase.auth.currentUser?.id : null,
        'winner_profile_id': _transporterId,
        'cases': totalCases,
        'weight_kg': totalWeight,
        'remarks': _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      };
      final freightId = currentFreightId ?? _uuid();
      newPodPath = await _uploadPodFileIfNeeded(freightId);
      if (newPodPath != null) freightPayload['pod_file_path'] = newPodPath;
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
      final charges =
          _charges
              .map((charge) => charge.toInsert(freightId))
              .where((row) => ((row['amount'] as double?) ?? 0) != 0)
              .toList();
      final products =
          _products
              .map((product) => product.toInsert(freightId))
              .where((row) => (row['product_name'] as String).isNotEmpty)
              .toList();
      await supabase.rpc(
        'save_manual_ledger_entry',
        params: {
          'p_freight_id': freightId,
          'p_is_new': !_editing,
          'p_freight': freightPayload,
          'p_invoices': invoiceInserts,
          'p_charges': charges,
          'p_products': products,
          'p_overrides': _duplicateOverridePayload(duplicateMatches, freightId),
          'p_settlement': _settlementPayload(
            company: company,
            transporterId: _transporterId,
            periodSource: firstBillDate ?? firstDispatchDate,
          ),
        },
      );
      newPodPath = null; // The committed ledger now owns the uploaded proof.
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (newPodPath != null) {
        try {
          await supabase.storage.from('delivery-documents').remove([
            newPodPath,
          ]);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(e))));
    }
  }

  Future<List<_DuplicateInvoiceMatch>> _findDuplicateInvoiceMatches(
    List<Map<String, dynamic>> invoiceRows,
    String? currentFreightId,
  ) async {
    final invoiceNumbers =
        invoiceRows
            .map((row) => (row['invoice_number'] ?? '').toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
    if (invoiceNumbers.isEmpty) return const [];
    final rows = await supabase.rpc(
      'find_duplicate_finalized_invoices',
      params: {
        'invoice_numbers': invoiceNumbers,
        'excluded_freight_id': currentFreightId,
      },
    );
    return (rows as List)
        .map(
          (row) => _DuplicateInvoiceMatch.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> _duplicateOverridePayload(
    List<_DuplicateInvoiceMatch> matches,
    String freightId,
  ) =>
      matches
          .map(
            (match) => <String, dynamic>{
              'invoice_number': match.invoiceNumber,
              'existing_freight_id': match.existingFreightId,
              'reason': _duplicateOverrideReason.text.trim(),
              'remark': _duplicateOverrideRemark.text.trim(),
              'metadata': {
                'company_name': match.companyName,
                'transporter_name': match.transporterName,
              },
            },
          )
          .toList();

  void _showDuplicateSnackBar(List<_DuplicateInvoiceMatch> matches) {
    final invoice = matches.first.invoiceNumber;
    final more = matches.length > 1 ? ' +${matches.length - 1} more' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Duplicate freight blocked: invoice $invoice$more already has finalized freight.',
        ),
      ),
    );
  }

  String _cleanSegment(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    return cleaned.isEmpty ? 'upload' : cleaned;
  }

  String _contentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickPodFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.adminPodFileReadFailed),
        ),
      );
      return;
    }
    setState(() {
      _podPendingFile = _PickedPodFile(
        name: file.name,
        extension: file.extension,
        bytes: Uint8List.fromList(bytes),
      );
      _ack = 'received';
      if (_podReceivedDate.text.trim().isEmpty) {
        _podReceivedDate.text = DateTime.now().toIso8601String().substring(
          0,
          10,
        );
      }
    });
  }

  Future<String?> _uploadPodFileIfNeeded(String freightId) async {
    final file = _podPendingFile;
    final uid = supabase.auth.currentUser?.id;
    if (file == null || uid == null) return null;
    final extension = _cleanSegment(file.extension ?? 'jpg');
    final originalName = file.name;
    final baseName =
        originalName.toLowerCase().endsWith('.${extension.toLowerCase()}')
            ? originalName.substring(
              0,
              originalName.length - extension.length - 1,
            )
            : originalName;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}-${_cleanSegment(baseName)}';
    final path = '$uid/$freightId/delivered/pod/$fileName.$extension';
    await supabase.storage
        .from('delivery-documents')
        .uploadBinary(
          path,
          file.bytes,
          fileOptions: FileOptions(
            contentType: _contentType(file.extension),
            upsert: true,
          ),
        );
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final suggestedCapacity = _suggestVehicleCapacityCategory(
      _invoices.fold<double>(
        0,
        (sum, invoice) =>
            sum + (double.tryParse(invoice.weight.text.trim()) ?? 0),
      ),
    );
    final capacityValue = _vehicleCapacityCategory ?? suggestedCapacity;
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
                  Expanded(
                    child: Text(
                      l.adminLedgerEntry,
                      style: const TextStyle(
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
              child:
                  _loadingExisting
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          GuidanceCard(
                            title: officeCopy(
                              context,
                              'Record the trip, then its invoices',
                              'पहले चक्कर, फिर इनवॉइस भरें',
                            ),
                            message: officeCopy(
                              context,
                              'Start with the company, route and vehicle. Add one line for each invoice. Optional charges and payments are below.',
                              'कंपनी, मार्ग और वाहन से शुरुआत करें। हर इनवॉइस की एक पंक्ति जोड़ें। वैकल्पिक शुल्क और भुगतान नीचे हैं।',
                            ),
                            icon: Icons.edit_note_outlined,
                          ),
                          const SizedBox(height: 20),
                          SectionHeading(
                            title: officeCopy(
                              context,
                              'Trip and delivery details',
                              'चक्कर और डिलीवरी की जानकारी',
                            ),
                          ),
                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _field(_company, l.adminCompanyRequiredLabel),
                              _field(_party, l.adminParty),
                              _field(_origin, l.adminOrigin),
                              _field(_branch, l.adminBranch),
                              _field(_vehicle, l.adminVehicle),
                              _field(_vehicleType, l.adminVehicleType),
                              _field(_dispatchGrBilty, l.adminDispatchGrBilty),
                              _VehicleCapacityPicker(
                                value: capacityValue,
                                onChanged:
                                    (value) => setState(() {
                                      _vehicleCapacityCategory = value;
                                      _vehicleCapacityEdited = true;
                                    }),
                              ),
                              SizedBox(
                                width: 260,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _transporterId,
                                  decoration: InputDecoration(
                                    labelText: l.transporter,
                                    border: const OutlineInputBorder(),
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
                                  onChanged:
                                      (v) => setState(() => _transporterId = v),
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _ack,
                                  decoration: InputDecoration(
                                    labelText: l.adminAckStatus,
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text(l.adminPending),
                                    ),
                                    DropdownMenuItem(
                                      value: 'received',
                                      child: Text(l.adminReceived),
                                    ),
                                    DropdownMenuItem(
                                      value: 'not_required',
                                      child: Text(l.adminNotRequired),
                                    ),
                                  ],
                                  onChanged:
                                      (v) => setState(() {
                                        _ack = v ?? 'pending';
                                        if (_ack == 'received' &&
                                            _podReceivedDate.text
                                                .trim()
                                                .isEmpty) {
                                          _podReceivedDate.text = DateTime.now()
                                              .toIso8601String()
                                              .substring(0, 10);
                                        }
                                      }),
                                ),
                              ),
                              _field(_podReceivedDate, l.adminPodReceivedDate),
                              _field(_podRemark, l.adminPodRemark),
                              _PodFilePicker(
                                path: _podFilePath,
                                pendingName: _podPendingFile?.name,
                                onPick: _pickPodFile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            title: l.adminInvoiceLines,
                            onAdd:
                                () => setState(
                                  () => _invoices.add(_InvoiceDraft()),
                                ),
                          ),
                          for (var i = 0; i < _invoices.length; i++)
                            _InvoiceDraftRow(
                              draft: _invoices[i],
                              onChanged:
                                  () => setState(() {
                                    if (!_vehicleCapacityEdited) {
                                      _vehicleCapacityCategory = null;
                                    }
                                  }),
                              onRemove:
                                  _invoices.length == 1
                                      ? null
                                      : () => setState(() {
                                        _invoices.removeAt(i).dispose();
                                        if (!_vehicleCapacityEdited) {
                                          _vehicleCapacityCategory = null;
                                        }
                                      }),
                            ),
                          _DuplicateFreightOverridePanel(
                            matches: _duplicateMatches,
                            approved: _duplicateOverrideApproved,
                            isAdmin: _isAdmin,
                            reason: _duplicateOverrideReason,
                            remark: _duplicateOverrideRemark,
                            onApprovedChanged:
                                (value) => setState(
                                  () =>
                                      _duplicateOverrideApproved =
                                          value ?? false,
                                ),
                          ),
                          const SizedBox(height: 14),
                          ExpansionTile(
                            initiallyExpanded: widget.row != null,
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              officeCopy(
                                context,
                                'Charges, settlement and products',
                                'शुल्क, भुगतान और उत्पाद',
                              ),
                            ),
                            subtitle: Text(
                              officeCopy(
                                context,
                                'Open when this entry needs extra charges or payment details.',
                                'अतिरिक्त शुल्क या भुगतान की जानकारी के लिए खोलें।',
                              ),
                            ),
                            children: [
                              _SectionHeader(
                                title: l.adminCharges,
                                onAdd:
                                    () => setState(
                                      () => _charges.add(
                                        _ChargeDraft(kind: 'other'),
                                      ),
                                    ),
                              ),
                              for (var i = 0; i < _charges.length; i++)
                                _ChargeDraftRow(
                                  draft: _charges[i],
                                  onRemove:
                                      _charges.length == 1
                                          ? null
                                          : () => setState(
                                            () =>
                                                _charges.removeAt(i).dispose(),
                                          ),
                                ),
                              const SizedBox(height: 14),
                              _SectionHeader(
                                title: l.adminSettlement,
                                onAdd: null,
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _field(
                                    _lastMonthBalance,
                                    l.adminLastMonthBalance,
                                    number: true,
                                  ),
                                  _field(
                                    _payment,
                                    l.adminPayment,
                                    number: true,
                                  ),
                                  _field(
                                    _settlementDeduction,
                                    l.adminSettlementDeduction,
                                    number: true,
                                  ),
                                  _field(
                                    _settlementRemarks,
                                    l.adminSettlementRemarks,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionHeader(
                                title: l.adminProducts,
                                onAdd:
                                    () => setState(
                                      () => _products.add(_ProductDraft()),
                                    ),
                              ),
                              if (_products.isEmpty)
                                Text(
                                  l.adminOptionalProductsHelp,
                                  style: const TextStyle(
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                              for (var i = 0; i < _products.length; i++)
                                _ProductDraftRow(
                                  draft: _products[i],
                                  onRemove:
                                      () => setState(
                                        () => _products.removeAt(i).dispose(),
                                      ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _remarks,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l.adminRemarks,
                              border: const OutlineInputBorder(),
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
                    child: Text(l.adminCancel),
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
                    label: Text(l.adminSaveEntry),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic>? _settlementPayload({
    required String company,
    required String? transporterId,
    required String? periodSource,
  }) {
    if (transporterId == null) return null;
    final hasSettlement =
        _lastMonthBalance.text.trim().isNotEmpty ||
        _payment.text.trim().isNotEmpty ||
        _settlementDeduction.text.trim().isNotEmpty ||
        _settlementRemarks.text.trim().isNotEmpty;
    if (!hasSettlement) return null;
    final periodMonth = _monthStart(periodSource);
    return {
      'company_name': company,
      'transporter_id': transporterId,
      'period_month': periodMonth,
      'last_month_balance': double.tryParse(_lastMonthBalance.text.trim()) ?? 0,
      'payment_amount': double.tryParse(_payment.text.trim()) ?? 0,
      'deduction_amount':
          double.tryParse(_settlementDeduction.text.trim()) ?? 0,
      'remarks':
          _settlementRemarks.text.trim().isEmpty
              ? null
              : _settlementRemarks.text.trim(),
      'created_by': supabase.auth.currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback? onAdd;

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
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.adminAdd),
          ),
      ],
    );
  }
}

class _DuplicateInvoiceMatch {
  const _DuplicateInvoiceMatch({
    required this.invoiceNumber,
    required this.invoiceNumberNorm,
    required this.existingFreightId,
    required this.companyName,
    required this.transporterName,
    required this.billDate,
    required this.dispatchDate,
    required this.totalFreight,
  });

  final String invoiceNumber;
  final String invoiceNumberNorm;
  final String existingFreightId;
  final String companyName;
  final String transporterName;
  final String billDate;
  final String dispatchDate;
  final num? totalFreight;

  factory _DuplicateInvoiceMatch.fromMap(Map<String, dynamic> map) {
    return _DuplicateInvoiceMatch(
      invoiceNumber: (map['invoice_number'] ?? '').toString(),
      invoiceNumberNorm: (map['invoice_number_norm'] ?? '').toString(),
      existingFreightId: (map['existing_freight_id'] ?? '').toString(),
      companyName: (map['company_name'] ?? '').toString(),
      transporterName: (map['transporter_name'] ?? '').toString(),
      billDate: (map['bill_date'] ?? '').toString(),
      dispatchDate: (map['dispatch_date'] ?? '').toString(),
      totalFreight: _num(map['total_freight']),
    );
  }
}

class _DuplicateFreightOverridePanel extends StatelessWidget {
  const _DuplicateFreightOverridePanel({
    required this.matches,
    required this.approved,
    required this.isAdmin,
    required this.reason,
    required this.remark,
    required this.onApprovedChanged,
  });

  final List<_DuplicateInvoiceMatch> matches;
  final bool approved;
  final bool isAdmin;
  final TextEditingController reason;
  final TextEditingController remark;
  final ValueChanged<bool?> onApprovedChanged;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF8E1),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.adminDuplicateFreightLock,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final match in matches.take(4))
              Text(
                '${match.invoiceNumber} already exists in ${match.companyName.isEmpty ? 'finalized freight' : match.companyName} '
                '${match.billDate.isEmpty ? '' : 'on ${match.billDate} '}'
                '${match.transporterName.isEmpty ? '' : 'via ${match.transporterName}'}',
              ),
            if (matches.length > 4)
              Text('+${matches.length - 4} ${l.adminMore}'),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: approved,
              onChanged: isAdmin ? onApprovedChanged : null,
              title: Text(l.adminOverrideApproval),
              subtitle:
                  isAdmin
                      ? Text(l.adminReasonRemarkRequired)
                      : Text(l.adminOnlyAdminOverride),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (approved) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _field(reason, l.adminOverrideReason),
                  _field(remark, l.adminOverrideRemark),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceDraft {
  _InvoiceDraft();
  String id = _uuid();
  Map<String, dynamic> preservedFields = {};

  final invoice = TextEditingController();
  final party = TextEditingController();
  final eWay = TextEditingController();
  final extraEways = <TextEditingController>[];
  final deliveryReference = TextEditingController();
  final lr = TextEditingController();
  final extraGrs = <TextEditingController>[];
  final town = TextEditingController();
  final billDate = TextEditingController();
  final dispatchDate = TextEditingController();
  final cases = TextEditingController();
  final weight = TextEditingController();
  final baseFreight = TextEditingController();

  Map<String, dynamic> toInsert() => {
    ...preservedFields,
    'id': id,
    'invoice_number':
        invoice.text.trim().isEmpty
            ? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}'
            : invoice.text.trim(),
    'e_way_bill_number': eWay.text.trim().isEmpty ? null : eWay.text.trim(),
    'e_way_bill_numbers': _numbers(eWay, extraEways),
    'delivery_reference':
        deliveryReference.text.trim().isEmpty
            ? null
            : deliveryReference.text.trim(),
    'gr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'lr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'gr_bilty_numbers': _numbers(lr, extraGrs),
    'party_name': party.text.trim().isEmpty ? null : party.text.trim(),
    'town': town.text.trim(),
    'bill_date': _dateText(billDate.text),
    'dispatch_date': _dateText(dispatchDate.text),
    'cases': int.tryParse(cases.text.trim()),
    'weight_kg': double.tryParse(weight.text.trim()),
    'base_freight': double.tryParse(baseFreight.text.trim()),
    'freight_share': double.tryParse(baseFreight.text.trim()),
  };

  List<String> _numbers(
    TextEditingController primary,
    List<TextEditingController> extras,
  ) =>
      [primary, ...extras]
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

  void _loadExtraNumbers(
    Map<String, dynamic> map,
    String key,
    TextEditingController primary,
    List<TextEditingController> extras,
  ) {
    final numbers =
        (map[key] as List? ?? const [])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList();
    if (numbers.isEmpty) return;
    primary.text = numbers.first;
    extras.addAll(
      numbers.skip(1).map((value) => TextEditingController(text: value)),
    );
  }

  factory _InvoiceDraft.fromMap(Map<String, dynamic> map) {
    final draft = _InvoiceDraft();
    draft.id = map['id']?.toString() ?? draft.id;
    draft.preservedFields = Map<String, dynamic>.from(map);
    draft.invoice.text = (map['invoice_number'] ?? '').toString();
    draft.party.text = (map['party_name'] ?? '').toString();
    draft.eWay.text = (map['e_way_bill_number'] ?? '').toString();
    draft._loadExtraNumbers(
      map,
      'e_way_bill_numbers',
      draft.eWay,
      draft.extraEways,
    );
    draft.deliveryReference.text = (map['delivery_reference'] ?? '').toString();
    draft.lr.text = (map['lr_number'] ?? map['gr_number'] ?? '').toString();
    draft._loadExtraNumbers(map, 'gr_bilty_numbers', draft.lr, draft.extraGrs);
    draft.town.text = (map['town'] ?? '').toString();
    draft.billDate.text = _shortDate(map['bill_date']);
    if (draft.billDate.text == '-') draft.billDate.clear();
    draft.dispatchDate.text = _shortDate(map['dispatch_date']);
    if (draft.dispatchDate.text == '-') draft.dispatchDate.clear();
    draft.cases.text = _editNumber(map['cases']);
    draft.weight.text = _editNumber(map['weight_kg']);
    draft.baseFreight.text = _editNumber(
      map['freight_share'] ?? map['base_freight'],
    );
    return draft;
  }

  factory _InvoiceDraft.fromLedgerRow(Map<String, dynamic> row) {
    final draft = _InvoiceDraft();
    draft.invoice.text = (row['invoice_number'] ?? '').toString();
    draft.party.text = (row['party_name'] ?? '').toString();
    draft.eWay.text = (row['e_way_bill_number'] ?? '').toString();
    draft.deliveryReference.text = (row['delivery_reference'] ?? '').toString();
    draft.lr.text = (row['lr_gr_number'] ?? '').toString();
    draft.town.text = (row['town'] ?? '').toString();
    draft.billDate.text = _shortDate(row['bill_date']);
    if (draft.billDate.text == '-') draft.billDate.clear();
    draft.dispatchDate.text = _shortDate(row['dispatch_date']);
    if (draft.dispatchDate.text == '-') draft.dispatchDate.clear();
    draft.cases.text = _editNumber(row['cases']);
    draft.weight.text = _editNumber(row['weight_kg']);
    draft.baseFreight.text = _editNumber(row['freight']);
    return draft;
  }

  void dispose() {
    invoice.dispose();
    party.dispose();
    eWay.dispose();
    for (final controller in extraEways) {
      controller.dispose();
    }
    deliveryReference.dispose();
    lr.dispose();
    for (final controller in extraGrs) {
      controller.dispose();
    }
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
  String? invoiceId;
  bool addedAfterLock = false;
  final amount = TextEditingController();
  final remarks = TextEditingController();

  Map<String, dynamic> toInsert(String freightId) => {
    'freight_id': freightId,
    'kind': kind,
    'invoice_id': invoiceId,
    'added_after_lock': addedAfterLock,
    'amount': double.tryParse(amount.text.trim()) ?? 0,
    'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim(),
    'added_by': supabase.auth.currentUser?.id,
    'approved': true,
  };

  factory _ChargeDraft.fromMap(Map<String, dynamic> map) {
    final draft = _ChargeDraft(kind: (map['kind'] ?? 'other').toString());
    draft.invoiceId = map['invoice_id']?.toString();
    draft.addedAfterLock = map['added_after_lock'] == true;
    draft.amount.text = _editNumber(map['amount']);
    draft.remarks.text = (map['remarks'] ?? '').toString();
    return draft;
  }

  void dispose() {
    amount.dispose();
    remarks.dispose();
  }
}

class _ProductDraft {
  _ProductDraft();

  final name = TextEditingController();
  final quantity = TextEditingController();

  Map<String, dynamic> toInsert(String freightId) => {
    'freight_id': freightId,
    'product_name': name.text.trim(),
    'quantity': double.tryParse(quantity.text.trim()) ?? 0,
  };

  factory _ProductDraft.fromMap(Map<String, dynamic> map) {
    final draft = _ProductDraft();
    draft.name.text = (map['product_name'] ?? '').toString();
    draft.quantity.text = _editNumber(map['quantity']);
    return draft;
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _InvoiceDraftRow extends StatelessWidget {
  const _InvoiceDraftRow({
    required this.draft,
    required this.onChanged,
    this.onRemove,
  });

  final _InvoiceDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
            _field(draft.invoice, l.adminInvoiceShort),
            _field(draft.party, l.adminParty),
            _field(draft.eWay, l.adminEwayBill),
            for (final controller in draft.extraEways)
              _extraDocumentField(
                controller,
                l.adminEwayBill,
                l.opsRemoveDocument,
                () {
                  draft.extraEways.remove(controller);
                  controller.dispose();
                  onChanged();
                },
              ),
            TextButton.icon(
              onPressed: () {
                draft.extraEways.add(TextEditingController());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.opsAddAnotherEwayBill),
            ),
            _field(draft.deliveryReference, l.adminDelRef),
            _field(draft.lr, l.adminLrGr),
            for (final controller in draft.extraGrs)
              _extraDocumentField(
                controller,
                l.adminLrGr,
                l.opsRemoveDocument,
                () {
                  draft.extraGrs.remove(controller);
                  controller.dispose();
                  onChanged();
                },
              ),
            TextButton.icon(
              onPressed: () {
                draft.extraGrs.add(TextEditingController());
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.opsAddAnotherGrBilty),
            ),
            _field(draft.town, l.adminTownRequired),
            _field(draft.billDate, l.adminBillDate),
            _field(draft.dispatchDate, l.adminDispatchDate),
            _field(
              draft.cases,
              l.adminCases,
              number: true,
              onChanged: onChanged,
            ),
            _field(
              draft.weight,
              l.adminMetricMt,
              number: true,
              onChanged: onChanged,
            ),
            _field(draft.baseFreight, l.adminFreightShare, number: true),
            IconButton(
              tooltip: l.adminRemoveInvoice,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _extraDocumentField(
    TextEditingController controller,
    String label,
    String removeTooltip,
    VoidCallback onRemove,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _field(controller, label),
      IconButton(
        tooltip: removeTooltip,
        onPressed: onRemove,
        icon: const Icon(Icons.close, size: 18),
      ),
    ],
  );
}

class _PickedPodFile {
  const _PickedPodFile({
    required this.name,
    required this.bytes,
    this.extension,
  });

  final String name;
  final Uint8List bytes;
  final String? extension;
}

class _PodFilePicker extends StatelessWidget {
  const _PodFilePicker({
    required this.path,
    required this.pendingName,
    required this.onPick,
  });

  final String? path;
  final String? pendingName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label =
        pendingName ??
        (((path ?? '').trim().isEmpty)
            ? l.adminPodFile
            : l.adminPodFileUploaded);
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: onPick,
        icon: Icon(
          pendingName != null || (path ?? '').trim().isNotEmpty
              ? Icons.attach_file
              : Icons.upload_file_outlined,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _VehicleCapacityPicker extends StatelessWidget {
  const _VehicleCapacityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.adminVehicleCapacity,
          border: const OutlineInputBorder(),
        ),
        items:
            _vehicleCapacityCategories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
        onChanged: onChanged,
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
    final l = AppLocalizations.of(context)!;
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
                decoration: InputDecoration(
                  labelText: l.adminKind,
                  border: const OutlineInputBorder(),
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
            _field(draft.amount, l.adminAmount, number: true),
            _field(draft.remarks, l.adminChargeRemarks),
            IconButton(
              tooltip: l.adminRemoveCharge,
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
    final l = AppLocalizations.of(context)!;
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
            _field(draft.name, l.adminProduct),
            _field(draft.quantity, l.adminCases, number: true),
            IconButton(
              tooltip: l.adminRemoveProduct,
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
  VoidCallback? onChanged,
}) {
  return SizedBox(
    width: 220,
    child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      onChanged: (_) => onChanged?.call(),
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

String _saveErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('Duplicate freight blocked')) {
    final start = message.indexOf('Duplicate freight blocked');
    final clean = start >= 0 ? message.substring(start) : message;
    return clean.replaceAll(RegExp(r'["}\]]+$'), '');
  }
  return 'Save failed: $message';
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

String _editNumber(dynamic value) {
  final n = _num(value);
  if (n == null || n == 0) return '';
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toString();
}

String _money(dynamic value) {
  final n = _num(value) ?? 0;
  return '₹${n.toStringAsFixed(0)}';
}

String _monthStart(String? dateText) {
  final parsed = dateText == null ? null : DateTime.tryParse(dateText);
  final date = parsed ?? DateTime.now();
  return DateTime(date.year, date.month).toIso8601String().substring(0, 10);
}

String _csvCell(dynamic value) {
  final raw = (value ?? '').toString();
  final escaped = raw.replaceAll('"', '""');
  return '"$escaped"';
}

String _tableCsv(List<String> headers, List<List<dynamic>> rows) {
  final body = rows.map((row) => row.map(_csvCell).join(','));
  return [headers.map(_csvCell).join(','), ...body].join('\n');
}

/// Each table owns both axes so its visible scrollbars always have a position.
class LedgerTableScroll extends StatefulWidget {
  const LedgerTableScroll({super.key, required this.child});
  final Widget child;
  @override
  State<LedgerTableScroll> createState() => _LedgerTableScrollState();
}

class _LedgerTableScrollState extends State<LedgerTableScroll> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const ScrollBehavior().copyWith(scrollbars: false),
    child: Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _horizontal,
        primary: false,
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          controller: _vertical,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: _vertical,
            primary: false,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}
