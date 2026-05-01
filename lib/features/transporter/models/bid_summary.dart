class BidSummary {
  const BidSummary({
    required this.id,
    required this.fromTown,
    required this.toTown,
    required this.cases,
    required this.weight,
    required this.freight,
    required this.bidders,
    required this.timeLeftMinutes,
  });

  final String id;
  final String fromTown;
  final String toTown;
  final int cases;
  final int weight;
  final int freight;
  final int bidders;
  final int timeLeftMinutes;

  String get route => '$fromTown → $toTown';
  String get summary => '$cases QT - $weight WT - $freight Freight';

  String get timeLeftLabel {
    if (timeLeftMinutes >= 60) {
      final h = timeLeftMinutes ~/ 60;
      final m = timeLeftMinutes % 60;
      return '$h hour${h == 1 ? '' : 's'} $m min left';
    }
    return '$timeLeftMinutes min left';
  }

  bool get isUrgent => timeLeftMinutes < 30;
}

class WonBidSummary {
  const WonBidSummary({
    required this.route,
    required this.status,
  });

  final String route;
  final String status;
}

const sampleLatestBids = <BidSummary>[
  BidSummary(
    id: 'B-1001',
    fromTown: 'Hoshi.',
    toTown: 'Ludhi.',
    cases: 174,
    weight: 34,
    freight: 6500,
    bidders: 13,
    timeLeftMinutes: 83,
  ),
  BidSummary(
    id: 'B-1002',
    fromTown: 'Jala.',
    toTown: 'Amrit.',
    cases: 160,
    weight: 28,
    freight: 5900,
    bidders: 11,
    timeLeftMinutes: 22,
  ),
];

const sampleWonBids = <WonBidSummary>[
  WonBidSummary(route: 'BATAL → PATH.', status: 'Awaiting Vehicle.'),
  WonBidSummary(route: 'DELHI → GHAZI.', status: 'Awaiting Vehicle'),
  WonBidSummary(route: 'SRINA. → AMRI.', status: 'Penalised'),
  WonBidSummary(route: 'BATAL → PATH.', status: 'Delivered'),
  WonBidSummary(route: 'DELHI → GHAZI.', status: 'Delivered'),
];
