import 'package:latlong2/latlong.dart';

class GeoPin {
  const GeoPin({required this.latitude, required this.longitude, this.label});

  final double latitude;
  final double longitude;
  final String? label;

  LatLng get latLng => LatLng(latitude, longitude);

  GeoPin copyWith({
    double? latitude,
    double? longitude,
    String? label,
    bool clearLabel = false,
  }) {
    return GeoPin(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: clearLabel ? null : (label ?? this.label),
    );
  }

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'label': label,
  };

  factory GeoPin.fromJson(Map<String, dynamic> json) {
    return GeoPin(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GeoPin &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, label);
}
