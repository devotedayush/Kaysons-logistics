import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/language_button.dart';
import '../../core/widgets/logistics_artwork.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/enrollment_strings.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String t(String en, String hi) => enrollmentText(context, en, hi);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaysons Logistics'),
        actions: const [LanguageButton(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: WorkspaceFormLayout(
            aside: LogisticsArtwork(
              dark: true,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 54,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 36),
                    Text(
                      t(
                        'Every trip.\nEvery delivery.\nTogether.',
                        'हर सफ़र।\nहर डिलीवरी।\nएक जगह।',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t(
                        'A shared workspace for your transport team—from finding a vehicle to checking delivery proof.',
                        'आपकी परिवहन टीम के लिए साझा कार्यस्थल—वाहन चुनने से डिलीवरी प्रमाण जाँचने तक।',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 80),
                    Text(
                      'KAYSONS SALES PRIVATE LIMITED',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/branding/kaysons-app-icon.png',
                      width: 68,
                      height: 68,
                      semanticLabel: 'Kaysons logo',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('Transport made easier', 'परिवहन का काम आसान'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l.welcomeTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  l.welcomeSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                WorkspaceSection(
                  title: t('Get started', 'शुरू करें'),
                  description: t(
                    'Already approved? Sign in to continue your work.',
                    'आपका खाता स्वीकृत है? अपना काम जारी रखने के लिए लॉगिन करें।',
                  ),
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l.loginEmailMobile,
                        onPressed: () => context.push('/login'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    Text(
                      t('New transporter?', 'नए ट्रांसपोर्टर हैं?'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t(
                        'Register with your phone and name. Your account is reviewed by an administrator.',
                        'फोन और नाम से पंजीकरण करें। प्रशासक आपके खाते की समीक्षा करेंगे।',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: l.registerWithUs,
                        style: PrimaryButtonStyle.outlined,
                        onPressed: () => context.push('/register'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GuidanceCard(
                  title: t('Use the language you know', 'अपनी भाषा चुनें'),
                  message: t(
                    'Choose English or हिन्दी at the top. Each account shows only the work assigned to its role.',
                    'ऊपर English या हिन्दी चुनें। हर खाते में उसकी भूमिका का काम दिखता है।',
                  ),
                  icon: Icons.translate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
