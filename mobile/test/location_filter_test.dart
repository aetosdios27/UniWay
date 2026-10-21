import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_filter.dart';

const _baseLat = 26.8438;
const _baseLng = 75.5652;
const _metersPerDegree = 6371000 * math.pi / 180;
final _t0 = DateTime.utc(2026, 10, 19, 10);

LocationFix _fix({
  double north = 0,
  double east = 0,
  required double accuracy,
  required int seconds,
}) {
  final lat = _baseLat + north / _metersPerDegree;
  final lng = _baseLng + east / (_metersPerDegree * math.cos(_baseLat * math.pi / 180));
  return LocationFix(
    latitude: lat,
    longitude: lng,
    accuracyMeters: accuracy,
    timestamp: _t0.add(Duration(seconds: seconds)),
  );
}

double _northOf(LocationFix fix) => (fix.latitude - _baseLat) * _metersPerDegree;

double _eastOf(LocationFix fix) =>
    (fix.longitude - _baseLng) * _metersPerDegree * math.cos(_baseLat * math.pi / 180);

double _gaussian(math.Random rng) {
  final u1 = 1 - rng.nextDouble();
  final u2 = rng.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

void main() {
  group('LocationQuality.fromAccuracy', () {
    test('maps accuracy bands to good, fair and poor', () {
      expect(LocationQuality.fromAccuracy(15), LocationQuality.good);
      expect(LocationQuality.fromAccuracy(15.1), LocationQuality.fair);
      expect(LocationQuality.fromAccuracy(35), LocationQuality.fair);
      expect(LocationQuality.fromAccuracy(35.1), LocationQuality.poor);
    });
  });

  group('LocationFilter', () {
    test('accepts the first fix as-is', () {
      final out = LocationFilter().accept(_fix(north: 40, accuracy: 30, seconds: 0));

      expect(out, isNotNull);
      expect(_northOf(out!), closeTo(40, 0.001));
      expect(out.accuracyMeters, 30);
    });

    group('rule b: weak fix while a good one is held', () {
      test('ignores a fix worse than 3x and worse than 50 m', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        expect(filter.accept(_fix(north: 100, accuracy: 60, seconds: 2)), isNull);
      });

      test('keeps the held position when a weak fix was ignored', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));
        filter.accept(_fix(north: 100, accuracy: 60, seconds: 2));

        final out = filter.accept(_fix(accuracy: 6, seconds: 4));

        expect(out, isNotNull);
        expect(_northOf(out!), closeTo(0, 0.001));
      });

      test('keeps a fix worse than 3x when it is within 50 m', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        final out = filter.accept(_fix(accuracy: 40, seconds: 2));

        expect(out, isNotNull);
        expect(out!.accuracyMeters, 40);
      });

      test('keeps a fix above 50 m when it is within 3x the held accuracy', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 30, seconds: 0));

        final out = filter.accept(_fix(accuracy: 80, seconds: 2));

        expect(out, isNotNull);
        expect(out!.accuracyMeters, 80);
      });

      test('ignores a fix above 3x the held accuracy and above 50 m', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 30, seconds: 0));

        expect(filter.accept(_fix(accuracy: 95, seconds: 2)), isNull);
      });
    });

    group('rule c: teleports', () {
      test('rejects a 150 m jump with poor accuracy', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 8, seconds: 0));

        expect(filter.accept(_fix(east: 150, accuracy: 40, seconds: 1)), isNull);
      });

      test('rejects a 50 m/s jump to a fix that is less accurate', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        expect(filter.accept(_fix(north: 500, accuracy: 8, seconds: 10)), isNull);
      });

      test('accepts an implied 11.8 m/s move to a fix that is less accurate', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        expect(filter.accept(_fix(north: 118, accuracy: 8, seconds: 10)), isNotNull);
      });

      test('rejects an implied 12.5 m/s move to a fix that is less accurate', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        expect(filter.accept(_fix(north: 125, accuracy: 8, seconds: 10)), isNull);
      });

      test('accepts a legitimate 50 m/s move when the new fix is at least as accurate', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        final out = filter.accept(_fix(north: 500, accuracy: 5, seconds: 10));

        // Kalman estimate: prior 500 m -> 495.45 m after one update (gain 0.991)
        expect(out, isNotNull);
        expect(_northOf(out!), closeTo(495.45, 0.1));
      });

      test('ignores a fix older than the last accepted one', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 10));

        expect(filter.accept(_fix(accuracy: 5, seconds: 4)), isNull);
      });
    });

    group('rule d: dead zone', () {
      test('holds the published position and takes the new accuracy inside the dead zone', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 10, seconds: 0));

        final out = filter.accept(_fix(north: 3, accuracy: 8, seconds: 2));

        expect(out, isNotNull);
        expect(_northOf(out!), closeTo(0, 0.001));
        expect(out.accuracyMeters, 8);
      });

      test('uses a 2 m floor when the new accuracy is very good', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 10, seconds: 0));

        final out = filter.accept(_fix(north: 1.5, accuracy: 1, seconds: 2));

        expect(out, isNotNull);
        expect(_northOf(out!), closeTo(0, 0.001));
      });

      test('moves the published position just outside the dead zone', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 10, seconds: 0));

        final out = filter.accept(_fix(north: 5, accuracy: 8, seconds: 2));

        // prior variance 111.84, measurement variance 64: gain 0.636, 5 m * 0.636 = 3.18 m
        expect(_northOf(out!), closeTo(3.18, 0.01));
      });
    });

    group('rule e: constant-velocity Kalman smoothing', () {
      test('pulls toward a fix of equal accuracy by the Kalman gain', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 10, seconds: 0));

        final out = filter.accept(_fix(north: 20, accuracy: 10, seconds: 2));

        // prior variance 111.84, measurement variance 100: gain 0.528, 20 m * 0.528 = 10.56 m
        expect(_northOf(out!), closeTo(10.56, 0.01));
      });

      test('barely moves toward a much worse fix', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));

        final out = filter.accept(_fix(north: 40, accuracy: 40, seconds: 4));

        // prior variance 120.36, measurement variance 1600: gain 0.070, 40 m * 0.070 = 2.80 m
        expect(_northOf(out!), closeTo(2.8, 0.01));
      });

      test('moves most of the way toward a much better fix', () {
        final filter = LocationFilter()..accept(_fix(accuracy: 40, seconds: 0));

        final out = filter.accept(_fix(north: 30, accuracy: 5, seconds: 2));

        // prior variance 1611.84, measurement variance 25: gain 0.985, 30 m * 0.985 = 29.54 m
        expect(_northOf(out!), closeTo(29.54, 0.01));
      });
    });

    test('a noisy stationary sequence publishes at most the first position', () {
      const jitter = [
        (0.0, 0.0, 8.0),
        (1.8, -1.2, 10.0),
        (-1.5, 0.9, 7.0),
        (0.6, 2.1, 12.0),
        (-2.4, -0.3, 9.0),
        (1.1, 1.4, 6.0),
        (-0.7, -1.8, 11.0),
        (2.2, 0.5, 8.0),
        (-1.0, 1.6, 10.0),
        (0.4, -0.9, 7.0),
      ];
      final filter = LocationFilter();
      final published = <(double, double)>{};
      var index = 0;

      for (final (north, east, accuracy) in jitter) {
        final out = filter.accept(_fix(
          north: north,
          east: east,
          accuracy: accuracy,
          seconds: index * 2,
        ));
        index++;

        expect(out, isNotNull, reason: 'stationary fix $index was ignored');
        expect(out!.accuracyMeters, accuracy);
        published.add((out.latitude, out.longitude));
      }

      expect(published, hasLength(1));
      expect(published.single.$1, closeTo(_baseLat, 1e-12));
    });

    test('a 1.4 m/s walk with 10 m noise is tracked better than the raw fixes', () {
      final rng = math.Random(7);
      final filter = LocationFilter();
      var rawSquared = 0.0;
      var filteredSquared = 0.0;
      var samples = 0;
      LocationFix? published;

      for (var t = 0; t <= 300; t++) {
        final trueEast = 1.4 * t;
        final noiseEast = _gaussian(rng) * 10;
        final noiseNorth = _gaussian(rng) * 10;
        final out = filter.accept(_fix(
          east: trueEast + noiseEast,
          north: noiseNorth,
          accuracy: 10,
          seconds: t,
        ));
        published = out ?? published;
        if (t < 20) continue;

        rawSquared += noiseEast * noiseEast + noiseNorth * noiseNorth;
        final eastError = _eastOf(published!) - trueEast;
        final northError = _northOf(published);
        filteredSquared += eastError * eastError + northError * northError;
        samples++;
      }

      final rawRms = math.sqrt(rawSquared / samples);
      final filteredRms = math.sqrt(filteredSquared / samples);
      expect(filteredRms, lessThan(rawRms));
    });

    test('reset makes the next fix a first fix again', () {
      final filter = LocationFilter()..accept(_fix(accuracy: 5, seconds: 0));
      filter.reset();

      final out = filter.accept(_fix(north: 5000, accuracy: 20, seconds: 2));

      expect(out, isNotNull);
      expect(_northOf(out!), closeTo(5000, 0.001));
    });
  });
}
