import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/bid_window.dart';

class BidWindowCountdown extends StatefulWidget {
  const BidWindowCountdown({
    super.key,
    required this.status,
    required this.opensAt,
    required this.closesAt,
    this.style,
  });

  final String status;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final TextStyle? style;

  @override
  State<BidWindowCountdown> createState() => _BidWindowCountdownState();
}

class _BidWindowCountdownState extends State<BidWindowCountdown> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    bidWindowLabel(
      status: widget.status,
      opensAt: widget.opensAt,
      closesAt: widget.closesAt,
    ),
    style: widget.style,
  );
}
