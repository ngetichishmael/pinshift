import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/timezone_check.dart';

void main() {
  test('flags a large longitude vs offset gap', () {
    expect(
      timezoneLooksMismatched(
        longitude: 139.69,
        deviceOffset: const Duration(hours: 3),
      ),
      isTrue,
    );
  });

  test('accepts a nearby offset', () {
    expect(
      timezoneLooksMismatched(
        longitude: 36.8,
        deviceOffset: const Duration(hours: 3),
      ),
      isFalse,
    );
  });
}
