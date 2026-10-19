import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/data/repositories/auth_repository.dart';

/// In-memory [AuthRepository] used by the auth controller and widget tests.
class FakeAuthRepository extends AuthRepository {
  User? mockUser;
  String? mockToken;
  bool mockGuest = false;
  String? failWith;
  bool throwOnStorageRead = false;

  @override
  Future<String?> getSavedToken() async {
    if (throwOnStorageRead) throw Exception('preferences unavailable');
    return mockToken;
  }

  @override
  Future<User?> fetchCurrentUser() async => mockUser;

  @override
  Future<User?> getSavedUser() async {
    if (throwOnStorageRead) throw Exception('preferences unavailable');
    return mockUser;
  }

  @override
  Future<bool> isGuestMode() async {
    if (throwOnStorageRead) throw Exception('preferences unavailable');
    return mockGuest;
  }

  @override
  Future<void> setGuestMode(bool isGuest) async {
    mockGuest = isGuest;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    if (failWith != null) throw AuthException(failWith!);
    mockUser = User(id: 'u-1', email: email, name: 'Logged In User', authProvider: 'email');
    mockToken = 'new-token';
    mockGuest = false;
    return mockUser!;
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (failWith != null) throw AuthException(failWith!);
    mockUser = User(id: 'u-reg', email: email, name: name, authProvider: 'email');
    mockToken = 'reg-token';
    mockGuest = false;
    return mockUser!;
  }

  @override
  Future<User> loginWithGoogle(String idToken) async {
    if (failWith != null) throw AuthException(failWith!);
    mockUser = const User(
      id: 'u-google',
      email: 'g@example.com',
      name: 'Google User',
      authProvider: 'google',
    );
    mockToken = 'google-token';
    mockGuest = false;
    return mockUser!;
  }

  @override
  Future<void> clearSession() async {
    mockUser = null;
    mockToken = null;
    mockGuest = true;
  }
}
