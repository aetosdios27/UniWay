import 'dart:math' as math;

const _earthRadiusMeters = 6371000.0;

/// Great-circle distance in meters between two WGS84 coordinates.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final sinLat = math.sin(_toRadians(lat2 - lat1) / 2);
  final sinLng = math.sin(_toRadians(lng2 - lng1) / 2);
  final a = sinLat * sinLat +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * sinLng * sinLng;
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
