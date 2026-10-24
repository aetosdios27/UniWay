import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/main.dart';
import 'package:uniway_mobile/presentation/controllers/theme_controller.dart';
import 'package:uniway_mobile/presentation/theme/uniway_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UniWayApp Theme Integration', () {
    testWidgets('themeMode follows ThemeController mode changes (system/light/dark)', (tester) async {
      final controller = ThemeController();

      await tester.pumpWidget(
        UniWayApp(
          themeController: controller,
          home: const SizedBox(),
        ),
      );
      await tester.pump();

      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme?.brightness, Brightness.light);
      expect(app.darkTheme?.brightness, Brightness.dark);
      expect(app.theme?.extension<UniWayColors>(), isNotNull);
      expect(app.darkTheme?.extension<UniWayColors>(), isNotNull);

      await controller.setMode(ThemeMode.dark);
      await tester.pump();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      await controller.setMode(ThemeMode.light);
      await tester.pump();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);

      await controller.setMode(ThemeMode.system);
      await tester.pump();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);

      controller.dispose();
    });

    testWidgets('theme choice persists across app restarts with SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final firstController = ThemeController();
      await firstController.setMode(ThemeMode.dark);

      final restartedController = ThemeController();
      await restartedController.load();

      expect(restartedController.mode, ThemeMode.dark);

      await tester.pumpWidget(
        UniWayApp(
          themeController: restartedController,
          home: const SizedBox(),
        ),
      );
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      firstController.dispose();
      restartedController.dispose();
    });

    testWidgets('UniWayApp without explicit controller restores saved theme from preferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeController.prefsKey: 'dark',
      });

      await tester.pumpWidget(
        const UniWayApp(
          home: SizedBox(),
        ),
      );
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}
