import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'supabase_bootstrap.dart';

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
  });

  final String id;
  final String status;
  final DateTime requestedAt;

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id'].toString(),
      status: json['status'].toString(),
      requestedAt: DateTime.parse(json['requested_at'].toString()).toLocal(),
    );
  }
}

class AccountDeletionService {
  AccountDeletionService._();

  static final instance = AccountDeletionService._();

  static const _activeStatuses = ['pending', 'verifying', 'approved'];

  Future<AccountDeletionRequest?> activeRequest() async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) return null;
    final row =
        await supabase
            .from('account_deletion_requests')
            .select('id, status, requested_at')
            .eq('user_id', uid)
            .inFilter('status', _activeStatuses)
            .order('requested_at', ascending: false)
            .limit(1)
            .maybeSingle();
    return row == null ? null : AccountDeletionRequest.fromJson(row);
  }

  Future<AccountDeletionRequest> submit({String? reason}) async {
    final user = AuthService.instance.user;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException(
        'Your signed-in account does not have a verified email address.',
      );
    }

    try {
      final row =
          await supabase
              .from('account_deletion_requests')
              .insert({
                'user_id': user.id,
                'email': email,
                'source': 'in_app',
                'status': 'pending',
                'reason':
                    reason == null || reason.trim().isEmpty
                        ? null
                        : reason.trim(),
              })
              .select('id, status, requested_at')
              .single();
      return AccountDeletionRequest.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await activeRequest();
        if (existing != null) return existing;
      }
      rethrow;
    }
  }

  Future<void> cancel(AccountDeletionRequest request) async {
    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      throw const AuthException('Sign in again to cancel this request.');
    }
    await supabase
        .from('account_deletion_requests')
        .update({'status': 'cancelled'})
        .eq('id', request.id)
        .eq('user_id', uid);
  }
}
