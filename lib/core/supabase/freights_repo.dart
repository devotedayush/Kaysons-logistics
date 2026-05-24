import 'supabase_bootstrap.dart';

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

  Stream<List<Map<String, dynamic>>> streamAcceptedDispatchFreights() {
    return streamAllFreights().map(
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
    final submittedAt = DateTime.now();
    final current =
        await supabase
            .from('freights')
            .select(
              'delivery_stages, status, dispatched_at, origin, destination_town, winner_profile_id',
            )
            .eq('id', freightId)
            .single();
    final existing = Map<String, dynamic>.from(
      current['delivery_stages'] as Map? ?? {},
    );
    existing[stage] = {
      ...data,
      'submitted_at': submittedAt.toIso8601String(),
    };
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

  Future<void> awardWinner({
    required String freightId,
    required String winnerProfileId,
  }) async {
    await supabase
        .from('freights')
        .update({'winner_profile_id': winnerProfileId, 'status': 'awarded'})
        .eq('id', freightId);

    // mark bids as won/lost
    await supabase
        .from('bids')
        .update({'state': 'lost'})
        .eq('freight_id', freightId);
    await supabase
        .from('bids')
        .update({'state': 'won'})
        .eq('freight_id', freightId)
        .eq('transporter_id', winnerProfileId);

    await _createFaultAlertForMissingVehicleDocs(
      freightId: freightId,
      winnerProfileId: winnerProfileId,
    );
  }

  Future<void> linkInvoiceAndLock({
    required String freightId,
    required String invoiceNumber,
    required String grNumber,
    required String eWayBillNumber,
    required double? toll,
    required double? club,
    required double? dalla,
    required double? other,
  }) async {
    final freight =
        await supabase
            .from('freights')
            .select('winner_profile_id, delivery_stages')
            .eq('id', freightId)
            .single();
    final invoice =
        await supabase
            .from('invoices')
            .insert({
              'freight_id': freightId,
              'invoice_number': invoiceNumber,
              'gr_number': grNumber,
              'e_way_bill_number': eWayBillNumber,
              'transporter_id': freight['winner_profile_id'],
              'validated': true,
            })
            .select('id')
            .single();
    final charges = [
      ('toll', toll),
      ('club', club),
      ('dalla', dalla),
      ('other', other),
    ];
    final inserts =
        charges
            .where((c) => (c.$2 ?? 0) > 0)
            .map(
              (c) => {
                'freight_id': freightId,
                'kind': c.$1,
                'amount': c.$2,
                'approved': false,
              },
            )
            .toList();
    if (inserts.isNotEmpty) {
      await supabase.from('freight_charges').insert(inserts);
    }
    await supabase
        .from('freights')
        .update({
          'status': 'locked',
          'locked_at': DateTime.now().toIso8601String(),
        })
        .eq('id', freightId);

    await _createInvoiceMismatchAlerts(
      freightId: freightId,
      invoiceId: invoice['id'] as String?,
      invoiceGrNumber: grNumber,
      invoiceEWayBillNumber: eWayBillNumber,
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
    required String? invoiceId,
    required String invoiceGrNumber,
    required String invoiceEWayBillNumber,
    required Map<String, dynamic> deliveryStages,
  }) async {
    final inTransit = Map<String, dynamic>.from(
      deliveryStages['in_transit'] as Map? ?? const {},
    );
    final delivered = Map<String, dynamic>.from(
      deliveryStages['delivered'] as Map? ?? const {},
    );

    final stageGr =
        (inTransit['gr_bilty_number'] ?? delivered['gr_number'] ?? '')
            .toString()
            .trim();
    final stageEWay =
        (inTransit['e_way_bill_number'] ?? delivered['e_way_bill_number'] ?? '')
            .toString()
            .trim();

    final alerts = <Map<String, dynamic>>[];
    if (stageGr.isEmpty) {
      alerts.add({
        'category': 'missing_verification',
        'severity': 'high',
        'title': 'GR/Bilty missing in transit trail',
        'message':
            'Invoice verification was submitted before the transporter shared a GR/Bilty number in transit updates.',
      });
    } else if (stageGr != invoiceGrNumber.trim()) {
      alerts.add({
        'category': 'mismatch',
        'severity': 'high',
        'title': 'GR/Bilty mismatch detected',
        'message':
            'Transit GR/Bilty "$stageGr" does not match invoice GR/Bilty "${invoiceGrNumber.trim()}".',
      });
    }

    if (stageEWay.isEmpty) {
      alerts.add({
        'category': 'missing_verification',
        'severity': 'high',
        'title': 'E-way bill missing in transit trail',
        'message':
            'Invoice verification was submitted before the transporter shared an e-way bill number in transit updates.',
      });
    } else if (stageEWay != invoiceEWayBillNumber.trim()) {
      alerts.add({
        'category': 'mismatch',
        'severity': 'high',
        'title': 'E-way bill mismatch detected',
        'message':
            'Transit e-way bill "$stageEWay" does not match invoice e-way bill "${invoiceEWayBillNumber.trim()}".',
      });
    }

    for (final alert in alerts) {
      await _createAlertSafe(
        freightId: freightId,
        invoiceId: invoiceId,
        category: alert['category'] as String,
        severity: alert['severity'] as String,
        title: alert['title'] as String,
        message: alert['message'] as String,
        metadata: {
          'invoice_gr_number': invoiceGrNumber.trim(),
          'invoice_e_way_bill_number': invoiceEWayBillNumber.trim(),
          'transit_gr_bilty_number': stageGr,
          'transit_e_way_bill_number': stageEWay,
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
