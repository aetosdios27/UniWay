import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/core/services/location_snapshot.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';

const _lat = 26.8438;
const _lng = 75.5652;
const _lostTimeout = Duration(seconds: 5);
final _t0 = DateTime.utc(2026, 10, 19, 10);

class FakeLocationService implements LocationService {
  StreamController<LocationFix>? _current;
  int positionStreamCalls = 0;
  int getCurrentLocationCalls = 0;

  bool get isListening => _current?.hasListener ?? false;

  void emit(LocationFix fix) => _current!.add(fix);

  void fail(LocationUnavailableReason reason) => _current!.addError(LocationException(reason));

  void close() => unawaited(_current?.close());

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationResult> getCurrentLocation() async {
    getCurrentLocationCalls++;
    return const LocationResult(error: 'not stubbed');
  }

  @override
  Stream<LocationFix> positionStream() {
    positionStreamCalls++;
    _current = StreamController<LocationFix>();
    return _current!.stream;
  }
}

class FakeRoutingRepository implements RoutingRepository {
  final List<double?> routeStartLats = [];

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return const DestinationsResult(destinations: [_destination], statusCode: 200);
  }

  @override
  Future<MapPoisResult> getMapPois({
    required String campusId,
    String? category,
  }) async {
    return const MapPoisResult(pois: [], statusCode: 200);
  }

  @override
  Future<RoutingResult> getRoute({
    required String campusId,
    Destination? origin,
    double? fromLng,
    double? fromLat,
    required Destination destination,
    bool accessible = false,
  }) async {
    routeStartLats.add(fromLat);
    return const RoutingResult(statusCode: 200, latencyMs: 1, errorMessage: 'stub');
  }

  @override
  void dispose() {}
}

const _destination = Destination(
  id: 'DEST_1',
  routingNodeId: 'OUT_DOME_0_001',
  name: 'Dome Entrance',
  category: 'academic',
  latitude: 26.843,
  longitude: 75.565,
);

LocationFix _fix({
  double north = 0,
  required double accuracy,
  Duration at = Duration.zero,
}) {
  return LocationFix(
    latitude: _lat + north / 111194.93,
    longitude: _lng,
    accuracyMeters: accuracy,
    timestamp: _t0.add(at),
  );
}

RoutingController _controller(FakeLocationService service, FakeRoutingRepository repo) {
  return RoutingController(
    repository: repo,
    locationService: service,
    lostTimeout: _lostTimeout,
  );
}

