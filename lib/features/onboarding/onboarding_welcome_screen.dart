import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/primary_button.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final illustrationSize =
                constraints.maxWidth > 520
                    ? 308.0
                    : constraints.maxWidth * 0.62;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: illustrationSize.clamp(220.0, 308.0),
                              height: illustrationSize.clamp(220.0, 308.0),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                size: 120,
                                color: Color(0xFFB39DC8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'Never miss a freight',
                            style: textTheme.displaySmall?.copyWith(
                              fontSize: constraints.maxWidth < 420 ? 30 : null,
                              height: constraints.maxWidth < 420 ? 1.15 : null,
                            ),
                            textAlign:
                                constraints.maxWidth < 520
                                    ? TextAlign.left
                                    : TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Get regular updates on the latest freight',
                            style: textTheme.bodyLarge,
                            textAlign:
                                constraints.maxWidth < 520
                                    ? TextAlign.left
                                    : TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          if (constraints.maxWidth > 560) const Spacer(),
                          PrimaryButton(
                            label: 'Login with email / mobile',
                            style: PrimaryButtonStyle.filledBlack,
                            onPressed: () => context.push('/login'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0x33000000)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'OR',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0x33000000)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Register with us',
                            style: PrimaryButtonStyle.filledPurple,
                            onPressed: () => context.push('/register'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
