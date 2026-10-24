import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniway_mobile/presentation/controllers/theme_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to following the system', () async {
    final controller = ThemeController();
    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('persists the chosen mode and restores it', () async {
    final first = ThemeController();
    await first.setMode(ThemeMode.dark);

    final second = ThemeController();
    await second.load();

    expect(second.mode, ThemeMode.dark);
  });

  test('ignores a corrupted saved value', () async {
    SharedPreferences.setMockInitialValues({ThemeController.prefsKey: 'purple'});
    final controller = ThemeController();
    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('notifies only when the mode actually changes', () async {
    final controller = ThemeController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ThemeMode.system);
    await controller.setMode(ThemeMode.light);
    await controller.setMode(ThemeMode.light);

    expect(notifications, 1);
  });

  testWidgets('ThemeScope rebuilds dependents when the mode changes', (tester) async {
    final controller = ThemeController();
    final seen = <ThemeMode>[];

    await tester.pumpWidget(
      ThemeScope(
        controller: controller,
        child: Builder(builder: (context) {
          seen.add(ThemeScope.of(context).mode);
          return const SizedBox();
        }),
      ),
    );
    await controller.setMode(ThemeMode.dark);
    await tester.pump();

    expect(seen, [ThemeMode.system, ThemeMode.dark]);
  });
}
