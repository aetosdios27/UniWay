import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/token_storage.dart';
import '../models/user.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  const AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthRepository {
  final http.Client _client;
  SharedPreferences? _prefs;
  final TokenStorage _tokenStorage;

  static const String _tokenKey = 'uniway_auth_token';
  static const String _userKey = 'uniway_auth_user';
  static const String _guestKey = 'uniway_guest_mode';

  AuthRepository({
    http.Client? client,
    SharedPreferences? prefs,
    TokenStorage? tokenStorage,
  })  : _client = client ?? http.Client(),
        _prefs = prefs,
        _tokenStorage = tokenStorage ?? SecureTokenStorage();

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<String?> getSavedToken() async {
    final stored = await _tokenStorage.read();
    if (stored != null) return stored;

    final prefs = await _getPrefs();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null) {
      await _tokenStorage.write(legacy);
      await prefs.remove(_tokenKey);
    }
    return legacy;
  }

  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authRegisterEndpoint}');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'name': name.trim(),
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await saveSession(token, user);
        return user;
      }

      final errorMsg = body['error'] as String? ?? 'Registration failed';
      throw AuthException(errorMsg, statusCode: response.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error during registration: $e');
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authLoginEndpoint}');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await saveSession(token, user);
        return user;
      }

      final errorMsg = body['error'] as String? ?? 'Login failed';
      throw AuthException(errorMsg, statusCode: response.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error during login: $e');
    }
  }

  Future<User> loginWithGoogle(String idToken) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authGoogleEndpoint}');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(ApiConstants.requestTimeout);

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await saveSession(token, user);
        return user;
      }

      final errorMsg = body['error'] as String? ?? 'Google sign-in failed';
      throw AuthException(errorMsg, statusCode: response.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error during Google sign-in: $e');
    }
  }

  Future<User?> fetchCurrentUser() async {
    final token = await getSavedToken();
    if (token == null) return null;

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authMeEndpoint}');
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await _saveUser(user);
        return user;
      }

      if (response.statusCode == 401) {
        await clearSession();
        return null;
      }

      return await getSavedUser();
    } catch (_) {
      return await getSavedUser();
    }
  }

  Future<void> saveSession(String token, User user) async {
    final prefs = await _getPrefs();
    await _tokenStorage.write(token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(_guestKey, false);
  }

  Future<void> _saveUser(User user) async {
    final prefs = await _getPrefs();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getSavedUser() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isGuestMode() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_guestKey) ?? false;
  }

  Future<void> setGuestMode(bool isGuest) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_guestKey, isGuest);
  }

  Future<void> clearSession() async {
    final prefs = await _getPrefs();
    await _tokenStorage.delete();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.setBool(_guestKey, true);
  }
}
