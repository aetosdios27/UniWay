import 'package:google_sign_in/google_sign_in.dart';

import '../constants/api_constants.dart';

class GoogleSignInUnavailable implements Exception {
  final String message;

  const GoogleSignInUnavailable(this.message);

  @override
  String toString() => message;
}

abstract class GoogleIdentityProvider {
  Future<String?> getIdToken();
  Future<void> signOut();
}

class GoogleSignInService implements GoogleIdentityProvider {
  static final GoogleSignInService _shared = GoogleSignInService._();

  factory GoogleSignInService() => _shared;

  GoogleSignInService._() : _signIn = GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const clientId = ApiConstants.googleServerClientId;
    await _signIn.initialize(serverClientId: clientId.isEmpty ? null : clientId);
    _initialized = true;
  }

  @override
  Future<String?> getIdToken() async {
    await ensureInitialized();

    try {
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const GoogleSignInUnavailable(
          'Google did not issue a sign-in token. Check the server client ID in docs/auth-setup.md.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const GoogleSignInUnavailable(
            'Google Sign-In is not configured for this build. See docs/auth-setup.md.',
          );
        default:
          throw const GoogleSignInUnavailable('Google sign-in failed. Please try again.');
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _signIn.signOut();
  }
}
