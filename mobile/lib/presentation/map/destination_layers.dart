import 'map_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/map_constants.dart';
import '../../core/constants/poi_icons.dart';
import '../../data/models/destination.dart';
import 'poi_icon_registry.dart';

// Destinations are rendered as one GeoJSON source with a symbol layer (or circle
// fallback) and a label layer, so a destination list change costs a single
// platform channel call instead of one circle plus one symbol per destination.

// Labels are hidden below this zoom once the collection becomes dense.
const double labelDenseZoom = 15.0;

// Above this many destinations the label layer is treated as dense.
const int denseDestinationThreshold = 50;

// Sentinel id used by the highlight filters, no destination can match it.
const String noHighlightId = '__uniway_no_highlight__';

// Circle radius grows with the zoom level, used when icon registration fails.
const List<Object> destinationCircleRadius = [
  'interpolate',
  ['linear'],
  ['zoom'],
  14,
  5,
  19,
  8,
];

// Highlight rings sit just outside the marker icon (about 13px to 18px radius).
const List<Object> destinationHighlightRadius = [
  'interpolate',
  ['linear'],
  ['zoom'],
  14,
  16,
  19,
  21,
];

// Marker icons are drawn at 26 dp (zoom 14) growing to 34 dp (zoom 19), the size
// Google and Apple Maps use for place markers, independent of screen density.
List<Object> destinationIconSize(double pixelRatio) => poiIconSizeExpression(
      pixelRatio: pixelRatio,
      minZoom: 14,
      minDp: 26,
      maxZoom: 19,
      maxDp: 34,
    );


CircleLayerProperties destinationCirclePaintFor(MapPalette palette) =>
    CircleLayerProperties(
      circleRadius: destinationCircleRadius,
      circleColor: palette.destinationCircleFill,
      circleStrokeWidth: 2.5,
      circleStrokeColor: palette.destinationCircleStroke,
      circleOpacity: 0.95,
    );

CircleLayerProperties destinationOriginPaintFor(MapPalette palette) =>
    CircleLayerProperties(
      circleRadius: destinationHighlightRadius,
      circleColor: palette.destinationOriginRing,
      circleOpacity: 0.0,
      circleStrokeWidth: 3.0,
      circleStrokeColor: palette.destinationOriginRing,
    );

CircleLayerProperties destinationDestinationPaintFor(MapPalette palette) =>
    CircleLayerProperties(
      circleRadius: destinationHighlightRadius,
      circleColor: palette.destinationDestinationRing,
      circleOpacity: 0.0,
      circleStrokeWidth: 3.0,
      circleStrokeColor: palette.destinationDestinationRing,
    );

SymbolLayerProperties destinationLabelPaintFor(MapPalette palette) =>
    SymbolLayerProperties(
      textField: const ['get', 'name'],
      textFont: const ['Noto Sans Regular'],
      textSize: 11.0,
      textColor: palette.destinationLabelText,
      textHaloColor: palette.destinationLabelHalo,
      textHaloWidth: 2.0,
      textOffset: const [0, 2.1],
      textAnchor: 'top',
      symbolSortKey: 0,
      textAllowOverlap: false,
      textOptional: true,
    );

SymbolLayerProperties destinationMarkerPaint(double pixelRatio) =>
    SymbolLayerProperties(
      iconImage: ['get', 'icon'],
      iconSize: destinationIconSize(pixelRatio),
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      iconAnchor: 'center',
    );

// Tracks whether each map's label layer is currently rendered in dense mode.
// Keying on the controller keeps independent maps from sharing density state,
// and the weak Expando drops an entry once its controller is collected.
final Expando<bool> _labelDenseByController =
    Expando<bool>('destinationLabelDense');

bool _isDenseDestinationCollection(int destinationCount) =>
    destinationCount > denseDestinationThreshold;

Map<String, String>? _iconProperty(String key, Set<String> registered) {
  final icon = effectiveIconImageId(key, registered);
  return icon == null ? null : {'icon': icon};
}

/// Builds a GeoJSON feature collection holding every destination.
Map<String, dynamic> destinationsToFeatureCollection(
  List<Destination> destinations, {
  Set<String>? registeredIcons,
}) {
  final registered = registeredIcons ?? kPoiIconKeys.toSet();
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final destination in destinations)
        {
          'type': 'Feature',
          'id': destination.id,
          'geometry': {
            'type': 'Point',
            'coordinates': [destination.longitude, destination.latitude],
          },
          'properties': {
            'id': destination.id,
            'name': destination.name,
            'category': destination.category,
            ...?_iconProperty(destination.resolvedIconKey, registered),
          },
        },
    ],
  };
}

