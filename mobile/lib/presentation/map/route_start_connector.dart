import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/utils/geo_distance.dart';
import 'map_palette.dart';

const double routeStartConnectorThresholdMeters = 3.0;

/// Whether the raw position and the route start are far enough apart that a
/// connector line is needed to avoid implying the route starts at the fix.
bool shouldDrawStartConnector(LatLng user, LatLng routeStart) {
  return haversineMeters(
        user.latitude,
        user.longitude,
        routeStart.latitude,
        routeStart.longitude,
      ) >
      routeStartConnectorThresholdMeters;
}

/// Draws the connector between the raw position and the route start using a
/// single reusable line.
class RouteStartConnector {
  Line? _line;
  MapLibreMapController? _map;
  bool _disposed = false;

  /// Forgets the line handle without calling [removeLine] on the map.
  /// Used after a style reload when the underlying style destroyed the line.
  void reset() {
    _line = null;
  }

  Future<void> update(
    MapLibreMapController map,
    LatLng user,
    LatLng routeStart, {
    MapPalette palette = MapPalette.light,
  }) async {
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
        await map.updateLine(
          line,
          LineOptions(
            geometry: geometry,
            lineColor: palette.connectorColor,
            lineOpacity: palette.connectorOpacity,
          ),
        );
      } catch (_) {}
      return;
    }

    try {
      _line = await map.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: palette.connectorColor,
          lineWidth: 1.5,
          lineOpacity: palette.connectorOpacity,
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
