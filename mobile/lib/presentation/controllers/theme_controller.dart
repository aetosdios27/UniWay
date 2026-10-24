import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's appearance choice (follow system, light or dark) and
/// remembers it across launches.
class ThemeController extends ChangeNotifier {
  static const prefsKey = 'uniway_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  bool _disposed = false;

  ThemeController({ThemeMode initialMode = ThemeMode.system})
      : _mode = initialMode;

  ThemeMode get mode => _mode;

  /// Reads the saved choice. A missing or unrecognised value keeps [ThemeMode.system].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final restored = _decode(prefs.getString(prefsKey));
    if (_disposed || restored == _mode) return;
    _mode = restored;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }

  static ThemeMode _decode(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return ThemeMode.system;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Exposes the [ThemeController] to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Null when no scope is mounted, which keeps widget tests lightweight.
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'ThemeScope is missing above this widget');
    return controller!;
  }
}
