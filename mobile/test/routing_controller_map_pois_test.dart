import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/map_poi.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';

class StubRepoWithPois implements RoutingRepository {
  final List<Destination> destinations;
  final List<MapPoi> mapPois;
  final bool shouldFailPois;
  final bool throwOnPois;

  StubRepoWithPois({
    required this.destinations,
    required this.mapPois,
    this.shouldFailPois = false,
    this.throwOnPois = false,
  });

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return DestinationsResult(destinations: destinations, statusCode: 200);
  }

  @override
  Future<MapPoisResult> getMapPois({
    required String campusId,
    String? category,
  }) async {
    if (throwOnPois) {
      throw Exception('Server unreachable');
    }
    if (shouldFailPois) {
      return const MapPoisResult(
        pois: [],
        errorMessage: '500 Internal Server Error',
        statusCode: 500,
      );
    }
    return MapPoisResult(pois: mapPois, statusCode: 200);
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
    throw UnimplementedError();
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDestinations = [
    const Destination(
      id: 'D1',
      name: 'Block AB1',
      category: 'academic',
      latitude: 26.84,
      longitude: 75.56,
    ),
  ];

  final testPois = [
    const MapPoi(
      id: 'P1',
      name: 'Medical Clinic',
      category: 'medical',
      latitude: 26.841,
      longitude: 75.561,
    ),
  ];

  group('RoutingController Map POIs integration', () {
    test('loads map POIs alongside destinations on success', () async {
      final repo = StubRepoWithPois(
        destinations: testDestinations,
        mapPois: testPois,
      );

      final controller = RoutingController(repository: repo);
      await controller.loadDestinations();

      expect(controller.destinations.length, 1);
      expect(controller.mapPois.length, 1);
      expect(controller.mapPois.first.name, 'Medical Clinic');
      expect(controller.mapPoisRevision, greaterThan(0));

      controller.dispose();
    });

    test('handles POI endpoint failure non-fatally without blocking destinations', () async {
      final repo = StubRepoWithPois(
        destinations: testDestinations,
        mapPois: testPois,
        shouldFailPois: true,
      );

      final controller = RoutingController(repository: repo);
      await controller.loadDestinations();

      expect(controller.destinations.length, 1);
      expect(controller.mapPois, isEmpty);
      expect(controller.destinationsError, isNull);

      controller.dispose();
    });

    test('handles POI network exception non-fatally without throwing', () async {
      final repo = StubRepoWithPois(
        destinations: testDestinations,
        mapPois: testPois,
        throwOnPois: true,
      );

      final controller = RoutingController(repository: repo);
      await controller.loadDestinations();

      expect(controller.destinations.length, 1);
      expect(controller.mapPois, isEmpty);
      expect(controller.destinationsError, isNull);

      controller.dispose();
    });
  });
}
