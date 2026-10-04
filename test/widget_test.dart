import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinshift/app.dart';
import 'package:pinshift/core/mock_location_status.dart';
import 'package:pinshift/data/mock_location_platform.dart';
import 'package:pinshift/presentation/simulation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlatform implements MockLocationPlatform {
  final _controller = StreamController<MockLocationStatus>.broadcast();
  MockLocationStatus status = const MockLocationStatus(
    developerOptionsEnabled: false,
    mockAppSelected: false,
    locationPermissionGranted: false,
    notificationPermissionGranted: true,
    simulating: false,
  );

  @override
  Future<MockLocationStatus> getStatus() async => status;

  @override
  Stream<MockLocationStatus> watchStatus() => _controller.stream;

  @override
  Future<MockLocationStatus> start({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double jitterMeters,
    bool spoofHardening = false,
    double altitudeMeters = 0.0,
  }) async {
    status = status.copyWith(
      error: 'Select Pinshift as the mock location app.',
    );
    return status;
  }

  @override
  Future<MockLocationStatus> stop() async => status;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openDeveloperSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows setup copy before simulation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakePlatform();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockLocationPlatformProvider.overrideWithValue(fake)],
        child: const PinshiftApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.textContaining('Setup needed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GPS only'), findsOneWidget);
    expect(find.text('Start simulation'), findsOneWidget);
  });
}
