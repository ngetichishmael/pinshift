class ParsedCoordinates {
  const ParsedCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

final _coordPattern = RegExp(
  r'^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$',
);

/// Parses `lat, lng` or `lat lng`. Returns null when the text is a place query.
ParsedCoordinates? parseCoordinates(String raw) {
  final match = _coordPattern.firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final latitude = double.parse(match.group(1)!);
  final longitude = double.parse(match.group(2)!);
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return ParsedCoordinates(latitude, longitude);
}
