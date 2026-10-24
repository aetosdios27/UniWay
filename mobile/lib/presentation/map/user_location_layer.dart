import 'map_palette.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/services/location_snapshot.dart';
import 'supplementary_layers.dart';

const String userLocationSourceId = 'uniway-user-location-source';
const String userLocationAccuracyFillLayerId =
    'uniway-user-location-accuracy-fill';
const String userLocationAccuracyOutlineLayerId =
    'uniway-user-location-accuracy-outline';
const String userLocationAccuracyLostLayerId =
    'uniway-user-location-accuracy-lost-outline';
const String userLocationDotLayerId = 'uniway-user-location-dot';

const int userLocationAccuracyVertexCount = 48;

const double _earthRadiusMeters = 6371008.8;
const double _metersPerDegree = _earthRadiusMeters * math.pi / 180.0;

const String userLocationGoodColor = '#2563EB';
const String userLocationFairColor = '#F59E0B';
const String userLocationPoorColor = '#F97316';
const String userLocationLostColor = '#9CA3AF';

const List<dynamic> userLocationQualityColorExpression = [
  'match',
  ['get', 'quality'],
  'good',
  userLocationGoodColor,
  'fair',
  userLocationFairColor,
  'poor',
  userLocationPoorColor,
  'lost',
  userLocationLostColor,
  userLocationGoodColor,
];

const List<dynamic> userLocationAccuracyOpacityExpression = [
  'case',
  ['==', ['get', 'quality'], 'lost'],
  0.06,
  0.18,
];

const FillLayerProperties userLocationAccuracyFillPaint = FillLayerProperties(
  fillColor: userLocationQualityColorExpression,
  fillOpacity: userLocationAccuracyOpacityExpression,
);

const LineLayerProperties userLocationAccuracyOutlinePaint =
    LineLayerProperties(
  lineColor: userLocationQualityColorExpression,
  lineWidth: 1.2,
  lineOpacity: 0.5,
);

const LineLayerProperties userLocationAccuracyLostPaint = LineLayerProperties(
  lineColor: userLocationQualityColorExpression,
  lineWidth: 1.2,
  lineOpacity: 0.45,
  lineDasharray: [2, 2],
);


List<dynamic> userLocationQualityColorExpressionFor(MapPalette palette) => [
  'match',
  ['get', 'quality'],
  'good',
  palette.userLocationGood,
  'fair',
  palette.userLocationFair,
  'poor',
  palette.userLocationPoor,
  'lost',
  palette.userLocationLost,
  palette.userLocationGood,
];

FillLayerProperties userLocationAccuracyFillPaintFor(MapPalette palette) =>
    FillLayerProperties(
      fillColor: userLocationQualityColorExpressionFor(palette),
      fillOpacity: userLocationAccuracyOpacityExpression,
    );

LineLayerProperties userLocationAccuracyOutlinePaintFor(MapPalette palette) =>
    LineLayerProperties(
      lineColor: userLocationQualityColorExpressionFor(palette),
      lineWidth: 1.2,
      lineOpacity: 0.5,
    );

LineLayerProperties userLocationAccuracyLostPaintFor(MapPalette palette) =>
    LineLayerProperties(
      lineColor: userLocationQualityColorExpressionFor(palette),
      lineWidth: 1.2,
      lineOpacity: 0.45,
      lineDasharray: const [2, 2],
    );

CircleLayerProperties userLocationDotPaintFor(MapPalette palette) =>
    CircleLayerProperties(
      circleRadius: 7,
      circleColor: userLocationQualityColorExpressionFor(palette),
      circleOpacity: 0.95,
      circleStrokeWidth: 2.5,
      circleStrokeColor: palette.userLocationDotRing,
    );

const CircleLayerProperties userLocationDotPaint = CircleLayerProperties(
  circleRadius: 7,
  circleColor: userLocationQualityColorExpression,
  circleOpacity: 0.95,
  circleStrokeWidth: 2.5,
  circleStrokeColor: '#FFFFFF',
);

