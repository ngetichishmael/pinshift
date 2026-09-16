/// Crude solar-offset check. DST and national zones make this a hint, not truth.
bool timezoneLooksMismatched({
  required double longitude,
  required Duration deviceOffset,
  int thresholdHours = 3,
}) {
  final expectedHours = (longitude / 15).round().clamp(-12, 14);
  final deviceHours = (deviceOffset.inMinutes / 60.0).round();
  return (expectedHours - deviceHours).abs() >= thresholdHours;
}
