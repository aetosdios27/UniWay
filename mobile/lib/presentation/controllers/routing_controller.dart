import 'package:flutter/foundation.dart';
import '../../core/constants/campus_constants.dart';
import '../../data/models/campus_route.dart';
import '../../data/models/destination.dart';
import '../../data/repositories/routing_repository.dart';

class RoutingController extends ChangeNotifier {
  final RoutingRepository _repository;
  final String campusId;

  List<Destination> _destinations = const [];
  Destination? _origin;
  Destination? _destination;
  CampusRoute? _currentRoute;
  bool _isLoading = false;
  bool _isLoadingDestinations = false;
  String? _errorMessage;
  String? _destinationsError;
  int? _statusCode;
  int? _latencyMs;
  bool _accessibleOnly = false;
  int _activeRouteRequestId = 0;
  int _activeDestinationsRequestId = 0;
  int _destinationsRevision = 0;
  bool _disposed = false;

  RoutingController({
    RoutingRepository? repository,
    this.campusId = CampusConstants.syntheticCampusId,
  }) : _repository = repository ?? RoutingRepository() {
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

      if (_destinations.length >= 2) {
        _origin = _destinations.firstWhere(
          (d) => d.name.toLowerCase().contains('dome') || d.name.toLowerCase().contains('ab1'),
          orElse: () => _destinations[0],
        );
        _destination = _destinations.firstWhere(
          (d) => d != _origin,
          orElse: () => _destinations[1],
        );
      } else if (_destinations.isNotEmpty) {
        _origin = _destinations[0];
        _destination = null;
      } else {
        _origin = null;
        _destination = null;
      }
      _clearActiveRoute();
    } else {
      _destinations = const [];
      _destinationsError = result.errorMessage ?? 'Failed to load campus destinations';
      _origin = null;
      _destination = null;
      _clearActiveRoute();
    }

    notifyListeners();
  }

  List<Destination> get destinations => _destinations;
  Destination? get origin => _origin;
  Destination? get destination => _destination;
  CampusRoute? get currentRoute => _currentRoute;
  bool get isLoading => _isLoading;
  bool get isLoadingDestinations => _isLoadingDestinations;
  String? get errorMessage => _errorMessage;
  String? get destinationsError => _destinationsError;
  int? get statusCode => _statusCode;
  int? get latencyMs => _latencyMs;
  bool get accessibleOnly => _accessibleOnly;
  int get destinationsRevision => _destinationsRevision;
  bool get isDisposed => _disposed;

  bool get canGo =>
      !_isLoadingDestinations &&
      _destinationsError == null &&
      _origin != null &&
      _destination != null &&
      _origin != _destination &&
      !_isLoading;

  void setOrigin(Destination? newOrigin) {
    if (_origin == newOrigin) return;
    _activeRouteRequestId++;
    _origin = newOrigin;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _origin != null && _destination != null) {
      fetchRoute();
    }
  }

  void setDestination(Destination? newDestination) {
    if (_destination == newDestination) return;
    _activeRouteRequestId++;
    _destination = newDestination;
    final hadRoute = _currentRoute != null;
    _clearActiveRoute();
    notifyListeners();
    if (hadRoute && _origin != null && _destination != null) {
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
    if (hadRoute && _origin != null && _destination != null) {
      fetchRoute();
    }
  }

  void swap() {
    if (_origin == null || _destination == null) return;
    _activeRouteRequestId++;
    final temp = _origin;
    _origin = _destination;
    _destination = temp;
    _clearActiveRoute();
    notifyListeners();
    fetchRoute();
  }

  Future<void> fetchRoute() async {
    if (_origin == null || _destination == null || _disposed) return;

    final requestId = ++_activeRouteRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.getRoute(
      campusId: campusId,
      origin: _origin!,
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
