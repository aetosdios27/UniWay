import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/presentation/map/basemap_pois.dart';

class FakeBasemapController extends Fake implements MapLibreMapController {
  final List<String> existingLayerIds;
  final Map<String, bool> layerVisibility = {};
  bool throwOnGetLayerIds;

  FakeBasemapController({
    required this.existingLayerIds,
    this.throwOnGetLayerIds = false,
  });

  @override
  Future<List> getLayerIds() async {
    if (throwOnGetLayerIds) {
      throw Exception('getLayerIds not supported');
    }
    return existingLayerIds;
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    layerVisibility[layerId] = visible;
  }
}

void main() {
  group('Basemap POI Suppression', () {
    test('contains expected OpenFreeMap Liberty POI symbol layers', () {
      expect(kBasemapPoiLayerIds, ['poi_r1', 'poi_r7', 'poi_r20']);
      expect(kBasemapPoiLayerIds.contains('poi_transit'), isFalse);
    });

    test('hides existing basemap POI layers', () async {
      final controller = FakeBasemapController(
        existingLayerIds: [
          'background',
          'poi_r1',
          'poi_r7',
          'poi_r20',
          'poi_transit',
        ],
      );

      await hideBasemapPois(controller);

      expect(controller.layerVisibility['poi_r1'], isFalse);
      expect(controller.layerVisibility['poi_r7'], isFalse);
      expect(controller.layerVisibility['poi_r20'], isFalse);
      expect(controller.layerVisibility.containsKey('poi_transit'), isFalse);
    });

    test('skips missing basemap POI layers when getLayerIds is supported', () async {
      final controller = FakeBasemapController(
        existingLayerIds: [
          'background',
          'poi_r1',
          'poi_transit',
        ],
      );

      await hideBasemapPois(controller);

      expect(controller.layerVisibility['poi_r1'], isFalse);
      expect(controller.layerVisibility.containsKey('poi_r7'), isFalse);
      expect(controller.layerVisibility.containsKey('poi_r20'), isFalse);
      expect(controller.layerVisibility.containsKey('poi_transit'), isFalse);
    });

    test('falls back to per-layer try/catch when getLayerIds throws', () async {
      final controller = FakeBasemapController(
        existingLayerIds: [],
        throwOnGetLayerIds: true,
      );

      await hideBasemapPois(controller);

      expect(controller.layerVisibility['poi_r1'], isFalse);
      expect(controller.layerVisibility['poi_r7'], isFalse);
      expect(controller.layerVisibility['poi_r20'], isFalse);
      expect(controller.layerVisibility.containsKey('poi_transit'), isFalse);
    });

    test('poi_transit is untouched even if present in the style', () async {
      final controller = FakeBasemapController(
        existingLayerIds: [
          'poi_r1',
          'poi_transit',
        ],
      );

      await hideBasemapPois(controller);

      expect(controller.layerVisibility.containsKey('poi_transit'), isFalse);
    });
  });
}
