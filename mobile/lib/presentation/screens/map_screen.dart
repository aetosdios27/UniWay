import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/map_constants.dart';
import '../../data/models/campus_route.dart';
import '../../data/models/destination.dart';
import '../controllers/routing_controller.dart';
import '../widgets/debug_panel.dart';
import '../widgets/route_picker_card.dart';
import '../widgets/route_status_banner.dart';

class MapScreen extends StatefulWidget {
  final RoutingController? controller;
  final Widget Function(
    BuildContext context,
    void Function(MapLibreMapController controller) onMapCreated,
    void Function() onStyleLoaded,
  )? mapBuilder;

  const MapScreen({
    super.key,
    this.controller,
    this.mapBuilder,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final RoutingController _controller;
  bool _createdLocalController = false;
  MapLibreMapController? _mapController;
  Line? _activeRouteLine;
  Line? _activeRouteCasing;
  final List<Circle> _destinationCircles = [];
  final List<Symbol> _destinationSymbols = [];
  bool _styleLoaded = false;
  String _renderedDestinationsHash = '';
  bool _isRedrawing = false;
  bool _redrawPending = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = RoutingController();
      _createdLocalController = true;
    }
    _controller.addListener(_onRoutingStateChanged);
  }

  @override
  void dispose() {
    _disposed = true;
    _redrawPending = false;
    _controller.removeListener(_onRoutingStateChanged);
    if (_createdLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _syncMapWithState().catchError((_) {});
  }

  void _onRoutingStateChanged() {
    _syncMapWithState().catchError((_) {});
  }

  Future<void> _syncMapWithState() async {
    final map = _mapController;
    if (_disposed || !mounted || !_styleLoaded || map == null) return;

    if (_isRedrawing) {
      _redrawPending = true;
      return;
    }

    _isRedrawing = true;
    try {
      do {
        if (_disposed || !mounted) return;
        _redrawPending = false;

        final currentDestinations = _controller.destinations;
        final currentHash = currentDestinations
            .map((d) => '${d.id}:${d.routingNodeId}:${d.latitude}:${d.longitude}')
            .join('|');

        if (_renderedDestinationsHash != currentHash) {
          await _renderDestinationMarkers(map, currentDestinations);
          if (_disposed || !mounted) return;
          _renderedDestinationsHash = currentHash;
        }

        final route = _controller.currentRoute;
        if (route != null) {
          await _drawRoute(map, route);
        } else {
          await _clearRoute(map);
        }
        if (_disposed || !mounted) return;
      } while (_redrawPending && !_disposed && mounted);
    } finally {
      _isRedrawing = false;
    }
  }

  Future<void> _renderDestinationMarkers(
    MapLibreMapController map,
    List<Destination> destinations,
  ) async {
    for (final circle in _destinationCircles) {
      if (_disposed || !mounted) return;
      await map.removeCircle(circle);
    }
    _destinationCircles.clear();

    for (final symbol in _destinationSymbols) {
      if (_disposed || !mounted) return;
      await map.removeSymbol(symbol);
    }
    _destinationSymbols.clear();

    for (final d in destinations) {
      if (_disposed || !mounted) return;
      final latLng = LatLng(d.latitude, d.longitude);

      final circle = await map.addCircle(
        CircleOptions(
          geometry: latLng,
          circleColor: '#2563EB',
          circleRadius: 7.0,
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
          circleOpacity: 0.95,
        ),
      );
      _destinationCircles.add(circle);

      if (_disposed || !mounted) return;
      final symbol = await map.addSymbol(
        SymbolOptions(
          geometry: latLng,
          textField: d.name,
          textSize: 11.0,
          textColor: '#1E293B',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.0,
          textOffset: const Offset(0, 1.2),
          textAnchor: 'top',
        ),
      );
      _destinationSymbols.add(symbol);
    }
  }

  Future<void> _clearRoute(MapLibreMapController map) async {
    if (_activeRouteCasing != null) {
      final casing = _activeRouteCasing!;
      _activeRouteCasing = null;
      if (_disposed || !mounted) return;
      await map.removeLine(casing);
    }
    if (_activeRouteLine != null) {
      final line = _activeRouteLine!;
      _activeRouteLine = null;
      if (_disposed || !mounted) return;
      await map.removeLine(line);
    }
  }

  Future<void> _drawRoute(MapLibreMapController map, CampusRoute route) async {
    if (route.points.isEmpty || _disposed || !mounted) return;

    await _clearRoute(map);
    if (_disposed || !mounted) return;

    _activeRouteCasing = await map.addLine(
      LineOptions(
        geometry: route.points,
        lineColor: '#1E40AF',
        lineWidth: 8.0,
        lineOpacity: 0.5,
        lineJoin: 'round',
      ),
    );

    if (_disposed || !mounted) return;

    _activeRouteLine = await map.addLine(
      LineOptions(
        geometry: route.points,
        lineColor: '#2563EB',
        lineWidth: 5.0,
        lineOpacity: 0.95,
        lineJoin: 'round',
      ),
    );

    if (_disposed || !mounted) return;

    _fitRouteBounds(map, route.points);
  }

  void _fitRouteBounds(MapLibreMapController map, List<LatLng> points) {
    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        top: 140,
        bottom: 120,
        left: 40,
        right: 40,
      ),
    );
  }

  void _recenterMuj() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(MapConstants.mujLatitude, MapConstants.mujLongitude),
          zoom: MapConstants.defaultZoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              if (widget.mapBuilder != null)
                widget.mapBuilder!(context, _onMapCreated, _onStyleLoaded)
              else
                MapLibreMap(
                  styleString: MapConstants.openFreeMapLibertyStyle,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(
                      MapConstants.mujLatitude,
                      MapConstants.mujLongitude,
                    ),
                    zoom: MapConstants.defaultZoom,
                  ),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  myLocationEnabled: false,
                  trackCameraPosition: true,
                  compassEnabled: true,
                ),
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoutePickerCard(controller: _controller),
                    RouteStatusBanner(controller: _controller),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'recenterMuj',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      onPressed: _recenterMuj,
                      tooltip: 'Center on MUJ',
                      child: const Icon(Icons.school),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SafeArea(
                  child: DebugPanel(controller: _controller),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
