import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Normalizes a supported Indian mobile number to the E.164 format Supabase
/// expects. Users may enter either the ten-digit number or a +91-prefixed one.
String normalizeIndiaPhoneNumber(String input) {
  final value = input.trim();
  if (value.isEmpty || !RegExp(r'^\+?[0-9() .-]+$').hasMatch(value)) {
    throw const FormatException('Enter a valid 10-digit Indian mobile number.');
  }
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final nationalNumber =
      digits.length == 12 && digits.startsWith('91')
          ? digits.substring(2)
          : digits;
  if (nationalNumber.length != 10 ||
      !RegExp(r'^[6-9][0-9]{9}$').hasMatch(nationalNumber)) {
    throw const FormatException('Enter a valid 10-digit Indian mobile number.');
  }
  return '+91$nationalNumber';
}

bool isSameIndiaPhoneNumber(String? actual, String expected) {
  try {
    return normalizeIndiaPhoneNumber(actual ?? '') ==
        normalizeIndiaPhoneNumber(expected);
  } on FormatException {
    return false;
  }
}

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

  /// Allows isolated Auth integration tests without the global Flutter client.
  AuthService.forClient(SupabaseClient client) : _providedClient = client;
  SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? supabase;
  static final instance = AuthService._();

  GoTrueClient get _auth => _client.auth;

  Session? get session => _auth.currentSession;
  User? get user => _auth.currentUser;

  Stream<AuthState> get onAuthState => _auth.onAuthStateChange;

  Future<AppRole> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
    return requireApprovedAccess();
  }

  Future<void> sendPhoneOtp(String phone) {
    return _auth.signInWithOtp(phone: phone, shouldCreateUser: false);
  }

  /// Enrollment authenticates a phone but never grants operational access.
  Future<void> sendRegistrationOtp(String phone) => _auth.signInWithOtp(
    phone: normalizeIndiaPhoneNumber(phone),
    shouldCreateUser: true,
  );

  Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String phone,
    required String token,
  }) async {
    final phoneE164 = normalizeIndiaPhoneNumber(phone);
    // OTP verification may succeed before the following profile read fails.
    // Reuse only this authenticated, confirmed phone identity on retry.
    final hasVerifiedSession =
        session != null &&
        user?.isAnonymous == false &&
        user?.phoneConfirmedAt != null &&
        isSameIndiaPhoneNumber(user?.phone, phoneE164);
    final verifiedUser =
        hasVerifiedSession
            ? user
            : (await _auth.verifyOTP(
              phone: phoneE164,
              token: token,
              type: OtpType.sms,
            )).user;
    _requireAuthenticatedUser();
    if (!isSameIndiaPhoneNumber(verifiedUser?.phone, phoneE164) ||
        verifiedUser?.phoneConfirmedAt == null) {
      throw AuthException('Phone verification could not be confirmed.');
    }
    final profile = await fetchAccessProfile();
    if (profile == null) throw AuthException('Your access profile is missing.');
    return profile;
  }

  /// Filter the mutation as well as checking the returned profile so a concurrent
  /// admin decision cannot be reset or overwritten by registration retries.
  Future<void> completePhoneRegistration({
    required String name,
    String? contactEmail,
  }) async {
    _requireAuthenticatedUser();
    if (user?.phoneConfirmedAt == null || (user?.phone ?? '').isEmpty) {
      throw AuthException('Verify your phone before completing registration.');
    }
    await _client
        .from('profiles')
        .update({
          'full_name': name.trim(),
          if (contactEmail != null && contactEmail.trim().isNotEmpty)
            'email': contactEmail.trim(),
        })
        .eq('id', user!.id)
        .eq('status', 'pending')
        .select('id')
        .single();
  }

  Future<void> sendEmailOtp(String email) {
    return _auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  Future<AppRole> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
    return requireApprovedAccess();
  }

  /// Starts a phone-change challenge for the currently authenticated user.
  /// This changes only the signed-in user's own auth phone and grants no
  /// operational access, so unapproved registrants can complete enrollment.
  Future<void> requestPhoneChange(String phone) async {
    _requireAuthenticatedUser();
    await _auth.updateUser(UserAttributes(phone: phone));
  }

  Future<void> resendPhoneChangeOtp(String phone) async {
    _requireAuthenticatedUser();
    await _auth.resend(phone: phone, type: OtpType.phoneChange);
  }

  /// Verifies the phone-change challenge for the currently authenticated user.
  /// This enrollment step does not approve the account or grant app roles.
  Future<void> verifyPhoneChangeOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.phoneChange,
    );
    _requireAuthenticatedUser();
    final verifiedUser = response.user ?? user;
    if (!isSameIndiaPhoneNumber(verifiedUser?.phone, phone) ||
        verifiedUser?.phoneConfirmedAt == null) {
      throw AuthException(
        'Supabase did not confirm the requested phone number.',
      );
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.email);
    await requireApprovedAccess();
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppRole> fetchRole() async {
    return requireApprovedAccess();
  }

  /// Confirms the authenticated user has an approved profile before the app
  /// grants access to role-specific screens. Rejects and signs out otherwise.
  Future<AppRole> requireApprovedAccess() async {
    try {
      final profile = await fetchAccessProfile();
      if (profile == null) {
        throw AuthException('Your Kaysons access profile could not be found.');
      }
      final status = profile['status'] as String?;
      if (status != 'approved') {
        throw AuthException(switch (status) {
          'pending' =>
            'Your registration is awaiting admin approval. You can sign in after it is approved.',
          'rejected' =>
            'Your registration was declined. Contact a Kaysons administrator for help.',
          _ => 'Your account is not approved for operational access.',
        });
      }
      final roleName = profile['role'] as String?;
      if (roleName == null || !_knownRoles.contains(roleName)) {
        throw AuthException('This account has no valid access role.');
      }
      return _parseRole(roleName);
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {
        // Keep the original access-check error visible to the caller.
      }
      rethrow;
    }
  }

  void _requireAuthenticatedUser() {
    final currentUser = user;
    if (session == null || currentUser == null || currentUser.isAnonymous) {
      throw AuthSessionMissingException();
    }
  }

  Future<Map<String, dynamic>?> fetchAccessProfile() async {
    final uid = user?.id;
    if (uid == null) return null;
    return await _client
        .from('profiles')
        .select('role, status')
        .eq('id', uid)
        .maybeSingle();
  }
}

const _knownRoles = {
  'admin',
  'logistics_manager',
  'dispatch_manager',
  'accountant',
  'transporter',
};
