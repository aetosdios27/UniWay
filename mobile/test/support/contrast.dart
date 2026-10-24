import 'dart:math';
import 'package:flutter/material.dart';

/// Calculates the WCAG relative luminance of a color.
double relativeLuminance(Color color) {
  return color.computeLuminance();
}

/// Computes the WCAG contrast ratio between two colors (range 1.0 to 21.0).
double contrastRatio(Color a, Color b) {
  final l1 = relativeLuminance(a);
  final l2 = relativeLuminance(b);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Blends a foreground color with alpha over an opaque background color.
Color compositeColors(Color foreground, Color background) {
  final fgA = foreground.a;
  if (fgA >= 1.0) return foreground;
  final bgA = background.a;
  final outA = fgA + bgA * (1.0 - fgA);
  if (outA <= 0.0) return Colors.transparent;

  final r = (foreground.r * fgA + background.r * bgA * (1.0 - fgA)) / outA;
  final g = (foreground.g * fgA + background.g * bgA * (1.0 - fgA)) / outA;
  final b = (foreground.b * fgA + background.b * bgA * (1.0 - fgA)) / outA;

  return Color.from(alpha: outA, red: r, green: g, blue: b);
}

void main() {}
