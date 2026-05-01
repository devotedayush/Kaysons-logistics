import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/pill_text_field.dart';
import 'registration_draft.dart';
import 'registration_shell.dart';

class RegisterEmailScreen extends StatefulWidget {
  const RegisterEmailScreen({super.key});

  @override
  State<RegisterEmailScreen> createState() => _RegisterEmailScreenState();
}

class _RegisterEmailScreenState extends State<RegisterEmailScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationShell(
      step: 1,
      title: 'Enter your email address',
      subtitle:
          "Sign in with your email. If you don't have a Kaysons account yet, we'll set one up",
      fields: [
        LabeledField(
          label: 'Your Email',
          child: PillTextField(
            controller: _email,
            hint: 'abc@gmail.com',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ],
      ctaLabel: 'Next',
      onNext: () {
        final v = _email.text.trim();
        if (v.isEmpty || !v.contains('@')) return;
        RegistrationDraft.instance.email = v;
        context.push('/register/password');
      },
    );
  }
}
