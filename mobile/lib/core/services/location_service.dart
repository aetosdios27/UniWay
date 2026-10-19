import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_fix.dart';
import 'location_snapshot.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? error;
  final bool isPermissionDenied;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.error,
    this.isPermissionDenied = false,
  });

  bool get isSuccess => latitude != null && longitude != null && error == null;
}

class LocationException implements Exception {
  final LocationUnavailableReason reason;

  const LocationException(this.reason);

  @override
  String toString() => 'LocationException: ${reason.name}';
}

class LocationService {
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationResult> getCurrentLocation() async {
    final problem = await _accessProblem();
    if (problem != null) return _failure(problem);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (e) {
      return LocationResult(
        error: 'Failed to acquire GPS fix: ${e.toString()}',
      );
    }
  }

  Stream<LocationFix> positionStream() async* {
    final problem = await _accessProblem();
    if (problem != null) throw LocationException(problem);

    yield* Geolocator.getPositionStream(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 2),
            )
          : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
    ).map(
      (position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      ),
    );
  }

  Future<LocationUnavailableReason?> _accessProblem() async {
    if (!await isLocationServiceEnabled()) {
      return LocationUnavailableReason.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationUnavailableReason.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationUnavailableReason.permissionDeniedForever;
    }

    return null;
  }

  static LocationResult _failure(LocationUnavailableReason reason) {
    switch (reason) {
      case LocationUnavailableReason.serviceDisabled:
        return const LocationResult(
          error: 'Location services are disabled on this device',
        );
      case LocationUnavailableReason.permissionDenied:
        return const LocationResult(
          error: 'Location permission denied',
          isPermissionDenied: true,
        );
      case LocationUnavailableReason.permissionDeniedForever:
        return const LocationResult(
          error: 'Location permissions are permanently denied. Please enable them in settings.',
          isPermissionDenied: true,
        );
      case LocationUnavailableReason.signalLost:
        return const LocationResult(error: 'Location signal lost');
    }
  }
}
