import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

enum AppRole {
  transporter,
  logisticsManager,
  dispatchManager,
  accountant,
  admin,
}

AppRole _parseRole(String? v) {
  switch (v) {
    case 'admin':
      return AppRole.admin;
    case 'logistics_manager':
      return AppRole.logisticsManager;
    case 'dispatch_manager':
      return AppRole.dispatchManager;
    case 'accountant':
      return AppRole.accountant;
    default:
      return AppRole.transporter;
  }
}

String roleToDb(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return 'admin';
    case AppRole.logisticsManager:
      return 'logistics_manager';
    case AppRole.dispatchManager:
      return 'dispatch_manager';
    case AppRole.accountant:
      return 'accountant';
    case AppRole.transporter:
      return 'transporter';
  }
}

String routeForRole(AppRole role) {
  switch (role) {
    case AppRole.admin:
      return '/admin';
    case AppRole.logisticsManager:
      return '/lm/home';
    case AppRole.dispatchManager:
      return '/dm/home';
    case AppRole.accountant:
      return '/acct/ledger';
    case AppRole.transporter:
      return '/home';
  }
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  GoTrueClient get _auth => supabase.auth;

  Session? get session => _auth.currentSession;
  User? get user => _auth.currentUser;

  Stream<AuthState> get onAuthState => _auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPhoneOtp(String phone) {
    return _auth.signInWithOtp(phone: phone, shouldCreateUser: false);
  }

  Future<void> sendEmailOtp(String email) {
    return _auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppRole> fetchRole() async {
    final uid = user?.id;
    if (uid == null) return AppRole.transporter;
    final row =
        await supabase
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .maybeSingle();
    return _parseRole(row?['role'] as String?);
  }
}
