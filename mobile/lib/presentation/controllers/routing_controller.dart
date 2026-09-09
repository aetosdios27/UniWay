import 'package:flutter/foundation.dart';
import '../../core/constants/campus_constants.dart';
import '../../core/services/location_service.dart';
import '../../data/models/campus_route.dart';
import '../../data/models/destination.dart';
import '../../data/repositories/routing_repository.dart';

class RoutingController extends ChangeNotifier {
  final RoutingRepository _repository;
  final LocationService _locationService;
  final String campusId;

  List<Destination> _destinations = const [];
  Destination? _origin;
  Destination? _destination;
  CampusRoute? _currentRoute;
  bool _isLoading = false;
  bool _isLocating = false;
  bool _isLoadingDestinations = false;
  String? _errorMessage;
  String? _destinationsError;
  int? _statusCode;
  int? _latencyMs;
  bool _accessibleOnly = false;
  double? _userLatitude;
  double? _userLongitude;
  int _activeRouteRequestId = 0;
  int _activeDestinationsRequestId = 0;
  int _destinationsRevision = 0;
  bool _disposed = false;

  RoutingController({
    RoutingRepository? repository,
    LocationService? locationService,
    this.campusId = CampusConstants.syntheticCampusId,
  })  : _repository = repository ?? RoutingRepository(),
        _locationService = locationService ?? LocationService() {
    loadDestinations();
  }

  Future<void> loadDestinations() async {
    final requestId = ++_activeDestinationsRequestId;
    _activeRouteRequestId++;
    _clearActiveRoute();
    _isLoadingDestinations = true;
    _destinationsError = null;
    notifyListeners();

    final result = await _repository.getDestinations(campusId: campusId);
    if (_disposed || requestId != _activeDestinationsRequestId) return;

    _isLoadingDestinations = false;

    if (result.isSuccess) {
      _destinations = result.destinations;
      _destinationsRevision++;
      _destinationsError = null;

      if (_destinations.isNotEmpty) {
        if (_destination == null || !_destinations.contains(_destination)) {
          _destination = _destinations.firstWhere(
            (d) => d.name.toLowerCase().contains('ab1'),
            orElse: () => _destinations[0],
          );
        }
      } else {
        _destination = null;
      }
      _clearActiveRoute();
    } else {
      _destinations = const [];
      _destinationsError = result.errorMessage ?? 'Failed to load campus destinations';
      _destination = null;
      _clearActiveRoute();
    }

    notifyListeners();
  }

  List<Destination> get destinations => _destinations;
  Destination? get origin {
    if (_origin != null) return _origin;
    if (_userLatitude != null && _userLongitude != null) {
      return Destination(
        id: 'GPS_CURRENT_LOCATION',
        routingNodeId: 'GPS',
        name: 'Current Location',
        category: 'gps',
        latitude: _userLatitude!,
        longitude: _userLongitude!,
      );
    }
    return null;
  }
  Destination? get destination => _destination;
  CampusRoute? get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;
  bool get isLocating => _isLocating;
  bool get isLoadingDestinations => _isLoadingDestinations;
  String? get errorMessage => _errorMessage;
  String? get destinationsError => _destinationsError;
  int? get statusCode => _statusCode;
  int? get latencyMs => _latencyMs;
  bool get accessibleOnly => _accessibleOnly;
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  int get destinationsRevision => _destinationsRevision;
  bool get isDisposed => _disposed;
  bool get isGpsOrigin => _origin == null;

  bool get canGo =>
      !_isLoadingDestinations &&
      _destinationsError == null &&
      _destination != null &&
      (_origin == null || _origin!.id != _destination!.id) &&
      !_isLoading &&
      !_isLocating;

  void setDestination(Destination? newDestination) {
    if (_destination == newDestination) return;
    _activeRouteRequestId++;
    _destination = newDestination;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _destination != null) {
      fetchRoute();
    }
  }

  void setUserLocation(double latitude, double longitude) {
    _userLatitude = latitude;
    _userLongitude = longitude;
    notifyListeners();
  }

  void setOrigin(Destination? newOrigin) {
    final effective = (newOrigin == null || newOrigin.id == 'YOUR_LOCATION') ? null : newOrigin;
    if (_origin == effective) return;
    _activeRouteRequestId++;
    _origin = effective;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _destination != null) {
      fetchRoute();
    }
  }

  void setAccessibleOnly(bool value) {
    if (_accessibleOnly == value) return;
    _activeRouteRequestId++;
    _accessibleOnly = value;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _destination != null) {
      fetchRoute();
    }
  }

  void swap() {
    if (_origin == null || _destination == null) return;
    if (_origin!.id == _destination!.id) return;
    _activeRouteRequestId++;
    final temp = _origin;
    _origin = _destination;
    _destination = temp;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _destination != null) {
      fetchRoute();
    }
  }

  Future<void> fetchRoute({double? customLat, double? customLng}) async {
    if (_destination == null || _disposed) return;
    if (_origin != null && _origin!.id == _destination!.id) return;

    final requestId = ++_activeRouteRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    double? startLat;
    double? startLng;

    if (_origin != null) {
      startLat = _origin!.latitude;
      startLng = _origin!.longitude;
    } else {
      startLat = customLat ?? _userLatitude;
      startLng = customLng ?? _userLongitude;

      if (startLat == null || startLng == null) {
        _isLocating = true;
        notifyListeners();

        final locResult = await _locationService.getCurrentLocation();
        if (_disposed || requestId != _activeRouteRequestId) return;

        _isLocating = false;

        if (!locResult.isSuccess) {
          _isLoading = false;
          _errorMessage = locResult.error ?? 'Unable to acquire device GPS location';
          notifyListeners();
          return;
        }

        startLat = locResult.latitude;
        startLng = locResult.longitude;
        _userLatitude = startLat;
        _userLongitude = startLng;
      }
    }

    final result = await _repository.getRoute(
      campusId: campusId,
      fromLng: startLng,
      fromLat: startLat,
      origin: _origin,
      destination: _destination!,
      accessible: _accessibleOnly,
    );

    if (_disposed || requestId != _activeRouteRequestId) {
      return;
    }

    _isLoading = false;
    _statusCode = result.statusCode;
    _latencyMs = result.latencyMs;

    if (result.isSuccess) {
      _currentRoute = result.route;
      _errorMessage = null;
    } else {
      _currentRoute = null;
      _errorMessage = result.errorMessage;
    }

    notifyListeners();
  }

  void clearRoute() {
    _activeRouteRequestId++;
    _clearActiveRoute();
    notifyListeners();
  }

  void _clearActiveRoute() {
    _isLoading = false;
    _isLocating = false;
    _currentRoute = null;
    _errorMessage = null;
    _statusCode = null;
    _latencyMs = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _activeRouteRequestId++;
    _activeDestinationsRequestId++;
    _clearActiveRoute();
    _repository.dispose();
    super.dispose();
  }
}
