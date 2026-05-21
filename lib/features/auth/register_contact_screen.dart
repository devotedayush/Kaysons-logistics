import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
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
  bool _submitting = false;

  @override
  void dispose() {
    _mobile.dispose();
    _landline.dispose();
    _gst.dispose();
    _bizNum.dispose();
    _rcNumber.dispose();
    _insurance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = RegistrationDraft.instance;
    if ((draft.email ?? '').isEmpty || (draft.password ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restart registration: email/password missing'),
        ),
      );
      return;
    }
    final normalizedMobile = _normalizeIndiaPhone(_mobile.text);
    if (normalizedMobile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 10 digit Indian mobile number.'),
        ),
      );
      return;
    }
    draft.mobile = normalizedMobile;
    draft.landline = _landline.text.trim();
    draft.gst = _gst.text.trim();
    draft.businessNumber = _bizNum.text.trim();
    draft.rcNumber = _rcNumber.text.trim();
    draft.insuranceNumber = _insurance.text.trim();

    setState(() => _submitting = true);
    try {
      await AuthService.instance.signUpWithPassword(
        email: draft.email!,
        password: draft.password!,
      );
      await _finalizeRegistration();
      draft.reset();
      final role = await AuthService.instance.fetchRole();
      if (!mounted) return;
      context.go(routeForRole(role));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _normalizeIndiaPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final tenDigits =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (tenDigits.length != 10 || tenDigits.startsWith('0')) return null;
    return '+91$tenDigits';
  }

  Future<void> _finalizeRegistration() async {
    final draft = RegistrationDraft.instance;
    final uid = AuthService.instance.user?.id;
    if (uid == null) return;
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
    return RegistrationShell(
      step: 5,
      title: 'How do we contact You?',
      subtitle:
          'Give us your number and business details. You will be signed in once you tap Submit.',
      fields: [
        LabeledField(
          label: 'Mobile No.',
          child: PillTextField(
            controller: _mobile,
            hint: '987-6543-214',
            keyboardType: TextInputType.phone,
          ),
        ),
        LabeledField(
          label: 'Company Landline No.',
          child: PillTextField(
            controller: _landline,
            hint: '987-654-321',
            keyboardType: TextInputType.phone,
          ),
        ),
        LabeledField(
          label: 'Business Registration No.',
          child: PillTextField(controller: _bizNum, hint: 'BRN-1234'),
        ),
        LabeledField(
          label: 'Lorry RC Number',
          child: PillTextField(controller: _rcNumber, hint: 'PB10AB1234'),
        ),
        LabeledField(
          label: 'Lorry Insurance Number',
          child: PillTextField(controller: _insurance, hint: 'INS-2026-44321'),
        ),
        LabeledField(
          label: 'GSTIN (optional)',
          child: PillTextField(controller: _gst, hint: '27ABCDE1234F1Z5'),
        ),
      ],
      ctaLabel: _submitting ? 'Submitting…' : 'Submit',
      onNext: _submit,
    );
  }
}