/// Polygon approximating a circle of [meters] radius around [c].
///
/// Returns [userLocationAccuracyVertexCount] distinct vertices spread evenly
/// over the full circle, followed by a closing point that repeats the first
/// one. The ring therefore holds `userLocationAccuracyVertexCount + 1` points
/// and every edge, including the closing one, spans the same angle.
List<LatLng> accuracyCirclePolygon(LatLng c, double meters) {
  if (meters <= 0) {
    return [c, c];
  }

  final latOffset = meters / _metersPerDegree;
  final cosLat = math.cos(c.latitude * math.pi / 180.0);
  final lngOffset =
      meters / (_metersPerDegree * (cosLat.abs() < 0.01 ? 0.01 : cosLat));

  final points = <LatLng>[];
  for (var i = 0; i < userLocationAccuracyVertexCount; i++) {
    final angle = 2 * math.pi * i / userLocationAccuracyVertexCount;
    points.add(
      LatLng(
        c.latitude + latOffset * math.cos(angle),
        c.longitude + lngOffset * math.sin(angle),
      ),
    );
  }
  points.add(points.first);
  return points;
}

/// Quality used for styling; a stale fix is always drawn as lost.
String effectiveLocationQuality(LocationSnapshot snapshot) {
  if (snapshot.isStale) return 'lost';
  return snapshot.quality.name;
}

Map<String, dynamic> buildUserLocationGeoJson(LocationSnapshot snapshot) {
  final center = LatLng(snapshot.latitude, snapshot.longitude);
  final quality = effectiveLocationQuality(snapshot);
  final features = <Map<String, dynamic>>[];

  if (snapshot.accuracyMeters > 0) {
    final ring = accuracyCirclePolygon(center, snapshot.accuracyMeters);
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [for (final point in ring) [point.longitude, point.latitude]],
        ],
      },
      'properties': {
        'kind': 'accuracy',
        'quality': quality,
        'stale': snapshot.isStale,
      },
    });
  }

  features.add({
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [center.longitude, center.latitude],
    },
    'properties': {
      'kind': 'dot',
      'quality': quality,
      'stale': snapshot.isStale,
    },
  });

  return {
    'type': 'FeatureCollection',
    'features': features,
  };
}

/// Minimal map surface used by [UserLocationLayer].
abstract class UserLocationMapSink {
  /// Creates the GeoJSON source backing the user location layers.
  Future<void> addSource(String sourceId);

  /// Replaces the data of an already created GeoJSON source.
  Future<void> setSource(String sourceId, Map<String, dynamic> geojson);

  /// Adds the accuracy and dot layers on top of [sourceId].
  Future<void> addLayers(String sourceId);

  /// Removes the layers previously added by [addLayers].
  Future<void> removeLayers();
}

class MapLibreUserLocationSink implements UserLocationMapSink {
  final MapLibreMapController controller;
  MapPalette palette;

  MapLibreUserLocationSink(
    this.controller, {
    this.palette = MapPalette.light,
  });

  @override
  Future<void> addSource(String sourceId) async {
    try {
      await controller.removeSource(sourceId);
    } catch (_) {}
    try {
      await controller.addGeoJsonSource(
        sourceId,
        const {
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        },
      );
    } catch (_) {}
  }

  @override
  Future<void> setSource(String sourceId, Map<String, dynamic> geojson) async {
    try {
      await controller.setGeoJsonSource(sourceId, geojson);
    } catch (_) {}
  }

