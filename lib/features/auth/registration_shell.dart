import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Step $step of 5',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF757575),
                      height: 16 / 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ...fields,
                  if (extraBelowFields != null) ...[
                    const SizedBox(height: 24),
                    extraBelowFields!,
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: PrimaryButton(label: ctaLabel, onPressed: onNext),
                  ),
                  if (footerSocial != null) ...[
                    const SizedBox(height: 24),
                    ...footerSocial!,
                  ],
                  const SizedBox(height: 48),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0x80000000),
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Go Back',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
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
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
