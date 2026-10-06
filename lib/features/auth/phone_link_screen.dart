import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import 'auth_workspace.dart';
import 'enrollment_strings.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';

class PhoneLinkScreen extends StatefulWidget {
  const PhoneLinkScreen({super.key});

  @override
  State<PhoneLinkScreen> createState() => _PhoneLinkScreenState();
}

class _PhoneLinkScreenState extends State<PhoneLinkScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  Timer? _cooldownTimer;
  String? _pendingPhone;
  int _resendSeconds = 0;
  bool _busy = false;
  bool _requested = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_busy || _resendSeconds > 0) return;
    late final String phone;
    try {
      phone = _pendingPhone ?? normalizeIndiaPhoneNumber(_phone.text);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }

    setState(() => _busy = true);
    try {
      if (resend) {
        await AuthService.instance.resendPhoneChangeOtp(phone);
      } else {
        await AuthService.instance.requestPhoneChange(phone);
      }
      if (!mounted) return;
      setState(() {
        _pendingPhone = phone;
        _requested = true;
        _otp.clear();
      });
      _startCooldown();
      _showMessage('A verification code was sent to $phone.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final phone = _pendingPhone;
    final token = _otp.text.trim();
    if (phone == null) {
      _showMessage('Request a verification code first.');
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(token)) {
      _showMessage('Enter the 6-digit code from the SMS.');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance.verifyPhoneChangeOtp(
        phone: phone,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _requested = false;
        _pendingPhone = null;
        _phone.text = phone;
        _otp.clear();
      });
      _cooldownTimer?.cancel();
      setState(() => _resendSeconds = 0);
      _showMessage('Phone number verified. You can now sign in with OTP.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    if (error is FormatException) return error.message;
    return '${AppLocalizations.of(context)!.loginFailed}: $error';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String hi) => enrollmentText(context, en, hi);
    final currentUser = AuthService.instance.user;
    final currentPhone = currentUser?.phone;
    final confirmed = currentUser?.phoneConfirmedAt != null;
    return AuthWorkspace(
      title: t('Sign-in phone number', 'लॉगिन फोन नंबर'),
      subtitle: t(
        'Use a phone you can access. We verify the new number before it becomes your sign-in number.',
        'ऐसा फोन नंबर दें जो आपके पास हो। लॉगिन नंबर बदलने से पहले हम नए नंबर का सत्यापन करेंगे।',
      ),
      step:
          _requested
              ? t(
                'Step 2 of 2 · Verify new number',
                'चरण 2/2 · नया नंबर सत्यापित करें',
              )
              : t('Step 1 of 2 · New phone number', 'चरण 1/2 · नया फोन नंबर'),
      children: [
        GuidanceCard(
          title: t('Current phone', 'वर्तमान फोन'),
          message:
              currentPhone == null || currentPhone.isEmpty
                  ? t('No phone linked yet.', 'अभी फोन नंबर नहीं जुड़ा है।')
                  : '$currentPhone · ${confirmed ? t('Verified', 'सत्यापित') : t('Not verified', 'सत्यापित नहीं')}',
          tone: confirmed ? WorkspaceTone.success : WorkspaceTone.neutral,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 24),
        if (!_requested) ...[
          Text(
            t('New mobile number', 'नया मोबाइल नंबर'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          PillTextField(
            controller: _phone,
            hint: '+91 98765 43210',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ] else ...[
          Text(
            t(
              'Enter the code sent to ${_pendingPhone ?? ''}',
              '${_pendingPhone ?? ''} पर भेजा गया कोड भरें',
            ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          PillTextField(
            controller: _otp,
            hint: t('6-digit code', '6 अंकों का कोड'),
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
                    ? t('Please wait…', 'कृपया प्रतीक्षा करें…')
                    : _requested
                    ? t('Verify number', 'नंबर सत्यापित करें')
                    : _resendSeconds > 0
                    ? t(
                      'Wait ${_resendSeconds}s to resend',
                      '$_resendSeconds सेकंड रुकें',
                    )
                    : t('Send verification code', 'सत्यापन कोड भेजें'),
            onPressed:
                _busy || (!_requested && _resendSeconds > 0)
                    ? null
                    : _requested
                    ? _verifyCode
                    : _requestCode,
          ),
        ),
        if (_requested) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed:
                    _busy || _resendSeconds > 0
                        ? null
                        : () => _requestCode(resend: true),
                child: Text(
                  _resendSeconds > 0
                      ? t(
                        'Resend in ${_resendSeconds}s',
                        '$_resendSeconds सेकंड में फिर भेजें',
                      )
                      : t('Resend code', 'कोड फिर भेजें'),
                ),
              ),
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => setState(() {
                          _requested = false;
                          _pendingPhone = null;
                          _otp.clear();
                        }),
                child: Text(t('Change number', 'नंबर बदलें')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
