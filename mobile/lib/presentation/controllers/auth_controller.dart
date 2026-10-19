import 'package:flutter/foundation.dart';
import '../../core/services/google_sign_in_service.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repository;
  final GoogleIdentityProvider? _googleIdentityProvider;

  User? _user;
  bool _isGuest = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _errorMessage;

  AuthController({AuthRepository? repository, GoogleIdentityProvider? googleIdentityProvider})
      : _repository = repository ?? AuthRepository(),
        _googleIdentityProvider = googleIdentityProvider;

  User? get user => _user;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isLoading = true;
    _notify();

    try {
      final token = await _repository.getSavedToken();
      if (token != null) {
        _user = await _repository.fetchCurrentUser();
        _isGuest = _user == null;
      } else {
        _isGuest = await _repository.isGuestMode();
        _user = null;
      }
    } catch (_) {
      try {
        _user = await _repository.getSavedUser();
      } catch (_) {
        _user = null;
      }
      _isGuest = _user == null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      _notify();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> continueAsGuest() async {
    _isGuest = true;
    _user = null;
    _errorMessage = null;
    await _repository.setGuestMode(true);
    _notify();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _user = await _repository.login(email: email, password: password);
      _isGuest = false;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _user = await _repository.register(email: email, password: password, name: name);
      _isGuest = false;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _user = await _repository.loginWithGoogle(idToken);
      _isGuest = false;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> logout() async {
    await _repository.clearSession();
    try {
      await _googleIdentityProvider?.signOut();
    } catch (_) {}
    _user = null;
    _isGuest = true;
    _errorMessage = null;
    _notify();
  }
}
