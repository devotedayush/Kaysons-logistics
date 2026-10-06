import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/utils/bid_window.dart';

void main() {
  test('bid timestamps sent to the database include their UTC offset', () {
    final selected = DateTime(2026, 9, 26, 12, 52);
    final encoded = bidTimestampForDatabase(selected);
    expect(encoded, endsWith('Z'));
    expect(DateTime.parse(encoded).isAtSameMomentAs(selected), isTrue);
  });

  test('bidding is live only inside the actual window', () {
    final opens = DateTime.utc(2026, 9, 26, 7, 22);
    final closes = DateTime.utc(2026, 9, 26, 9, 22);

    expect(
      bidWindowPhase(
        status: 'bidding',
        opensAt: opens,
        closesAt: closes,
        now: opens.subtract(const Duration(seconds: 1)),
      ),
      BidWindowPhase.upcoming,
    );
    expect(
      bidWindowPhase(
        status: 'bidding',
        opensAt: opens,
        closesAt: closes,
        now: opens,
      ),
      BidWindowPhase.live,
    );
    expect(
      bidWindowPhase(
        status: 'bidding',
        opensAt: opens,
        closesAt: closes,
        now: closes,
      ),
      BidWindowPhase.closed,
    );
    expect(
      bidWindowPhase(
        status: 'awarded',
        opensAt: opens,
        closesAt: closes,
        now: opens,
      ),
      BidWindowPhase.closed,
    );
    expect(
      bidWindowLabel(
        status: 'bidding',
        opensAt: opens,
        closesAt: closes,
        now: opens,
      ),
      'Bidding live · 2h 0m left',
    );
  });
}
