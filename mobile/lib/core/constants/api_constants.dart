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
  static String mapPoisEndpoint(String campusId) => '/api/campus/$campusId/map-pois';
  static String poisEndpoint(String campusId) => '/api/campus/$campusId/pois';
  static const String authRegisterEndpoint = '/api/auth/register';
  static const String authLoginEndpoint = '/api/auth/login';
  static const String authGoogleEndpoint = '/api/auth/google';
  static const String authMeEndpoint = '/api/auth/me';

  /// Web/server OAuth client ID passed at build time via
  /// --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>. It is the audience the backend
  /// requires on Google ID tokens (see docs/auth-setup.md).
  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const Duration requestTimeout = Duration(seconds: 12);
}
