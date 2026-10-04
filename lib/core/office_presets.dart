import 'package:pinshift/core/geo_pin.dart';
import 'package:pinshift/core/place.dart';

/// Confirmed by Ish from Google Maps (Upper Hill / Kilimanjaro Rd).
/// Source: https://maps.app.goo.gl/nPdHrN4kC2eTQRnAA
const jubileeOfficePin = GeoPin(
  latitude: -1.2988138,
  longitude: 36.8151017,
  label: 'Jubilee office',
);

/// Public Shinrai HQ (Ushuru Pension Plaza). Not the Jubilee site.
const shinraiOfficePin = GeoPin(
  latitude: -1.2606485,
  longitude: 36.7824392,
  label: 'Shinrai office',
);

const cityPresets = [
  GeoPin(latitude: 40.7580,   longitude: -73.9855,  label: 'New York'),
  GeoPin(latitude: 51.5074,   longitude: -0.1278,   label: 'London'),
  GeoPin(latitude: 25.2048,   longitude: 55.2708,   label: 'Dubai'),
  GeoPin(latitude: 1.3521,    longitude: 103.8198,  label: 'Singapore'),
  GeoPin(latitude: 35.6762,   longitude: 139.6503,  label: 'Tokyo'),
  GeoPin(latitude: 48.8566,   longitude: 2.3522,    label: 'Paris'),
  GeoPin(latitude: -33.8688,  longitude: 151.2093,  label: 'Sydney'),
  GeoPin(latitude: -26.1076,  longitude: 28.0567,   label: 'Johannesburg'),
  GeoPin(latitude: 19.0760,   longitude: 72.8777,   label: 'Mumbai'),
  GeoPin(latitude: 6.5244,    longitude: 3.3792,    label: 'Lagos'),
  GeoPin(latitude: 52.3676,   longitude: 4.9041,    label: 'Amsterdam'),
  GeoPin(latitude: 43.6532,   longitude: -79.3832,  label: 'Toronto'),
];

const workPresets = [jubileeOfficePin, shinraiOfficePin];

const officePresets = [...workPresets, ...cityPresets];

List<Place> defaultPlaces() => [
  for (final pin in workPresets)
    Place(id: 'default-${pin.label}', pin: pin, group: PlaceGroup.offices),
  for (final pin in cityPresets)
    Place(id: 'default-${pin.label}', pin: pin, group: PlaceGroup.cities),
];
