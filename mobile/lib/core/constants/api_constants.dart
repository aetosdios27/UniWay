import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _customBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://localhost:3000';
  }

  static String routeEndpoint(String campusId) => '/api/campus/$campusId/route';
  static String nodeRouteEndpoint(String campusId) => '/api/campus/$campusId/node-route';
  static String destinationsEndpoint(String campusId) => '/api/campus/$campusId/destinations';
  static String poisEndpoint(String campusId) => '/api/campus/$campusId/pois';
  static const Duration requestTimeout = Duration(seconds: 12);
}
