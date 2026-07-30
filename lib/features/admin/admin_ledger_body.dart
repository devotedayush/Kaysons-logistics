import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

enum _ReportExportFormat { csv, excel }

enum _LedgerPresentation { overview, rows }

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
  bool _delayedOnly = false;
  bool _latePodOnly = false;
  bool _showAdvancedFilters = false;
  _LedgerPresentation _presentation = _LedgerPresentation.overview;
  _OverviewSummary _overviewSummary = _OverviewSummary.transporter;
  int _ledgerPage = 0;
  int _ledgerPageSize = 75;
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
      if (!_containsAny(
        _placeSearch.text,
        [row['origin'], row['town'], row['party_name']],
      )) {
        return false;
      }
      if (!_containsAny(_invoiceSearch.text, [
        row['invoice_number'],
        row['invoice_numbers'],
      ])) {
        return false;
      }
      if (!_containsAny(_ewaySearch.text, [
        row['e_way_bill_number'],
        row['e_way_bill_numbers'],
      ])) {
        return false;
      }
      if (_delayedOnly && ((_num(row['delay_days']) ?? 0) <= 0)) return false;
      if (_latePodOnly &&
          !_flag(row['pod_late_flag']) &&
          !_flag(row['pod_missing_overdue_flag'])) {
        return false;
      }
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
    setState(() => _month = DateTime(picked.year, picked.month));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV upload failed: $e')));
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
          'vehicle_capacity_category': row.vehicleCapacityCategory,
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
      freight['vehicle_capacity_category'] = _suggestVehicleCapacityCategory(
        (freight['weight_kg'] as double?) ?? row.weight,
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

    await _insertChunks('freights', freightsById.values.toList());
    await _insertChunks('invoices', invoices);
    await _insertChunks('freight_charges', charges);
    return _CsvUploadResult(
      rowsImported: parsed.length,
      chargesImported: charges.length,
      missingTransporters: missingTransporters.toList()..sort(),
      sourceBranch: sourceBranch,
    );
  }

  Future<void> _insertChunks(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (var i = 0; i < rows.length; i += 100) {
      final end = (i + 100) > rows.length ? rows.length : i + 100;
      await supabase.from(table).insert(rows.sublist(i, end));
    }
  }

  void _exportReport(_ReportExportType type, _ReportExportFormat format) {
    final report = _buildExportReport(type);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final extension = format == _ReportExportFormat.csv ? 'csv' : 'xls';
    final fileName = '${report.slug}-$stamp.$extension';
    final content =
        format == _ReportExportFormat.csv
            ? _tableCsv(report.headers, report.rows)
            : _excelTable(report.title, report.headers, report.rows);
    try {
      if (format == _ReportExportFormat.csv) {
        downloadCsv(fileName, content);
      } else {
        downloadFile(
          fileName,
          content,
          'application/vnd.ms-excel;charset=utf-8',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
            final category =
                (row['vehicle_capacity_category'] ?? '').toString().trim();
            return category.isEmpty
                ? _suggestVehicleCapacityCategory(
                  _num(row['weight_kg'])?.toDouble() ?? 0,
                )
                : category;
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
      'Last Month Balance',
      'Payment',
      'Settlement Deduction',
      'Balance',
      'Ack Status',
      'POD Received Date',
      'POD File',
      'POD Remark',
      'POD Received By',
      'POD Risk',
      'Remarks',
    ];
    return _ExportReport(
      title: 'Invoice-wise freight report',
      slug: 'kaysons-invoice-wise-freight-report',
      headers: headers,
      rows: rows.map(_invoiceExportRow).toList(),
    );
  }

  _ExportReport _podPendingExportReport(List<Map<String, dynamic>> rows) {
    final pendingRows =
        rows.where((row) => _podAckLabel(row) != 'Received').toList();
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
      ],
      rows:
          pendingRows
              .map(
                (row) => [
                  row['company_name'],
                  row['invoice_number'],
                  row['e_way_bill_number'],
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
    row['e_way_bill_number'],
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
    row['last_month_balance'],
    row['payment_amount'],
    row['settlement_deduction'],
    row['balance'],
    _podAckLabel(row),
    row['pod_received_date'],
    (row['pod_file_path'] ?? '').toString().trim().isEmpty
        ? ''
        : row['pod_file_path'],
    row['pod_remark'],
    row['pod_received_by_name'],
    _podRiskLabel(row),
    row['remarks'],
  ];

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final transporterSummaries = _transporterSummaries(rows);
    final vehicleCapacitySummaries = _movementSummaries(
      rows,
      (row) {
        final category = (row['vehicle_capacity_category'] ?? '').toString().trim();
        return category.isEmpty
            ? _suggestVehicleCapacityCategory(_num(row['weight_kg'])?.toDouble() ?? 0)
            : category;
      },
    );
    final destinationSummaries = _movementSummaries(
      rows,
      (row) {
        final town = (row['town'] ?? '').toString().trim();
        return town.isEmpty ? 'Unknown' : town;
      },
    );
    final routeSummaries = _movementSummaries(
      rows,
      (row) {
        final origin = (row['origin'] ?? '').toString().trim();
        final town = (row['town'] ?? '').toString().trim();
        return '${origin.isEmpty ? 'Unknown' : origin} -> ${town.isEmpty ? 'Unknown' : town}';
      },
    );
    final companies = _options('company_name');
    final transporters = _options('transporter_name');
    final destinations = _options('town');
    final advancedFilterCount = [
      _customStart != null || _customEnd != null || _rangeDays != 90,
      _status != null,
      _podAck != null,
      _placeSearch.text.trim().isNotEmpty,
      _ewaySearch.text.trim().isNotEmpty,
      _delayedOnly,
      _latePodOnly,
    ].where((active) => active).length;
    final pageCount =
        rows.isEmpty ? 1 : ((rows.length - 1) ~/ _ledgerPageSize) + 1;
    final page = _ledgerPage.clamp(0, pageCount - 1).toInt();
    final pageStart = rows.isEmpty ? 0 : page * _ledgerPageSize;
    final pageEnd =
        rows.isEmpty
            ? 0
            : math.min(pageStart + _ledgerPageSize, rows.length);
    final visibleRows = rows.sublist(pageStart, pageEnd);
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
              PopupMenuButton<(_ReportExportType, _ReportExportFormat)>(
                tooltip: 'Export reports',
                enabled: rows.isNotEmpty,
                icon: const Icon(Icons.download_outlined),
                onSelected:
                    (choice) => _exportReport(choice.$1, choice.$2),
                itemBuilder:
                    (context) => [
                      _exportMenuItem(
                        _ReportExportType.transporterMonthly,
                        _ReportExportFormat.excel,
                        'Transporter monthly Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.transporterMonthly,
                        _ReportExportFormat.csv,
                        'Transporter monthly CSV',
                      ),
                      _exportMenuItem(
                        _ReportExportType.placeWise,
                        _ReportExportFormat.excel,
                        'Place-wise Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.placeWise,
                        _ReportExportFormat.csv,
                        'Place-wise CSV',
                      ),
                      _exportMenuItem(
                        _ReportExportType.invoiceWise,
                        _ReportExportFormat.excel,
                        'Invoice-wise Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.invoiceWise,
                        _ReportExportFormat.csv,
                        'Invoice-wise CSV',
                      ),
                      _exportMenuItem(
                        _ReportExportType.podPending,
                        _ReportExportFormat.excel,
                        'POD pending Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.podPending,
                        _ReportExportFormat.csv,
                        'POD pending CSV',
                      ),
                      _exportMenuItem(
                        _ReportExportType.vehicleTonnage,
                        _ReportExportFormat.excel,
                        'Vehicle tonnage Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.vehicleTonnage,
                        _ReportExportFormat.csv,
                        'Vehicle tonnage CSV',
                      ),
                      _exportMenuItem(
                        _ReportExportType.routeWise,
                        _ReportExportFormat.excel,
                        'Route-wise Excel',
                      ),
                      _exportMenuItem(
                        _ReportExportType.routeWise,
                        _ReportExportFormat.csv,
                        'Route-wise CSV',
                      ),
                    ],
              ),
              IconButton(
                tooltip: 'Upload CSV',
                onPressed: _uploading ? null : _uploadLedgerCsv,
                icon:
                    _uploading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upload_file_outlined),
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MonthFilter(
                month: _month,
                onPick: _pickMonth,
                onClear: () => setState(() => _month = null),
              ),
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
                label: 'Destination / Place',
                value: _destination,
                options: destinations,
                onChanged: (v) => setState(() => _destination = v),
              ),
              _SearchFilter(
                label: 'Invoice Number',
                hint: 'Search invoice',
                controller: _invoiceSearch,
                onChanged: () => setState(() {}),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => setState(
                      () => _showAdvancedFilters = !_showAdvancedFilters,
                    ),
                icon: Icon(
                  _showAdvancedFilters
                      ? Icons.expand_less
                      : Icons.tune_outlined,
                  size: 18,
                ),
                label: Text(
                  advancedFilterCount == 0
                      ? 'Filters'
                      : 'Filters ($advancedFilterCount)',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        ),
        if (_showAdvancedFilters)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FF),
              border: Border.all(color: const Color(0xFFCAC4D0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateWindowBar(
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterMenu(
                      label: 'Status',
                      value: _status,
                      options: const ['Open', 'Closed', 'Completed'],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    _FilterMenu(
                      label: 'POD / Acknowledgement',
                      value: _podAck,
                      options: const ['Received', 'Pending'],
                      onChanged: (v) => setState(() => _podAck = v),
                    ),
                    _SearchFilter(
                      label: 'Place search',
                      hint: 'Origin, destination, party',
                      controller: _placeSearch,
                      onChanged: () => setState(() {}),
                    ),
                    _SearchFilter(
                      label: 'E-way Bill Number',
                      hint: 'Search e-way bill',
                      controller: _ewaySearch,
                      onChanged: () => setState(() {}),
                    ),
                    FilterChip(
                      label: const Text('Delayed only'),
                      selected: _delayedOnly,
                      onSelected: (v) => setState(() => _delayedOnly = v),
                    ),
                    FilterChip(
                      label: const Text('Late POD'),
                      selected: _latePodOnly,
                      onSelected: (v) => setState(() => _latePodOnly = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LedgerStatChip(
                      label: 'Rows',
                      value: _number(rows.length),
                    ),
                    _LedgerStatChip(
                      label: 'Cases',
                      value: _number(
                        rows.fold<num>(
                          0,
                          (sum, row) => sum + (_num(row['cases']) ?? 0),
                        ),
                      ),
                    ),
                    _LedgerStatChip(
                      label: 'MT',
                      value: _number(
                        rows.fold<num>(
                          0,
                          (sum, row) => sum + (_num(row['weight_kg']) ?? 0),
                        ),
                      ),
                    ),
                    _LedgerStatChip(
                      label: 'Freight',
                      value: _money(
                        rows.fold<num>(
                          0,
                          (sum, row) => sum + (_num(row['total_freight']) ?? 0),
                        ),
                      ),
                    ),
                    _LedgerStatChip(
                      label: 'POD pending',
                      value:
                          rows
                              .where((row) => _podAckLabel(row) != 'Received')
                              .length
                              .toString(),
                    ),
                  ],
                ),
              ),
              SegmentedButton<_LedgerPresentation>(
                segments: const [
                  ButtonSegment(
                    value: _LedgerPresentation.overview,
                    icon: Icon(Icons.dashboard_outlined),
                    label: Text('Overview'),
                  ),
                  ButtonSegment(
                    value: _LedgerPresentation.rows,
                    icon: Icon(Icons.table_rows_outlined),
                    label: Text('Rows'),
                  ),
                ],
                selected: {_presentation},
                onSelectionChanged:
                    (selection) => setState(
                      () => _presentation = selection.first,
                    ),
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
                  : _presentation == _LedgerPresentation.overview
                  ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Summary report',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SegmentedButton<_OverviewSummary>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: _OverviewSummary.transporter,
                                  label: Text('Transporter'),
                                ),
                                ButtonSegment(
                                  value: _OverviewSummary.destination,
                                  label: Text('Place'),
                                ),
                                ButtonSegment(
                                  value: _OverviewSummary.route,
                                  label: Text('Route'),
                                ),
                                ButtonSegment(
                                  value: _OverviewSummary.vehicle,
                                  label: Text('Vehicle'),
                                ),
                              ],
                              selected: {_overviewSummary},
                              onSelectionChanged:
                                  (selection) => setState(
                                    () => _overviewSummary = selection.first,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _OverviewSummaryBody(
                          summary: _overviewSummary,
                          transporterSummaries: transporterSummaries,
                          vehicleCapacitySummaries: vehicleCapacitySummaries,
                          destinationSummaries: destinationSummaries,
                          routeSummaries: routeSummaries,
                        ),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Showing ${pageStart + 1}-$pageEnd of ${rows.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _onSurfaceVariant,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 112,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _ledgerPageSize,
                                  isExpanded: true,
                                  items:
                                      const [50, 75, 100, 150]
                                          .map(
                                            (size) => DropdownMenuItem(
                                              value: size,
                                              child: Text('$size rows'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) => setState(() {
                                        _ledgerPageSize =
                                            value ?? _ledgerPageSize;
                                        _ledgerPage = 0;
                                      }),
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'Previous page',
                              onPressed:
                                  page <= 0
                                      ? null
                                      : () => setState(() => _ledgerPage--),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Next page',
                              onPressed:
                                  page >= pageCount - 1
                                      ? null
                                      : () => setState(() => _ledgerPage++),
                              icon: const Icon(Icons.chevron_right),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Scroll table left',
                              onPressed: () => _scrollLedgerTable(-1),
                              icon: const Icon(Icons.keyboard_double_arrow_left),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Scroll table right',
                              onPressed: () => _scrollLedgerTable(1),
                              icon:
                                  const Icon(Icons.keyboard_double_arrow_right),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _ledgerHorizontalScroll,
                          thumbVisibility: true,
                          interactive: true,
                          scrollbarOrientation: ScrollbarOrientation.bottom,
                          child: SingleChildScrollView(
                            controller: _ledgerHorizontalScroll,
                            primary: false,
                            scrollDirection: Axis.horizontal,
                            child: Scrollbar(
                              controller: _ledgerVerticalScroll,
                              thumbVisibility: true,
                              interactive: true,
                              child: SingleChildScrollView(
                                controller: _ledgerVerticalScroll,
                                primary: false,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  24,
                                ),
                                child: DataTable(
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 56,
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF6EDFB),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Company')),
                                    DataColumn(label: Text('Edit')),
                                    DataColumn(label: Text('Bill')),
                                    DataColumn(label: Text('Dispatch')),
                                    DataColumn(label: Text('Delay')),
                                    DataColumn(label: Text('Invoice')),
                                    DataColumn(label: Text('Inv Count')),
                                    DataColumn(label: Text('E-way')),
                                    DataColumn(label: Text('E-way Count')),
                                    DataColumn(label: Text('DEL')),
                                    DataColumn(label: Text('Party')),
                                    DataColumn(label: Text('Party Count')),
                                    DataColumn(label: Text('Origin')),
                                    DataColumn(label: Text('Town')),
                                    DataColumn(label: Text('Cases')),
                                    DataColumn(label: Text('Ton')),
                                    DataColumn(label: Text('Vehicle')),
                                    DataColumn(label: Text('Capacity')),
                                    DataColumn(label: Text('Dispatch GR')),
                                    DataColumn(label: Text('Transporter')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Total')),
                                    DataColumn(label: Text('Balance')),
                                    DataColumn(label: Text('POD Status')),
                                    DataColumn(label: Text('POD Date')),
                                    DataColumn(label: Text('POD File')),
                                    DataColumn(label: Text('POD Remark')),
                                    DataColumn(label: Text('Received By')),
                                    DataColumn(label: Text('POD')),
                                  ],
                                  rows: visibleRows.map(_dataRow).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  void _scrollLedgerTable(int direction) {
    if (!_ledgerHorizontalScroll.hasClients) return;
    final position = _ledgerHorizontalScroll.position;
    final viewport = position.viewportDimension;
    final step = viewport < 650 ? viewport * 0.8 : 520.0;
    final target = (position.pixels + (step * direction)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _ledgerHorizontalScroll.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _clearFilters() {
    setState(() {
      _rangeDays = 90;
      _customStart = null;
      _customEnd = null;
      _company = null;
      _transporter = null;
      _destination = null;
      _month = null;
      _status = null;
      _podAck = null;
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
      final summary = summaries.putIfAbsent(key, () => _TransporterSummary(key));
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
          IconButton(
            tooltip: 'Edit ledger entry',
            onPressed: () => _openEntryForm(row),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
        DataCell(Text(_shortDate(row['bill_date']))),
        DataCell(Text(_shortDate(row['dispatch_date']))),
        DataCell(Text(_num(row['delay_days'])?.toStringAsFixed(0) ?? '-')),
        DataCell(Text(_text(row['invoice_number']))),
        DataCell(Text(_number(row['invoice_count']))),
        DataCell(Text(_text(row['e_way_bill_number']))),
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
        DataCell(Text(_shortDate(row['pod_received_date']))),
        DataCell(Text(_text(row['pod_file_path']).trim() == '-' ? '-' : 'Uploaded')),
        DataCell(Text(_text(row['pod_remark']))),
        DataCell(Text(_text(row['pod_received_by_name']))),
        DataCell(Text(_podRiskLabel(row))),
      ],
    );
  }
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
  return 'OK';
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
  if (ack == 'received' || row['ack_received_at'] != null) return 'Received';
  if (row['pod_received_date'] != null) return 'Received';
  if (row['pod_submitted_at'] != null) return 'Received';
  return 'Pending';
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
  final Set<String> vehicles = <String>{};
  double totalCases = 0;
  double totalMetricTons = 0;
  double totalFreight = 0;
  int podPending = 0;
  int podReceived = 0;

  void add(Map<String, dynamic> row) {
    final vehicle = (row['vehicle_number'] ?? '').toString().trim();
    if (vehicle.isNotEmpty) vehicles.add(vehicle);
    totalCases += (_num(row['cases']) ?? 0).toDouble();
    totalMetricTons += (_num(row['weight_kg']) ?? 0).toDouble();
    totalFreight += (_num(row['total_freight']) ?? 0).toDouble();
    if (_podAckLabel(row) == 'Received') {
      podReceived++;
    } else {
      podPending++;
    }
  }

  int get totalVehicles => vehicles.length;
  double get freightPerMetricTon =>
      totalMetricTons == 0 ? 0 : totalFreight / totalMetricTons;
  double get freightPerCase => totalCases == 0 ? 0 : totalFreight / totalCases;
}

class _TransporterSummaryTable extends StatelessWidget {
  const _TransporterSummaryTable({required this.summaries, this.framed = true});

  final List<_TransporterSummary> summaries;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();
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
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                'Transporter summary',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF6EDFB),
                    ),
                    columns: const [
                      DataColumn(label: Text('Transporter')),
                      DataColumn(label: Text('Vehicles'), numeric: true),
                      DataColumn(label: Text('Cases'), numeric: true),
                      DataColumn(label: Text('MT'), numeric: true),
                      DataColumn(label: Text('Freight'), numeric: true),
                      DataColumn(label: Text('Freight/MT'), numeric: true),
                      DataColumn(label: Text('Freight/Case'), numeric: true),
                      DataColumn(label: Text('POD Pending'), numeric: true),
                      DataColumn(label: Text('POD Received'), numeric: true),
                    ],
                    rows: summaries.map(_row).toList(),
                  ),
                ),
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
  final Set<String> vehicles = <String>{};
  final Map<String, Set<String>> transporterVehicles = <String, Set<String>>{};
  final Map<String, int> transporterRows = <String, int>{};
  double totalCases = 0;
  double totalMetricTons = 0;
  double totalFreight = 0;

  void add(Map<String, dynamic> row) {
    final vehicle = (row['vehicle_number'] ?? '').toString().trim();
    if (vehicle.isNotEmpty) vehicles.add(vehicle);
    final transporter = (row['transporter_name'] ?? '').toString().trim();
    final transporterKey = transporter.isEmpty ? 'Unassigned' : transporter;
    transporterRows[transporterKey] = (transporterRows[transporterKey] ?? 0) + 1;
    if (vehicle.isNotEmpty) {
      transporterVehicles
          .putIfAbsent(transporterKey, () => <String>{})
          .add(vehicle);
    }
    totalCases += (_num(row['cases']) ?? 0).toDouble();
    totalMetricTons += (_num(row['weight_kg']) ?? 0).toDouble();
    totalFreight += (_num(row['total_freight']) ?? 0).toDouble();
  }

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
    final visible = entries.take(3).map((entry) => '${entry.key} ${entry.value}');
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
    if (summaries.isEmpty) return const SizedBox.shrink();
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
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF6EDFB),
                    ),
                    columns: [
                      DataColumn(label: Text(firstColumn)),
                      const DataColumn(label: Text('Vehicles'), numeric: true),
                      const DataColumn(label: Text('Cases'), numeric: true),
                      const DataColumn(label: Text('MT'), numeric: true),
                      const DataColumn(label: Text('Freight'), numeric: true),
                      const DataColumn(
                        label: Text('Avg Freight/MT'),
                        numeric: true,
                      ),
                      if (showBreakup)
                        const DataColumn(label: Text('Transporter breakup')),
                    ],
                    rows: summaries.map(_row).toList(),
                  ),
                ),
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
    final title = switch (summary) {
      _OverviewSummary.transporter => 'Transporter-wise summary',
      _OverviewSummary.destination => 'Place-wise summary',
      _OverviewSummary.route => 'Route-wise summary',
      _OverviewSummary.vehicle => 'Vehicle tonnage summary',
    };
    final subtitle = switch (summary) {
      _OverviewSummary.transporter =>
        'Vehicles, freight efficiency, and POD status by transporter.',
      _OverviewSummary.destination =>
        'Destination movement with transporter breakup.',
      _OverviewSummary.route => 'From-to route freight comparison.',
      _OverviewSummary.vehicle => 'Vehicle capacity category usage.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCAC4D0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _tableForSummary()),
          ],
        ),
      ),
    );
  }

  Widget _tableForSummary() {
    return switch (summary) {
      _OverviewSummary.transporter => _TransporterSummaryTable(
        summaries: transporterSummaries,
        framed: false,
      ),
      _OverviewSummary.destination => _MovementSummaryTable(
        title: 'Destination summary',
        firstColumn: 'Destination',
        summaries: destinationSummaries,
        showBreakup: true,
        framed: false,
      ),
      _OverviewSummary.route => _MovementSummaryTable(
        title: 'Route summary',
        firstColumn: 'From -> To',
        summaries: routeSummaries,
        showBreakup: false,
        framed: false,
      ),
      _OverviewSummary.vehicle => _MovementSummaryTable(
        title: 'Vehicle tonnage summary',
        firstColumn: 'Category',
        summaries: vehicleCapacitySummaries,
        showBreakup: false,
        framed: false,
      ),
    };
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

PopupMenuItem<(_ReportExportType, _ReportExportFormat)> _exportMenuItem(
  _ReportExportType type,
  _ReportExportFormat format,
  String label,
) {
  return PopupMenuItem(
    value: (type, format),
    child: Row(
      children: [
        Icon(
          format == _ReportExportFormat.csv
              ? Icons.description_outlined
              : Icons.table_chart_outlined,
          size: 18,
        ),
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
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String?>(
        value: value,
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

class _MonthFilter extends StatelessWidget {
  const _MonthFilter({
    required this.month,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? month;
  final Future<void> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () => onPick(),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(month == null ? 'Month' : _formatMonth(month!)),
          ),
          if (month != null)
            IconButton(
              tooltip: 'Clear month',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
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
      title: const Text('Select month'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
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
                  onChanged:
                      (value) => setState(() => _year = value ?? _year),
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
                    backgroundColor:
                        selected ? const Color(0xFFE8DEF8) : null,
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
          child: const Text('Cancel'),
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

String _formatMonth(DateTime value) {
  return '${_monthName(value.month)} ${value.year}';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Company is required.')));
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
    return AlertDialog(
      title: const Text('Upload ledger CSV'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                labelText: 'Company / sheet name *',
                hintText: 'Bunge, Cargill, Ludhiana',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Upload tag',
                hintText: 'CSV Upload',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use an Excel-exported CSV. Direct .xlsx upload is not enabled in this first version.',
              style: TextStyle(color: _onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choose CSV'),
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
    return AlertDialog(
      title: const Text('CSV upload complete'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rows imported: ${result.rowsImported}'),
            Text('Charge rows imported: ${result.chargesImported}'),
            Text('Upload tag: ${result.sourceBranch}'),
            if (result.missingTransporters.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'These transporters were not found in approved profiles, so their names were saved in remarks:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(result.missingTransporters.take(12).join(', ')),
              if (result.missingTransporters.length > 12)
                Text('+${result.missingTransporters.length - 12} more'),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
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
  final String lrNumber;
  final String remarks;
  final String origin;
}

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
  for (final raw in rawRows.skip(headerIndex + 1)) {
    if (raw.every((cell) => _cleanCell(cell).isEmpty)) continue;
    final billDate = _parseUploadDate(cell(raw, const ['billdate']));
    final party = cell(raw, const ['partyname', 'customerparty', 'customer']);
    final town = cell(raw, const ['place', 'town', 'destination']);
    final invoice = cell(raw, const ['invoicenumber', 'invoiceno']);
    final weight = _parseUploadNumber(cell(raw, const [
      'weightmt',
      'netweightinmt',
      'metricton',
      'mt',
      'weight',
    ]));
    final rawCapacity = cell(raw, const [
      'vehiclecapacitycategory',
      'vehiclecategory',
      'capacitycategory',
      'tonnagecategory',
    ]);
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
    if (billDate == null || party.isEmpty || town.isEmpty) continue;
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
        cases: _parseUploadNumber(cell(raw, const ['cases', 'case'])).round(),
        weight: weight,
        freight: _parseUploadNumber(cell(raw, const [
          'freight',
          'freightamount',
        ])),
        extraFreight: _parseUploadNumber(cell(raw, const [
          'extrafreight',
          'extra',
        ])),
        labour: _parseUploadNumber(cell(raw, const ['labour', 'labor'])),
        detention: _parseUploadNumber(cell(raw, const ['detention'])),
        ackReceived: _isAckReceived(cell(raw, const [
          'podacknowledgement',
          'acknowledgementstatus',
          'acknwoledgementstatus',
          'podstatus',
          'ackstatus',
        ])),
        billDate: billDate,
        dispatchDate: _parseUploadDate(cell(raw, const ['dispatchdate'])),
        vehicleNumber: cell(raw, const ['vehiclenumber', 'vehicle']),
        vehicleType: cell(raw, const ['vehicletype']),
        vehicleCapacityCategory:
            _normalizeVehicleCapacityCategory(rawCapacity) ??
            _suggestVehicleCapacityCategory(weight),
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
  final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return 0;
  return double.tryParse(cleaned) ?? 0;
}

String? _parseUploadDate(String value) {
  final text = _cleanCell(value);
  if (text.isEmpty) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso.toIso8601String().substring(0, 10);
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
  return DateTime(year, month, day).toIso8601String().substring(0, 10);
}

bool _isAckReceived(String value) {
  final text = _cleanCell(value).toLowerCase();
  return text == 'received' || text == 'recd' || text == 'yes' || text == 'pod received';
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
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
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
          await supabase.from('profiles').select('role').eq('id', uid).maybeSingle();
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
      final invoices = await supabase
          .from('invoices')
          .select()
          .eq('freight_id', freightId)
          .order('created_at');
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
            (freight['gr_bilty_number'] ?? row['dispatch_gr_bilty_number'] ?? '')
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
        _lastMonthBalance.text = _editNumber(row['last_month_balance']);
        _payment.text = _editNumber(row['payment_amount']);
        _settlementDeduction.text = _editNumber(row['settlement_deduction']);
        _settlementRemarks.text = (row['settlement_remarks'] ?? '').toString();
        for (final invoice in _invoices) {
          invoice.dispose();
        }
        _invoices
          ..clear()
          ..addAll(
            (invoices as List).map(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    }
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
      final currentFreightId = _editing ? widget.row!['freight_id'] as String : null;
      final duplicateMatches = await _findDuplicateInvoiceMatches(
        invoiceRows,
        currentFreightId,
      );
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
        'status': 'locked',
      };
      final String freightId;
      if (_editing) {
        freightId = currentFreightId!;
        await supabase
            .from('freights')
            .update(freightPayload)
            .eq('id', freightId);
        await supabase.from('invoices').delete().eq('freight_id', freightId);
        await supabase
            .from('freight_charges')
            .delete()
            .eq('freight_id', freightId);
        await supabase
            .from('freight_product_lines')
            .delete()
            .eq('freight_id', freightId);
      } else {
        final freight =
            await supabase
                .from('freights')
                .insert({
                  ...freightPayload,
                  'created_by': supabase.auth.currentUser!.id,
                })
                .select('id')
                .single();
        freightId = freight['id'] as String;
      }
      if (duplicateMatches.isNotEmpty) {
        await _saveDuplicateOverrides(duplicateMatches, freightId);
      }
      final uploadedPodPath = await _uploadPodFileIfNeeded(freightId);
      if (uploadedPodPath != null) {
        await supabase
            .from('freights')
            .update({'pod_file_path': uploadedPodPath})
            .eq('id', freightId);
      }
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
      await _saveSettlement(
        company: company,
        transporterId: _transporterId,
        periodSource: firstBillDate ?? firstDispatchDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
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
        .map((row) => _DuplicateInvoiceMatch.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> _saveDuplicateOverrides(
    List<_DuplicateInvoiceMatch> matches,
    String freightId,
  ) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('You must be signed in to approve override.');
    final reason = _duplicateOverrideReason.text.trim();
    final remark = _duplicateOverrideRemark.text.trim();
    await supabase.from('duplicate_freight_overrides').insert(
      matches
          .map(
            (match) => {
              'invoice_number': match.invoiceNumber,
              'invoice_number_norm': match.invoiceNumberNorm,
              'existing_freight_id': match.existingFreightId,
              'new_freight_id': freightId,
              'approved_by': uid,
              'reason': reason,
              'remark': remark,
              'metadata': {
                'company_name': match.companyName,
                'transporter_name': match.transporterName,
                'bill_date': match.billDate,
                'dispatch_date': match.dispatchDate,
                'total_freight': match.totalFreight,
              },
            },
          )
          .toList(),
    );
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not read POD file')));
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
        _podReceivedDate.text = DateTime.now().toIso8601String().substring(0, 10);
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
            ? originalName.substring(0, originalName.length - extension.length - 1)
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
                  const Expanded(
                    child: Text(
                      'Ledger entry',
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
              child:
                  _loadingExisting
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
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
                              _field(_dispatchGrBilty, 'Dispatch GR/Bilty'),
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
                                  value: _transporterId,
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
                                  onChanged:
                                      (v) => setState(() => _transporterId = v),
                                ),
                              ),
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  value: _ack,
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
                                      (v) => setState(() {
                                        _ack = v ?? 'pending';
                                        if (_ack == 'received' &&
                                            _podReceivedDate.text.trim().isEmpty) {
                                          _podReceivedDate.text =
                                              DateTime.now()
                                                  .toIso8601String()
                                                  .substring(0, 10);
                                        }
                                      }),
                                ),
                              ),
                              _field(
                                _podReceivedDate,
                                'POD received yyyy-mm-dd',
                              ),
                              _field(_podRemark, 'POD remark'),
                              _PodFilePicker(
                                path: _podFilePath,
                                pendingName: _podPendingFile?.name,
                                onPick: _pickPodFile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            title: 'Invoice lines',
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
                                      : () => setState(
                                        () {
                                          _invoices.removeAt(i).dispose();
                                          if (!_vehicleCapacityEdited) {
                                            _vehicleCapacityCategory = null;
                                          }
                                        },
                                      ),
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
                          _SectionHeader(
                            title: 'Charges',
                            onAdd:
                                () => setState(
                                  () =>
                                      _charges.add(_ChargeDraft(kind: 'other')),
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
                          const _SectionHeader(
                            title: 'Settlement',
                            onAdd: null,
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _field(
                                _lastMonthBalance,
                                'Last month balance',
                                number: true,
                              ),
                              _field(_payment, 'Payment', number: true),
                              _field(
                                _settlementDeduction,
                                'Settlement deduction',
                                number: true,
                              ),
                              _field(_settlementRemarks, 'Settlement remarks'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionHeader(
                            title: 'Products',
                            onAdd:
                                () => setState(
                                  () => _products.add(_ProductDraft()),
                                ),
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
                                  () => setState(
                                    () => _products.removeAt(i).dispose(),
                                  ),
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

  Future<void> _saveSettlement({
    required String company,
    required String? transporterId,
    required String? periodSource,
  }) async {
    if (transporterId == null) return;
    final hasSettlement =
        _lastMonthBalance.text.trim().isNotEmpty ||
        _payment.text.trim().isNotEmpty ||
        _settlementDeduction.text.trim().isNotEmpty ||
        _settlementRemarks.text.trim().isNotEmpty;
    if (!hasSettlement) return;
    final periodMonth = _monthStart(periodSource);
    await supabase.from('transporter_ledger_settlements').upsert({
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
    }, onConflict: 'company_name,transporter_id,period_month');
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
            label: const Text('Add'),
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
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF8E1),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Duplicate freight lock',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final match in matches.take(4))
              Text(
                '${match.invoiceNumber} already exists in ${match.companyName.isEmpty ? 'finalized freight' : match.companyName} '
                '${match.billDate.isEmpty ? '' : 'on ${match.billDate} '}'
                '${match.transporterName.isEmpty ? '' : 'via ${match.transporterName}'}',
              ),
            if (matches.length > 4) Text('+${matches.length - 4} more'),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: approved,
              onChanged: isAdmin ? onApprovedChanged : null,
              title: const Text('Admin approval to override duplicate lock'),
              subtitle:
                  isAdmin
                      ? const Text('Reason and remark are mandatory.')
                      : const Text('Only an admin can approve duplicate freight.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (approved) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _field(reason, 'Override reason *'),
                  _field(remark, 'Override remark *'),
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

  final invoice = TextEditingController();
  final eWay = TextEditingController();
  final deliveryReference = TextEditingController();
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
    'delivery_reference':
        deliveryReference.text.trim().isEmpty
            ? null
            : deliveryReference.text.trim(),
    'gr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'lr_number': lr.text.trim().isEmpty ? null : lr.text.trim(),
    'town': town.text.trim(),
    'bill_date': _dateText(billDate.text),
    'dispatch_date': _dateText(dispatchDate.text),
    'cases': int.tryParse(cases.text.trim()),
    'weight_kg': double.tryParse(weight.text.trim()),
    'base_freight': double.tryParse(baseFreight.text.trim()),
    'freight_share': double.tryParse(baseFreight.text.trim()),
  };

  factory _InvoiceDraft.fromMap(Map<String, dynamic> map) {
    final draft = _InvoiceDraft();
    draft.invoice.text = (map['invoice_number'] ?? '').toString();
    draft.eWay.text = (map['e_way_bill_number'] ?? '').toString();
    draft.deliveryReference.text = (map['delivery_reference'] ?? '').toString();
    draft.lr.text = (map['lr_number'] ?? map['gr_number'] ?? '').toString();
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
    eWay.dispose();
    deliveryReference.dispose();
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

  factory _ChargeDraft.fromMap(Map<String, dynamic> map) {
    final draft = _ChargeDraft(kind: (map['kind'] ?? 'other').toString());
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
            _field(draft.deliveryReference, 'DEL ref'),
            _field(draft.lr, 'LR/GR'),
            _field(draft.town, 'Town *'),
            _field(draft.billDate, 'Bill date yyyy-mm-dd'),
            _field(draft.dispatchDate, 'Dispatch date yyyy-mm-dd'),
            _field(draft.cases, 'Cases', number: true, onChanged: onChanged),
            _field(
              draft.weight,
              'Metric Ton',
              number: true,
              onChanged: onChanged,
            ),
            _field(draft.baseFreight, 'Freight share', number: true),
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
    final label =
        pendingName ??
        (((path ?? '').trim().isEmpty) ? 'POD file' : 'POD file uploaded');
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: onPick,
        icon: Icon(
          pendingName != null || (path ?? '').trim().isNotEmpty
              ? Icons.attach_file
              : Icons.upload_file_outlined,
        ),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
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
        value: value,
        decoration: const InputDecoration(
          labelText: 'Vehicle capacity',
          border: OutlineInputBorder(),
        ),
        items:
            _vehicleCapacityCategories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
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
                value: draft.kind,
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
            _field(draft.quantity, 'Cases', number: true),
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

String _excelTable(
  String title,
  List<String> headers,
  List<List<dynamic>> rows,
) {
  final headerCells = headers.map((header) => '<th>${_htmlCell(header)}</th>');
  final bodyRows = rows.map((row) {
    final cells = row.map((value) => '<td>${_htmlCell(value)}</td>').join();
    return '<tr>$cells</tr>';
  });
  return '''
<html>
<head>
  <meta charset="utf-8">
  <style>
    table { border-collapse: collapse; font-family: Arial, sans-serif; }
    th { background: #f6edfb; font-weight: bold; }
    th, td { border: 1px solid #c8c8c8; padding: 6px 8px; }
  </style>
</head>
<body>
  <h3>${_htmlCell(title)}</h3>
  <table>
    <thead><tr>${headerCells.join()}</tr></thead>
    <tbody>${bodyRows.join()}</tbody>
  </table>
</body>
</html>
''';
}

String _htmlCell(dynamic value) {
  return (value ?? '')
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
