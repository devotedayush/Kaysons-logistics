import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/primary_button.dart';
import 'auth_workspace.dart';
import '../../l10n/app_localizations.dart';

class RegistrationShell extends StatelessWidget {
  const RegistrationShell({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.ctaLabel,
    required this.onNext,
    this.extraBelowFields,
    this.footerSocial,
  });

  final int step;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final Widget? extraBelowFields;
  final String ctaLabel;
  final VoidCallback onNext;
  final List<Widget>? footerSocial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AuthWorkspace(
      title: title,
      subtitle: subtitle,
      step: l.stepOfFive(step),
      children: [
        ...fields,
        if (extraBelowFields != null) ...[
          const SizedBox(height: 20),
          extraBelowFields!,
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(label: ctaLabel, onPressed: onNext),
        ),
        if (footerSocial != null) ...[
          const SizedBox(height: 20),
          ...footerSocial!,
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text('${l.alreadyAccount} ${l.goBack}'),
        ),
      ],
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
