import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';

class MockLocationService implements LocationService {
  bool isEnabled = true;
  double mockLat = 26.8438;
  double mockLng = 75.5652;
  String? mockError;

  @override
  Future<bool> isLocationServiceEnabled() async => isEnabled;

  @override
  Future<LocationResult> getCurrentLocation() async {
    if (mockError != null) {
      return LocationResult(error: mockError);
    }
    return LocationResult(latitude: mockLat, longitude: mockLng);
  }
}

class MockRoutingRepository implements RoutingRepository {
  bool shouldSucceed = true;
  bool destinationsShouldSucceed = true;
  List<Destination> mockDestinations = [];
  int routeDelayMs = 0;
  Future<RoutingResult> Function({
    Destination? origin,
    double? fromLng,
    double? fromLat,
    required Destination destination,
    bool accessible,
  })? onGetRoute;
  Future<DestinationsResult> Function({required String campusId})? onGetDestinations;

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    if (onGetDestinations != null) {
      return onGetDestinations!(campusId: campusId);
    }
    if (destinationsShouldSucceed) {
      return DestinationsResult(
        destinations: mockDestinations,
        statusCode: 200,
      );
    }
    return const DestinationsResult(
      destinations: [],
      errorMessage: 'Network error loading destinations',
      statusCode: 500,
    );
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
    if (onGetRoute != null) {
      return onGetRoute!(
        origin: origin,
        fromLng: fromLng,
        fromLat: fromLat,
        destination: destination,
        accessible: accessible,
      );
    }
    if (routeDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: routeDelayMs));
    }

    final startLat = fromLat ?? origin?.latitude ?? 26.843;
    final startLng = fromLng ?? origin?.longitude ?? 75.565;

    if (shouldSucceed) {
      return RoutingResult(
        route: CampusRoute(
          distanceMeters: 250.0,
          points: [
            LatLng(startLat, startLng),
            LatLng(destination.latitude, destination.longitude),
          ],
          rawCoordinates: [
            [startLng, startLat],
            [destination.longitude, destination.latitude],
          ],
          rawFeature: const {},
        ),
        statusCode: 200,
        latencyMs: 45,
      );
    } else {
      return const RoutingResult(
        errorMessage: 'Could not find a valid route to destination',
        statusCode: 404,
        latencyMs: 50,
      );
    }
  }

  @override
  void dispose() {}
}

