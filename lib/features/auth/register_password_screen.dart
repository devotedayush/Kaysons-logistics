import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/pill_text_field.dart';
import 'registration_draft.dart';
import 'registration_shell.dart';

class RegisterPasswordScreen extends StatefulWidget {
  const RegisterPasswordScreen({super.key});

  @override
  State<RegisterPasswordScreen> createState() => _RegisterPasswordScreenState();
}

class _RegisterPasswordScreenState extends State<RegisterPasswordScreen> {
  final _pwd = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;

  @override
  void dispose() {
    _pwd.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationShell(
      step: 2,
      title: 'Create Password',
      subtitle: 'Must be 8 character or longer',
      fields: [
        LabeledField(
          label: 'New Password',
          child: PillTextField(
            controller: _pwd,
            obscureText: true,
            hint: 'Password',
          ),
        ),
        LabeledField(
          label: 'Confirm New Password',
          child: PillTextField(
            controller: _confirm,
            obscureText: true,
            hint: 'Confirm password',
          ),
        ),
      ],
      extraBelowFields: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            activeColor: AppColors.primary,
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Please agree to Kaysons Terms of Use and Privacy Policy and to receive emails from Kaysons.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0x80000000),
                  height: 16 / 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
      ctaLabel: 'Next',
      onNext: () {
        if (_pwd.text.length < 8 || _pwd.text != _confirm.text || !_agree) return;
        RegistrationDraft.instance.password = _pwd.text;
        context.push('/register/name');
      },
    );
  }
}
