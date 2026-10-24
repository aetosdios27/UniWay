import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/constants/campus_constants.dart';
import '../../core/services/location_fix.dart';
import '../../core/services/location_filter.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_snapshot.dart';
import '../../data/models/campus_route.dart';
import '../../data/models/destination.dart';
import '../../data/models/map_poi.dart';
import '../../data/repositories/routing_repository.dart';

const locationPublishInterval = Duration(milliseconds: 200);
const locationRetryBaseDelay = Duration(seconds: 1);
const locationRetryMaxDelay = Duration(seconds: 30);

class RoutingController extends ChangeNotifier {
  final RoutingRepository _repository;
  final LocationService _locationService;
  final String campusId;
  final Duration lostTimeout;

  List<Destination> _destinations = const [];
  List<MapPoi> _mapPois = const [];
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
  int _activeRouteRequestId = 0;
  int _activeDestinationsRequestId = 0;
  int _destinationsRevision = 0;
  int _mapPoisRevision = 0;
  bool _disposed = false;

  final LocationFilter _locationFilter = LocationFilter();
  final ValueNotifier<LocationSnapshot?> _location = ValueNotifier(null);
  LocationFix? _fix;
  LocationFix? _pending;
  double? _accuracy;
  bool _stale = false;
  LocationUnavailableReason? _unavailableReason;
  LocationQuality? _notifiedQuality;
  LocationUnavailableReason? _notifiedReason;
  StreamSubscription<LocationFix>? _subscription;
  bool _wantsUpdates = false;
  bool _foreground = true;
  int _retryAttempts = 0;
  Timer? _lostTimer;
  Timer? _flushTimer;
  Timer? _retryTimer;

