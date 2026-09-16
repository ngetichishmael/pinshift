import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/browser_presets.dart';

void main() {
  test('adds https when the scheme is missing', () {
    expect(
      parseBrowseUrl('hrms.shinraitechnologies.io')?.host,
      'hrms.shinraitechnologies.io',
    );
    expect(parseBrowseUrl('hrms.shinraitechnologies.io')?.scheme, 'https');
  });

  test('rejects empty and schemeless junk', () {
    expect(parseBrowseUrl(''), isNull);
    expect(parseBrowseUrl('   '), isNull);
  });
}
