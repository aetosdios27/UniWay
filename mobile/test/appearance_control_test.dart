import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:uniway_mobile/data/models/user.dart";
import "package:uniway_mobile/presentation/controllers/auth_controller.dart";
import "package:uniway_mobile/presentation/controllers/theme_controller.dart";
import "package:uniway_mobile/presentation/widgets/profile_sheet.dart";
import "support/fake_auth_repository.dart";

Widget buildTestApp({
  required AuthController authController,
  ThemeController? themeController,
}) {
  Widget child = MaterialApp(
    home: Scaffold(
      body: ProfileSheet(authController: authController),
    ),
  );

  if (themeController != null) {
    child = ThemeScope(
      controller: themeController,
      child: child,
    );
  }

  return child;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("Appearance Control in ProfileSheet", () {
    testWidgets("is absent when no ThemeScope is mounted", (tester) async {
      final repo = FakeAuthRepository()..mockGuest = true;
      final authController = AuthController(repository: repo);
      await authController.initialize();

      await tester.pumpWidget(buildTestApp(authController: authController));

      expect(find.text("Appearance"), findsNothing);
      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    });

    testWidgets("is present for guest users when ThemeScope is mounted", (tester) async {
      final repo = FakeAuthRepository()..mockGuest = true;
      final authController = AuthController(repository: repo);
      await authController.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(buildTestApp(
        authController: authController,
        themeController: themeController,
      ));

      expect(find.text("Appearance"), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text("System"), findsOneWidget);
      expect(find.text("Light"), findsOneWidget);
      expect(find.text("Dark"), findsOneWidget);
      expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets("is present for authenticated users when ThemeScope is mounted", (tester) async {
      final repo = FakeAuthRepository()
        ..mockToken = 'token-alice'
        ..mockUser = const User(
          id: "u-1",
          email: "test@example.com",
          name: "Alice Smith",
          authProvider: "email",
        );
      final authController = AuthController(repository: repo);
      await authController.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(buildTestApp(
        authController: authController,
        themeController: themeController,
      ));

      expect(find.text("Appearance"), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(find.text("Alice Smith"), findsOneWidget);
    });

    testWidgets("selecting each segment updates ThemeController and reflects current mode", (tester) async {
      final repo = FakeAuthRepository()..mockGuest = true;
      final authController = AuthController(repository: repo);
      await authController.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(buildTestApp(
        authController: authController,
        themeController: themeController,
      ));

      // Initial state is System
      expect(themeController.mode, ThemeMode.system);
      final initialButton = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(initialButton.selected, {ThemeMode.system});

      // Tap Light
      await tester.tap(find.text("Light"));
      await tester.pumpAndSettle();
      expect(themeController.mode, ThemeMode.light);
      final lightButton = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(lightButton.selected, {ThemeMode.light});

      // Tap Dark
      await tester.tap(find.text("Dark"));
      await tester.pumpAndSettle();
      expect(themeController.mode, ThemeMode.dark);
      final darkButton = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(darkButton.selected, {ThemeMode.dark});

      // Tap System
      await tester.tap(find.text("System"));
      await tester.pumpAndSettle();
      expect(themeController.mode, ThemeMode.system);
      final systemButton = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(systemButton.selected, {ThemeMode.system});
    });

    testWidgets("appearance control provides semantics and tooltips", (tester) async {
      final repo = FakeAuthRepository()..mockGuest = true;
      final authController = AuthController(repository: repo);
      await authController.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(buildTestApp(
        authController: authController,
        themeController: themeController,
      ));

      expect(find.bySemanticsLabel("Appearance mode"), findsOneWidget);

      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.segments[0].tooltip, "System appearance");
      expect(button.segments[1].tooltip, "Light appearance");
      expect(button.segments[2].tooltip, "Dark appearance");
    });
  });
}
