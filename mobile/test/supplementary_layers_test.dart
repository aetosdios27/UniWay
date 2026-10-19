import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/constants/map_constants.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/map/supplementary_layers.dart';
import 'package:uniway_mobile/presentation/screens/map_screen.dart';

class RecordingMapLibreController extends Fake
    implements MapLibreMapController {
  final List<String> calls = [];
  final Map<String, SourceProperties> addedSources = {};
  final List<Map<String, dynamic>> addedFillLayers = [];
  final List<Map<String, dynamic>> addedFillExtrusionLayers = [];
  final List<Map<String, dynamic>> addedSymbolLayers = [];
  final List<String> removedLayers = [];
  final List<String> removedSources = [];

  @override
  Future<void> removeLayer(String layerId) async {
    calls.add('removeLayer:$layerId');
    removedLayers.add(layerId);
  }

  @override
  Future<void> removeSource(String sourceId) async {
    calls.add('removeSource:$sourceId');
    removedSources.add(sourceId);
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    calls.add('addSource:$sourceId');
    addedSources[sourceId] = properties;
  }

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    FillLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    calls.add('addFillLayer:$layerId');
    addedFillLayers.add({
      'sourceId': sourceId,
      'layerId': layerId,
      'properties': properties,
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': filter,
      'enableInteraction': enableInteraction,
    });
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    FillExtrusionLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    calls.add('addFillExtrusionLayer:$layerId');
    addedFillExtrusionLayers.add({
      'sourceId': sourceId,
      'layerId': layerId,
      'properties': properties,
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
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
      'belowLayerId': belowLayerId,
      'minzoom': minzoom,
      'maxzoom': maxzoom,
      'filter': filter,
      'enableInteraction': enableInteraction,
    });
  }
}

class ErroringMapLibreController extends Fake implements MapLibreMapController {
  @override
  Future<void> removeLayer(String layerId) async {
    throw Exception('Failed to remove layer');
  }

  @override
  Future<void> removeSource(String sourceId) async {
    throw Exception('Failed to remove source');
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    throw Exception('Platform channel addSource error');
  }
}

