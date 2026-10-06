import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/language_button.dart';
import '../../core/widgets/logistics_artwork.dart';
import '../../core/widgets/workspace_widgets.dart';
import 'enrollment_strings.dart';

class AuthWorkspace extends StatelessWidget {
  const AuthWorkspace({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.step,
    this.icon = Icons.phone_android_outlined,
  });
  final String title, subtitle;
  final List<Widget> children;
  final String? step;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    String t(String en, String hi) => enrollmentText(context, en, hi);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: t('Go back', 'वापस जाएँ'),
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
        title: const Text('Kaysons Logistics'),
        actions: const [LanguageButton(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            20,
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
            32,
          ),
          child: WorkspaceFormLayout(
            aside: LogisticsArtwork(
              dark: true,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/branding/kaysons-app-icon.png',
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t(
                        'Your work,\none clear next step.',
                        'आपका काम,\nअगला कदम साफ़।',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t(
                        'From booking a truck to confirming delivery, keep the whole trip together.',
                        'ट्रक की बुकिंग से डिलीवरी की पुष्टि तक, पूरे सफ़र की जानकारी एक जगह रखें।',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    for (final (number, label) in [
                      (
                        1,
                        t('Book & assign a vehicle', 'बुक करें और वाहन चुनें'),
                      ),
                      (
                        2,
                        t(
                          'Track pickup & deliveries',
                          'पिकअप और डिलीवरी देखें',
                        ),
                      ),
                      (
                        3,
                        t(
                          'Review proof & settle costs',
                          'प्रमाण जाँचें और खर्च तय करें',
                        ),
                      ),
                    ]) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              '$number',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/branding/kaysons-app-icon.png',
                        width: 52,
                        height: 52,
                        semanticLabel: 'Kaysons logo',
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kaysons Sales Private Limited Logistics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                WorkspaceSection(
                  title: title,
                  description: subtitle,
                  children: [
                    if (step != null) ...[
                      StatusBadge(label: step!, tone: WorkspaceTone.info),
                      const SizedBox(height: 22),
                    ],
                    ...children,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
