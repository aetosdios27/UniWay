import 'map_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/map_constants.dart';
import '../../core/constants/poi_icons.dart';
import '../../data/models/map_poi.dart';
import 'poi_icon_registry.dart';

const double poiMinZoom = 16.0;

// Non-routable POIs are smaller than destinations: 22 dp at zoom 16 to 28 dp at 19.
List<Object> poiIconSize(double pixelRatio) => poiIconSizeExpression(
      pixelRatio: pixelRatio,
      minZoom: 16,
      minDp: 22,
      maxZoom: 19,
      maxDp: 28,
    );


SymbolLayerProperties poiSymbolPaintFor(double pixelRatio, MapPalette palette) => SymbolLayerProperties(
  iconImage: const ['get', 'icon'],
  iconSize: poiIconSize(pixelRatio),
  iconAllowOverlap: true,
  iconIgnorePlacement: true,
  iconAnchor: 'center',
  textField: const ['get', 'name'],
  textFont: const ['Noto Sans Regular'],
  textSize: 10.0,
  textColor: palette.poiLabelText,
  textHaloColor: palette.poiLabelHalo,
  textHaloWidth: 1.5,
  textOffset: const [0, 1.5],
  textAnchor: 'top',
  textOptional: true,
  symbolSortKey: 1,
);

CircleLayerProperties poiFallbackCirclePaintFor(MapPalette palette) => CircleLayerProperties(
  circleRadius: 5.0,
  circleColor: palette.poiFallbackCircle,
  circleStrokeWidth: 1.5,
  circleStrokeColor: palette.poiFallbackCircleStroke,
  circleOpacity: 0.9,
);

Map<String, String>? _iconProperty(String key, Set<String> registered) {
  final icon = effectiveIconImageId(key, registered);
  return icon == null ? null : {'icon': icon};
}

/// Builds a GeoJSON FeatureCollection holding every map POI.
Map<String, dynamic> poisToFeatureCollection(
  List<MapPoi> pois, {
  Set<String>? registeredIcons,
}) {
  final registered = registeredIcons ?? kPoiIconKeys.toSet();
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final poi in pois)
        {
          'type': 'Feature',
          'id': poi.id,
          'geometry': {
            'type': 'Point',
            'coordinates': [poi.longitude, poi.latitude],
          },
          'properties': {
            'id': poi.id,
            'name': poi.name,
            'category': poi.category,
            ...?_iconProperty(poi.resolvedIconKey, registered),
          },
        },
    ],
  };
}

Future<void> removePoiLayers(MapLibreMapController controller) async {
  try {
    await controller.removeLayer(MapConstants.poisLayerId);
  } catch (_) {}
  try {
    await controller.removeSource(MapConstants.poisSourceId);
  } catch (_) {}
}

Future<void> addPoiLayers(
  MapLibreMapController controller, {
  Set<String>? registeredIcons,
  double pixelRatio = kDefaultPixelRatio,
  MapPalette palette = MapPalette.light,
}) async {
  try {
    await removePoiLayers(controller);

    final registered = registeredIcons ?? kPoiIconKeys.toSet();
    final hasFallback = registered.contains(kPoiIconFallback);

    await controller.addSource(
      MapConstants.poisSourceId,
      GeojsonSourceProperties(
        data: poisToFeatureCollection(const [], registeredIcons: registered),
      ),
    );

    if (hasFallback) {
      await controller.addSymbolLayer(
        MapConstants.poisSourceId,
        MapConstants.poisLayerId,
        poiSymbolPaintFor(pixelRatio, palette),
        minzoom: poiMinZoom,
        enableInteraction: false,
      );
    } else {
      await controller.addCircleLayer(
        MapConstants.poisSourceId,
        MapConstants.poisLayerId,
        poiFallbackCirclePaintFor(palette),
        minzoom: poiMinZoom,
        enableInteraction: false,
      );
    }
  } catch (e) {
    debugPrint('addPoiLayers failed: $e');
  }
}

Future<void> updatePoiSource(
  MapLibreMapController controller,
  List<MapPoi> pois, {
  Set<String>? registeredIcons,
}) async {
  try {
    await controller.setGeoJsonSource(
      MapConstants.poisSourceId,
      poisToFeatureCollection(pois, registeredIcons: registeredIcons),
    );
  } catch (e) {
    debugPrint('updatePoiSource failed: $e');
  }
}
