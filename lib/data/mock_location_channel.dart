import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pinshift/core/mock_location_status.dart';
import 'package:pinshift/data/mock_location_platform.dart';

const methodChannelName = 'com.pinshift.pinshift/mock_location';
const eventChannelName = 'com.pinshift.pinshift/mock_location_events';

class MethodChannelMockLocation implements MockLocationPlatform {
  MethodChannelMockLocation({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(methodChannelName),
      _events = events ?? const EventChannel(eventChannelName);

  final MethodChannel _methods;
  final EventChannel _events;

  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;
  static const _unsupportedMessage =
      'Mock location is only available on Android.';

  @override
  Future<MockLocationStatus> getStatus() async {
    if (!_supported) {
      return MockLocationStatus.unknown();
    }
    final raw = await _methods.invokeMapMethod<String, dynamic>('getStatus');
    return MockLocationStatus.fromMap(raw ?? const {});
  }

  @override
  Stream<MockLocationStatus> watchStatus() {
    if (!_supported) {
      return const Stream.empty();
    }
    return _events.receiveBroadcastStream().map((event) {
      return MockLocationStatus.fromMap(
        event is Map ? Map<dynamic, dynamic>.from(event) : const {},
      );
    });
  }

  @override
  Future<MockLocationStatus> start({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double jitterMeters,
    bool spoofHardening = false,
    double altitudeMeters = 0.0,
  }) async {
    if (!_supported) {
      return MockLocationStatus.unknown().copyWith(error: _unsupportedMessage);
    }
    try {
      final raw = await _methods.invokeMapMethod<String, dynamic>('start', {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'jitterMeters': jitterMeters,
        'spoofHardening': spoofHardening,
        'altitudeMeters': altitudeMeters,
      });
      return MockLocationStatus.fromMap(raw ?? const {});
    } on PlatformException catch (error) {
      final details = error.details;
      if (details is Map) {
        return MockLocationStatus.fromMap(
          details,
        ).copyWith(error: error.message);
      }
      return MockLocationStatus.unknown().copyWith(error: error.message);
    }
  }

  @override
  Future<MockLocationStatus> stop() async {
    if (!_supported) {
      return MockLocationStatus.unknown();
    }
    final raw = await _methods.invokeMapMethod<String, dynamic>('stop');
    return MockLocationStatus.fromMap(raw ?? const {});
  }

  @override
  Future<void> openDeveloperSettings() async {
    if (!_supported) {
      return;
    }
    await _methods.invokeMethod<void>('openDeveloperSettings');
  }

  @override
  Future<void> openAppSettings() async {
    if (!_supported) {
      return;
    }
    await _methods.invokeMethod<void>('openAppSettings');
  }
}
