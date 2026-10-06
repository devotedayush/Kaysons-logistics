import 'package:flutter/material.dart';

enum RoutePointKind { origin, stop, destination }

class RoutePoint {
  const RoutePoint({required this.label, required this.kind, this.meta});

  final String label;
  final RoutePointKind kind;
  final String? meta;
}

class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.points,
    this.padding = const EdgeInsets.all(14),
  });

  final List<RoutePoint> points;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visible = points
        .where((p) => p.label.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.length < 2) return const SizedBox.shrink();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FC),
        border: Border.all(color: const Color(0xFFE1DAE8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow forms must show every stop without a hidden sideways scroll.
          if (constraints.maxWidth < visible.length * 180) {
            return Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _RoutePointView(point: visible[i], index: i, vertical: true),
                  if (i != visible.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.arrow_downward,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                Expanded(child: _RoutePointView(point: visible[i], index: i)),
                if (i != visible.length - 1) const _Connector(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoutePointView extends StatelessWidget {
  const _RoutePointView({
    required this.point,
    required this.index,
    this.vertical = false,
  });

  final RoutePoint point;
  final int index;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final color = switch (point.kind) {
      RoutePointKind.origin => const Color(0xFF146C2E),
      RoutePointKind.stop => const Color(0xFF6750A4),
      RoutePointKind.destination => const Color(0xFFB3261E),
    };
    final icon = switch (point.kind) {
      RoutePointKind.origin => Icons.trip_origin,
      RoutePointKind.stop => Icons.location_on_outlined,
      RoutePointKind.destination => Icons.flag_outlined,
    };
    final hindi = Localizations.maybeLocaleOf(context)?.languageCode == 'hi';
    final label = switch (point.kind) {
      RoutePointKind.origin => hindi ? 'माल उठाने का स्थान' : 'Pickup',
      RoutePointKind.stop => hindi ? 'पड़ाव $index' : 'Stop $index',
      RoutePointKind.destination => hindi ? 'अंतिम डिलीवरी' : 'Final delivery',
    };
    final marker = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, size: 22, color: color),
    );
    final details = Column(
      crossAxisAlignment:
          vertical ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: const Color(0xFF49454F)),
          textAlign: vertical ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          point.label,
          textAlign: vertical ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (point.meta != null && point.meta!.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            point.meta!,
            textAlign: vertical ? TextAlign.start : TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
    if (vertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            marker,
            const SizedBox(width: 14),
            Expanded(child: details),
          ],
        ),
      );
    }
    return Column(children: [marker, const SizedBox(height: 8), details]);
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      margin: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: const Color(0xFFB9A8CF))),
          const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF6750A4)),
          Expanded(child: Container(height: 2, color: const Color(0xFFB9A8CF))),
        ],
      ),
    );
  }
}
