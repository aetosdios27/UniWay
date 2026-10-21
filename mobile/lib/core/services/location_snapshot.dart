import 'location_fix.dart';

enum LocationUnavailableReason { serviceDisabled, permissionDenied, permissionDeniedForever, signalLost }

class LocationSnapshot {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final LocationQuality quality;
  final DateTime timestamp;
  final bool isStale;
  final LocationUnavailableReason? unavailableReason;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.quality,
    required this.timestamp,
    required this.isStale,
    this.unavailableReason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSnapshot &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracyMeters == other.accuracyMeters &&
          quality == other.quality &&
          timestamp == other.timestamp &&
          isStale == other.isStale &&
          unavailableReason == other.unavailableReason;

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        accuracyMeters,
        quality,
        timestamp,
        isStale,
        unavailableReason,
      );
}
