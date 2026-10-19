import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/core/utils/auth_guard.dart';
import 'package:uniway_mobile/data/models/user.dart';
import 'package:uniway_mobile/presentation/controllers/auth_controller.dart';

import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(AuthController controller, VoidCallback onAuthenticated) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => requireAuth(
              context,
              controller,
              prompt: 'Sign in to report a hazard',
              onAuthenticated: onAuthenticated,
            ),
            child: const Text('Report hazard'),
          ),
        ),
      ),
    );
  }

  group('requireAuth guard', () {
    testWidgets('runs the gated action immediately for signed-in users', (tester) async {
      final controller = AuthController(
        repository: FakeAuthRepository()
          ..mockToken = 'valid-jwt'
          ..mockUser = const User(
            id: 'u-1',
            email: 'alice@example.com',
            name: 'Alice Smith',
            authProvider: 'email',
          ),
      );
      await controller.initialize();
      var actionRuns = 0;

      await tester.pumpWidget(host(controller, () => actionRuns++));
      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      expect(actionRuns, 1);
      expect(find.text('Sign in to UniWay'), findsNothing);
    });

    testWidgets('shows the auth prompt with the gated action wording for guests', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.continueAsGuest();
      var actionRuns = 0;

      await tester.pumpWidget(host(controller, () => actionRuns++));
      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      expect(actionRuns, 0);
      expect(find.text('Sign in to UniWay'), findsOneWidget);
      expect(find.text('Sign in to report a hazard'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('continues as guest without running the gated action', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.continueAsGuest();
      var actionRuns = 0;

      await tester.pumpWidget(host(controller, () => actionRuns++));
      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(actionRuns, 0);
      expect(controller.isGuest, true);
      expect(find.text('Sign in to UniWay'), findsNothing);
    });

    testWidgets('runs the gated action after signing in from the prompt', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.continueAsGuest();
      var actionRuns = 0;

      await tester.pumpWidget(host(controller, () => actionRuns++));
      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'alice@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(controller.isAuthenticated, true);
      expect(actionRuns, 1);
      expect(find.text('Sign in to UniWay'), findsNothing);
    });

    testWidgets('re-prompts after a cancelled sign-in rather than losing the gated action', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.continueAsGuest();
      var actionRuns = 0;

      await tester.pumpWidget(host(controller, () => actionRuns++));
      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      // Dismiss the sheet without authenticating, then retry the gated action.
      Navigator.of(tester.element(find.text('Sign in to UniWay'))).pop();
      await tester.pumpAndSettle();
      expect(actionRuns, 0);

      await tester.tap(find.text('Report hazard'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to report a hazard'), findsOneWidget);
      expect(actionRuns, 0);
    });
  });
}
