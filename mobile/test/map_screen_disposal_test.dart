import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';

class MockMapLibreController extends Fake implements MapLibreMapController {
  final Completer<void> sourceCompleter = Completer<void>();
  int setGeoJsonSourceCalls = 0;
  int addCircleCalls = 0;
  int addSymbolCalls = 0;
  int addLineCalls = 0;
  int removeLineCalls = 0;

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) {
    setGeoJsonSourceCalls++;
    return sourceCompleter.future;
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {}

  @override
  Future<void> removeSource(String sourceId) async {}

  @override
  Future<void> removeLayer(String layerId) async {}

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {}

  @override
  Future<List> getLayerIds() async => [];

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {}

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {}

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<Circle> addCircle(CircleOptions options, [Map? data]) async {
    addCircleCalls++;
    return Circle('fake_circle', options);
  }

  @override
  Future<void> removeCircle(Circle circle) async {
    addCircleCalls--;
  }

  @override
  Future<Symbol> addSymbol(SymbolOptions options, [Map? data]) async {
    addSymbolCalls++;
    return Symbol('fake_symbol', options);
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {
    addSymbolCalls--;
  }

  @override
  Future<Line> addLine(LineOptions options, [Map? data]) async {
    addLineCalls++;
    return Line('test_line', options);
  }

  @override
  Future<void> removeLine(Line line) async {
    removeLineCalls++;
  }

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }
}

class ErroringMockMapLibreController extends Fake implements MapLibreMapController {
  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    throw Exception('Simulated platform channel failure');
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    throw Exception('Simulated platform channel failure');
  }
}

class TestRoutingRepo implements RoutingRepository {
  final List<Destination> destinations;

  TestRoutingRepo(this.destinations);

  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return DestinationsResult(destinations: destinations, statusCode: 200);
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
    return const RoutingResult(
      route: CampusRoute(
        distanceMeters: 100,
        points: [LatLng(26.8, 75.5), LatLng(26.9, 75.6)],
        rawCoordinates: [],
        rawFeature: {},
      ),
      statusCode: 200,
      latencyMs: 10,
    );
  }

  @override
  void dispose() {}
}

void main() {
  group('MapScreen Disposal & Async Safety Tests', () {
    testWidgets('map screen gracefully stops pending redraws on disposal', (tester) async {
      final destinations = [
        const Destination(
          id: 'D1',
          routingNodeId: 'NODE_1',
          name: 'Dome',
          category: 'academic',
          latitude: 26.84,
          longitude: 75.56,
        ),
        const Destination(
          id: 'D2',
          routingNodeId: 'NODE_2',
          name: 'AB1',
          category: 'academic',
          latitude: 26.85,
          longitude: 75.57,
        ),
      ];

      final repo = TestRoutingRepo(destinations);
      final controller = RoutingController(repository: repo);
      await controller.loadDestinations();

      final mockMap = MockMapLibreController();

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onMapCreated(mockMap);
                onStyleLoaded();
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      expect(mockMap.setGeoJsonSourceCalls, 1);
      expect(mockMap.addCircleCalls, 0);
      expect(mockMap.addSymbolCalls, 0);

      await tester.pumpWidget(const SizedBox());

      mockMap.sourceCompleter.complete();
      await tester.pump();

      expect(mockMap.setGeoJsonSourceCalls, 1);
      expect(mockMap.addCircleCalls, 0);

      controller.dispose();
    });

    testWidgets('swallows async errors during fire-and-forget map sync without crashing', (tester) async {
      final destinations = [
        const Destination(
          id: 'D1',
          routingNodeId: 'NODE_1',
          name: 'Dome',
          category: 'academic',
          latitude: 26.84,
          longitude: 75.56,
        ),
      ];

      final repo = TestRoutingRepo(destinations);
      final controller = RoutingController(repository: repo);
      await controller.loadDestinations();

      final mockMap = ErroringMockMapLibreController();

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onMapCreated(mockMap);
                onStyleLoaded();
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(MapScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
