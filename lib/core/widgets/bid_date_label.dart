import 'package:flutter/material.dart';

class BidDateLabel extends StatelessWidget {
  const BidDateLabel({super.key, required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: Color(0xFF49454F),
          ),
          const SizedBox(width: 6),
          Text(
            _format(date!.toLocal()),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF49454F),
            ),
          ),
        ],
      ),
    );
  }

  static String _format(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final month = months[value.month - 1];
    return '$day $month ${value.year}';
  }
}
