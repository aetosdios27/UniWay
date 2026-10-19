import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/core/services/google_sign_in_service.dart';
import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/presentation/controllers/auth_controller.dart';
import 'package:uniway_mobile/presentation/widgets/auth_modal.dart';
import 'package:uniway_mobile/presentation/widgets/profile_badge.dart';
import 'package:uniway_mobile/presentation/widgets/profile_sheet.dart';

import 'support/fake_auth_repository.dart';

class FakeGoogleProvider implements GoogleIdentityProvider {
  FakeGoogleProvider();

  String? idToken = 'google-id-token';
  GoogleSignInUnavailable? throwWith;
  bool signOutCalled = false;

  @override
  Future<String?> getIdToken() async {
    if (throwWith != null) throw throwWith!;
    return idToken;
  }

  @override
  Future<void> signOut() async => signOutCalled = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthModal & ProfileBadge Widgets', () {
    testWidgets('renders AuthModal with sign-in and guest buttons', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      expect(find.text('Sign in to UniWay'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('switches to Create Account form on segmented button click', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Create UniWay Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('validates required credentials before calling the controller', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(controller.isAuthenticated, false);
    });

    testWidgets('sign up rejects a password shorter than eight characters', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Alice Smith');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'alice@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
      expect(controller.isAuthenticated, false);
    });

    testWidgets('shows the server error message after a failed sign in', (tester) async {
      final fakeRepo = FakeAuthRepository()..failWith = 'Invalid email or password';
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'user@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongPassword');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(controller.isAuthenticated, false);
    });

    testWidgets('successful sign in closes the sheet and runs the success callback', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);
      var successCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthModal.show(
                  context,
                  authController: controller,
                  onSuccess: () => successCalls++,
                ),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to UniWay'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'user@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(successCalls, 1);
      expect(find.text('Sign in to UniWay'), findsNothing);
      expect(controller.isAuthenticated, true);
    });

    testWidgets('Google sign-in success closes the sheet with an authenticated controller', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      final provider = FakeGoogleProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthModal.show(
                  context,
                  authController: controller,
                  googleProvider: provider,
                ),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(controller.isAuthenticated, true);
      expect(controller.user?.authProvider, 'google');
      expect(find.text('Sign in to UniWay'), findsNothing);
    });

    testWidgets('cancelling the Google flow keeps the sheet open and unauthenticated', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      final provider = FakeGoogleProvider()..idToken = null;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthModal.show(
                  context,
                  authController: controller,
                  googleProvider: provider,
                ),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Dismissing the Google sheet is not an error and does not sign in... and closing the
      // modal afterwards still falls back to guest mode rather than being stuck.
      expect(controller.isAuthenticated, false);
      expect(find.text('Sign in to UniWay'), findsOneWidget);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();
      expect(controller.isGuest, true);
    });

    testWidgets('a misconfigured Google build shows an explanatory message, not a crash', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      final provider = FakeGoogleProvider()
        ..throwWith = const GoogleSignInUnavailable(
          'Google Sign-In is not configured for this build. See docs/auth-setup.md.',
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthModal.show(
                  context,
                  authController: controller,
                  googleProvider: provider,
                ),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('not configured for this build'), findsOneWidget);
      expect(controller.isAuthenticated, false);
    });

    testWidgets('dismissing the first-run sheet by dragging counts as guest mode', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      expect(controller.isGuest, false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AuthModal.show(context, authController: controller),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to UniWay'), findsOneWidget);

      // Swipe the sheet away without authenticating, as a first-time user would.
      await tester.fling(find.text('Sign in to UniWay'), const Offset(0, 300), 600);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to UniWay'), findsNothing);
      // Non-blocking and consistent: the badge state now matches what the user saw.
      expect(controller.isGuest, true);
      expect(controller.isAuthenticated, false);
    });

    testWidgets('tapping Continue as Guest calls continueAsGuest', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthModal(authController: controller),
          ),
        ),
      );

      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();

      expect(controller.isGuest, true);
    });

    testWidgets('ProfileBadge shows guest indicator and user initial', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileBadge(authController: controller),
          ),
        ),
      );

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);

      await controller.login(email: 'alice@muj.manipal.edu', password: 'password123');
      await tester.pumpAndSettle();

      expect(find.text('Logged'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
    });

    testWidgets('ProfileBadge returns to the guest indicator after sign out', (tester) async {
      final fakeRepo = FakeAuthRepository();
      final controller = AuthController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileBadge(authController: controller),
          ),
        ),
      );

      await controller.login(email: 'alice@muj.manipal.edu', password: 'password123');
      await tester.pumpAndSettle();
      expect(find.text('Logged'), findsOneWidget);

      await controller.logout();
      await tester.pumpAndSettle();

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('Logged'), findsNothing);
    });

    testWidgets('ProfileSheet displays user details and logout option', (tester) async {
      final fakeRepo = FakeAuthRepository()
        ..mockToken = 'token-alice'
        ..mockUser = const User(
          id: 'u-1',
          email: 'alice@example.com',
          name: 'Alice Smith',
          authProvider: 'email',
        );
      final controller = AuthController(repository: fakeRepo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSheet(authController: controller),
          ),
        ),
      );

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('guest ProfileSheet offers sign in instead of sign out', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSheet(authController: controller),
          ),
        ),
      );

      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('Sign In or Register'), findsOneWidget);
      expect(find.text('Sign Out'), findsNothing);
      expect(find.text('Saved Places'), findsNothing);
    });

    testWidgets('guest ProfileSheet opens the auth sheet when signing in', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ProfileSheet.show(context, authController: controller),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      expect(find.text('Guest User'), findsOneWidget);

      await tester.tap(find.text('Sign In or Register'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sign in to UniWay'), findsOneWidget);
    });
  });
}
