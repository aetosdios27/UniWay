class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });
}

enum LocationQuality {
  good,
  fair,
  poor,
  lost;

  static LocationQuality fromAccuracy(double meters) {
    if (meters <= 15) return good;
    if (meters <= 35) return fair;
    return poor;
  }
}