  RoutingController({
    RoutingRepository? repository,
    LocationService? locationService,
    this.campusId = CampusConstants.syntheticCampusId,
    this.lostTimeout = const Duration(seconds: 15),
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

    unawaited(_loadMapPois(requestId));

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

  /// Map POIs are decorative, so a slow or failing request never delays or breaks destinations.
  Future<void> _loadMapPois(int requestId) async {
    final MapPoisResult result;
    try {
      result = await _repository.getMapPois(campusId: campusId);
    } catch (_) {
      return;
    }
    if (_disposed || requestId != _activeDestinationsRequestId) return;

    _mapPois = result.isSuccess ? result.pois : const [];
    if (result.isSuccess) _mapPoisRevision++;
    notifyListeners();
  }

  List<Destination> get destinations => _destinations;
  List<MapPoi> get mapPois => _mapPois;
  int get mapPoisRevision => _mapPoisRevision;
  Destination? get origin {
    if (_origin != null) return _origin;
    final lat = userLatitude;
    final lng = userLongitude;
    if (lat != null && lng != null) {
      return Destination(
        id: 'GPS_CURRENT_LOCATION',
        routingNodeId: 'GPS',
        name: 'Current Location',
        category: 'gps',
        latitude: lat,
        longitude: lng,
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
  int get destinationsRevision => _destinationsRevision;
  bool get isDisposed => _disposed;
  bool get isGpsOrigin => _origin == null;

  double? get userLatitude => _fix?.latitude;
  double? get userLongitude => _fix?.longitude;
  double? get userAccuracyMeters => _accuracy;
  DateTime? get lastLocationFixAt => _fix?.timestamp;
  ValueListenable<LocationSnapshot?> get locationListenable => _location;
  LocationUnavailableReason? get unavailableReason => _unavailableReason;

  LocationQuality? get locationQuality {
    if (_stale) return LocationQuality.lost;
    final accuracy = _accuracy;
    return accuracy == null ? null : LocationQuality.fromAccuracy(accuracy);
  }

  bool get isLocationLost => locationQuality == LocationQuality.lost;

  bool get isRouteStartApproximate {
    final quality = locationQuality;
    return isGpsOrigin &&
        (quality == LocationQuality.poor || quality == LocationQuality.lost);
  }

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

  void setUserLocation(double latitude, double longitude, {double? accuracyMeters}) {
    _adopt(
      LocationFix(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters ?? 0,
        timestamp: DateTime.now(),
      ),
      accuracyMeters,
    );
    notifyListeners();
  }

  /// Starts the GPS stream. Safe to call repeatedly; a no-op while already listening.
  void startLocationUpdates() {
    if (_disposed) return;
    _wantsUpdates = true;
    if (_subscription != null || _retryTimer != null) return;
    _retryAttempts = 0;
    _subscribe();
  }

  void stopLocationUpdates() {
    _wantsUpdates = false;
    _retryAttempts = 0;
    if (!_disposed) _publishPending();
    _cancelSubscription();
    _cancelTimers();
  }

  /// Cancels the GPS stream in the background and restarts it, with a fresh filter, on resume.
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      if (!_wantsUpdates) return;
      _locationFilter.reset();
      _stale = true;
      _retryAttempts = 0;
      _refresh();
      _subscribe();
      return;
    }
    if (!_foreground) return;
    _foreground = false;
    _publishPending();
    _cancelSubscription();
    _cancelTimers();
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
      startLat = customLat ?? userLatitude;
      startLng = customLng ?? userLongitude;

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
        _adopt(
          LocationFix(
            latitude: startLat!,
            longitude: startLng!,
            accuracyMeters: locResult.accuracyMeters ?? 0,
            timestamp: DateTime.now(),
          ),
          locResult.accuracyMeters,
        );
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

  void _subscribe() {
    if (_disposed || !_wantsUpdates || !_foreground || _subscription != null) return;
    _armLostTimer();
    _subscription = _locationService.positionStream().listen(
      _onRawFix,
      onError: (Object error) => _onLocationFailure(
        error is LocationException ? error.reason : LocationUnavailableReason.signalLost,
      ),
      onDone: () => _onLocationFailure(LocationUnavailableReason.signalLost),
    );
  }

  void _cancelSubscription() {
    final subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
  }

  void _onRawFix(LocationFix raw) {
    if (_disposed) return;
    _retryAttempts = 0;
    _armLostTimer();
    _accuracy = raw.accuracyMeters;
    _unavailableReason = null;

    final accepted = _locationFilter.accept(raw);
    if (accepted == null) {
      final fix = _fix;
      if (fix != null && raw.timestamp.difference(fix.timestamp) > lostTimeout) {
        _stale = true;
      }
      _refresh();
      return;
    }

    final fix = _fix;
    if (fix == null || accepted.timestamp.difference(fix.timestamp) >= locationPublishInterval) {
      _publish(accepted);
    } else {
      _pending = accepted;
      _refresh();
      _flushTimer ??= Timer(locationPublishInterval, _flushPending);
    }
  }

  void _flushPending() {
    _flushTimer = null;
    _publishPending();
  }

  void _publishPending() {
    final pending = _pending;
    if (pending != null) _publish(pending);
  }

  void _publish(LocationFix fix) {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending = null;
    _fix = fix;
    _stale = false;
    _refresh(positionChanged: true);
  }

  void _onLocationFailure(LocationUnavailableReason reason) {
    if (_disposed) return;
    _cancelSubscription();
    _lostTimer?.cancel();
    _lostTimer = null;
    _stale = true;
    _unavailableReason = reason;
    _refresh();
    _scheduleRetry(reason);
  }

  /// Only "service off" and "no signal" are retried, forever at the capped delay; permission denials wait for the user.
  void _scheduleRetry(LocationUnavailableReason reason) {
    final retryable = reason == LocationUnavailableReason.serviceDisabled ||
        reason == LocationUnavailableReason.signalLost;
    if (!retryable || !_wantsUpdates || !_foreground || _retryTimer != null) return;

    var delay = locationRetryBaseDelay * (1 << _retryAttempts);
    if (delay > locationRetryMaxDelay) {
      delay = locationRetryMaxDelay;
    } else {
      _retryAttempts++;
    }
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _subscribe();
    });
  }

  void _armLostTimer() {
    _lostTimer?.cancel();
    _lostTimer = Timer(lostTimeout, _markLost);
  }

  void _markLost() {
    _lostTimer = null;
    if (_disposed) return;
    _stale = true;
    _unavailableReason ??= LocationUnavailableReason.signalLost;
    _refresh();
  }

  void _adopt(LocationFix fix, double? accuracy) {
    _locationFilter.reset();
    if (accuracy != null) _locationFilter.accept(fix);
    _pending = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _accuracy = accuracy;
    _stale = false;
    _unavailableReason = null;
    _fix = fix;
    _refresh(positionChanged: true);
  }

  /// Publishes the snapshot when the position changed, and notifies the controller only on coarse changes.
  void _refresh({bool positionChanged = false}) {
    if (_disposed) return;
    final quality = locationQuality;
    final coarse = quality != _notifiedQuality || _unavailableReason != _notifiedReason;
    if (coarse) {
      _notifiedQuality = quality;
      _notifiedReason = _unavailableReason;
    }
    if (positionChanged || coarse) _location.value = _buildSnapshot(quality);
    if (coarse) notifyListeners();
  }

  LocationSnapshot? _buildSnapshot(LocationQuality? quality) {
    final fix = _fix;
    final accuracy = _accuracy;
    if (fix == null || accuracy == null || quality == null) return null;
    return LocationSnapshot(
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: accuracy,
      quality: quality,
      timestamp: fix.timestamp,
      isStale: _stale,
      unavailableReason: _unavailableReason,
    );
  }

  void _cancelTimers() {
    _lostTimer?.cancel();
    _lostTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stopLocationUpdates();
    _location.dispose();
    _activeRouteRequestId++;
    _activeDestinationsRequestId++;
    _clearActiveRoute();
    _repository.dispose();
    super.dispose();
  }
}
