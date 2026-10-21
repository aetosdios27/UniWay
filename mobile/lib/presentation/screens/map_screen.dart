import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/constants/map_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_snapshot.dart';
import '../../data/models/campus_route.dart';
import '../controllers/auth_controller.dart';
import '../controllers/routing_controller.dart';
import '../map/destination_layers.dart';
import '../map/route_start_connector.dart';
import '../map/supplementary_layers.dart';
import '../map/user_location_layer.dart';
import '../widgets/auth_modal.dart';
import '../widgets/debug_panel.dart';
import '../widgets/location_status_chip.dart';
import '../widgets/profile_badge.dart';
import '../widgets/route_picker_card.dart';
import '../widgets/route_start_notice.dart';
import '../widgets/route_status_banner.dart';

class MapScreen extends StatefulWidget {
  final RoutingController? controller;
  final AuthController? authController;
  final Widget Function(
    BuildContext context,
    void Function(MapLibreMapController controller) onMapCreated,
    void Function() onStyleLoaded,
  )? mapBuilder;

  const MapScreen({
    super.key,
    this.controller,
    this.authController,
    this.mapBuilder,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  late final RoutingController _controller;
  bool _createdLocalController = false;
  late final AuthController _authController;
  bool _createdLocalAuthController = false;
  MapLibreMapController? _mapController;
  Line? _activeRouteLine;
  Line? _activeRouteCasing;
  final RouteStartConnector _startConnector = RouteStartConnector();
  UserLocationLayer? _userLocationLayer;
  LocationSnapshot? _latestSnapshot;
  bool _styleLoaded = false;
  String _renderedDestinationsHash = '';
  String? _highlightedOriginId;
  String? _highlightedDestinationId;
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
    _controller.locationListenable.addListener(_onLocationSnapshot);
    WidgetsBinding.instance.addObserver(this);

    if (widget.authController != null) {
      _authController = widget.authController!;
    } else {
      _authController = AuthController();
      _createdLocalAuthController = true;
    }

    _authController.initialize().then((_) {
      if (!_disposed && !_authController.isAuthenticated && !_authController.isGuest) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && mounted && !_authController.isAuthenticated && !_authController.isGuest) {
            AuthModal.show(context, authController: _authController);
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        _controller.startLocationUpdates();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _redrawPending = false;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onRoutingStateChanged);
    _controller.locationListenable.removeListener(_onLocationSnapshot);
    _controller.stopLocationUpdates();
    _userLocationLayer?.dispose();
    _startConnector.dispose();
    if (_createdLocalController) {
      _controller.dispose();
    }
    if (_createdLocalAuthController) {
      _authController.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.onAppLifecycleChanged(state);
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    final map = _mapController;
    if (map != null) {
      addSupplementaryLayers(map).catchError((_) {});
      await addDestinationLayers(
        map,
        destinationCount: _controller.destinations.length,
      ).catchError((_) {});
      _attachUserLocationLayer(map);
    }
    if (_disposed || !mounted) return;
    // A style reload rebuilds the layers, so the data and the highlights have
    // to be sent again.
    _renderedDestinationsHash = '';
    _highlightedOriginId = null;
    _highlightedDestinationId = null;
    _styleLoaded = true;
    await _syncMapWithState().catchError((_) {});
  }

  void _attachUserLocationLayer(MapLibreMapController map) {
    final layer = _userLocationLayer ??= UserLocationLayer(
      sink: MapLibreUserLocationSink(map),
    );
    layer.attach().catchError((_) {});
    final snapshot = _latestSnapshot;
    if (snapshot != null) {
      layer.update(snapshot);
    }
  }

  void _onLocationSnapshot() {
    final snapshot = _controller.locationListenable.value;
    if (snapshot == null) return;
    _latestSnapshot = snapshot;
    _userLocationLayer?.update(snapshot);
    final map = _mapController;
    if (map != null) {
      _syncStartConnector(map).catchError((_) {});
    }
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
            .map((d) =>
                '${d.id}:${d.routingNodeId}:${d.latitude}:${d.longitude}:${d.name}:${d.category}')
            .join('|');

        if (_renderedDestinationsHash != currentHash) {
          await updateDestinationSource(map, currentDestinations);
          if (_disposed || !mounted) return;
          _renderedDestinationsHash = currentHash;
        }

        final originId = _controller.origin?.id;
        final destinationId = _controller.destination?.id;
        if (_highlightedOriginId != originId ||
            _highlightedDestinationId != destinationId) {
          _highlightedOriginId = originId;
          _highlightedDestinationId = destinationId;
          await setHighlightedDestinations(
            map,
            originId: originId,
            destinationId: destinationId,
          );
          if (_disposed || !mounted) return;
        }

        final route = _controller.currentRoute;
        if (route != null) {
          await _drawRoute(map, route);
        } else {
          await _clearRoute(map);
        }
        if (_disposed || !mounted) return;
        await _syncStartConnector(map);
        if (_disposed || !mounted) return;
      } while (_redrawPending && !_disposed && mounted);
    } finally {
      _isRedrawing = false;
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

  Future<void> _syncStartConnector(MapLibreMapController map) async {
    final snapshot = _latestSnapshot;
    final route = _controller.currentRoute;
    if (_disposed || !mounted) return;
    if (snapshot == null ||
        route == null ||
        route.points.isEmpty ||
        !_controller.isGpsOrigin) {
      await _startConnector.clear(map);
      return;
    }
    await _startConnector.update(
      map,
      LatLng(snapshot.latitude, snapshot.longitude),
      route.points.first,
    );
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

  void _recenterUser() async {
    final snapshot = _controller.locationListenable.value;
    if (snapshot != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(snapshot.latitude, snapshot.longitude),
            zoom: 17.5,
          ),
        ),
      );
      return;
    }
    if (_controller.userLatitude != null && _controller.userLongitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_controller.userLatitude!, _controller.userLongitude!),
            zoom: 17.5,
          ),
        ),
      );
    } else {
      final loc = await LocationService().getCurrentLocation();
      if (_disposed || !mounted) return;
      if (loc.isSuccess && loc.latitude != null && loc.longitude != null) {
        _controller.setUserLocation(
          loc.latitude!,
          loc.longitude!,
          accuracyMeters: loc.accuracyMeters,
        );
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(loc.latitude!, loc.longitude!),
              zoom: 17.5,
            ),
          ),
        );
      }
    }
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'UniWay',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          ProfileBadge(authController: _authController),
                        ],
                      ),
                    ),
                    RoutePickerCard(
                      controller: _controller,
                      onDestinationFocused: (d) => _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(LatLng(d.latitude, d.longitude), 17.5),
                      ),
                    ),
                    LocationStatusChip(
                      _controller.locationListenable,
                      reason: _controller.unavailableReason,
                    ),
                    RouteStatusBanner(controller: _controller),
                    RouteStartNotice(controller: _controller),
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
                      heroTag: 'recenterUser',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      onPressed: _recenterUser,
                      tooltip: 'My Location',
                      child: const Icon(Icons.my_location),
                    ),
                    const SizedBox(height: 8),
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
