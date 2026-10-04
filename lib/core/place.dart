import 'package:pinshift/core/geo_pin.dart';

enum PlaceGroup {
  offices('Offices'),
  cities('Cities');

  const PlaceGroup(this.label);

  final String label;
}

class Place {
  const Place({required this.id, required this.pin, required this.group});

  final String id;
  final GeoPin pin;
  final PlaceGroup group;

  String get name => pin.label ?? '';

  Place copyWith({GeoPin? pin, PlaceGroup? group}) {
    return Place(id: id, pin: pin ?? this.pin, group: group ?? this.group);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'group': group.name,
    'pin': pin.toJson(),
  };

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      group: PlaceGroup.values.firstWhere(
        (g) => g.name == json['group'],
        orElse: () => PlaceGroup.cities,
      ),
      pin: GeoPin.fromJson(json['pin'] as Map<String, dynamic>),
    );
  }
}