void main() {
  group('RoutingController State & GPS Tests', () {
    late MockRoutingRepository mockRepo;
    late MockLocationService mockLocation;
    late RoutingController controller;

    final defaultTestDestinations = [
      const Destination(
        id: 'DEST_1',
        routingNodeId: 'OUT_DOME_0_001',
        name: 'Dome Entrance',
        category: 'academic',
        latitude: 26.843,
        longitude: 75.565,
      ),
      const Destination(
        id: 'DEST_2',
        routingNodeId: 'OUT_AB1_0_001',
        name: 'AB1 Entrance',
        category: 'academic',
        latitude: 26.844,
        longitude: 75.566,
      ),
      const Destination(
        id: 'DEST_3',
        routingNodeId: 'OUT_LIB_0_001',
        name: 'Central Library',
        category: 'library',
        latitude: 26.845,
        longitude: 75.567,
      ),
    ];

    setUp(() {
      mockRepo = MockRoutingRepository();
      mockLocation = MockLocationService();
      mockRepo.mockDestinations = defaultTestDestinations;
      controller = RoutingController(
        repository: mockRepo,
        locationService: mockLocation,
      );
    });

    tearDown(() {
      if (!controller.isDisposed) {
        controller.dispose();
      }
    });

    test('initializes cleanly and populates destinations dynamically', () async {
      await Future<void>.delayed(Duration.zero);

      expect(controller.destinations.length, 3);
      expect(controller.destination, isNotNull);
      expect(controller.canGo, isTrue);
    });

    test('failed destination loading disables Go and exposes error state', () async {
      mockRepo.destinationsShouldSucceed = false;

      await controller.loadDestinations();

      expect(controller.destinations, isEmpty);
      expect(controller.destinationsError, contains('Network error loading destinations'));
      expect(controller.canGo, isFalse);
      expect(controller.destination, isNull);
    });

    test('auto-resolves device GPS location during route fetch', () async {
      await Future<void>.delayed(Duration.zero);

      mockLocation.mockLat = 26.8435;
      mockLocation.mockLng = 75.5655;

      await controller.fetchRoute();

      expect(controller.userLatitude, 26.8435);
      expect(controller.userLongitude, 75.5655);
      expect(controller.currentRoute, isNotNull);
      expect(controller.origin?.name, 'Current Location');
      expect(controller.canGo, isTrue);
    });

    test('handles device location failure gracefully', () async {
      await Future<void>.delayed(Duration.zero);

      mockLocation.mockError = 'Location permission denied';

      await controller.fetchRoute();

      expect(controller.currentRoute, isNull);
      expect(controller.errorMessage, 'Location permission denied');
      expect(controller.isLoading, isFalse);
      expect(controller.canGo, isTrue);
    });

    test('ignores out-of-order route responses with distinct destinations and payloads', () async {
      await Future<void>.delayed(Duration.zero);

      final completerSlow = Completer<RoutingResult>();
      final completerFast = Completer<RoutingResult>();

      mockRepo.onGetRoute = ({
        Destination? origin,
        double? fromLng,
        double? fromLat,
        required Destination destination,
        bool accessible = false,
      }) {
        if (destination.id == 'DEST_2') {
          return completerSlow.future;
        }
        return completerFast.future;
      };

      expect(controller.destination!.id, 'DEST_2');
      final slowFuture = controller.fetchRoute();

      final dest3 = defaultTestDestinations[2];
      controller.setDestination(dest3);
      final fastFuture = controller.fetchRoute();

      completerFast.complete(
        RoutingResult(
          route: CampusRoute(
            distanceMeters: 500.0,
            points: [
              const LatLng(26.8438, 75.5652),
              LatLng(dest3.latitude, dest3.longitude),
            ],
            rawCoordinates: const [],
            rawFeature: const {},
          ),
          statusCode: 200,
          latencyMs: 30,
        ),
      );
      await fastFuture;

      expect(controller.currentRoute, isNotNull);
      expect(controller.currentRoute!.distanceMeters, 500.0);
      expect(controller.destination!.id, 'DEST_3');
      expect(controller.isLoading, isFalse);
      expect(controller.canGo, isTrue);

      completerSlow.complete(
        RoutingResult(
          route: CampusRoute(
            distanceMeters: 100.0,
            points: [
              const LatLng(26.8438, 75.5652),
              LatLng(defaultTestDestinations[1].latitude, defaultTestDestinations[1].longitude),
            ],
            rawCoordinates: const [],
            rawFeature: const {},
          ),
          statusCode: 200,
          latencyMs: 120,
        ),
      );
      await slowFuture;

      expect(controller.currentRoute!.distanceMeters, 500.0);
      expect(controller.destination!.id, 'DEST_3');
      expect(controller.isLoading, isFalse);
      expect(controller.canGo, isTrue);
    });

    test('clearing route mid-flight cancels pending route and restores loading and Go state', () async {
      await Future<void>.delayed(Duration.zero);

      final completer = Completer<RoutingResult>();
      mockRepo.onGetRoute = ({
        Destination? origin,
        double? fromLng,
        double? fromLat,
        required Destination destination,
        bool accessible = false,
      }) => completer.future;

      final pendingFuture = controller.fetchRoute();
      expect(controller.isLoading, isTrue);
      expect(controller.canGo, isFalse);
      expect(controller.currentRoute, isNull);

      controller.clearRoute();
      expect(controller.isLoading, isFalse);
      expect(controller.canGo, isTrue);
      expect(controller.currentRoute, isNull);

      completer.complete(
        const RoutingResult(
          route: CampusRoute(
            distanceMeters: 250.0,
            points: [LatLng(26.843, 75.565), LatLng(26.844, 75.566)],
            rawCoordinates: [],
            rawFeature: {},
          ),
          statusCode: 200,
          latencyMs: 10,
        ),
      );

      await pendingFuture;
      expect(controller.isLoading, isFalse);
      expect(controller.canGo, isTrue);
      expect(controller.currentRoute, isNull);
    });

    test('reloading destinations during pending route invalidates route and drops stale completion', () async {
      await Future<void>.delayed(Duration.zero);

      final routeCompleter = Completer<RoutingResult>();
      mockRepo.onGetRoute = ({
        Destination? origin,
        double? fromLng,
        double? fromLat,
        required Destination destination,
        bool accessible = false,
      }) => routeCompleter.future;

      final pendingRoute = controller.fetchRoute();
      expect(controller.isLoading, isTrue);

      final newDestinations = [
        const Destination(
          id: 'NEW_1',
          routingNodeId: 'OUT_NEW_1',
          name: 'New Hall',
          category: 'academic',
          latitude: 26.850,
          longitude: 75.570,
        ),
      ];
      mockRepo.mockDestinations = newDestinations;

      final reloadFuture = controller.loadDestinations();
      expect(controller.isLoading, isFalse);
      expect(controller.isLoadingDestinations, isTrue);

      routeCompleter.complete(
        const RoutingResult(
          route: CampusRoute(
            distanceMeters: 300.0,
            points: [],
            rawCoordinates: [],
            rawFeature: {},
          ),
          statusCode: 200,
          latencyMs: 10,
        ),
      );

      await pendingRoute;
      await reloadFuture;

      expect(controller.destinations.first.id, 'NEW_1');
      expect(controller.currentRoute, isNull);
      expect(controller.isLoading, isFalse);
      expect(controller.isLoadingDestinations, isFalse);
      expect(controller.canGo, isTrue);
    });

    test('overlapping destination reloads ignores stale earlier responses', () async {
      await Future<void>.delayed(Duration.zero);

      final completerD1 = Completer<DestinationsResult>();
      final completerD2 = Completer<DestinationsResult>();

      int callCount = 0;
      mockRepo.onGetDestinations = ({required String campusId}) {
        callCount++;
        if (callCount == 1) return completerD1.future;
        return completerD2.future;
      };

      final reload1 = controller.loadDestinations();
      final reload2 = controller.loadDestinations();

      const list2 = [
        Destination(
          id: 'LATEST',
          routingNodeId: 'OUT_LATEST',
          name: 'Latest Point',
          category: 'test',
          latitude: 26.86,
          longitude: 75.58,
        ),
      ];

      const list1 = [
        Destination(
          id: 'STALE',
          routingNodeId: 'OUT_STALE',
          name: 'Stale Point',
          category: 'test',
          latitude: 26.81,
          longitude: 75.51,
        ),
      ];

      completerD2.complete(const DestinationsResult(destinations: list2, statusCode: 200));
      await reload2;

      expect(controller.destinations.first.id, 'LATEST');

      completerD1.complete(const DestinationsResult(destinations: list1, statusCode: 200));
      await reload1;

      expect(controller.destinations.first.id, 'LATEST');
    });

    test('dispose cancels pending route completions without throwing', () async {
      await Future<void>.delayed(Duration.zero);

      mockRepo.routeDelayMs = 50;
      final pendingFuture = controller.fetchRoute();

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      await expectLater(pendingFuture, completes);
    });

    test('supports custom campus destination as origin, swap, and blocks same-destination routing', () async {
      await Future<void>.delayed(Duration.zero);

      final dest1 = defaultTestDestinations[0];
      final dest2 = defaultTestDestinations[1];

      // 1. Set custom origin
      controller.setOrigin(dest1);
      controller.setDestination(dest2);
      expect(controller.isGpsOrigin, isFalse);
      expect(controller.origin, equals(dest1));
      expect(controller.destination, equals(dest2));
      expect(controller.canGo, isTrue);

      // 2. Fetch route uses custom origin coordinates
      Destination? passedOrigin;
      double? passedFromLat;
      double? passedFromLng;
      mockRepo.onGetRoute = ({
        Destination? origin,
        double? fromLng,
        double? fromLat,
        required Destination destination,
        bool accessible = false,
      }) async {
        passedOrigin = origin;
        passedFromLat = fromLat;
        passedFromLng = fromLng;
        return RoutingResult(
          route: CampusRoute(
            distanceMeters: 350.0,
            points: [LatLng(fromLat!, fromLng!), LatLng(destination.latitude, destination.longitude)],
            rawCoordinates: const [],
            rawFeature: const {},
          ),
          statusCode: 200,
          latencyMs: 30,
        );
      };

      await controller.fetchRoute();
      expect(controller.currentRoute, isNotNull);
      expect(passedFromLat, dest1.latitude);
      expect(passedFromLng, dest1.longitude);
      expect(passedOrigin, equals(dest1));

      // 3. Swap origins
      controller.swap();
      expect(controller.origin, equals(dest2));
      expect(controller.destination, equals(dest1));

      // 4. Same location blocks canGo
      controller.setOrigin(dest1);
      controller.setDestination(dest1);
      expect(controller.canGo, isFalse);

      // 5. Switching back to Your Location (null) restores GPS mode
      controller.setOrigin(null);
      expect(controller.isGpsOrigin, isTrue);
      expect(controller.canGo, isTrue);
    });
  });
}
