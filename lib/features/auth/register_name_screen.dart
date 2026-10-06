import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;
    return RegistrationShell(
      step: 3,
      title: l.registerNameTitle,
      subtitle: l.registerProfileSubtitle,
      fields: [
        LabeledField(
          label: l.fullName,
          child: PillTextField(controller: _fullName, hint: 'Naveen Garg'),
        ),
        LabeledField(
          label: l.companyName,
          child: PillTextField(
            controller: _company,
            hint: 'Jagdamba Enterprises',
          ),
        ),
      ],
      ctaLabel: l.next,
      onNext: () {
        if (_fullName.text.trim().isEmpty) return;
        RegistrationDraft.instance.fullName = _fullName.text.trim();
        RegistrationDraft.instance.businessName = _company.text.trim();
        context.push('/register/bank');
      },
    );
  }
}