void main() {
  group('RoutingController location', () {
    testWidgets('startLocationUpdates is idempotent and listens once', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      expect(controller.locationListenable.value, isNull);
      expect(controller.locationQuality, isNull);

      controller.startLocationUpdates();
      controller.startLocationUpdates();

      expect(service.positionStreamCalls, 1);
      expect(service.isListening, isTrue);

      controller.dispose();
      service.close();
    });

    testWidgets('publishes a snapshot and keeps the existing getters in step', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      final fix = _fix(accuracy: 8);
      service.emit(fix);
      await tester.pump();

      final snapshot = controller.locationListenable.value!;
      expect(snapshot.latitude, _lat);
      expect(snapshot.accuracyMeters, 8);
      expect(snapshot.quality, LocationQuality.good);
      expect(snapshot.timestamp, fix.timestamp);
      expect(snapshot.isStale, isFalse);
      expect(snapshot.unavailableReason, isNull);
      expect(controller.userLatitude, _lat);
      expect(controller.userAccuracyMeters, 8);
      expect(controller.lastLocationFixAt, fix.timestamp);

      controller.dispose();
      service.close();
    });

    testWidgets('fine position updates do not notify the controller', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();
      await tester.pump();
      var controllerNotifications = 0;
      var snapshotUpdates = 0;
      controller.addListener(() => controllerNotifications++);
      controller.locationListenable.addListener(() => snapshotUpdates++);

      service.emit(_fix(accuracy: 8));
      await tester.pump();
      expect(controllerNotifications, 1);

      service.emit(_fix(north: 20, accuracy: 8, at: const Duration(seconds: 2)));
      await tester.pump();

      expect(controllerNotifications, 1);
      expect(snapshotUpdates, 2);

      controller.dispose();
      service.close();
    });

    testWidgets('publishes at most once per interval and flushes the latest fix', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();
      var snapshotUpdates = 0;
      controller.locationListenable.addListener(() => snapshotUpdates++);

      service.emit(_fix(accuracy: 8));
      await tester.pump();
      expect(snapshotUpdates, 1);

      for (final ms in [50, 100, 150]) {
        service.emit(_fix(accuracy: 8, at: Duration(milliseconds: ms)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(snapshotUpdates, 1);

      await tester.pump(const Duration(milliseconds: 50));
      expect(snapshotUpdates, 2);
      expect(controller.locationListenable.value!.timestamp, _t0.add(const Duration(milliseconds: 150)));

      controller.dispose();
      service.close();
    });

    testWidgets('a weak fix after a good one keeps the position and drops quality', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 5));
      await tester.pump();
      service.emit(_fix(north: 100, accuracy: 60, at: const Duration(seconds: 2)));
      await tester.pump();

      expect(controller.userLatitude, _lat);
      expect(controller.locationQuality, LocationQuality.poor);
      expect(controller.locationListenable.value!.quality, LocationQuality.poor);

      controller.dispose();
      service.close();
    });

    testWidgets('marks the location lost after the timeout and keeps the last position', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 8));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(controller.isLocationLost, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(controller.isLocationLost, isTrue);
      final snapshot = controller.locationListenable.value!;
      expect(snapshot.quality, LocationQuality.lost);
      expect(snapshot.isStale, isTrue);
      expect(snapshot.unavailableReason, LocationUnavailableReason.signalLost);
      expect(controller.userLatitude, _lat);

      controller.dispose();
      service.close();
    });

    testWidgets('a live stream of weak fixes still goes stale once the position is too old', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      service.emit(_fix(north: 100, accuracy: 60, at: const Duration(seconds: 4)));
      await tester.pump();
      expect(controller.isLocationLost, isFalse);

      await tester.pump(const Duration(seconds: 4));
      service.emit(_fix(north: 100, accuracy: 60, at: const Duration(seconds: 8)));
      await tester.pump();
      expect(controller.isLocationLost, isTrue);
      expect(controller.locationListenable.value!.isStale, isTrue);

      controller.dispose();
      service.close();
    });

    testWidgets('recovers to a good quality on the next fix', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 8));
      await tester.pump(const Duration(seconds: 6));
      expect(controller.isLocationLost, isTrue);

      service.emit(_fix(accuracy: 10, at: const Duration(seconds: 7)));
      await tester.pump();

      expect(controller.isLocationLost, isFalse);
      expect(controller.locationQuality, LocationQuality.good);
      expect(controller.locationListenable.value!.isStale, isFalse);
      expect(controller.unavailableReason, isNull);

      controller.dispose();
      service.close();
    });

    testWidgets('a stream error marks the location lost and keeps the last position', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 8));
      await tester.pump();
      service.fail(LocationUnavailableReason.signalLost);
      await tester.pump();

      expect(controller.isLocationLost, isTrue);
      expect(controller.userLatitude, _lat);
      expect(controller.userAccuracyMeters, 8);

      controller.dispose();
      service.close();
    });

    testWidgets('service-disabled errors retry with capped exponential backoff and then stop', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.fail(LocationUnavailableReason.serviceDisabled);
      await tester.pump();
      expect(controller.unavailableReason, LocationUnavailableReason.serviceDisabled);
      expect(service.positionStreamCalls, 1);

      await tester.pump(locationRetryBaseDelay);
      expect(service.positionStreamCalls, 2);

      service.fail(LocationUnavailableReason.serviceDisabled);
      await tester.pump(const Duration(seconds: 1));
      expect(service.positionStreamCalls, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(service.positionStreamCalls, 3);

      for (var i = 0; i < 12; i++) {
        if (service.isListening) service.fail(LocationUnavailableReason.serviceDisabled);
        await tester.pump(locationRetryMaxDelay);
      }
      expect(service.positionStreamCalls, 3 + 12);

      controller.dispose();
      service.close();
    });

    testWidgets('a permission denial is reported and not retried', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.fail(LocationUnavailableReason.permissionDenied);
      await tester.pump();
      await tester.pump(locationRetryMaxDelay);

      expect(controller.unavailableReason, LocationUnavailableReason.permissionDenied);
      expect(controller.isLocationLost, isTrue);
      expect(service.positionStreamCalls, 1);

      controller.dispose();
      service.close();
    });

    testWidgets('leaving the foreground cancels the stream and resuming restarts it with a fresh filter', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 5));
      await tester.pump();

      controller.onAppLifecycleChanged(AppLifecycleState.paused);
      expect(service.isListening, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(controller.isLocationLost, isFalse);
      expect(service.positionStreamCalls, 1);

      controller.onAppLifecycleChanged(AppLifecycleState.resumed);
      expect(service.positionStreamCalls, 2);
      expect(service.isListening, isTrue);
      expect(controller.locationListenable.value!.isStale, isTrue);

      // 500 m away with worse accuracy would be a teleport, but the filter was reset on resume.
      service.emit(_fix(north: 500, accuracy: 8, at: const Duration(seconds: 2)));
      await tester.pump();
      expect(controller.userLatitude, closeTo(_lat + 500 / 111194.93, 1e-9));
      expect(controller.locationListenable.value!.isStale, isFalse);

      controller.dispose();
      service.close();
    });

    testWidgets('stopLocationUpdates cancels the stream and its timers', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();
      service.emit(_fix(accuracy: 8));
      await tester.pump();

      controller.stopLocationUpdates();
      expect(service.isListening, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(controller.isLocationLost, isFalse);

      controller.startLocationUpdates();
      expect(service.positionStreamCalls, 2);

      controller.dispose();
      service.close();
    });

    testWidgets('dispose cancels the subscription and every timer', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());
      controller.startLocationUpdates();
      service.emit(_fix(accuracy: 8));
      service.emit(_fix(north: 1, accuracy: 8, at: const Duration(milliseconds: 50)));
      await tester.pump();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispose();

      expect(service.isListening, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(notifications, 0);
      service.close();
    });

    testWidgets('fetchRoute uses the stream-fed location without querying GPS', (tester) async {
      final service = FakeLocationService();
      final repo = FakeRoutingRepository();
      final controller = _controller(service, repo);
      await tester.pump();
      controller.startLocationUpdates();

      service.emit(_fix(accuracy: 8));
      await tester.pump();
      await controller.fetchRoute();

      expect(service.getCurrentLocationCalls, 0);
      expect(repo.routeStartLats.single, closeTo(_lat, 1e-9));

      controller.dispose();
      service.close();
    });

    testWidgets('setUserLocation without accuracy sets the position but no snapshot', (tester) async {
      final service = FakeLocationService();
      final controller = _controller(service, FakeRoutingRepository());

      controller.setUserLocation(_lat, _lng);

      expect(controller.userLatitude, _lat);
      expect(controller.userAccuracyMeters, isNull);
      expect(controller.locationQuality, isNull);
      expect(controller.locationListenable.value, isNull);

      controller.dispose();
    });
  });
}
