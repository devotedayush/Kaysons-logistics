import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/workflow_formatters.dart';
import '../../core/widgets/pill_text_field.dart';
import 'registration_draft.dart';
import 'registration_shell.dart';

class RegisterContactScreen extends StatefulWidget {
  const RegisterContactScreen({super.key});

  @override
  State<RegisterContactScreen> createState() => _RegisterContactScreenState();
}

class _RegisterContactScreenState extends State<RegisterContactScreen> {
  final _mobile = TextEditingController();
  final _landline = TextEditingController();
  final _gst = TextEditingController();
  final _bizNum = TextEditingController();
  final _rcNumber = TextEditingController();
  final _insurance = TextEditingController();
  final _phoneOtp = TextEditingController();
  bool _submitting = false;
  bool _signupCompleted = false;
  bool _phoneOtpPending = false;
  bool _phoneVerified = false;
  String? _registrationUserId;
  String? _phoneE164;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _mobile.dispose();
    _landline.dispose();
    _gst.dispose();
    _bizNum.dispose();
    _rcNumber.dispose();
    _insurance.dispose();
    _phoneOtp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = RegistrationDraft.instance;
    if ((draft.email ?? '').isEmpty || (draft.password ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.registerRestart)),
      );
      return;
    }
    if (!_phoneOtpPending) {
      final normalizedMobile = _normalizeIndiaPhone(_mobile.text);
      if (normalizedMobile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.invalidMobile)),
        );
        return;
      }
      _phoneE164 = normalizedMobile;
      draft.mobile = normalizedMobile;
      draft.landline = _landline.text.trim();
      draft.gst = _gst.text.trim();
      draft.businessNumber = _bizNum.text.trim();
      draft.rcNumber = _rcNumber.text.trim();
      draft.insuranceNumber = _insurance.text.trim();
    } else if (!_phoneVerified &&
        !RegExp(r'^[0-9]{6}$').hasMatch(_phoneOtp.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code from the SMS.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_phoneOtpPending) {
        final phone = _phoneE164;
        if (phone == null) {
          throw AuthException('Request a phone verification code first.');
        }
        _ensureRegistrationSession(draft);
        if (!_phoneVerified) {
          await AuthService.instance.verifyPhoneChangeOtp(
            phone: phone,
            token: _phoneOtp.text.trim(),
          );
          _phoneVerified = true;
        }
        draft.mobile = phone;
        await _finalizeRegistration();
        draft.reset();
        if (AuthService.instance.session != null) {
          try {
            await AuthService.instance.signOut();
          } catch (_) {
            // Registration is complete; continue to login if sign-out fails.
          }
        }
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Phone verified. Registration submitted; your transporter access is pending admin approval.',
            ),
          ),
        );
        context.go('/login');
      } else {
        if (!_signupCompleted) {
          if (AuthService.instance.session != null) {
            throw AuthException(
              'Sign out before starting a new transporter registration.',
            );
          }
          await AuthService.instance.signUpWithPassword(
            email: draft.email!,
            password: draft.password!,
          );
          _signupCompleted = true;
          _registrationUserId = AuthService.instance.user?.id;
        }
        if (AuthService.instance.session == null) {
          throw AuthException(
            'Confirm your email, then sign in and finish phone verification before registration can be submitted.',
          );
        }
        _ensureRegistrationSession(draft);
        final phone = _phoneE164!;
        await AuthService.instance.requestPhoneChange(phone);
        if (!mounted) return;
        setState(() {
          _phoneOtpPending = true;
          _phoneOtp.clear();
        });
        _startResendCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A verification code was sent to $phone.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.registrationFailed}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendPhoneOtp() async {
    if (_submitting || _resendSeconds > 0) return;
    final phone = _phoneE164;
    if (phone == null) return;
    setState(() => _submitting = true);
    try {
      await AuthService.instance.resendPhoneChangeOtp(phone);
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('A new code was sent to $phone.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.registrationFailed}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  String? _normalizeIndiaPhone(String raw) => normalizeIndianPhone(raw);

  void _ensureRegistrationSession(RegistrationDraft draft) {
    final currentUser = AuthService.instance.user;
    if (AuthService.instance.session == null || currentUser == null) {
      throw AuthSessionMissingException();
    }
    if (_registrationUserId == null || currentUser.id != _registrationUserId) {
      throw AuthException(
        'This registration no longer matches the signed-in account. Restart registration to continue.',
      );
    }
    final expectedEmail = draft.email?.trim().toLowerCase();
    if (expectedEmail == null ||
        currentUser.email?.trim().toLowerCase() != expectedEmail) {
      throw AuthException(
        'The signed-in account does not match this registration email.',
      );
    }
  }

  Future<void> _finalizeRegistration() async {
    final draft = RegistrationDraft.instance;
    _ensureRegistrationSession(draft);
    final uid = AuthService.instance.user?.id;
    if (uid == null) {
      throw AuthException(
        'Your sign-in session expired. Sign in again to finish registration.',
      );
    }
    await supabase
        .from('profiles')
        .update({
          'full_name': draft.fullName,
          'business_name': draft.businessName,
          'phone': draft.mobile,
          'business_number': draft.businessNumber,
          'gst': draft.gst,
          'role': 'transporter',
          'status': 'pending',
        })
        .eq('id', uid);
    await _saveVehicleRegistration(uid, draft);
    if ((draft.bankAccountNumber ?? '').isNotEmpty) {
      final chequePath = await _uploadChequePhoto(uid, draft);
      await supabase.from('bank_accounts').insert({
        'profile_id': uid,
        'account_number': draft.bankAccountNumber,
        'holder_name': draft.bankHolder,
        'cheque_url': chequePath,
      });
    }
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

  Future<String?> _uploadChequePhoto(
    String uid,
    RegistrationDraft draft,
  ) async {
    final bytes = draft.chequeBytes;
    if (bytes == null || bytes.isEmpty) return null;
    final extension = _cleanSegment(draft.chequeExtension ?? 'jpg');
    final originalName = draft.chequeFileName ?? 'blank-cheque';
    final baseName =
        originalName.toLowerCase().endsWith('.${extension.toLowerCase()}')
            ? originalName.substring(
              0,
              originalName.length - extension.length - 1,
            )
            : originalName;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}-${_cleanSegment(baseName)}.$extension';
    final path = '$uid/registration/bank-cheque/$fileName';
    await supabase.storage
        .from('delivery-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(draft.chequeExtension),
            upsert: true,
          ),
        );
    return path;
  }

  Future<void> _saveVehicleRegistration(
    String uid,
    RegistrationDraft draft,
  ) async {
    final rc = (draft.rcNumber ?? '').trim();
    final insurance = (draft.insuranceNumber ?? '').trim();
    if (rc.isEmpty && insurance.isEmpty) return;

    try {
      await supabase
          .from('profiles')
          .update({
            'rc_number': rc.isEmpty ? null : rc,
            'lorry_insurance_number': insurance.isEmpty ? null : insurance,
          })
          .eq('id', uid);
    } catch (_) {
      // Older environments may not have these columns yet.
    }

    if (rc.isNotEmpty) {
      try {
        await supabase.from('vehicles').insert({
          'profile_id': uid,
          'transporter_id': uid,
          'registration_number': rc,
          'number': rc,
          'rc_number': rc,
          'insurance_number': insurance.isEmpty ? null : insurance,
          'status': 'pending',
        });
      } catch (_) {
        // Vehicle persistence is best-effort until every environment is migrated.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegistrationShell(
      step: 5,
      title: l.registerContactTitle,
      subtitle: l.contactSubtitle,
      fields: [
        if (!_phoneOtpPending) ...[
          LabeledField(
            label: l.mobileNumber,
            child: PillTextField(
              controller: _mobile,
              hint: '987-6543-214',
              keyboardType: TextInputType.phone,
            ),
          ),
          LabeledField(
            label: l.landlineNumber,
            child: PillTextField(
              controller: _landline,
              hint: '987-654-321',
              keyboardType: TextInputType.phone,
            ),
          ),
          LabeledField(
            label: l.businessRegistrationNumber,
            child: PillTextField(controller: _bizNum, hint: 'BRN-1234'),
          ),
          LabeledField(
            label: l.lorryRcNumber,
            child: PillTextField(controller: _rcNumber, hint: 'PB10AB1234'),
          ),
          LabeledField(
            label: l.lorryInsuranceNumber,
            child: PillTextField(
              controller: _insurance,
              hint: 'INS-2026-44321',
            ),
          ),
          LabeledField(
            label: l.gstinOptional,
            child: PillTextField(controller: _gst, hint: '27ABCDE1234F1Z5'),
          ),
        ] else ...[
          LabeledField(
            label:
                _phoneVerified
                    ? 'Phone number verified'
                    : 'Verification code sent to ${_phoneE164 ?? ''}',
            child:
                _phoneVerified
                    ? const Text(
                      'Tap Complete registration to submit your details for admin approval.',
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PillTextField(
                          controller: _phoneOtp,
                          hint: '6-digit code',
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _submitting || _resendSeconds > 0
                                    ? null
                                    : _resendPhoneOtp,
                            child: Text(
                              _resendSeconds > 0
                                  ? 'Resend in ${_resendSeconds}s'
                                  : 'Resend code',
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ],
      ctaLabel:
          _submitting
              ? l.submitting
              : _phoneOtpPending
              ? _phoneVerified
                  ? 'Complete registration'
                  : 'Verify phone number'
              : 'Create account and send code',
      onNext: _submit,
    );
  }
}
