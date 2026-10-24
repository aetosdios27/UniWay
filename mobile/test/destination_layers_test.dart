import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/constants/map_constants.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'dart:typed_data';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/map/destination_layers.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';

class RecordingMapLibreController extends Fake implements MapLibreMapController {
  final List<String> calls = [];
  final List<Map<String, dynamic>> sourceUpdates = [];
  final List<Map<String, dynamic>> addedCircleLayers = [];
  final List<Map<String, dynamic>> addedSymbolLayers = [];
  final List<String> removedLayers = [];
  final List<String> removedSources = [];
  final List<Map<String, dynamic>> filters = [];
  int addCircleCalls = 0;
  int addSymbolCalls = 0;

  int get setGeoJsonSourceCalls => sourceUpdates.length;

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    calls.add('addSource:$sourceId');
  }

  @override
  Future<void> removeSource(String sourceId) async {
    calls.add('removeSource:$sourceId');
    removedSources.add(sourceId);
  }

  @override
  Future<void> removeLayer(String layerId) async {
    calls.add('removeLayer:$layerId');
    removedLayers.add(layerId);
  }

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {
    calls.add('addImage:$name');
  }

  @override
  Future<List> getLayerIds() async {
    calls.add('getLayerIds');
    return [];
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    calls.add('setLayerVisibility:$layerId:$visible');
  }

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
  }) async {
    calls.add('addCircleLayer:$layerId');
    addedCircleLayers.add({
      'sourceId': sourceId,
      'layerId': layerId,
      'properties': properties,
      'minzoom': minzoom,
      'filter': filter,
      'enableInteraction': enableInteraction,
    });
  }

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
  }) async {
    calls.add('addSymbolLayer:$layerId');
    addedSymbolLayers.add({
      'sourceId': sourceId,
      'layerId': layerId,
      'properties': properties,
      'minzoom': minzoom,
      'filter': filter,
      'enableInteraction': enableInteraction,
    });
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    calls.add('setGeoJsonSource:$sourceId');
    sourceUpdates.add(geojson);
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    calls.add('setFilter:$layerId');
    filters.add({'layerId': layerId, 'filter': filter});
  }

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
}

class ErroringMapLibreController extends Fake implements MapLibreMapController {
  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    throw Exception('Platform channel addSource error');
  }

  @override
  Future<void> removeLayer(String layerId) async {
    throw Exception('Platform channel removeLayer error');
  }

  @override
  Future<void> removeSource(String sourceId) async {
    throw Exception('Platform channel removeSource error');
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    throw Exception('Platform channel setGeoJsonSource error');
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    throw Exception('Platform channel setFilter error');
  }
}

class MutableRoutingRepo implements RoutingRepository {
  List<Destination> destinations;