/// Filter that selects a single destination by its id.
List<Object> destinationIdFilter(String? id) {
  return ['==', 'id', id ?? noHighlightId];
}

Future<void> removeDestinationLayers(MapLibreMapController controller) async {
  try {
    await controller.removeLayer(MapConstants.destinationsLabelsLayerId);
  } catch (_) {}
  try {
    await controller.removeLayer(MapConstants.destinationsDestinationLayerId);
  } catch (_) {}
  try {
    await controller.removeLayer(MapConstants.destinationsOriginLayerId);
  } catch (_) {}
  try {
    await controller.removeLayer(MapConstants.destinationsLayerId);
  } catch (_) {}
  try {
    await controller.removeSource(MapConstants.destinationsSourceId);
  } catch (_) {}
}

Future<void> addDestinationLayers(
  MapLibreMapController controller, {
  int destinationCount = 0,
  Set<String>? registeredIcons,
  double pixelRatio = kDefaultPixelRatio,
  MapPalette palette = MapPalette.light,
}) async {
  try {
    await removeDestinationLayers(controller);

    final registered = registeredIcons ?? kPoiIconKeys.toSet();
    final hasFallback = registered.contains(kPoiIconFallback);

    await controller.addSource(
      MapConstants.destinationsSourceId,
      GeojsonSourceProperties(
        data: destinationsToFeatureCollection(
          const [],
          registeredIcons: registered,
        ),
      ),
    );

    if (hasFallback) {
      await controller.addSymbolLayer(
        MapConstants.destinationsSourceId,
        MapConstants.destinationsLayerId,
        destinationMarkerPaint(pixelRatio),
        enableInteraction: false,
      );
    } else {
      await controller.addCircleLayer(
        MapConstants.destinationsSourceId,
        MapConstants.destinationsLayerId,
        destinationCirclePaintFor(palette),
        enableInteraction: false,
      );
    }

    await controller.addCircleLayer(
      MapConstants.destinationsSourceId,
      MapConstants.destinationsOriginLayerId,
      destinationOriginPaintFor(palette),
      filter: destinationIdFilter(null),
      enableInteraction: false,
    );

    await controller.addCircleLayer(
      MapConstants.destinationsSourceId,
      MapConstants.destinationsDestinationLayerId,
      destinationDestinationPaintFor(palette),
      filter: destinationIdFilter(null),
      enableInteraction: false,
    );

    final dense = _isDenseDestinationCollection(destinationCount);
    await _addDestinationLabelLayer(controller, dense: dense, palette: palette);
    _labelDenseByController[controller] = dense;
  } catch (e) {
    debugPrint('addDestinationLayers failed: $e');
  }
}

/// Replaces the destination data with a single source update.
Future<void> updateDestinationSource(
  MapLibreMapController controller,
  List<Destination> destinations, {
  Set<String>? registeredIcons,
  MapPalette palette = MapPalette.light,
}) async {
  try {
    await controller.setGeoJsonSource(
      MapConstants.destinationsSourceId,
      destinationsToFeatureCollection(
        destinations,
        registeredIcons: registeredIcons,
      ),
    );
  } catch (e) {
    debugPrint('updateDestinationSource failed: $e');
  }

  // The label zoom range is a layer property, it can only be changed by
  // recreating the label layer. Only this controller's own density decides
  // whether that is needed.
  final dense = _isDenseDestinationCollection(destinations.length);
  if (dense != _labelDenseByController[controller]) {
    try {
      await controller.removeLayer(MapConstants.destinationsLabelsLayerId);
      await _addDestinationLabelLayer(controller, dense: dense, palette: palette);
      _labelDenseByController[controller] = dense;
    } catch (_) {}
  }
}

/// Highlights the route endpoints by filtering the highlight layers, the
/// destination collection itself is never re-sent.
Future<void> setHighlightedDestinations(
  MapLibreMapController controller, {
  String? originId,
  String? destinationId,
}) async {
  try {
    await controller.setFilter(
      MapConstants.destinationsOriginLayerId,
      destinationIdFilter(originId),
    );
    await controller.setFilter(
      MapConstants.destinationsDestinationLayerId,
      destinationIdFilter(destinationId),
    );
  } catch (e) {
    debugPrint('setHighlightedDestinations failed: $e');
  }
}

Future<void> _addDestinationLabelLayer(
  MapLibreMapController controller, {
  required bool dense,
  MapPalette palette = MapPalette.light,
}) async {
  await controller.addSymbolLayer(
    MapConstants.destinationsSourceId,
    MapConstants.destinationsLabelsLayerId,
    destinationLabelPaintFor(palette),
    minzoom: dense ? labelDenseZoom : null,
    enableInteraction: false,
  );
}
