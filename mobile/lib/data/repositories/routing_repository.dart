import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/campus_route.dart';
import '../models/destination.dart';

class RoutingResult {
  final CampusRoute? route;
  final String? errorMessage;
  final int statusCode;
  final int latencyMs;

  const RoutingResult({
    this.route,
    this.errorMessage,
    required this.statusCode,
    required this.latencyMs,
  });

  bool get isSuccess => route != null && errorMessage == null;
}

class DestinationsResult {
  final List<Destination> destinations;
  final String? errorMessage;
  final int statusCode;

  const DestinationsResult({
    this.destinations = const [],
    this.errorMessage,
    required this.statusCode,
  });

  bool get isSuccess => errorMessage == null && statusCode == 200;
}

class RoutingRepository {
  final http.Client _client;

  RoutingRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<DestinationsResult> getDestinations({required String campusId}) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.destinationsEndpoint(campusId)}',
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'x-request-id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>? ?? [];
        final parsed = data
            .map((item) => Destination.fromJson(item as Map<String, dynamic>))
            .toList();
        return DestinationsResult(
          destinations: parsed,
          statusCode: 200,
        );
      }

      String message = 'Failed to load destinations (${response.statusCode})';
      try {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded.containsKey('error') && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}

      return DestinationsResult(
        destinations: const [],
        errorMessage: message,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return DestinationsResult(
        destinations: const [],
        errorMessage: e.toString(),
        statusCode: 0,
      );
    }
  }

  Future<RoutingResult> getRoute({
    required String campusId,
    required Destination origin,
    required Destination destination,
    bool accessible = false,
  }) async {
    final queryParams = {
      'fromLng': origin.longitude.toString(),
      'fromLat': origin.latitude.toString(),
      'toNodeId': destination.routingNodeId,
      'floor': '0',
      if (accessible) 'accessible': 'true',
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.nodeRouteEndpoint(campusId)}',
    ).replace(queryParameters: queryParams);

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'x-request-id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(ApiConstants.requestTimeout);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final route = CampusRoute.fromGeoJson(decoded);
        return RoutingResult(
          route: route,
          statusCode: 200,
          latencyMs: latency,
        );
      }

      String message = 'Failed to calculate route (${response.statusCode})';
      try {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        if (decoded.containsKey('error') && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}

      return RoutingResult(
        errorMessage: message,
        statusCode: response.statusCode,
        latencyMs: latency,
      );
    } catch (e) {
      stopwatch.stop();
      return RoutingResult(
        errorMessage: e.toString(),
        statusCode: 0,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