  MutableRoutingRepo(this.destinations);

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

List<Destination> phase0Destinations() {
  const names = [
    'Dome Building',
    'Library',
    'Academic Building 1',
    'Old Mess',
    'Academic Building 2',
    'LHC',
    'Academic Building 3',
  ];
  return [
    for (var i = 0; i < names.length; i++)
      Destination(
        id: 'DEST_0${i + 1}',
        routingNodeId: 'NODE_0${i + 1}',
        name: names[i],
        category: 'destination',
        latitude: 26.8416371 + i * 0.0002,
        longitude: 75.565927 - i * 0.0003,
      ),
  ];
}

List<Destination> generatedDestinations(int count) {
  return [
    for (var i = 0; i < count; i++)
      Destination(
        id: 'GEN_$i',
        routingNodeId: 'NODE_$i',
        name: 'Room $i',
        category: 'room',
        latitude: 26.8 + (i % 100) * 0.0001,
        longitude: 75.5 + (i % 100) * 0.0001,
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The style load chain is asynchronous, pump until the map was updated.
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 20 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('Destination Feature Collection', () {
    test('is an empty feature collection for an empty destination list', () {
      final collection = destinationsToFeatureCollection(const []);

      expect(collection['type'], 'FeatureCollection');
      expect(collection['features'], isEmpty);
    });

    test('builds one feature per Phase 0 destination', () {
      final destinations = phase0Destinations();
      final collection = destinationsToFeatureCollection(destinations);
      final features = collection['features'] as List;

      expect(features.length, 7);
      for (var i = 0; i < destinations.length; i++) {
        final feature = features[i] as Map<String, dynamic>;
        final destination = destinations[i];

        expect(feature['type'], 'Feature');
        expect(feature['id'], destination.id);
        expect(feature['geometry']['type'], 'Point');

        final coordinates = feature['geometry']['coordinates'] as List;
        expect(coordinates[0], closeTo(destination.longitude, 1e-9));
        expect(coordinates[1], closeTo(destination.latitude, 1e-9));

        final properties = feature['properties'] as Map<String, dynamic>;
        expect(properties['id'], destination.id);
        expect(properties['name'], destination.name);
        expect(properties['category'], destination.category);
      }
    });

    test('keeps 10000 generated destinations unique', () {
      final collection = destinationsToFeatureCollection(generatedDestinations(10000));
      final features = collection['features'] as List;

      expect(features.length, 10000);
      final ids = features
          .map((f) => (f as Map<String, dynamic>)['id'])
          .toSet();
      expect(ids.length, 10000);
    });

    test('feature collection carries resolved icon property', () {
      final destinations = [
        const Destination(
          id: 'D_EXPLICIT',
          name: 'Food Court',
          category: 'food',
          iconKey: 'food',
          latitude: 26.84,
          longitude: 75.56,
        ),
        const Destination(
          id: 'D_CATEGORY',
          name: 'Central Canteen',
          category: 'canteen',
          latitude: 26.84,
          longitude: 75.56,
        ),
        const Destination(
          id: 'D_UNKNOWN',
          name: 'Secret Lab',
          category: 'mystery',
          latitude: 26.84,
          longitude: 75.56,
        ),
        const Destination(
          id: 'D_UNREGISTERED',
          name: 'Library Hub',
          category: 'library',
          iconKey: 'library',
          latitude: 26.84,
          longitude: 75.56,
        ),
      ];

      final fc = destinationsToFeatureCollection(
        destinations,
        registeredIcons: {'default', 'food'},
      );
      final features = fc['features'] as List;

      expect((features[0]['properties'] as Map)['icon'], 'uniway-poi-food');
      expect((features[1]['properties'] as Map)['icon'], 'uniway-poi-food');
      expect((features[2]['properties'] as Map)['icon'], 'uniway-poi-default');
      expect((features[3]['properties'] as Map)['icon'], 'uniway-poi-default');

      final fcNoFallback = destinationsToFeatureCollection(
        destinations,
        registeredIcons: {},
      );
      final featuresNoFallback = fcNoFallback['features'] as List;
      expect((featuresNoFallback[0]['properties'] as Map)['icon'], isNull);
    });
  });

  group('Destination Layer Controller Interaction', () {
    test('adds one source, the marker layers and one label layer', () async {
      final controller = RecordingMapLibreController();

      await addDestinationLayers(controller);

      expect(controller.calls, contains('addSource:${MapConstants.destinationsSourceId}'));
      expect(controller.addedCircleLayers.length, 2);
      expect(controller.addedSymbolLayers.length, 2);

      final circleLayerIds =
          controller.addedCircleLayers.map((l) => l['layerId']).toList();
      expect(circleLayerIds, contains(MapConstants.destinationsOriginLayerId));
      expect(circleLayerIds, contains(MapConstants.destinationsDestinationLayerId));

      final symbolLayerIds =
          controller.addedSymbolLayers.map((l) => l['layerId']).toList();
      expect(symbolLayerIds, contains(MapConstants.destinationsLayerId));
      expect(symbolLayerIds, contains(MapConstants.destinationsLabelsLayerId));

      final labelLayer = controller.addedSymbolLayers
          .firstWhere((l) => l['layerId'] == MapConstants.destinationsLabelsLayerId);
      expect(labelLayer['enableInteraction'], isFalse);
      expect(labelLayer['minzoom'], isNull);
    });

    test('falls back to circle layer if fallback icon failed to register', () async {
      final controller = RecordingMapLibreController();

      await addDestinationLayers(controller, registeredIcons: {});

      expect(controller.addedCircleLayers.length, 3);
      expect(controller.addedSymbolLayers.length, 1);

      final circleLayerIds =
          controller.addedCircleLayers.map((l) => l['layerId']).toList();
      expect(circleLayerIds, contains(MapConstants.destinationsLayerId));
    });

    test('is idempotent: removes the previous layers before adding them', () async {
      final controller = RecordingMapLibreController();

      await addDestinationLayers(controller);
      final callCountAfterFirst = controller.calls.length;

      await addDestinationLayers(controller);

      expect(controller.removedLayers, contains(MapConstants.destinationsLayerId));
      expect(controller.removedLayers, contains(MapConstants.destinationsLabelsLayerId));
      expect(controller.removedSources, contains(MapConstants.destinationsSourceId));
      expect(controller.calls.length, callCountAfterFirst * 2);
    });

    test('never throws when the controller fails', () async {
      final controller = ErroringMapLibreController();

      await expectLater(addDestinationLayers(controller), completes);
      await expectLater(updateDestinationSource(controller, phase0Destinations()), completes);
      await expectLater(
        setHighlightedDestinations(controller, originId: 'DEST_01'),
        completes,
      );
      await expectLater(removeDestinationLayers(controller), completes);
    });

    test('renders the symbol marker and label layers, clearing label offset', () async {
      final controller = RecordingMapLibreController();

      await addDestinationLayers(controller);

      final marker = controller.addedSymbolLayers
          .firstWhere((l) => l['layerId'] == MapConstants.destinationsLayerId);
      final markerJson =
          (marker['properties'] as SymbolLayerProperties).toJson();
      expect(markerJson['icon-image'], ['get', 'icon']);
      expect(markerJson['icon-allow-overlap'], isTrue);
      expect(markerJson['icon-ignore-placement'], isTrue);
      expect(markerJson['icon-anchor'], 'center');
      expect(markerJson['icon-size'], isA<List>());

      final label = controller.addedSymbolLayers
          .firstWhere((l) => l['layerId'] == MapConstants.destinationsLabelsLayerId);
      final labelJson = (label['properties'] as SymbolLayerProperties).toJson();
      expect(labelJson['text-field'], ['get', 'name']);
      expect(labelJson['text-size'], 11.0);
      expect(labelJson['text-color'], '#1E293B');
      expect(labelJson['text-halo-color'], '#FFFFFF');
      expect(labelJson['text-halo-width'], 2.0);
      expect(labelJson['text-offset'], [0, 2.1]);
      expect(labelJson['text-anchor'], 'top');
      expect(labelJson['text-allow-overlap'], isFalse);
      expect(labelJson['text-optional'], isTrue);
      expect(labelJson['symbol-sort-key'], isNotNull);

      final fallbackController = RecordingMapLibreController();
      await addDestinationLayers(fallbackController, registeredIcons: {});
      final circle = fallbackController.addedCircleLayers
          .firstWhere((l) => l['layerId'] == MapConstants.destinationsLayerId);
      final circleJson =
          (circle['properties'] as CircleLayerProperties).toJson();
      expect(circleJson['circle-color'], '#2563EB');
      expect(circleJson['circle-stroke-width'], 2.5);
      expect(circleJson['circle-stroke-color'], '#FFFFFF');
      expect(circleJson['circle-opacity'], 0.95);
      expect(circleJson['circle-radius'], isA<List>());
    });
  });

  group('Destination Source Updates', () {
    test('sends one source update per change and never adds annotations', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);

      for (var i = 0; i < 5; i++) {
        await updateDestinationSource(
          controller,
          phase0Destinations().sublist(0, i + 1),
        );
      }

      expect(controller.setGeoJsonSourceCalls, 5);
      expect(controller.addCircleCalls, 0);
      expect(controller.addSymbolCalls, 0);
      expect(controller.addedCircleLayers.length, 2);
      expect(controller.addedSymbolLayers.length, 2);
    });

    test('sends the destination collection as a single feature collection', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);

      final destinations = phase0Destinations();
      await updateDestinationSource(controller, destinations);

      final update = controller.sourceUpdates.single;
      expect(update['type'], 'FeatureCollection');
      expect((update['features'] as List).length, destinations.length);
    });

    test('hides labels below the dense zoom once the collection grows', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);

      await updateDestinationSource(controller, generatedDestinations(60));

      final labelLayer = controller.addedSymbolLayers.last;
      expect(labelLayer['layerId'], MapConstants.destinationsLabelsLayerId);
      expect(labelLayer['minzoom'], labelDenseZoom);
      expect(controller.removedLayers, contains(MapConstants.destinationsLabelsLayerId));
    });

    test('keeps labels visible for small collections', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);
      final symbolLayersAfterAdd = controller.addedSymbolLayers.length;

      await updateDestinationSource(controller, phase0Destinations());

      expect(controller.addedSymbolLayers.length, symbolLayersAfterAdd);
      expect(controller.addedSymbolLayers.first['minzoom'], isNull);
    });

    test('scopes dense label mode to each map controller', () async {
      final denseMap = RecordingMapLibreController();
      final smallMap = RecordingMapLibreController();
      final denseDestinations =
          generatedDestinations(denseDestinationThreshold + 10);
      final smallDestinations = phase0Destinations();

      await addDestinationLayers(
        denseMap,
        destinationCount: denseDestinations.length,
      );
      await addDestinationLayers(
        smallMap,
        destinationCount: smallDestinations.length,
      );

      expect(denseMap.addedSymbolLayers.last['minzoom'], labelDenseZoom);
      expect(smallMap.addedSymbolLayers.last['minzoom'], isNull);

      // Shrinking one map must not be skipped because the other map already
      // switched density modes in between.
      await updateDestinationSource(denseMap, smallDestinations);
      expect(denseMap.addedSymbolLayers.last['minzoom'], isNull);
      expect(smallMap.addedSymbolLayers.last['minzoom'], isNull);

      await updateDestinationSource(smallMap, denseDestinations);
      expect(smallMap.addedSymbolLayers.last['minzoom'], labelDenseZoom);
      expect(denseMap.addedSymbolLayers.last['minzoom'], isNull);

      await updateDestinationSource(denseMap, denseDestinations);
      expect(denseMap.addedSymbolLayers.last['minzoom'], labelDenseZoom);
      expect(smallMap.addedSymbolLayers.last['minzoom'], labelDenseZoom);

      await updateDestinationSource(smallMap, smallDestinations);
      expect(smallMap.addedSymbolLayers.last['minzoom'], isNull);
      expect(denseMap.addedSymbolLayers.last['minzoom'], labelDenseZoom);
    });

    test('reapplies density after a style reload', () async {
      final controller = RecordingMapLibreController();
      final denseDestinations =
          generatedDestinations(denseDestinationThreshold + 10);

      await addDestinationLayers(controller);
      await updateDestinationSource(controller, denseDestinations);
      expect(controller.addedSymbolLayers.last['minzoom'], labelDenseZoom);

      // A style reload rebuilds the label layer from the current count.
      await addDestinationLayers(
        controller,
        destinationCount: denseDestinations.length,
      );
      expect(controller.addedSymbolLayers.last['minzoom'], labelDenseZoom);

      await updateDestinationSource(controller, phase0Destinations());
      expect(controller.addedSymbolLayers.last['minzoom'], isNull);
    });
  });

  group('Destination Highlights', () {
    test('filters the origin and destination rings by id', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);

      await setHighlightedDestinations(
        controller,
        originId: 'DEST_01',
        destinationId: 'DEST_02',
      );

      expect(controller.filters.length, 2);
      expect(controller.filters.first['layerId'],
          MapConstants.destinationsOriginLayerId);
      expect(controller.filters.first['filter'], ['==', 'id', 'DEST_01']);
      expect(controller.filters.last['layerId'],
          MapConstants.destinationsDestinationLayerId);
      expect(controller.filters.last['filter'], ['==', 'id', 'DEST_02']);
    });

    test('matches no destination when an endpoint is missing', () async {
      final controller = RecordingMapLibreController();
      await addDestinationLayers(controller);

      await setHighlightedDestinations(controller);

      expect(controller.filters.first['filter'], ['==', 'id', noHighlightId]);
      expect(controller.filters.last['filter'], ['==', 'id', noHighlightId]);
    });
  });

  group('MapScreen Destination Integration', () {
    testWidgets('renders destinations as one source instead of annotations',
        (tester) async {
      final repo = MutableRoutingRepo(phase0Destinations());
      final routingController = RoutingController(repository: repo);
      await routingController.loadDestinations();

      final map = RecordingMapLibreController();
      var styleLoaded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: routingController,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              if (!styleLoaded) {
                styleLoaded = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onMapCreated(map);
                  onStyleLoaded();
                });
              }
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await pumpUntil(tester, () => map.setGeoJsonSourceCalls == 1);

      expect(map.setGeoJsonSourceCalls, 1);
      expect(map.addCircleCalls, 0);
      expect(map.addSymbolCalls, 0);
      expect((map.sourceUpdates.single['features'] as List).length, 7);

      await tester.pumpWidget(const SizedBox());
      routingController.dispose();
    });

    testWidgets('re-sends the source once per destination change',
        (tester) async {
      final repo = MutableRoutingRepo(phase0Destinations());
      final routingController = RoutingController(repository: repo);
      await routingController.loadDestinations();

      final map = RecordingMapLibreController();
      var styleLoaded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: routingController,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              if (!styleLoaded) {
                styleLoaded = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onMapCreated(map);
                  onStyleLoaded();
                });
              }
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await pumpUntil(tester, () => map.setGeoJsonSourceCalls == 1);
      expect(map.setGeoJsonSourceCalls, 1);

      repo.destinations = phase0Destinations().take(3).toList();
      await routingController.loadDestinations();
      await tester.pump();
      await pumpUntil(tester, () => map.setGeoJsonSourceCalls == 2);

      expect(map.setGeoJsonSourceCalls, 2);
      expect(map.addCircleCalls, 0);
      expect(map.addSymbolCalls, 0);

      await tester.pumpWidget(const SizedBox());
      routingController.dispose();
    });

    testWidgets('only updates the highlight filters when an endpoint changes',
        (tester) async {
      final destinations = phase0Destinations();
      final repo = MutableRoutingRepo(destinations);
      final routingController = RoutingController(repository: repo);
      await routingController.loadDestinations();

      final map = RecordingMapLibreController();
      var styleLoaded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: routingController,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              if (!styleLoaded) {
                styleLoaded = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onMapCreated(map);
                  onStyleLoaded();
                });
              }
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await pumpUntil(tester, () => map.filters.length == 2);

      final filtersAfterFirstSync = map.filters.length;
      expect(filtersAfterFirstSync, 2);

      // A redraw that does not change the endpoints must not touch the filters.
      await routingController.loadDestinations();
      await tester.pump();
      await pumpUntil(tester, () => map.filters.length != filtersAfterFirstSync);

      expect(map.filters.length, filtersAfterFirstSync);

      // Picking another destination changes the highlight filter.
      routingController.setDestination(destinations[4]);
      await tester.pump();
      await pumpUntil(
        tester,
        () => map.filters.length == filtersAfterFirstSync + 2,
      );

      expect(map.filters.length, filtersAfterFirstSync + 2);
      expect(map.filters.last['layerId'],
          MapConstants.destinationsDestinationLayerId);
      expect(map.filters.last['filter'], ['==', 'id', destinations[4].id]);

      await tester.pumpWidget(const SizedBox());
      routingController.dispose();
    });
  });
}
