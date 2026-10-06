import 'supabase_bootstrap.dart';

/// Receiving customers, append-only trip updates, and reviewed expense claims.
/// Office references are separate from the transporter report; no goods invoice
/// fields are exposed by these tables or RPCs.
class DeliveryWorkflowRepo {
  DeliveryWorkflowRepo._();
  static final instance = DeliveryWorkflowRepo._();

  Future<List<Map<String, dynamic>>> fetchReceivers(String freightId) async =>
      List<Map<String, dynamic>>.from(
        await supabase
            .from('freight_delivery_receivers')
            .select()
            .eq('freight_id', freightId)
            .order('stop_index', ascending: true)
            .order('created_at', ascending: true)
            .order('party_name', ascending: true),
      );
  Future<List<Map<String, dynamic>>> fetchJourney(String freightId) async {
    final rows = await supabase
        .from('freight_journey_updates')
        .select()
        .eq('freight_id', freightId)
        .order('submitted_at', ascending: false);
    return rows
        .map(
          (row) => <String, dynamic>{
            ...Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
            ...row,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchExpenses(String freightId) async =>
      List<Map<String, dynamic>>.from(
        await supabase
            .from('freight_expense_claims')
            .select()
            .eq('freight_id', freightId)
            .order('submitted_at', ascending: false),
      );
  Future<void> ensurePlan(String freightId) async {
    await supabase.rpc(
      'ensure_delivery_plan',
      params: {'p_freight_id': freightId},
    );
  }

  Future<void> savePlan(
    String freightId,
    List<Map<String, dynamic>> receivers,
  ) async {
    await supabase.rpc(
      'save_delivery_plan',
      params: {'p_freight_id': freightId, 'p_receivers': receivers},
    );
  }

  Future<void> saveReport(String receiverId, Map<String, dynamic> data) async {
    await supabase.rpc(
      'save_delivery_report',
      params: {'p_receiver_id': receiverId, 'p_data': data},
    );
  }

  Future<void> reviewPod(
    String receiverId,
    String decision, {
    String? note,
  }) async {
    await supabase.rpc(
      'review_delivery_pod',
      params: {
        'p_receiver_id': receiverId,
        'p_decision': decision,
        'p_note': note,
      },
    );
  }

  Future<void> addJourney(String freightId, Map<String, dynamic> data) async {
    await supabase.rpc(
      'add_journey_update',
      params: {'p_freight_id': freightId, 'p_data': data},
    );
  }

  Future<void> submitExpense(
    String freightId,
    Map<String, dynamic> data,
  ) async {
    await supabase.rpc(
      'submit_freight_expense',
      params: {'p_freight_id': freightId, 'p_data': data},
    );
  }

  Future<void> reviewExpense(
    String claimId,
    String decision, {
    String? note,
  }) async {
    await supabase.rpc(
      'review_freight_expense',
      params: {'p_claim_id': claimId, 'p_decision': decision, 'p_note': note},
    );
  }
}
