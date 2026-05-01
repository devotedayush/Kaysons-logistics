import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _showExport(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _StatCard(label: 'Monthly freight total', value: '₹4.20L'),
                      _StatCard(label: 'Per case freight', value: '₹38'),
                      _StatCard(label: 'Per unit freight', value: '₹1,191'),
                      _StatCard(label: 'Invoice match', value: '94%', positive: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('Transporter business volume'),
                              ..._transporters.map((t) => _TransporterRow(t: t)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: _AnalyticsAlertsColumn(),
                        ),
                      ],
                    )
                  else ...[
                    _SectionTitle('Transporter business volume'),
                    ..._transporters.map((t) => _TransporterRow(t: t)),
                    const SizedBox(height: 24),
                    const _AnalyticsAlertsColumn(),
                  ],
                  const SizedBox(height: 24),
                  _SectionTitle('Situation-wise freight match'),
                  const _MatchBar(label: 'Within calling bid', percent: 0.62, color: Color(0xFF14A33A)),
                  const _MatchBar(label: 'Above calling bid', percent: 0.28, color: Color(0xFFFFB400)),
                  const _MatchBar(label: 'Penalty triggered', percent: 0.10, color: Color(0xFFB3261E)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Export report'), dense: true),
            ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.table_chart), title: const Text('Excel'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.description), title: const Text('CSV'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

const _transporters = [
  ('Jagdamba Enterprises', 0.42, '₹1.78L'),
  ('Karan Transport', 0.27, '₹1.13L'),
  ('Shree Logistics', 0.19, '₹0.79L'),
  ('KK Royal Transports', 0.12, '₹0.50L'),
];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.positive = false});
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFECE6F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: positive ? const Color(0xFF14A33A) : const Color(0xFF1D1B20),
                )),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF49454F))),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsAlertsColumn extends StatelessWidget {
  const _AnalyticsAlertsColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SectionTitle('Duplicate freight alerts'),
        _AlertTile(
          title: 'Hoshi → Ludhi appears 3 times in 7 days',
          subtitle: 'Possible duplicate freight booking',
        ),
        _AlertTile(
          title: 'Invoice INV-2026-0019 not linked',
          subtitle: '5 days since dispatch',
        ),
      ],
    );
  }
}

class _TransporterRow extends StatelessWidget {
  const _TransporterRow({required this.t});
  final (String, double, String) t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.$1)),
              Text(t.$3,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.$2,
              minHeight: 8,
              backgroundColor: const Color(0xFFECE6F0),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchBar extends StatelessWidget {
  const _MatchBar({required this.label, required this.percent, required this.color});
  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('${(percent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: const Color(0xFFECE6F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFB3261E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF49454F))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
