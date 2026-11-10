class CheckoutWindow {
  const CheckoutWindow({
    required this.id,
    required this.label,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int id;
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  String get range =>
      '${_hhmm(startHour, startMinute)} - ${_hhmm(endHour, endMinute)}';
}

String _hhmm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

const checkoutWindows = <CheckoutWindow>[
  CheckoutWindow(
    id: 100,
    label: 'Morning',
    startHour: 8,
    startMinute: 0,
    endHour: 9,
    endMinute: 30,
  ),
  CheckoutWindow(
    id: 200,
    label: 'Evening',
    startHour: 16,
    startMinute: 30,
    endHour: 18,
    endMinute: 30,
  ),
];

const checkoutWeekdays = <int>[
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

/// Next Mon-Fri occurrence of [hour]:[minute] on or after [from] (same offset).
DateTime nextWeekdayAt(DateTime from, int weekday, int hour, int minute) {
  var d = DateTime(from.year, from.month, from.day, hour, minute);
  while (d.weekday != weekday || !d.isAfter(from)) {
    d = DateTime(d.year, d.month, d.day + 1, hour, minute);
  }
  return d;
}