  @override
  Future<void> addLayers(String sourceId) async {
    try {
      await controller.addFillLayer(
        sourceId,
        userLocationAccuracyFillLayerId,
        userLocationAccuracyFillPaintFor(palette),
        belowLayerId: belowBuildingLayerId,
        filter: ['==', r'$type', 'Polygon'],
        enableInteraction: false,
      );
    } catch (_) {}
    try {
      await controller.addLineLayer(
        sourceId,
        userLocationAccuracyOutlineLayerId,
        userLocationAccuracyOutlinePaintFor(palette),
        belowLayerId: belowBuildingLayerId,
        filter: ['all', ['==', r'$type', 'Polygon'], ['!=', 'quality', 'lost']],
        enableInteraction: false,
      );
    } catch (_) {}
    try {
      await controller.addLineLayer(
        sourceId,
        userLocationAccuracyLostLayerId,
        userLocationAccuracyLostPaintFor(palette),
        belowLayerId: belowBuildingLayerId,
        filter: ['all', ['==', r'$type', 'Polygon'], ['==', 'quality', 'lost']],
        enableInteraction: false,
      );
    } catch (_) {}
    try {
      await controller.addCircleLayer(
        sourceId,
        userLocationDotLayerId,
        userLocationDotPaintFor(palette),
        belowLayerId: belowBuildingLayerId,
        filter: ['==', r'$type', 'Point'],
        enableInteraction: false,
      );
    } catch (_) {}
  }

  @override
  Future<void> removeLayers() async {
    try {
      await controller.removeLayer(userLocationDotLayerId);
    } catch (_) {}
    try {
      await controller.removeLayer(userLocationAccuracyLostLayerId);
    } catch (_) {}
    try {
      await controller.removeLayer(userLocationAccuracyOutlineLayerId);
    } catch (_) {}
    try {
      await controller.removeLayer(userLocationAccuracyFillLayerId);
    } catch (_) {}
  }
}

/// Draws the user position on the map from a stream of [LocationSnapshot]s.
///
/// Updates are coalesced: while a source write is in flight only the newest
/// pending snapshot is kept, so a fast GPS stream never queues up work.
class UserLocationLayer {
  final UserLocationMapSink sink;

  UserLocationLayer({required this.sink});

  bool _disposed = false;
  bool _attached = false;
  bool _updateInFlight = false;
  LocationSnapshot? _pendingSnapshot;
  Completer<void>? _pendingCompleter;

  bool get isAttached => _attached;
  bool get isDisposed => _disposed;

  /// Creates the source and the layers. Safe to call again after a style
  /// reload: the source and the layers are recreated in place.
  Future<void> attach() async {
    if (_disposed) return;
    try {
      await sink.addSource(userLocationSourceId);
      await sink.addLayers(userLocationSourceId);
    } catch (_) {}
    _attached = true;
    if (_pendingSnapshot != null) {
      unawaited(_drain());
    }
  }

  /// Removes the layers from the map.
  Future<void> detach() async {
    if (_disposed) return;
    _attached = false;
    await _removeFromMap();
  }

  /// Queues [snapshot] for rendering. The returned future completes once the
  /// snapshot has been written to the map or superseded by a newer one.
  Future<void> update(LocationSnapshot snapshot) {
    if (_disposed) return Future<void>.value();
    _pendingSnapshot = snapshot;
    final completer = Completer<void>();
    _pendingCompleter?.complete();
    _pendingCompleter = completer;
    unawaited(_drain());
    return completer.future;
  }

  /// Releases the layer. Further calls are ignored.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _attached = false;
    _pendingSnapshot = null;
    _pendingCompleter?.complete();
    _pendingCompleter = null;
    unawaited(_removeFromMap());
  }

  Future<void> _drain() async {
    if (_updateInFlight || _disposed || !_attached) return;
    final snapshot = _pendingSnapshot;
    if (snapshot == null) return;

    final completer = _pendingCompleter;
    _pendingSnapshot = null;
    _pendingCompleter = null;
    _updateInFlight = true;
    try {
      await sink.setSource(
        userLocationSourceId,
        buildUserLocationGeoJson(snapshot),
      );
    } catch (_) {} finally {
      _updateInFlight = false;
    }
    completer?.complete();

    if (_pendingSnapshot != null && !_disposed) {
      unawaited(_drain());
    }
  }

  Future<void> _removeFromMap() async {
    try {
      await sink.removeLayers();
    } catch (_) {}
  }
}
