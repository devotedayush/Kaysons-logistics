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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              _RoutePointView(point: visible[i], index: i),
              if (i != visible.length - 1) const _Connector(),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoutePointView extends StatelessWidget {
  const _RoutePointView({required this.point, required this.index});

  final RoutePoint point;
  final int index;

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
    final label = switch (point.kind) {
      RoutePointKind.origin => 'From',
      RoutePointKind.stop => 'Stop $index',
      RoutePointKind.destination => 'To',
    };

    return SizedBox(
      width: 136,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF49454F),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            point.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1B20),
            ),
          ),
          if (point.meta != null && point.meta!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              point.meta!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF49454F)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
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
