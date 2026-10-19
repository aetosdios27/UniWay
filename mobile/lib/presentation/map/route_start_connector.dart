import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

const double routeStartConnectorThresholdMeters = 3.0;

const double _earthRadiusMeters = 6371008.8;

/// Great-circle distance between two points, in metres.
double distanceMetersBetween(LatLng a, LatLng b) {
  final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
  final lat1 = a.latitude * math.pi / 180.0;
  final lat2 = b.latitude * math.pi / 180.0;

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  return 2 * _earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Whether the raw position and the route start are far enough apart that a
/// connector line is needed to avoid implying the route starts at the fix.
bool shouldDrawStartConnector(LatLng user, LatLng routeStart) {
  return distanceMetersBetween(user, routeStart) >
      routeStartConnectorThresholdMeters;
}

/// Draws the connector between the raw position and the route start using a
/// single reusable line.
class RouteStartConnector {
  Line? _line;
  MapLibreMapController? _map;
  bool _disposed = false;

  Future<void> update(
    MapLibreMapController map,
    LatLng user,
    LatLng routeStart,
  ) async {
    if (_disposed) return;
    _map = map;

    if (!shouldDrawStartConnector(user, routeStart)) {
      await clear(map);
      return;
    }

    final geometry = [user, routeStart];
    final line = _line;
    if (line != null) {
      try {
        await map.updateLine(line, LineOptions(geometry: geometry));
      } catch (_) {}
      return;
    }

    try {
      _line = await map.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: '#64748B',
          lineWidth: 1.5,
          lineOpacity: 0.45,
          lineJoin: 'round',
        ),
      );
    } catch (_) {}
  }

  Future<void> clear(MapLibreMapController map) async {
    final line = _line;
    _line = null;
    if (line == null) return;
    try {
      await map.removeLine(line);
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    final line = _line;
    final map = _map;
    _line = null;
    if (line == null || map == null) return;
    map.removeLine(line).catchError((_) {});
  }
}
