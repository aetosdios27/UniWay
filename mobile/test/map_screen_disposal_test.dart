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
  final Completer<Circle> circleCompleter = Completer<Circle>();
  int addCircleCalls = 0;
  int removeCircleCalls = 0;
  int addLineCalls = 0;
  int removeLineCalls = 0;

  @override
  Future<Circle> addCircle(CircleOptions options, [Map? data]) {
    addCircleCalls++;
    return circleCompleter.future;
  }

  @override
  Future<void> removeCircle(Circle circle) async {
    removeCircleCalls++;
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
  Future<Symbol> addSymbol(SymbolOptions options, [Map? data]) async {
    return Symbol('test_symbol', options);
  }

  @override
  Future<void> removeSymbol(Symbol symbol) async {}

  @override
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    return true;
  }
}

class ErroringMockMapLibreController extends Fake implements MapLibreMapController {
  @override
  Future<Circle> addCircle(CircleOptions options, [Map? data]) async {
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
  Future<RoutingResult> getRoute({
    required String campusId,
    required Destination origin,
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
      expect(mockMap.addCircleCalls, 1);

      await tester.pumpWidget(const SizedBox());

      mockMap.circleCompleter.complete(Circle('c1', const CircleOptions()));
      await tester.pump();

      expect(mockMap.addCircleCalls, 1);

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
