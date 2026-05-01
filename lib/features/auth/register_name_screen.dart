import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/pill_text_field.dart';
import 'registration_draft.dart';
import 'registration_shell.dart';

class RegisterNameScreen extends StatefulWidget {
  const RegisterNameScreen({super.key});

  @override
  State<RegisterNameScreen> createState() => _RegisterNameScreenState();
}

class _RegisterNameScreenState extends State<RegisterNameScreen> {
  final _fullName = TextEditingController();
  final _company = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationShell(
      step: 3,
      title: 'What is your Name?',
      subtitle: 'This is used to build your profile on our platform',
      fields: [
        LabeledField(
          label: 'Full Name',
          child: PillTextField(controller: _fullName, hint: 'Naveen Garg'),
        ),
        LabeledField(
          label: 'Company Name',
          child: PillTextField(controller: _company, hint: 'Jagdamba Enterprises'),
        ),
      ],
      ctaLabel: 'Next',
      onNext: () {
        if (_fullName.text.trim().isEmpty) return;
        RegistrationDraft.instance.fullName = _fullName.text.trim();
        RegistrationDraft.instance.businessName = _company.text.trim();
        context.push('/register/bank');
      },
    );
  }
}
