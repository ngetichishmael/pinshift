import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/office_presets.dart';

void main() {
  test('Jubilee pin is the Upper Hill Google coordinate', () {
    expect(jubileeOfficePin.latitude, closeTo(-1.2988138, 0.0000001));
    expect(jubileeOfficePin.longitude, closeTo(36.8151017, 0.0000001));
    expect(jubileeOfficePin.label, 'Jubilee office');
  });
}