class TestGeoJsonAssetBundle extends CachingAssetBundle {
  final String geoJsonString;
  TestGeoJsonAssetBundle(this.geoJsonString);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == MapConstants.supplementaryGeoJsonAssetPath) {
      return geoJsonString;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleLibraryGeoJson = {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [75.566893, 26.842739],
              [75.566798, 26.842705],
              [75.566492, 26.842567],
              [75.566687, 26.842183],
              [75.567051, 26.842595],
              [75.566893, 26.842739],
            ],
          ],
        },
        'properties': {
          'id': 'MUJ_LIBRARY_001',
          'name': 'Knowledge Center',
          'category': 'library',
          'building': 'yes',
          'render_height': 12,
          'render_min_height': 0,
        },
      },
    ],
  };

  group('Supplementary Layers Pure Logic Tests', () {
    test('prepareSupplementaryGeoJson computes centroid and adds Point feature', () {
      final enriched = prepareSupplementaryGeoJson(sampleLibraryGeoJson);
      final features = enriched['features'] as List;

      expect(features.length, 2);
      final pointFeature = features.firstWhere(
        (f) => f['geometry']['type'] == 'Point',
      );

      expect(pointFeature['properties']['name'], 'Knowledge Center');
      final coordinates = pointFeature['geometry']['coordinates'] as List;
      expect(coordinates[0], closeTo(75.5667, 0.001));
      expect(coordinates[1], closeTo(26.8425, 0.001));
    });

    test('prepareSupplementaryGeoJson is idempotent when Point feature already exists', () {
      final enrichedOnce = prepareSupplementaryGeoJson(sampleLibraryGeoJson);
      final enrichedTwice = prepareSupplementaryGeoJson(enrichedOnce);

      expect((enrichedTwice['features'] as List).length, 2);
    });

    test('layer properties match OpenFreeMap Liberty style specifications', () {
      final fillJson = fillBuildingPaint.toJson();
      expect(fillJson['fill-color'], 'hsl(35,8%,85%)');
      expect(fillJson['fill-outline-color'], isA<List>());

      final extrusionJson = fillExtrusionBuildingPaint.toJson();
      expect(extrusionJson['fill-extrusion-color'], 'hsl(35,8%,85%)');
      expect(extrusionJson['fill-extrusion-base'], ['get', 'render_min_height']);
      expect(extrusionJson['fill-extrusion-height'], ['get', 'render_height']);
      expect(extrusionJson['fill-extrusion-opacity'], 0.8);

      final labelJson = symbolBuildingLabelProperties.toJson();
      expect(labelJson['text-field'], ['get', 'name']);
      expect(labelJson['text-font'], ['Noto Sans Italic']);
      expect(labelJson['text-size'], 12.0);
      expect(labelJson['text-color'], '#666666');
      expect(labelJson['text-halo-color'], '#ffffff');
      expect(labelJson['text-halo-width'], 1.0);
      expect(labelJson['text-halo-blur'], 0.5);
      expect(labelJson['text-anchor'], 'center');
    });
  });

  group('addSupplementaryLayers Controller Interaction Tests', () {
    test('adds source and layers directly below boundary_3 with correct zoom', () async {
      final controller = RecordingMapLibreController();
      final bundle = TestGeoJsonAssetBundle(jsonEncode(sampleLibraryGeoJson));

      await addSupplementaryLayers(controller, bundle: bundle);

      expect(controller.addedSources.containsKey(MapConstants.campusGeometrySourceId), isTrue);
      final source = controller.addedSources[MapConstants.campusGeometrySourceId]!;
      expect(source, isA<GeojsonSourceProperties>());
      final sourceJson = source.toJson();
      expect(sourceJson['type'], 'geojson');

      expect(controller.addedFillLayers.length, 1);
      final fill = controller.addedFillLayers.first;
      expect(fill['layerId'], MapConstants.campusBuildingsLayerId);
      expect(fill['belowLayerId'], 'boundary_3');
      expect(fill['minzoom'], 13.0);
      expect(fill['maxzoom'], 14.0);

      expect(controller.addedFillExtrusionLayers.length, 1);
      final extrusion = controller.addedFillExtrusionLayers.first;
      expect(extrusion['layerId'], MapConstants.campusBuildings3dLayerId);
      expect(extrusion['belowLayerId'], 'boundary_3');
      expect(extrusion['minzoom'], 14.0);

      expect(controller.addedSymbolLayers.length, 1);
      final symbol = controller.addedSymbolLayers.first;
      expect(symbol['layerId'], MapConstants.campusBuildingsLabelLayerId);
      expect(symbol['belowLayerId'], 'boundary_3');
      expect(symbol['minzoom'], 14.0);
    });

    test('is idempotent: removes existing layers and sources before adding', () async {
      final controller = RecordingMapLibreController();
      final bundle = TestGeoJsonAssetBundle(jsonEncode(sampleLibraryGeoJson));

      await addSupplementaryLayers(controller, bundle: bundle);
      final callCountAfterFirst = controller.calls.length;

      await addSupplementaryLayers(controller, bundle: bundle);

      expect(controller.removedLayers, contains(MapConstants.campusBuildingsLabelLayerId));
      expect(controller.removedLayers, contains(MapConstants.campusBuildings3dLayerId));
      expect(controller.removedLayers, contains(MapConstants.campusBuildingsLayerId));
      expect(controller.removedSources, contains(MapConstants.campusGeometrySourceId));

      expect(controller.calls.length, callCountAfterFirst * 2);
    });

    test('never throws on asset loading failure or controller error', () async {
      final failingBundle = TestGeoJsonAssetBundle('invalid json content');
      final controller = RecordingMapLibreController();

      await expectLater(
        addSupplementaryLayers(controller, bundle: failingBundle),
        completes,
      );

      final erroringController = ErroringMapLibreController();
      final bundle = TestGeoJsonAssetBundle(jsonEncode(sampleLibraryGeoJson));
      await expectLater(
        addSupplementaryLayers(erroringController, bundle: bundle),
        completes,
      );
    });
  });

  group('MapScreen Integration Tests', () {
    testWidgets('triggers supplementary layer loading on style loaded without crash', (tester) async {
      final controller = RecordingMapLibreController();
      final routingController = RoutingController();

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: routingController,
            mapBuilder: (context, onMapCreated, onStyleLoaded) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onMapCreated(controller);
                onStyleLoaded();
              });
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MapScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      routingController.dispose();
    });
  });
}
