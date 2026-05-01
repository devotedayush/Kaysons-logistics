import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

enum AppRole { transporter, logisticsManager, admin }

AppRole _parseRole(String? v) {
  switch (v) {
    case 'admin':
      return AppRole.admin;
    case 'logistics_manager':
      return AppRole.logisticsManager;
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

  Future<void> signInWithPassword({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithPassword({required String email, required String password}) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppRole> fetchRole() async {
    final uid = user?.id;
    if (uid == null) return AppRole.transporter;
    final row = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    return _parseRole(row?['role'] as String?);
  }
}
