enum BidWindowPhase { upcoming, live, closed }

DateTime? bidTimestamp(Object? value) =>
    DateTime.tryParse((value ?? '').toString());

/// Send an unambiguous instant to PostgreSQL's timestamptz columns.
String bidTimestampForDatabase(DateTime value) =>
    value.toUtc().toIso8601String();

BidWindowPhase bidWindowPhase({
  required String status,
  DateTime? opensAt,
  DateTime? closesAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  if (status != 'bidding' ||
      (closesAt != null && !current.isBefore(closesAt))) {
    return BidWindowPhase.closed;
  }
  if (opensAt != null && current.isBefore(opensAt)) {
    return BidWindowPhase.upcoming;
  }
  return BidWindowPhase.live;
}

String bidTimeRemaining(DateTime until, {DateTime? now}) {
  final seconds = until.difference(now ?? DateTime.now()).inSeconds;
  final minutes = seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
  final hours = minutes ~/ 60;
  final minutePart = minutes % 60;
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutePart}m';
}

String bidWindowLabel({
  required String status,
  DateTime? opensAt,
  DateTime? closesAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  switch (bidWindowPhase(
    status: status,
    opensAt: opensAt,
    closesAt: closesAt,
    now: current,
  )) {
    case BidWindowPhase.upcoming:
      return 'Opens in ${bidTimeRemaining(opensAt!, now: current)}';
    case BidWindowPhase.live:
      return closesAt == null
          ? 'Bidding live'
          : 'Bidding live · ${bidTimeRemaining(closesAt, now: current)} left';
    case BidWindowPhase.closed:
      return 'Bidding closed';
  }
}
