import 'package:flutter/material.dart';

class MobileDesktopFeature extends StatelessWidget {
  const MobileDesktopFeature({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.desktopFeatures,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> desktopFeatures;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE8DEF8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: const Color(0xFF4F378B)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1B20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF625B71),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Available in the web workspace',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF625B71),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9E1F1)),
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < desktopFeatures.length;
                  index++
                ) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 19,
                          color: Color(0xFF6750A4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          desktopFeatures[index],
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF49454F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (index != desktopFeatures.length - 1)
                    const SizedBox(height: 13),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This keeps the mobile app focused on quick decisions and work happening on the move.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF79747E),
            ),
          ),
        ],
      ),
    );
  }
}
