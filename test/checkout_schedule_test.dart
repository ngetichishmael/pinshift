import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/checkout_schedule.dart';

void main() {
  test('windows match 08:00-09:30 and 16:30-18:30', () {
    expect(checkoutWindows[0].range, '08:00 - 09:30');
    expect(checkoutWindows[1].range, '16:30 - 18:30');
  });

  test('nextWeekdayAt picks the next future occurrence', () {
    final wed = DateTime(2026, 11, 11, 10); // Wednesday
    expect(
      nextWeekdayAt(wed, DateTime.wednesday, 16, 30),
      DateTime(2026, 11, 11, 16, 30),
    );
    expect(
      nextWeekdayAt(wed, DateTime.wednesday, 8, 0),
      DateTime(2026, 11, 18, 8, 0),
    );
    expect(
      nextWeekdayAt(wed, DateTime.monday, 8, 0),
      DateTime(2026, 11, 16, 8, 0),
    );
  });
}
