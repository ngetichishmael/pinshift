class MockLocationStatus {
  const MockLocationStatus({
    required this.developerOptionsEnabled,
    required this.mockAppSelected,
    required this.locationPermissionGranted,
    required this.notificationPermissionGranted,
    required this.simulating,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.jitterMeters,
    this.spoofHardening = false,
    this.error,
  });

  final bool developerOptionsEnabled;
  final bool mockAppSelected;
  final bool locationPermissionGranted;
  final bool notificationPermissionGranted;
  final bool simulating;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? jitterMeters;
  final bool spoofHardening;
  final String? error;

  bool get canSimulate =>
      developerOptionsEnabled && mockAppSelected && locationPermissionGranted;

  factory MockLocationStatus.unknown() {
    return const MockLocationStatus(
      developerOptionsEnabled: false,
      mockAppSelected: false,
      locationPermissionGranted: false,
      notificationPermissionGranted: false,
      simulating: false,
    );
  }

  factory MockLocationStatus.fromMap(Map<dynamic, dynamic> map) {
    return MockLocationStatus(
      developerOptionsEnabled: map['developerOptionsEnabled'] == true,
      mockAppSelected: map['mockAppSelected'] == true,
      locationPermissionGranted: map['locationPermissionGranted'] == true,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] == true,
      simulating: map['simulating'] == true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
      jitterMeters: (map['jitterMeters'] as num?)?.toDouble(),
      spoofHardening: map['spoofHardening'] == true,
      error: map['error'] as String?,
    );
  }

  MockLocationStatus copyWith({
    bool? developerOptionsEnabled,
    bool? mockAppSelected,
    bool? locationPermissionGranted,
    bool? notificationPermissionGranted,
    bool? simulating,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? jitterMeters,
    bool? spoofHardening,
    String? error,
    bool clearError = false,
  }) {
    return MockLocationStatus(
      developerOptionsEnabled:
          developerOptionsEnabled ?? this.developerOptionsEnabled,
      mockAppSelected: mockAppSelected ?? this.mockAppSelected,
      locationPermissionGranted:
          locationPermissionGranted ?? this.locationPermissionGranted,
      notificationPermissionGranted:
          notificationPermissionGranted ?? this.notificationPermissionGranted,
      simulating: simulating ?? this.simulating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      jitterMeters: jitterMeters ?? this.jitterMeters,
      spoofHardening: spoofHardening ?? this.spoofHardening,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
