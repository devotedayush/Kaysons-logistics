import 'supabase_bootstrap.dart';
import '../utils/workflow_formatters.dart';

/// Keep previously recorded office references while updating delivery details.
/// Invoice fields are managed by the office and are not transporter inputs.
Map<String, dynamic> mergeTransporterDeliveryStage(
  Map<String, dynamic> saved,
  Map<String, dynamic> update,
  DateTime submittedAt,
) {
  final deliveryUpdate = Map<String, dynamic>.from(update)
    ..remove('invoice_number')
    ..remove('invoice_numbers')
    ..remove('invoice_photo_path');
  return {
    ...saved,
    ...deliveryUpdate,
    'submitted_at': submittedAt.toUtc().toIso8601String(),
  };
}

class FreightsRepo {
  FreightsRepo._();
  static final instance = FreightsRepo._();

  Stream<List<Map<String, dynamic>>> streamOpenFreights() {
    return supabase
        .from('freights')
        .stream(primaryKey: ['id'])
        .eq('status', 'bidding')
        .order('created_at', ascending: false)
        .map(_onlyOpenBids);
  }

  Stream<List<Map<String, dynamic>>> streamAllFreights() {
    return supabase
        .from('freights')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamOperationalFreights() {
    return supabase
        .from('freights')
        .stream(primaryKey: ['id'])
        .eq('record_origin', 'live')
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamAcceptedDispatchFreights() {
    return streamOperationalFreights().map(
      (rows) =>
          rows
              .where(
                (f) => const {
                  'awarded',
                  'dispatched',
                  'locked',
                  'completed',
                }.contains((f['status'] ?? '').toString()),
              )
              .toList(),
    );
  }

  Future<Map<String, dynamic>?> fetchFreight(String id) async {
    final r =
        await supabase.from('freights').select().eq('id', id).maybeSingle();
    return r;
  }

  Future<Map<String, dynamic>> fetchInvoiceState(String freightId) async {
    final freight =
        await supabase
            .from('freights')
            .select('status')
            .eq('id', freightId)
            .single();
    final invoices = await supabase
        .from('invoices')
        .select()
        .eq('freight_id', freightId)
        .order('created_at');
    final invoiceIds =
        invoices.map((invoice) => invoice['id'].toString()).toList();
    final documentRows =
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
          'gr_bilty_numbers': [
            for (final document in documentRows)
              if (document['invoice_id'] == invoice['id'] &&
                  document['document_kind'] == 'gr_bilty')
                document['document_number'],
          ],
          'e_way_bill_numbers': [
            for (final document in documentRows)
              if (document['invoice_id'] == invoice['id'] &&
                  document['document_kind'] == 'e_way_bill')
                document['document_number'],
          ],
        },
    ];
    final charges = await supabase
        .from('freight_charges')
        .select()
        .eq('freight_id', freightId)
        .order('created_at');
    return {
      'status': freight['status'],
      'invoices': invoicesWithDocuments,
      'charges': charges,
    };
  }

