import 'package:flutter/material.dart';

/// Semantic colours the Material scheme has no slot for (status and location
/// states). Widgets read these instead of hardcoding `Colors.green.shade50`.
@immutable
class UniWayColors extends ThemeExtension<UniWayColors> {
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color neutral;
  final Color neutralContainer;
  final Color onNeutralContainer;

  /// The user's own location blue. Reserved for "you" so it never reads as a place.
  final Color you;

  /// Weak-GPS orange, kept distinct from [warning] so fair and poor read differently.
  final Color poor;

  const UniWayColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.neutral,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.you,
    required this.poor,
  });

  static const light = UniWayColors(
    success: Color(0xFF16A34A),
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    danger: Color(0xFFDC2626),
    dangerContainer: Color(0xFFFEE2E2),
    onDangerContainer: Color(0xFF7F1D1D),
    neutral: Color(0xFF5B6578),
    neutralContainer: Color(0xFFE8EBF1),
    onNeutralContainer: Color(0xFF2B3342),
    you: Color(0xFF2563EB),
    poor: Color(0xFFC2410C),
  );

  static const dark = UniWayColors(
    success: Color(0xFF4ADE80),
    successContainer: Color(0xFF12351F),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF3A2A08),
    onWarningContainer: Color(0xFFFDE68A),
    danger: Color(0xFFF87171),
    dangerContainer: Color(0xFF3F1515),
    onDangerContainer: Color(0xFFFECACA),
    neutral: Color(0xFF9AA7BD),
    neutralContainer: Color(0xFF1F2938),
    onNeutralContainer: Color(0xFFD5DBE8),
    you: Color(0xFF5B9DFF),
    poor: Color(0xFFFB923C),
  );

  /// Falls back to the light set when a test pumps a widget without the extension.
  static UniWayColors of(BuildContext context) =>
      Theme.of(context).extension<UniWayColors>() ?? light;

  @override
  UniWayColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? neutral,
    Color? neutralContainer,
    Color? onNeutralContainer,
    Color? you,
    Color? poor,
  }) {
    return UniWayColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      neutral: neutral ?? this.neutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
      you: you ?? this.you,
      poor: poor ?? this.poor,
    );
  }

  @override
  UniWayColors lerp(ThemeExtension<UniWayColors>? other, double t) {
    if (other is! UniWayColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return UniWayColors(
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      onDangerContainer: mix(onDangerContainer, other.onDangerContainer),
      neutral: mix(neutral, other.neutral),
      neutralContainer: mix(neutralContainer, other.neutralContainer),
      onNeutralContainer: mix(onNeutralContainer, other.onNeutralContainer),
      you: mix(you, other.you),
      poor: mix(poor, other.poor),
    );
  }
}

class UniWayTheme {
  static const _seed = Color(0xFF2563EB);

  static ThemeData light() => _build(Brightness.light, UniWayColors.light);

  static ThemeData dark() => _build(Brightness.dark, UniWayColors.dark);

  static ThemeData _build(Brightness brightness, UniWayColors colors) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      extensions: [colors],
    );
  }
}
