import 'dart:math' as math;
import '../utils/geo_distance.dart';
import 'location_fix.dart';

/// Gates raw GPS fixes and publishes a smoothed position.
///
/// Each axis of a local meter frame (anchored at the first fix) is a
/// constant-velocity Kalman filter: state = [position, velocity], white-noise
/// acceleration with sigma 1 m/s^2 (walking), measurement variance = accuracy^2.
/// Gates run before the update: a weak fix while a good one is held is ignored,
/// an implied speed above 12 m/s is rejected unless the fix is at least as
/// accurate, and a fix inside the dead zone keeps the published position still
/// (only its accuracy and timestamp change).
class LocationFilter {
  static const _weakAbsoluteMeters = 50.0;
  static const _weakRelativeFactor = 3.0;
  static const _maxSpeedMps = 12.0;
  static const _deadZoneMinMeters = 2.0;
  static const _deadZoneAccuracyFactor = 0.5;
  static const _minAccuracyMeters = 1.0;
  static const _accelVariance = 1.0;
  static const _initialSpeedVariance = 1.4 * 1.4;
  static const _metersPerDegree = 6371000.0 * math.pi / 180;

  LocationFix? _published;
  double _originLat = 0;
  double _originLng = 0;
  double _cosOriginLat = 1;
  final _Axis _east = _Axis();
  final _Axis _north = _Axis();

  /// Returns the fix to publish for [raw], or null when [raw] is ignored.
  LocationFix? accept(LocationFix raw) {
    final accuracy = math.max(raw.accuracyMeters, _minAccuracyMeters);
    final published = _published;
    if (published == null) {
      _originLat = raw.latitude;
      _originLng = raw.longitude;
      _cosOriginLat = math.cos(raw.latitude * math.pi / 180);
      _east.reset(accuracy * accuracy, _initialSpeedVariance);
      _north.reset(accuracy * accuracy, _initialSpeedVariance);
      _published = raw;
      return raw;
    }

    final publishedAccuracy = math.max(published.accuracyMeters, _minAccuracyMeters);
    if (accuracy > _weakRelativeFactor * publishedAccuracy && accuracy > _weakAbsoluteMeters) {
      return null;
    }

    final elapsed = raw.timestamp.difference(published.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsed < 0) return null;

    final distance = haversineMeters(
      published.latitude,
      published.longitude,
      raw.latitude,
      raw.longitude,
    );
    if (accuracy > publishedAccuracy && distance > _maxSpeedMps * elapsed) return null;

    final variance = accuracy * accuracy;
    _east.predict(elapsed, _accelVariance);
    _north.predict(elapsed, _accelVariance);
    _east.update((raw.longitude - _originLng) * _metersPerDegree * _cosOriginLat, variance);
    _north.update((raw.latitude - _originLat) * _metersPerDegree, variance);

    final deadZone = math.max(_deadZoneMinMeters, _deadZoneAccuracyFactor * accuracy);
    final held = distance <= deadZone;
    final latitude = held ? published.latitude : _originLat + _north.position / _metersPerDegree;
    final longitude = held
        ? published.longitude
        : _originLng + _east.position / (_metersPerDegree * _cosOriginLat);
    _published = LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: raw.accuracyMeters,
      timestamp: raw.timestamp,
    );
    return _published;
  }

  void reset() {
    _published = null;
  }
}

class _Axis {
  double position = 0;
  double _velocity = 0;
  double _positionVariance = 0;
  double _covariance = 0;
  double _velocityVariance = 0;

  void reset(double positionVariance, double initialVelocityVariance) {
    position = 0;
    _velocity = 0;
    _positionVariance = positionVariance;
    _covariance = 0;
    _velocityVariance = initialVelocityVariance;
  }

  void predict(double dt, double accelVariance) {
    final dt2 = dt * dt;
    position += _velocity * dt;
    _positionVariance +=
        2 * dt * _covariance + dt2 * _velocityVariance + accelVariance * dt2 * dt2 / 4;
    _covariance += dt * _velocityVariance + accelVariance * dt * dt2 / 2;
    _velocityVariance += accelVariance * dt2;
  }

  void update(double measured, double measurementVariance) {
    final innovationVariance = _positionVariance + measurementVariance;
    final gainPosition = _positionVariance / innovationVariance;
    final gainVelocity = _covariance / innovationVariance;
    final innovation = measured - position;
    position += gainPosition * innovation;
    _velocity += gainVelocity * innovation;
    _velocityVariance -= gainVelocity * _covariance;
    _covariance *= 1 - gainPosition;
    _positionVariance *= 1 - gainPosition;
  }
}
