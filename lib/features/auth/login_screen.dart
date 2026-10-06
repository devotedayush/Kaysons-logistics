import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_workspace.dart';
import 'enrollment_strings.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  String? _notice;
  String t(String en, String hi) => enrollmentText(context, en, hi);
  bool _passwordMode = false;
  bool _otpSent = false;
  int _resendSeconds = 0;
  String? _phoneE164;
  Timer? _resendTimer;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || password.isEmpty || _busy) {
      _showMessage(
        t(
          'Enter your email and password to continue.',
          'आगे बढ़ने के लिए ईमेल और पासवर्ड भरें।',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final role = await AuthService.instance.signInWithPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      context.go(routeForRole(role));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    if (_busy) return;
    if (_resendSeconds > 0) {
      _showMessage(
        'Please wait ${_resendSeconds}s before requesting another code.',
      );
      return;
    }
    late final String phone;
    try {
      phone = normalizeIndiaPhoneNumber(_phone.text);
    } on FormatException catch (e) {
      _showMessage(e.message);
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance.sendPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _phoneE164 = phone;
        _otpSent = true;
        _otp.clear();
      });
      _startResendCooldown();
      _showMessage('A verification code was sent to $phone.');
    } catch (e) {
      if (mounted) _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (_busy) return;
    final token = _otp.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(token)) {
      _showMessage('Enter the 6-digit code from the SMS.');
      return;
    }
    final phone = _phoneE164;
    if (phone == null) {
      setState(() => _otpSent = false);
      _showMessage('Enter your phone number to request a code.');
      return;
    }

    setState(() => _busy = true);
    try {
      final role = await AuthService.instance.verifyPhoneOtp(
        phone: phone,
        token: token,
      );
      if (!mounted) return;
      context.go(routeForRole(role));
    } catch (e) {
      if (mounted) _showMessage(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) return error.message;
    if (error is FormatException) return error.message;
    return '${AppLocalizations.of(context)!.loginFailed}: $error';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AuthWorkspace(
      title:
          _otpSent ? t('Enter your SMS code', 'SMS कोड भरें') : l.welcomeBack,
      subtitle:
          _passwordMode
              ? t(
                'Sign in using the email and password for your approved account.',
                'स्वीकृत खाते के ईमेल और पासवर्ड से लॉगिन करें।',
              )
              : _otpSent
              ? t(
                'Open the SMS on your phone and enter the 6-digit code below.',
                'अपने फोन पर SMS खोलें और नीचे 6 अंकों का कोड भरें।',
              )
              : t(
                'Use the mobile number linked to your approved account. We will send you an SMS code.',
                'अपने स्वीकृत खाते का मोबाइल नंबर भरें। हम आपको SMS कोड भेजेंगे।',
              ),
      step:
          _passwordMode
              ? null
              : _otpSent
              ? t('Step 2 of 2 · Verify phone', 'चरण 2/2 · फोन सत्यापन')
              : t('Step 1 of 2 · Mobile number', 'चरण 1/2 · मोबाइल नंबर'),
      children: [
        if (_notice != null) ...[
          GuidanceCard(
            title: t('Sign-in message', 'लॉगिन संदेश'),
            message: _notice!,
          ),
          const SizedBox(height: 20),
        ],
        if (_passwordMode) ...[
          _label(l.email),
          PillTextField(
            controller: _email,
            enabled: !_busy,
            autofillHints: const [AutofillHints.username],
            hint: 'name@company.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _label(l.password),
          PillTextField(
            controller: _password,
            enabled: !_busy,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            hint: l.password,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
        ] else if (!_otpSent) ...[
          _label(t('Mobile number', 'मोबाइल नंबर')),
          PillTextField(
            controller: _phone,
            enabled: !_busy,
            autofillHints: const [AutofillHints.telephoneNumber],
            onSubmitted: (_) => _sendPhoneOtp(),
            hint: '+91 98765 43210',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Enter your 10-digit Indian mobile number.',
              'अपना 10 अंकों का भारतीय मोबाइल नंबर भरें।',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...[
          GuidanceCard(
            title: t(
              'Code sent to ${_phoneE164 ?? ''}',
              'कोड ${_phoneE164 ?? ''} पर भेजा गया',
            ),
            message: t(
              'Keep this screen open while you check your SMS.',
              'SMS देखते समय यह स्क्रीन खुली रखें।',
            ),
            icon: Icons.sms_outlined,
          ),
          const SizedBox(height: 18),
          _label(t('6-digit SMS code', '6 अंकों का SMS कोड')),
          PillTextField(
            controller: _otp,
            enabled: !_busy,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verifyPhoneOtp(),
            hint: '123456',
            prefixIcon: Icons.password_outlined,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label:
                _busy
                    ? l.signingIn
                    : _passwordMode
                    ? l.signIn
                    : _otpSent
                    ? t(
                      'Verify code & sign in',
                      'कोड सत्यापित करें और लॉगिन करें',
                    )
                    : _resendSeconds > 0
                    ? t(
                      'Wait ${_resendSeconds}s to resend',
                      'फिर भेजने के लिए $_resendSeconds सेकंड रुकें',
                    )
                    : t('Send verification code', 'सत्यापन कोड भेजें'),
            onPressed:
                _busy
                    ? null
                    : _passwordMode
                    ? _submit
                    : !_otpSent && _resendSeconds > 0
                    ? null
                    : _otpSent
                    ? _verifyPhoneOtp
                    : _sendPhoneOtp,
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: _resendSeconds == 0 && !_busy ? _sendPhoneOtp : null,
                child: Text(
                  _resendSeconds == 0
                      ? t('Resend code', 'कोड फिर भेजें')
                      : t(
                        'Resend in ${_resendSeconds}s',
                        '$_resendSeconds सेकंड में फिर भेजें',
                      ),
                ),
              ),
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => setState(() {
                          _otpSent = false;
                          _phoneE164 = null;
                          _otp.clear();
                          _notice = null;
                        }),
                child: Text(t('Change mobile number', 'मोबाइल नंबर बदलें')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () => setState(() {
                    _passwordMode = !_passwordMode;
                    _otpSent = false;
                    _phoneE164 = null;
                    _otp.clear();
                    _notice = null;
                  }),
          child: Text(
            _passwordMode
                ? t(
                  'Use phone verification code',
                  'फोन सत्यापन कोड से लॉगिन करें',
                )
                : t(
                  'Use email and password instead',
                  'ईमेल और पासवर्ड से लॉगिन करें',
                ),
          ),
        ),
        const SizedBox(height: 12),
        GuidanceCard(
          title: t('New transporter?', 'नए ट्रांसपोर्टर हैं?'),
          message: t(
            'Register with your phone and name. An administrator will review your request.',
            'फोन और नाम से पंजीकरण करें। प्रशासक आपके अनुरोध की समीक्षा करेंगे।',
          ),
          action: OutlinedButton(
            onPressed: () => context.push('/register'),
            child: Text(l.noAccountRegister),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
  );
}
