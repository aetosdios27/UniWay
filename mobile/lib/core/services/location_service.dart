import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;
  final bool isPermissionDenied;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.error,
    this.isPermissionDenied = false,
  });

  bool get isSuccess => latitude != null && longitude != null && error == null;
}

class LocationService {
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(
        error: 'Location services are disabled on this device',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          error: 'Location permission denied',
          isPermissionDenied: true,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
        error: 'Location permissions are permanently denied. Please enable them in settings.',
        isPermissionDenied: true,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return LocationResult(
        error: 'Failed to acquire GPS fix: ${e.toString()}',
      );
    }
  }
}
