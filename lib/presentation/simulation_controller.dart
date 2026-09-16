import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinshift/core/coordinate_parser.dart';
import 'package:pinshift/core/geo_pin.dart';
import 'package:pinshift/core/mock_location_status.dart';
import 'package:pinshift/data/mock_location_channel.dart';
import 'package:pinshift/data/mock_location_platform.dart';
import 'package:pinshift/data/pin_store.dart';

final mockLocationPlatformProvider = Provider<MockLocationPlatform>((ref) {
  return MethodChannelMockLocation();
});

final pinStoreProvider = Provider<PinStore>((ref) => PinStore());

final simulationControllerProvider =
    NotifierProvider<SimulationController, SimulationViewState>(
      SimulationController.new,
    );

class SimulationViewState {
  const SimulationViewState({
    required this.pin,
    required this.jitterMeters,
    required this.accuracyMeters,
    required this.status,
    this.spoofHardening = false,
    this.busy = false,
    this.searchError,
  });

  final GeoPin pin;
  final double jitterMeters;
  final double accuracyMeters;
  final MockLocationStatus status;
  final bool spoofHardening;
  final bool busy;
  final String? searchError;

  SimulationViewState copyWith({
    GeoPin? pin,
    double? jitterMeters,
    double? accuracyMeters,
    MockLocationStatus? status,
    bool? spoofHardening,
    bool? busy,
    String? searchError,
    bool clearSearchError = false,
  }) {
    return SimulationViewState(
      pin: pin ?? this.pin,
      jitterMeters: jitterMeters ?? this.jitterMeters,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      status: status ?? this.status,
      spoofHardening: spoofHardening ?? this.spoofHardening,
      busy: busy ?? this.busy,
      searchError: clearSearchError ? null : (searchError ?? this.searchError),
    );
  }
}

class SimulationController extends Notifier<SimulationViewState> {
  StreamSubscription<MockLocationStatus>? _statusSub;

  @override
  SimulationViewState build() {
    ref.onDispose(() {
      unawaited(_statusSub?.cancel());
    });
    Future<void>.microtask(_hydrate);
    return const SimulationViewState(
      pin: GeoPin(latitude: 0, longitude: 0, label: 'Drop a pin'),
      jitterMeters: 4,
      accuracyMeters: 5,
      status: MockLocationStatus(
        developerOptionsEnabled: false,
        mockAppSelected: false,
        locationPermissionGranted: false,
        notificationPermissionGranted: false,
        simulating: false,
      ),
    );
  }

  MockLocationPlatform get _platform => ref.read(mockLocationPlatformProvider);
  PinStore get _store => ref.read(pinStoreProvider);

  Future<void> _hydrate() async {
    final storedPin = await _store.loadPin();
    final jitter = await _store.loadJitter();
    final accuracy = await _store.loadAccuracy();
    final spoofHardening = await _store.loadSpoofHardening();
    MockLocationStatus status;
    try {
      status = await _platform.getStatus();
    } catch (_) {
      status = MockLocationStatus.unknown();
    }

    var pin = storedPin;
    if (pin == null && status.simulating && status.latitude != null) {
      pin = GeoPin(
        latitude: status.latitude!,
        longitude: status.longitude!,
        label: 'Simulating',
      );
    }
    pin ??= const GeoPin(latitude: 0, longitude: 0, label: 'Drop a pin');

    state = state.copyWith(
      pin: pin,
      jitterMeters: jitter,
      accuracyMeters: accuracy,
      spoofHardening: spoofHardening,
      status: status,
    );

    await _statusSub?.cancel();
    _statusSub = _platform.watchStatus().listen((next) {
      state = state.copyWith(status: next);
    });
  }

  Future<void> refreshStatus() async {
    state = state.copyWith(status: await _platform.getStatus());
  }

  Future<void> setPin(GeoPin pin) async {
    state = state.copyWith(pin: pin, clearSearchError: true);
    await _store.savePin(pin);
    if (state.status.simulating) {
      state = state.copyWith(
        status: await _platform.start(
          latitude: pin.latitude,
          longitude: pin.longitude,
          accuracyMeters: state.accuracyMeters,
          jitterMeters: state.jitterMeters,
          spoofHardening: state.spoofHardening,
        ),
      );
    }
  }

  Future<void> setJitter(double meters) async {
    state = state.copyWith(jitterMeters: meters);
    await _store.saveJitter(meters);
  }

  Future<void> lookup(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final parsed = parseCoordinates(trimmed);
    if (parsed != null) {
      await setPin(
        GeoPin(
          latitude: parsed.latitude,
          longitude: parsed.longitude,
          label: 'Coordinates',
        ),
      );
      return;
    }

    state = state.copyWith(busy: true, clearSearchError: true);
    try {
      final results = await Geocoding().locationFromAddress(trimmed);
      if (results.isEmpty) {
        state = state.copyWith(
          busy: false,
          searchError: 'No place matched that search.',
        );
        return;
      }
      final first = results.first;
      await setPin(
        GeoPin(
          latitude: first.latitude,
          longitude: first.longitude,
          label: trimmed,
        ),
      );
      state = state.copyWith(busy: false);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        searchError: 'Search failed. Check the network and try again.',
      );
    }
  }

  Future<void> centerOnDevice() async {
    state = state.copyWith(busy: true, clearSearchError: true);
    try {
      final permission = await Permission.location.request();
      if (!permission.isGranted) {
        state = state.copyWith(
          busy: false,
          searchError: 'Location permission is required to read the device.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await setPin(
        GeoPin(
          latitude: position.latitude,
          longitude: position.longitude,
          label: 'Device',
        ),
      );
      state = state.copyWith(busy: false);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        searchError: 'Could not read the device location.',
      );
    }
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
    await Permission.location.request();
    await refreshStatus();
  }

  Future<void> setSpoofHardening(bool enabled) async {
    state = state.copyWith(spoofHardening: enabled);
    await _store.saveSpoofHardening(enabled);
    if (state.status.simulating) {
      state = state.copyWith(
        status: await _platform.start(
          latitude: state.pin.latitude,
          longitude: state.pin.longitude,
          accuracyMeters: state.accuracyMeters,
          jitterMeters: state.jitterMeters,
          spoofHardening: enabled,
        ),
      );
    }
  }

  Future<void> start() async {
    await requestPermissions();
    state = state.copyWith(busy: true, clearSearchError: true);
    final status = await _platform.start(
      latitude: state.pin.latitude,
      longitude: state.pin.longitude,
      accuracyMeters: state.accuracyMeters,
      jitterMeters: state.jitterMeters,
      spoofHardening: state.spoofHardening,
    );
    state = state.copyWith(busy: false, status: status);
  }

  Future<void> stop() async {
    state = state.copyWith(busy: true);
    final status = await _platform.stop();
    state = state.copyWith(busy: false, status: status);
  }

  Future<void> openDeveloperSettings() => _platform.openDeveloperSettings();

  Future<void> openAppSettings() => _platform.openAppSettings();
}