  Stream<Map<String, dynamic>?> streamFreight(String id) {
    return supabase
        .from('freights')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<void> saveDeliveryStage({
    required String freightId,
    required String stage,
    required Map<String, dynamic> data,
  }) async {
    if (stage == 'delivered_stop') {
      final stopIndex = data['stop_index'];
      if (stopIndex is! int) {
        throw const FormatException('A delivery stop is required');
      }
      final result = await supabase.rpc(
        'save_delivered_stop',
        params: {
          'p_freight_id': freightId,
          'p_stop_index': stopIndex,
          'p_data': data,
        },
      );
      if (result is Map && result['newly_completed'] == true) {
        final freight =
            await supabase
                .from('freights')
                .select(
                  'dispatched_at, origin, destination_town, winner_profile_id',
                )
                .eq('id', freightId)
                .single();
        await _createLatePodAlertIfNeeded(
          freightId: freightId,
          freight: freight,
          submittedAt: DateTime.now(),
          podPhotoPath:
              result['all_pods_received'] == true
                  ? (data['pod_photo_path'] ?? '').toString()
                  : null,
        );
      }
      return;
    }
    final submittedAt = DateTime.now();
    final current =
        await supabase
            .from('freights')
            .select(
              'delivery_stages, status, dispatched_at, origin, destination_town, winner_profile_id, stop_details, stops',
            )
            .eq('id', freightId)
            .single();
    if (stage == 'delivered' && _hasMultipleDeliveryStops(current)) {
      throw StateError('Record each delivery stop separately');
    }
    final existing = Map<String, dynamic>.from(
      current['delivery_stages'] as Map? ?? {},
    );
    existing[stage] = mergeTransporterDeliveryStage(
      existing[stage] is Map ? Map<String, dynamic>.from(existing[stage]) : {},
      data,
      submittedAt,
    );
    if (stage == 'dispatched') {
      existing.remove('vehicle_confirmation');
    }
    if (stage == 'in_transit' &&
        (data['last_location'] ?? '').toString().trim().isNotEmpty) {
      existing[stage]['location_updated_at'] = DateTime.now().toIso8601String();
    }
    final update = <String, dynamic>{'delivery_stages': existing};

    // Mirror key fields to top-level columns + flip freight status where appropriate.
    if (stage == 'dispatched') {
      update['vehicle_number'] = data['lorry_number'];
      update['driver_name'] = data['driver_name'];
      update['driver_phone'] = data['driver_phone'];
      update['dispatched_at'] = submittedAt.toIso8601String();
      if (current['status'] == 'awarded') update['status'] = 'dispatched';
    }
    if (stage == 'delivered') {
      update['status'] = 'completed';
      final podPath = (data['pod_photo_path'] ?? '').toString().trim();
      if (podPath.isNotEmpty) {
        update['ack_status'] = 'received';
        update['ack_received_at'] = submittedAt.toIso8601String();
        update['pod_received_date'] = submittedAt.toIso8601String().substring(
          0,
          10,
        );
        update['pod_file_path'] = podPath;
        update['pod_received_by'] = supabase.auth.currentUser?.id;
      }
    }
    await supabase.from('freights').update(update).eq('id', freightId);
    if (stage == 'delivered') {
      await _createLatePodAlertIfNeeded(
        freightId: freightId,
        freight: current,
        submittedAt: submittedAt,
        podPhotoPath: data['pod_photo_path']?.toString(),
      );
    }
  }

  Future<void> saveDeliveryStageCheck({
    required String freightId,
    required String stage,
    required Map<String, dynamic> data,
  }) async {
    final submittedAt = DateTime.now();
    final current =
        await supabase
            .from('freights')
            .select(
              'delivery_stages, dispatched_at, origin, destination_town, winner_profile_id, stop_details, stops',
            )
            .eq('id', freightId)
            .single();
    if (stage == 'delivered' && _hasMultipleDeliveryStops(current)) {
      throw StateError('Record each delivery stop separately');
    }
    final existing = Map<String, dynamic>.from(
      current['delivery_stages'] as Map? ?? {},
    );
    existing[stage] = {...data, 'submitted_at': submittedAt.toIso8601String()};
    if (stage == 'dispatched') {
      existing.remove('vehicle_confirmation');
    }
    if (stage == 'in_transit' &&
        (data['last_location'] ?? '').toString().trim().isNotEmpty) {
      existing[stage]['location_updated_at'] = submittedAt.toIso8601String();
    }
    final update = <String, dynamic>{'delivery_stages': existing};
    if (stage == 'delivered') {
      final podPath = (data['pod_photo_path'] ?? '').toString().trim();
      if (podPath.isNotEmpty) {
        update['ack_status'] = 'received';
        update['ack_received_at'] = submittedAt.toIso8601String();
        update['pod_received_date'] = submittedAt.toIso8601String().substring(
          0,
          10,
        );
        update['pod_file_path'] = podPath;
        update['pod_received_by'] = supabase.auth.currentUser?.id;
      }
    }
    await supabase.from('freights').update(update).eq('id', freightId);
    if (stage == 'delivered') {
      await _createLatePodAlertIfNeeded(
        freightId: freightId,
        freight: current,
        submittedAt: submittedAt,
        podPhotoPath: data['pod_photo_path']?.toString(),
      );
    }
  }

  Future<void> saveTransitLocation({
    required String freightId,
    required String location,
  }) async {
    final current =
        await supabase
            .from('freights')
            .select('delivery_stages')
            .eq('id', freightId)
            .single();
    final existing = Map<String, dynamic>.from(
      current['delivery_stages'] as Map? ?? {},
    );
    final inTransit = Map<String, dynamic>.from(
      existing['in_transit'] as Map? ?? {},
    );
    inTransit['last_location'] = location;
    inTransit['location_updated_at'] = DateTime.now().toIso8601String();
    existing['in_transit'] = inTransit;
    await supabase
        .from('freights')
        .update({'delivery_stages': existing})
        .eq('id', freightId);
  }

  Future<void> confirmVehicleArrival({
    required String freightId,
    String? note,
  }) async {
    await _saveVehicleVerification(
      freightId: freightId,
      status: 'confirmed',
      note: note,
    );
  }

  Future<void> raiseVehicleIssue({
    required String freightId,
    required String issue,
  }) async {
    await _saveVehicleVerification(
      freightId: freightId,
      status: 'issue',
      note: issue,
    );
    await _createAlertSafe(
      freightId: freightId,
      category: 'vehicle_verification',
      severity: 'high',
      title: 'Vehicle details need confirmation',
      message: issue,
      metadata: {'verification_status': 'issue'},
    );
  }

  Future<void> _saveVehicleVerification({
    required String freightId,
    required String status,
    String? note,
  }) async {
    final current =
        await supabase
            .from('freights')
            .select('delivery_stages')
            .eq('id', freightId)
            .single();
    final existing = Map<String, dynamic>.from(
      current['delivery_stages'] as Map? ?? {},
    );
    existing['vehicle_confirmation'] = {
      'status': status,
      'note': (note ?? '').trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await supabase
        .from('freights')
        .update({'delivery_stages': existing})
        .eq('id', freightId);
  }

  Stream<List<Map<String, dynamic>>> streamBidsFor(String freightId) {
    return supabase
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('freight_id', freightId)
        .order('amount', ascending: true);
  }

  Future<void> upsertBid({
    required String freightId,
    required String transporterId,
    required double amount,
  }) async {
    await supabase.from('bids').upsert({
      'freight_id': freightId,
      'transporter_id': transporterId,
      'amount': amount,
      'state': 'active',
    }, onConflict: 'freight_id,transporter_id');
  }

  Future<Map<String, dynamic>?> getMyBid(
    String freightId,
    String transporterId,
  ) async {
    return await supabase
        .from('bids')
        .select()
        .eq('freight_id', freightId)
        .eq('transporter_id', transporterId)
        .maybeSingle();
  }

  /// Returns every freight for which this transporter has a bid, including
  /// awarded, lost, expired, locked, and completed history.  The open-bid
  /// stream intentionally stays small for the bidding surface; this query is
  /// used by the history section so a transporter can revisit a closed bid.
  Future<List<Map<String, dynamic>>> fetchMyBidHistory(
    String transporterId,
  ) async {
    final bidRows = await supabase
        .from('bids')
        .select('freight_id, amount, state, created_at, updated_at')
        .eq('transporter_id', transporterId)
        .order('updated_at', ascending: false);
    final bids = (bidRows as List).cast<Map<String, dynamic>>();
    final ids =
        bids
            .map((row) => row['freight_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    if (ids.isEmpty) return const [];
    final freightRows = await supabase
        .from('freights')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    final byFreight = <String, Map<String, dynamic>>{
      for (final row in (freightRows as List).cast<Map<String, dynamic>>())
        row['id'].toString(): row,
    };
    final result = <Map<String, dynamic>>[];
    for (final bid in bids) {
      final id = bid['freight_id']?.toString();
      final freight = id == null ? null : byFreight[id];
      if (freight == null) continue;
      result.add({
        ...freight,
        'my_bid_amount': bid['amount'],
        'my_bid_state': bid['state'],
      });
    }
    return result;
  }

  Future<void> awardWinner({
    required String freightId,
    required String winnerProfileId,
  }) async {
    // Awarding changes the freight winner and every bid state together.  Keep
    // this behind the narrow RPC so a failed award cannot leave a freight
    // looking awarded while its bids are still active (or vice versa).
    await supabase.rpc(
      'award_freight',
      params: {'p_freight_id': freightId, 'p_transporter_id': winnerProfileId},
    );

    await _createFaultAlertForMissingVehicleDocs(
      freightId: freightId,
      winnerProfileId: winnerProfileId,
    );
  }

  Future<void> linkInvoiceAndLock({
    required String freightId,
    required List<Map<String, dynamic>> invoices,
    required List<Map<String, dynamic>> charges,
  }) async {
    final freight =
        await supabase
            .from('freights')
            .select('delivery_stages')
            .eq('id', freightId)
            .single();
    if (invoices.isEmpty) {
      throw ArgumentError.value(
        invoices,
        'invoices',
        'At least one invoice is required',
      );
    }
    // The RPC owns freight/transporter linkage and invoice validation. Keep
    // the client payload to the documented invoice JSON contract so server
    // changes cannot accidentally persist transport-only fields from here.
    final normalizedInvoices = [
      for (final invoice in invoices) {...invoice},
    ];
    final normalizedCharges = <Map<String, dynamic>>[];
    for (final charge in charges) {
      final rawAmount = charge['amount'];
      final amount =
          rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse(rawAmount?.toString() ?? '');
      if (amount == null || amount <= 0) continue;
      final normalizedCharge = <String, dynamic>{
        'kind': canonicalChargeKind((charge['kind'] ?? 'other').toString()),
        'amount': amount,
        'remarks': charge['remarks'],
      };
      if (charge['invoice_index'] != null) {
        normalizedCharge['invoice_index'] = charge['invoice_index'];
      }
      normalizedCharges.add(normalizedCharge);
    }
    await supabase.rpc(
      'lock_freight_invoices',
      params: {
        'p_freight_id': freightId,
        'p_invoices': normalizedInvoices,
        'p_charges': normalizedCharges,
      },
    );

    await _createInvoiceMismatchAlerts(
      freightId: freightId,
      invoices: normalizedInvoices,
      deliveryStages: Map<String, dynamic>.from(
        freight['delivery_stages'] as Map? ?? const {},
      ),
    );
  }

  Future<void> _createFaultAlertForMissingVehicleDocs({
    required String freightId,
    required String winnerProfileId,
  }) async {
    try {
      final profile =
          await supabase
              .from('profiles')
              .select(
                'full_name, business_name, email, rc_number, lorry_insurance_number',
              )
              .eq('id', winnerProfileId)
              .maybeSingle();
      if (profile == null) return;
      final missing = <String>[];
      if ((profile['rc_number'] ?? '').toString().trim().isEmpty) {
        missing.add('RC number');
      }
      if ((profile['lorry_insurance_number'] ?? '').toString().trim().isEmpty) {
        missing.add('lorry insurance');
      }
      if (missing.isEmpty) return;
      final label =
          (profile['business_name'] ??
                  profile['full_name'] ??
                  profile['email'] ??
                  'Selected transporter')
              .toString();
      await _createAlertSafe(
        freightId: freightId,
        category: 'faulty_registration',
        severity: 'high',
        title: 'Transporter registration is incomplete',
        message:
            '$label is missing ${missing.join(' and ')} before dispatch verification.',
        metadata: {
          'winner_profile_id': winnerProfileId,
          'missing_fields': missing,
        },
      );
    } catch (_) {
      // Alert creation must not block the award flow.
    }
  }

  Future<void> _createInvoiceMismatchAlerts({
    required String freightId,
    required List<Map<String, dynamic>> invoices,
    required Map<String, dynamic> deliveryStages,
  }) async {
    final inTransit = Map<String, dynamic>.from(
      deliveryStages['in_transit'] as Map? ?? const {},
    );
    final delivered = Map<String, dynamic>.from(
      deliveryStages['delivered'] as Map? ?? const {},
    );

    final stops = deliveryStages['delivered_stops'] as List? ?? const [];
    final expectedGr = <String>{};
    final expectedEway = <String>{};
    for (final invoice in invoices) {
      expectedGr.addAll(
        _documentValues(invoice, 'gr_bilty_numbers', 'gr_number'),
      );
      expectedEway.addAll(
        _documentValues(invoice, 'e_way_bill_numbers', 'e_way_bill_number'),
      );
    }
    final observedGr = <String>{
      ..._documentValues(inTransit, 'gr_numbers', 'gr_bilty_number'),
      ..._documentValues(delivered, 'gr_numbers', 'gr_number'),
    };
    final observedEway = <String>{
      ..._documentValues(inTransit, 'e_way_bill_numbers', 'e_way_bill_number'),
      ..._documentValues(delivered, 'e_way_bill_numbers', 'e_way_bill_number'),
    };
    for (final stop in stops) {
      if (stop is! Map) continue;
      observedGr.addAll(_documentValues(stop, 'gr_numbers', 'gr_number'));
      observedEway.addAll(
        _documentValues(stop, 'e_way_bill_numbers', 'e_way_bill_number'),
      );
    }
    for (final (kind, expected, observed) in [
      ('GR/Bilty', expectedGr, observedGr),
      ('E-way bill', expectedEway, observedEway),
    ]) {
      final absent = expected.difference(observed);
      if (absent.isEmpty) continue;
      await _createAlertSafe(
        freightId: freightId,
        category: observed.isEmpty ? 'missing_verification' : 'mismatch',
        severity: 'high',
        title: '$kind references need verification',
        message:
            'Office $kind numbers absent from the transporter trail: ${absent.join(', ')}.',
        metadata: {
          'document_kind': kind,
          'office_numbers': expected.toList(),
          'transporter_numbers': observed.toList(),
          'unmatched_numbers': absent.toList(),
        },
      );
    }
  }

  Future<void> _createLatePodAlertIfNeeded({
    required String freightId,
    required Map<String, dynamic> freight,
    required DateTime submittedAt,
    required String? podPhotoPath,
  }) async {
    final dispatchedAt = DateTime.tryParse(
      (freight['dispatched_at'] ?? '').toString(),
    );
    if (dispatchedAt == null) return;
    final delayDays = _calendarDayDifference(dispatchedAt, submittedAt);
    if (delayDays <= 3) return;

    String transporterName = 'Selected transporter';
    final winnerId = freight['winner_profile_id'] as String?;
    if (winnerId != null && winnerId.isNotEmpty) {
      try {
        final profile =
            await supabase
                .from('profiles')
                .select('business_name, full_name, email')
                .eq('id', winnerId)
                .maybeSingle();
        transporterName =
            (profile?['business_name'] ??
                    profile?['full_name'] ??
                    profile?['email'] ??
                    transporterName)
                .toString();
      } catch (_) {}
    }

    final route =
        '${freight['origin'] ?? 'Unknown'} → ${freight['destination_town'] ?? 'Unknown'}';
    await _createAlertSafe(
      freightId: freightId,
      category: 'late_pod',
      severity: delayDays > 5 ? 'high' : 'medium',
      title: 'Late POD / possible freight clubbing review',
      message:
          '$transporterName submitted POD for $route $delayDays day(s) after dispatch. Review with the receiver and transporter before treating this as normal delivery delay.',
      metadata: {
        'transporter_id': winnerId,
        'transporter_name': transporterName,
        'route': route,
        'dispatch_at': dispatchedAt.toIso8601String(),
        'pod_submitted_at': submittedAt.toIso8601String(),
        'pod_delay_days': delayDays,
        'pod_photo_path': podPhotoPath,
        'sla_days': 3,
      },
    );
  }

  Future<void> _createAlertSafe({
    required String freightId,
    String? invoiceId,
    required String category,
    required String severity,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await supabase.from('admin_alerts').insert({
        'freight_id': freightId,
        'invoice_id': invoiceId,
        'category': category,
        'severity': severity,
        'title': title,
        'message': message,
        'metadata': metadata ?? const {},
        'status': 'open',
      });
    } catch (_) {
      // Some environments may not have the migration yet.
    }
  }
}

int _calendarDayDifference(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

bool _hasMultipleDeliveryStops(Map<String, dynamic> freight) {
  final details = freight['stop_details'];
  if (details is List && details.length > 1) return true;
  final stops = freight['stops'];
  return stops is List && stops.isNotEmpty;
}

Set<String> _documentValues(Map document, String listKey, String scalarKey) {
  final list = document[listKey];
  if (list is List && list.isNotEmpty) {
    return list
        .map((value) => value.toString().trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }
  final scalar = (document[scalarKey] ?? '').toString().trim().toUpperCase();
  return scalar.isEmpty ? <String>{} : <String>{scalar};
}

List<Map<String, dynamic>> _onlyOpenBids(List<Map<String, dynamic>> rows) {
  final now = DateTime.now();
  return rows.where((row) {
    final closes = DateTime.tryParse(row['bid_closes_at']?.toString() ?? '');
    return closes != null && closes.isAfter(now);
  }).toList();
}

Map<String, dynamic> freightView(Map<String, dynamic> row) {
  final opens = DateTime.tryParse(row['bid_opens_at']?.toString() ?? '');
  final closes = DateTime.tryParse(row['bid_closes_at']?.toString() ?? '');
  final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
  final now = DateTime.now();
  final minsLeft = closes == null ? 0 : closes.difference(now).inMinutes;
  return {
    'id': row['id'],
    'route': '${row['origin']} → ${row['destination_town']}',
    'origin': row['origin'],
    'destination': row['destination_town'],
    'cases': row['cases'] ?? 0,
    'weight_kg': (row['weight_kg'] as num?)?.toDouble() ?? 0,
    'internal_calling_bid': (row['internal_calling_bid'] as num?)?.toDouble(),
    'status': row['status'],
    'minsLeft': minsLeft > 0 ? minsLeft : 0,
    'created': created,
    'opens': opens,
    'closes': closes,
  };
}
