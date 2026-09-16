import 'package:pinshift/core/mock_location_status.dart';

abstract class MockLocationPlatform {
  Future<MockLocationStatus> getStatus();

  Stream<MockLocationStatus> watchStatus();

  Future<MockLocationStatus> start({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double jitterMeters,
    bool spoofHardening = false,
    double altitudeMeters = 0.0,
  });

  Future<MockLocationStatus> stop();

  Future<void> openDeveloperSettings();

  Future<void> openAppSettings();
}
