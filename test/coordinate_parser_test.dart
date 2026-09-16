import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/coordinate_parser.dart';

void main() {
  test('parses comma-separated coordinates', () {
    final parsed = parseCoordinates(' -1.2921, 36.8219 ');
    expect(parsed, isNotNull);
    expect(parsed!.latitude, closeTo(-1.2921, 0.0001));
    expect(parsed.longitude, closeTo(36.8219, 0.0001));
  });

  test('rejects out-of-range values', () {
    expect(parseCoordinates('91, 0'), isNull);
    expect(parseCoordinates('0, 181'), isNull);
  });

  test('leaves place names to geocoding', () {
    expect(parseCoordinates('Nairobi'), isNull);
  });
}
