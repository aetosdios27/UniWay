import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/core/services/google_sign_in_service.dart';
import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/data/repositories/auth_repository.dart';
import 'package:uniway_mobile/presentation/controllers/auth_controller.dart';

import 'support/fake_auth_repository.dart';

class PendingAuthRepository extends FakeAuthRepository {
  final Completer<User?> currentUserCompleter = Completer<User?>();

  @override
  Future<User?> fetchCurrentUser() => currentUserCompleter.future;
}

class RecordingGoogleProvider implements GoogleIdentityProvider {
  bool signOutCalled = false;
  bool throwOnSignOut = false;

  @override
  Future<String?> getIdToken() async {
    return idToken;
  }

  String? idToken = 'google-id-token';

  @override
  Future<void> signOut() async {
    if (throwOnSignOut) throw StateError('google unavailable');
    signOutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthController', () {
    test('initializes with guest mode when no session exists', () async {
      final fakeRepo = FakeAuthRepository()..mockGuest = true;
      final controller = AuthController(repository: fakeRepo);

      expect(controller.isInitialized, false);
      await controller.initialize();
      expect(controller.isInitialized, true);
      expect(controller.isGuest, true);
      expect(controller.isAuthenticated, false);
      expect(controller.user, null);
    });

    test('initializes with authenticated user when token exists', () async {
      final fakeRepo = FakeAuthRepository()
        ..mockToken = 'stored-jwt'
        ..mockUser = const User(
          id: 'user-1',
          email: 'u1@example.com',
          name: 'Student',
          authProvider: 'email',
        );
      final controller = AuthController(repository: fakeRepo);

      await controller.initialize();
      expect(controller.isAuthenticated, true);
      expect(controller.isGuest, false);
      expect(controller.user?.email, 'u1@example.com');
    });

    test('falls back to guest mode when a stored token no longer resolves a user', () async {
      final fakeRepo = FakeAuthRepository()..mockToken = 'expired-jwt';
      final controller = AuthController(repository: fakeRepo);

      await controller.initialize();

      expect(controller.isAuthenticated, false);
      expect(controller.isGuest, true);
      expect(controller.user, null);
      expect(controller.isLoading, false);
    });

    test('falls back to guest mode when local storage cannot be read', () async {
      final fakeRepo = FakeAuthRepository()..throwOnStorageRead = true;
      final controller = AuthController(repository: fakeRepo);

      await controller.initialize();

      expect(controller.isInitialized, true);
      expect(controller.isAuthenticated, false);
      expect(controller.isGuest, true);
      expect(controller.errorMessage, null);
    });

    test('toggles guest mode explicitly', () async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await controller.continueAsGuest();
      expect(controller.isGuest, true);
      expect(controller.isAuthenticated, false);
      expect(fakeRepo.mockGuest, true);
    });

    test('login updates user and clears guest mode', () async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);
      await controller.continueAsGuest();

      final ok = await controller.login(email: 'test@example.com', password: 'secretPassword');
      expect(ok, true);
      expect(controller.isAuthenticated, true);
      expect(controller.isGuest, false);
      expect(controller.user?.email, 'test@example.com');
      expect(fakeRepo.mockGuest, false);
    });

    test('login sets errorMessage on failure and keeps the guest unauthenticated', () async {
      final fakeRepo = FakeAuthRepository()..failWith = 'Invalid email or password';
      final controller = AuthController(repository: fakeRepo);

      final ok = await controller.login(email: 'wrong@example.com', password: 'bad');
      expect(ok, false);
      expect(controller.isAuthenticated, false);
      expect(controller.errorMessage, 'Invalid email or password');
      expect(controller.isLoading, false);
    });

    test('a later successful login clears the previous error message', () async {
      final fakeRepo = FakeAuthRepository()..failWith = 'Invalid email or password';
      final controller = AuthController(repository: fakeRepo);

      await controller.login(email: 'wrong@example.com', password: 'bad');
      expect(controller.errorMessage, isNotNull);

      fakeRepo.failWith = null;
      final ok = await controller.login(email: 'right@example.com', password: 'goodPassword');

      expect(ok, true);
      expect(controller.errorMessage, null);
      expect(controller.user?.email, 'right@example.com');
    });

    test('a failed login does not clear an existing session', () async {
      final fakeRepo = FakeAuthRepository()
        ..mockToken = 'valid-jwt'
        ..mockUser = const User(
          id: 'user-1',
          email: 'u1@example.com',
          name: 'Student',
          authProvider: 'email',
        );
      final controller = AuthController(repository: fakeRepo);
      await controller.initialize();

      fakeRepo.failWith = 'Invalid email or password';
      final ok = await controller.login(email: 'u1@example.com', password: 'bad');

      expect(ok, false);
      expect(controller.isAuthenticated, true);
      expect(controller.user?.email, 'u1@example.com');
    });

    test('register and google sign-in also leave guest mode', () async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);
      await controller.continueAsGuest();

      expect(await controller.register(email: 'new@example.com', password: 'password123', name: 'New'), true);
      expect(controller.isGuest, false);
      expect(controller.isAuthenticated, true);

      await controller.logout();
      expect(controller.isGuest, true);

      expect(await controller.loginWithGoogle('google-id-token'), true);
      expect(controller.isGuest, false);
      expect(controller.user?.authProvider, 'google');
    });

    test('logout resets session and sets guest mode', () async {
      final fakeRepo = FakeAuthRepository()
        ..mockToken = 'sample-jwt'
        ..mockUser = const User(
          id: 'u-1',
          email: 'u@example.com',
          name: 'User',
          authProvider: 'email',
        );
      final controller = AuthController(repository: fakeRepo);

      await controller.initialize();
      expect(controller.isAuthenticated, true);

      await controller.logout();
      expect(controller.isAuthenticated, false);
      expect(controller.isGuest, true);
      expect(controller.user, null);
    });

    test('logout signs out the Google web session when one is wired up', () async {
      final provider = RecordingGoogleProvider();
      final controller = AuthController(
        repository: FakeAuthRepository(),
        googleIdentityProvider: provider,
      );

      await controller.logout();
      expect(provider.signOutCalled, true);
    });

    test('logout tolerates a Google sign-out failure', () async {
      final provider = RecordingGoogleProvider()..throwOnSignOut = true;
      final controller = AuthController(
        repository: FakeAuthRepository(),
        googleIdentityProvider: provider,
      );

      await controller.logout();
      expect(controller.isGuest, true);
      expect(controller.isAuthenticated, false);
    });

    test('notifies listeners on auth state transitions', () async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.login(email: 'test@example.com', password: 'secretPassword');
      final afterLogin = notifications;
      expect(afterLogin, greaterThan(0));

      await controller.logout();
      expect(notifications, greaterThan(afterLogin));
    });

    test('an in-flight initialize does not notify a disposed controller', () async {
      final fakeRepo = PendingAuthRepository()
        ..mockToken = 'stored-jwt'
        ..mockUser = const User(
          id: 'user-1',
          email: 'u1@example.com',
          name: 'Student',
          authProvider: 'email',
        );
      final controller = AuthController(repository: fakeRepo);

      final pending = controller.initialize();
      controller.dispose();
      fakeRepo.currentUserCompleter.complete(fakeRepo.mockUser);

      await pending;
    });

    test('auth exceptions surface through AuthException with a status code', () {
      const failure = AuthException('An account with this email already exists', statusCode: 409);

      expect(failure.toString(), 'An account with this email already exists');
      expect(failure.statusCode, 409);
    });
  });
}
