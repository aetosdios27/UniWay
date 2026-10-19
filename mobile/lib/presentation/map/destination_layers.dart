import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/map_constants.dart';
import '../../data/models/destination.dart';

// Destinations are rendered as one GeoJSON source with a circle layer and a
// label layer, so a destination list change costs a single platform channel
// call instead of one circle plus one symbol per destination.

// Labels are hidden below this zoom once the collection becomes dense.
const double labelDenseZoom = 15.0;

// Above this many destinations the label layer is treated as dense.
const int denseDestinationThreshold = 50;

// Sentinel id used by the highlight filters, no destination can match it.
const String noHighlightId = '__uniway_no_highlight__';

// Circle radius grows with the zoom level, the old fixed radius was 7.
const List<Object> destinationCircleRadius = [
  'interpolate',
  ['linear'],
  ['zoom'],
  14,
  5,
  19,
  8,
];

// Highlight rings sit outside the marker circle.
const List<Object> destinationHighlightRadius = [
  'interpolate',
  ['linear'],
  ['zoom'],
  14,
  8,
  19,
  11,
];

const CircleLayerProperties destinationCirclePaint = CircleLayerProperties(
  circleRadius: destinationCircleRadius,
  circleColor: '#2563EB',
  circleStrokeWidth: 2.5,
  circleStrokeColor: '#FFFFFF',
  circleOpacity: 0.95,
);

const CircleLayerProperties destinationOriginPaint = CircleLayerProperties(
  circleRadius: destinationHighlightRadius,
  circleColor: '#16A34A',
  circleOpacity: 0.0,
  circleStrokeWidth: 3.0,
  circleStrokeColor: '#16A34A',
);

const CircleLayerProperties destinationDestinationPaint = CircleLayerProperties(
  circleRadius: destinationHighlightRadius,
  circleColor: '#DC2626',
  circleOpacity: 0.0,
  circleStrokeWidth: 3.0,
  circleStrokeColor: '#DC2626',
);

const SymbolLayerProperties destinationLabelPaint = SymbolLayerProperties(
  textField: ['get', 'name'],
  textFont: ['Noto Sans Regular'],
  textSize: 11.0,
  textColor: '#1E293B',
  textHaloColor: '#FFFFFF',
  textHaloWidth: 2.0,
  textOffset: [0, 1.2],
  textAnchor: 'top',
  // Crowded collections drop labels instead of stacking them on top of each
  // other, a constant sort key keeps the placement order stable.
  symbolSortKey: 0,
  textAllowOverlap: false,
  textOptional: true,
);

// Tracks whether the label layer is currently rendered in dense mode.
bool _labelDense = false;

/// Builds a GeoJSON feature collection holding every destination.
Map<String, dynamic> destinationsToFeatureCollection(
  List<Destination> destinations,
) {
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
}) async {
  try {
    await removeDestinationLayers(controller);

    await controller.addSource(
      MapConstants.destinationsSourceId,
      GeojsonSourceProperties(data: destinationsToFeatureCollection(const [])),
    );

    await controller.addCircleLayer(
      MapConstants.destinationsSourceId,
      MapConstants.destinationsLayerId,
      destinationCirclePaint,
      enableInteraction: false,
    );

    await controller.addCircleLayer(
      MapConstants.destinationsSourceId,
      MapConstants.destinationsOriginLayerId,
      destinationOriginPaint,
      filter: destinationIdFilter(null),
      enableInteraction: false,
    );

    await controller.addCircleLayer(
      MapConstants.destinationsSourceId,
      MapConstants.destinationsDestinationLayerId,
      destinationDestinationPaint,
      filter: destinationIdFilter(null),
      enableInteraction: false,
    );

    _labelDense = destinationCount > denseDestinationThreshold;
    await _addDestinationLabelLayer(controller);
  } catch (e) {
    debugPrint('addDestinationLayers failed: $e');
  }
}

/// Replaces the destination data with a single source update.
Future<void> updateDestinationSource(
  MapLibreMapController controller,
  List<Destination> destinations,
) async {
  try {
    await controller.setGeoJsonSource(
      MapConstants.destinationsSourceId,
      destinationsToFeatureCollection(destinations),
    );
  } catch (e) {
    debugPrint('updateDestinationSource failed: $e');
  }

  // The label zoom range is a layer property, it can only be changed by
  // recreating the label layer.
  final dense = destinations.length > denseDestinationThreshold;
  if (dense != _labelDense) {
    _labelDense = dense;
    try {
      await controller.removeLayer(MapConstants.destinationsLabelsLayerId);
      await _addDestinationLabelLayer(controller);
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
  MapLibreMapController controller,
) async {
  await controller.addSymbolLayer(
    MapConstants.destinationsSourceId,
    MapConstants.destinationsLabelsLayerId,
    destinationLabelPaint,
    minzoom: _labelDense ? labelDenseZoom : null,
    enableInteraction: false,
  );
}
