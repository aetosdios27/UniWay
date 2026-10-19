import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/core/services/token_storage.dart';
import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/data/repositories/auth_repository.dart';

class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AuthRepository', () {
    test('registers a new user and saves token to prefs', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        final body = jsonDecode(request.body);
        expect(body['email'], 'student@muj.manipal.edu');

        return http.Response(
          jsonEncode({
            'data': {
              'user': {
                'id': 'user-1',
                'email': 'student@muj.manipal.edu',
                'name': 'Student One',
                'auth_provider': 'email',
              },
              'token': 'jwt.token.sample',
            }
          }),
          201,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      final user = await repo.register(
        email: 'student@muj.manipal.edu',
        password: 'password123',
        name: 'Student One',
      );

      expect(user.id, 'user-1');
      expect(user.email, 'student@muj.manipal.edu');
      expect(await repo.getSavedToken(), 'jwt.token.sample');
      expect(await repo.isGuestMode(), false);
    });

    test('logs in an existing user and updates prefs', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        return http.Response(
          jsonEncode({
            'data': {
              'user': {
                'id': 'user-2',
                'email': 'login@muj.manipal.edu',
                'name': 'User Two',
                'auth_provider': 'email',
              },
              'token': 'login.jwt.token',
            }
          }),
          200,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      final user = await repo.login(email: 'login@muj.manipal.edu', password: 'password123');

      expect(user.id, 'user-2');
      expect(await repo.getSavedToken(), 'login.jwt.token');
    });

    test('throws AuthException on 401 login error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Invalid email or password'}),
          401,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      expect(
        () => repo.login(email: 'wrong@example.com', password: 'bad'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('Invalid email'))),
      );
    });

    test('fetches current user with saved token', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer saved-token-123');
        return http.Response(
          jsonEncode({
            'data': {
              'user': {
                'id': 'user-3',
                'email': 'me@muj.manipal.edu',
                'name': 'Current User',
                'auth_provider': 'google',
              }
            }
          }),
          200,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      await repo.saveSession(
        'saved-token-123',
        const User(id: 'user-3', email: 'me@muj.manipal.edu', name: 'Current User', authProvider: 'google'),
      );

      final user = await repo.fetchCurrentUser();
      expect(user?.id, 'user-3');
      expect(user?.email, 'me@muj.manipal.edu');
    });

    test('manages guest mode state', () async {
      final repo = AuthRepository(prefs: prefs, tokenStorage: SharedPreferencesTokenStorage(prefs));
      expect(await repo.isGuestMode(), false);

      await repo.setGuestMode(true);
      expect(await repo.isGuestMode(), true);

      await repo.clearSession();
      expect(await repo.getSavedToken(), null);
      expect(await repo.isGuestMode(), true);
    });

    test('surfaces a 409 duplicate email with its status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'An account with this email already exists', 'code': 'CONFLICT'}),
          409,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      await expectLater(
        repo.register(email: 'taken@example.com', password: 'password123', name: 'Taken'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', contains('already exists')),
        ),
      );
      expect(await repo.getSavedToken(), null);
    });

    test('wraps a non-JSON error response in an AuthException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html>Bad gateway</html>', 502);
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      await expectLater(
        repo.login(email: 'student@example.com', password: 'password123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('signs in with Google through an injected TokenStorage and persists the token', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/google');
        expect(jsonDecode(request.body)['idToken'], 'google-id-token');

        return http.Response(
          jsonEncode({
            'data': {
              'user': {
                'id': 'g-1',
                'email': 'google@muj.manipal.edu',
                'name': 'Google Student',
                'auth_provider': 'google',
                'avatar_url': 'https://example.com/a.png',
              },
              'token': 'google.jwt.token',
            }
          }),
          200,
        );
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      final user = await repo.loginWithGoogle('google-id-token');

      expect(user.authProvider, 'google');
      expect(user.avatarUrl, 'https://example.com/a.png');
      expect(await repo.getSavedToken(), 'google.jwt.token');
      expect(await repo.isGuestMode(), false);
    });

    test('clears the stored session when /me rejects the token with 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      await repo.saveSession(
        'expired-token',
        const User(id: 'user-4', email: 'old@example.com', name: 'Old User', authProvider: 'email'),
      );

      final user = await repo.fetchCurrentUser();

      expect(user, null);
      expect(await repo.getSavedToken(), null);
      expect(await repo.isGuestMode(), true);
    });

    test('falls back to the cached profile when /me is unreachable', () async {
      final mockClient = MockClient((request) async {
        throw Exception('connection refused');
      });

      final repo = AuthRepository(
        client: mockClient,
        prefs: prefs,
        tokenStorage: SharedPreferencesTokenStorage(prefs),
      );
      await repo.saveSession(
        'cached-token',
        const User(id: 'user-5', email: 'cached@example.com', name: 'Cached User', authProvider: 'email'),
      );

      final user = await repo.fetchCurrentUser();

      expect(user?.email, 'cached@example.com');
      expect(await repo.getSavedToken(), 'cached-token');
    });

    test('clearSession deletes the token from injected storage', () async {
      final secure = InMemoryTokenStorage();
      await secure.write('to-delete');

      final repo = AuthRepository(prefs: prefs, tokenStorage: secure);
      expect(await repo.getSavedToken(), 'to-delete');

      await repo.clearSession();
      expect(await secure.read(), null);
      expect(await repo.isGuestMode(), true);
    });

    test('migrates a legacy plaintext token into encrypted storage on first read', () async {
      SharedPreferences.setMockInitialValues({'uniway_auth_token': 'legacy-plaintext-token'});
      final legacyPrefs = await SharedPreferences.getInstance();
      final secure = InMemoryTokenStorage();

      final repo = AuthRepository(prefs: legacyPrefs, tokenStorage: secure);
      expect(await repo.getSavedToken(), 'legacy-plaintext-token');

      expect(await secure.read(), 'legacy-plaintext-token');
      // The plaintext copy is removed once migrated.
      expect(legacyPrefs.getString('uniway_auth_token'), null);
    });

    test('ignores a corrupted cached profile', () async {
      SharedPreferences.setMockInitialValues({'uniway_auth_user': 'not-json'});
      final corruptedPrefs = await SharedPreferences.getInstance();
      final repo = AuthRepository(prefs: corruptedPrefs);

      expect(await repo.getSavedUser(), null);
    });
  });
}
