import 'package:maplibre_gl/maplibre_gl.dart';

/// OpenFreeMap Liberty POI symbol layers to hide in favor of UniWay's icons.
/// Notice that 'poi_transit' is deliberately kept to maintain transit visibility.
const List<String> kBasemapPoiLayerIds = [
  'poi_r1',
  'poi_r7',
  'poi_r20',
];

/// Hides OpenFreeMap POI layers using the controller's style APIs.
///
/// If [getLayerIds] is supported by the controller, only existing layers are
/// hidden. Missing layers are skipped without throwing.
Future<void> hideBasemapPois(
  MapLibreMapController controller, {
  Iterable<String> layerIds = kBasemapPoiLayerIds,
}) async {
  Set<String>? existingLayers;
  try {
    final ids = await controller.getLayerIds();
    existingLayers = ids.map((id) => id.toString()).toSet();
  } catch (_) {
    existingLayers = null;
  }

  for (final layerId in layerIds) {
    if (existingLayers != null && !existingLayers.contains(layerId)) {
      continue;
    }
    try {
      await controller.setLayerVisibility(layerId, false);
    } catch (_) {}
  }
}
