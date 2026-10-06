import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;
    return RegistrationShell(
      step: 1,
      title: l.registerEmailTitle,
      subtitle: l.registerEmailSubtitle,
      fields: [
        LabeledField(
          label: l.yourEmail,
          child: PillTextField(
            controller: _email,
            hint: 'abc@gmail.com',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ],
      ctaLabel: l.next,
      onNext: () {
        final v = _email.text.trim();
        if (v.isEmpty || !v.contains('@')) return;
        RegistrationDraft.instance.email = v;
        context.push('/register/password');
      },
    );
  }
}
