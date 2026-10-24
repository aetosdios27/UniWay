import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/map_constants.dart';
import 'map_palette.dart';

// Library is 3 floors, height unknown: render_height 12 and render_min_height 0 (approximation).
const double libraryRenderHeight = 12.0;
const double libraryRenderMinHeight = 0.0;
const String belowBuildingLayerId = 'boundary_3';

FillLayerProperties fillBuildingPaintFor(MapPalette palette) => FillLayerProperties(
  fillColor: palette.buildingFill,
  fillOutlineColor: [
    'interpolate',
    ['linear'],
    ['zoom'],
    13,
    palette.buildingOutlineLowZoom,
    14,
    palette.buildingOutline,
  ],
);

FillExtrusionLayerProperties fillExtrusionBuildingPaintFor(MapPalette palette) =>
    FillExtrusionLayerProperties(
      fillExtrusionBase: const ['get', 'render_min_height'],
      fillExtrusionColor: palette.buildingExtrusion,
      fillExtrusionHeight: const ['get', 'render_height'],
      fillExtrusionOpacity: 0.8,
    );

SymbolLayerProperties symbolBuildingLabelPropertiesFor(MapPalette palette) =>
    SymbolLayerProperties(
      textField: const ['get', 'name'],
      textFont: const ['Noto Sans Italic'],
      textSize: 12.0,
      textColor: palette.buildingLabelText,
      textHaloColor: palette.buildingLabelHalo,
      textHaloWidth: 1.0,
      textHaloBlur: 0.5,
      textAnchor: 'center',
      textMaxWidth: 9.0,
    );

const fillBuildingPaint = FillLayerProperties(
  fillColor: 'hsl(35,8%,85%)',
  fillOutlineColor: [
    'interpolate',
    ['linear'],
    ['zoom'],
    13,
    'hsla(35,6%,79%,0.32)',
    14,
    'hsl(35,6%,79%)',
  ],
);

const fillExtrusionBuildingPaint = FillExtrusionLayerProperties(
  fillExtrusionBase: ['get', 'render_min_height'],
  fillExtrusionColor: 'hsl(35,8%,85%)',
  fillExtrusionHeight: ['get', 'render_height'],
  fillExtrusionOpacity: 0.8,
);

const symbolBuildingLabelProperties = SymbolLayerProperties(
  textField: ['get', 'name'],
  textFont: ['Noto Sans Italic'],
  textSize: 12.0,
  textColor: '#666666',
  textHaloColor: '#ffffff',
  textHaloWidth: 1.0,
  textHaloBlur: 0.5,
  textAnchor: 'center',
  textMaxWidth: 9.0,
);

Map<String, dynamic> prepareSupplementaryGeoJson(
  Map<String, dynamic> rawGeoJson,
) {
  final rawFeatures = rawGeoJson['features'];
  if (rawFeatures is! List) return rawGeoJson;

  final features = rawFeatures
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  if (features.isEmpty ||
      features.any((f) => f['geometry']?['type'] == 'Point')) {
    return rawGeoJson;
  }

  final updatedFeatures = List<Map<String, dynamic>>.from(features);
  for (final feature in features) {
    final geometry = feature['geometry'] as Map?;
    if (geometry == null || geometry['type'] != 'Polygon') continue;

    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null || coordinates.isEmpty) continue;

    final ring = coordinates[0] as List?;
    if (ring == null || ring.isEmpty) continue;

    double sumLng = 0;
    double sumLat = 0;
    int count = 0;

    final points = (ring.length > 1 &&
            ring.first is List &&
            ring.last is List &&
            ring.first[0] == ring.last[0] &&
            ring.first[1] == ring.last[1])
        ? ring.sublist(0, ring.length - 1)
        : ring;

    for (final pt in points) {
      if (pt is List && pt.length >= 2) {
        sumLng += (pt[0] as num).toDouble();
        sumLat += (pt[1] as num).toDouble();
        count++;
      }
    }

    if (count > 0) {
      final centroidLng = sumLng / count;
      final centroidLat = sumLat / count;
      final properties = feature['properties'] as Map?;
      final name = properties != null && properties['name'] != null
          ? properties['name'].toString()
          : 'Knowledge Center';

      updatedFeatures.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [centroidLng, centroidLat],
        },
        'properties': {
          'name': name,
        },
      });
    }
  }

  return {
    ...rawGeoJson,
    'features': updatedFeatures,
  };
}

Future<void> removeSupplementaryLayers(MapLibreMapController controller) async {
  try {
    await controller.removeLayer(MapConstants.campusBuildingsLabelLayerId);
  } catch (_) {}
  try {
    await controller.removeLayer(MapConstants.campusBuildings3dLayerId);
  } catch (_) {}
  try {
    await controller.removeLayer(MapConstants.campusBuildingsLayerId);
  } catch (_) {}
  try {
    await controller.removeSource(MapConstants.campusGeometrySourceId);
  } catch (_) {}
}

Future<void> addSupplementaryLayers(
  MapLibreMapController controller, {
  AssetBundle? bundle,
  MapPalette palette = MapPalette.light,
}) async {
  try {
    await removeSupplementaryLayers(controller);

    final assetBundle = bundle ?? rootBundle;
    final geoJsonString = await assetBundle.loadString(
      MapConstants.supplementaryGeoJsonAssetPath,
    );
    final rawGeoJson = jsonDecode(geoJsonString) as Map<String, dynamic>;
    final geoJsonData = prepareSupplementaryGeoJson(rawGeoJson);

    await controller.addSource(
      MapConstants.campusGeometrySourceId,
      GeojsonSourceProperties(data: geoJsonData),
    );

    await controller.addFillLayer(
      MapConstants.campusGeometrySourceId,
      MapConstants.campusBuildingsLayerId,
      fillBuildingPaintFor(palette),
      belowLayerId: belowBuildingLayerId,
      minzoom: 13.0,
      maxzoom: 14.0,
      filter: ['==', r'', 'Polygon'],
      enableInteraction: false,
    );

    await controller.addFillExtrusionLayer(
      MapConstants.campusGeometrySourceId,
      MapConstants.campusBuildings3dLayerId,
      fillExtrusionBuildingPaintFor(palette),
      belowLayerId: belowBuildingLayerId,
      minzoom: 14.0,
      filter: ['==', r'', 'Polygon'],
      enableInteraction: false,
    );

    await controller.addSymbolLayer(
      MapConstants.campusGeometrySourceId,
      MapConstants.campusBuildingsLabelLayerId,
      symbolBuildingLabelPropertiesFor(palette),
      belowLayerId: belowBuildingLayerId,
      minzoom: 14.0,
      filter: ['==', r'', 'Point'],
      enableInteraction: false,
    );
  } catch (_) {}
}
