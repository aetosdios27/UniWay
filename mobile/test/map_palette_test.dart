import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/constants/map_constants.dart';
import 'package:uniway_mobile/presentation/map/destination_layers.dart';
import 'package:uniway_mobile/presentation/map/map_palette.dart';
import 'package:uniway_mobile/presentation/map/map_style.dart';
import 'package:uniway_mobile/presentation/map/poi_layers.dart';
import 'package:uniway_mobile/presentation/map/route_start_connector.dart';
import 'package:uniway_mobile/presentation/map/supplementary_layers.dart';
import 'package:uniway_mobile/presentation/map/user_location_layer.dart';

Color parseColorString(String raw) {
  final str = raw.trim();
  if (str.startsWith('#')) {
    var hex = str.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  } else if (str.startsWith('hsl(') || str.startsWith('hsla(')) {
    final inner = str.substring(str.indexOf('(') + 1, str.indexOf(')'));
    final parts = inner.split(',');
    final h = double.parse(parts[0].trim());
    final s = double.parse(parts[1].trim().replaceAll('%', '')) / 100.0;
    final l = double.parse(parts[2].trim().replaceAll('%', '')) / 100.0;
    final a = parts.length > 3 ? double.parse(parts[3].trim()) : 1.0;
    return HSLColor.fromAHSL(a, h, s, l).toColor();
  } else if (str.startsWith('rgb(') || str.startsWith('rgba(')) {
    final inner = str.substring(str.indexOf('(') + 1, str.indexOf(')'));
    final parts = inner.split(',');
    final r = int.parse(parts[0].trim());
    final g = int.parse(parts[1].trim());
    final b = int.parse(parts[2].trim());
    final a = parts.length > 3 ? double.parse(parts[3].trim()) : 1.0;
    return Color.fromRGBO(r, g, b, a);
  }
  throw ArgumentError('Unrecognised color format: $raw');
}

double relativeLuminance(Color color) {
  double adjust(double c) {
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = adjust(color.r);
  final g = adjust(color.g);
  final b = adjust(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = relativeLuminance(c1);
  final l2 = relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

class FakeMapController extends Fake implements MapLibreMapController {
  final List<LineOptions> addedLines = [];
  final List<LineOptions> updatedLines = [];

  @override
  Future<Line> addLine(LineOptions options, [Map<String, dynamic>? data]) async {
    addedLines.add(options);
    return Line('test_line_${addedLines.length}', options);
  }

  @override
  Future<void> updateLine(Line line, LineOptions changes) async {
    updatedLines.add(changes);
  }

  @override
  Future<void> removeLine(Line line) async {}
}

void main() {
  group('MapPalette - Light Values', () {
    test('light palette matches existing literals exactly', () {
      const p = MapPalette.light;
      expect(p.brightness, Brightness.light);
      expect(p.buildingFill, 'hsl(35,8%,85%)');
      expect(p.buildingOutline, 'hsl(35,6%,79%)');
      expect(p.buildingOutlineLowZoom, 'hsla(35,6%,79%,0.32)');
      expect(p.buildingExtrusion, 'hsl(35,8%,85%)');
      expect(p.buildingLabelText, '#666666');
      expect(p.buildingLabelHalo, '#ffffff');

      expect(p.destinationLabelText, '#1E293B');
      expect(p.destinationLabelHalo, '#FFFFFF');
      expect(p.destinationCircleFill, '#2563EB');
      expect(p.destinationCircleStroke, '#FFFFFF');
      expect(p.destinationOriginRing, '#16A34A');
      expect(p.destinationDestinationRing, '#DC2626');

      expect(p.poiLabelText, '#334155');
      expect(p.poiLabelHalo, '#FFFFFF');
      expect(p.poiFallbackCircle, '#64748B');
      expect(p.poiFallbackCircleStroke, '#FFFFFF');

      expect(p.userLocationGood, '#2563EB');
      expect(p.userLocationFair, '#F59E0B');
      expect(p.userLocationPoor, '#F97316');
      expect(p.userLocationLost, '#9CA3AF');
      expect(p.userLocationDotRing, '#FFFFFF');

      expect(p.connectorColor, '#64748B');
      expect(p.connectorOpacity, 0.45);

      expect(p.routeLine, '#2563EB');
      expect(p.routeLineOpacity, 0.95);
      expect(p.routeCasing, '#1E40AF');
      expect(p.routeCasingOpacity, 0.5);
    });

    test('all light colours parse into valid colors', () {
      const p = MapPalette.light;
      final colors = [
        p.buildingFill,
        p.buildingOutline,
        p.buildingOutlineLowZoom,
        p.buildingExtrusion,
        p.buildingLabelText,
        p.buildingLabelHalo,
        p.destinationLabelText,
        p.destinationLabelHalo,
        p.destinationCircleFill,
        p.destinationCircleStroke,
        p.destinationOriginRing,
        p.destinationDestinationRing,
        p.poiLabelText,
        p.poiLabelHalo,
        p.poiFallbackCircle,
        p.poiFallbackCircleStroke,
        p.userLocationGood,
        p.userLocationFair,
        p.userLocationPoor,
        p.userLocationLost,
        p.userLocationDotRing,
        p.connectorColor,
        p.routeLine,
        p.routeCasing,
      ];

      for (final raw in colors) {
        final c = parseColorString(raw);
        expect(c, isA<Color>(), reason: '$raw should parse successfully');
      }
    });
  });

  group('MapPalette - Dark Values', () {
    test('dark palette holds expected design constants', () {
      const p = MapPalette.dark;
      expect(p.brightness, Brightness.dark);
      expect(p.buildingFill, '#1B2432');
      expect(p.buildingOutline, '#2A3548');
      expect(p.buildingExtrusion, '#202A3B');
      expect(p.buildingLabelText, '#9AA7BD');
      expect(p.buildingLabelHalo, '#0E1420');

      expect(p.destinationLabelText, '#E7ECF5');
      expect(p.destinationLabelHalo, '#0E1420');
      expect(p.destinationCircleFill, '#5B9DFF');
      expect(p.destinationOriginRing, '#4ADE80');
      expect(p.destinationDestinationRing, '#F87171');

      expect(p.poiLabelText, '#C5CEDC');
      expect(p.poiLabelHalo, '#0E1420');
      expect(p.poiFallbackCircle, '#9AA7BD');

      expect(p.userLocationGood, '#5B9DFF');
      expect(p.userLocationFair, '#FBBF24');
      expect(p.userLocationPoor, '#FB923C');
      expect(p.userLocationLost, '#9AA7BD');

      expect(p.connectorColor, '#9AA7BD');
      expect(p.connectorOpacity, 0.60);

      expect(p.routeLine, '#7DB2FF');
      expect(p.routeCasing, '#0A1226');
      expect(p.routeCasingOpacity, 0.5);
    });

    test('all dark colours parse into valid colors', () {
      const p = MapPalette.dark;
      final colors = [
        p.buildingFill,
        p.buildingOutline,
        p.buildingOutlineLowZoom,
        p.buildingExtrusion,
        p.buildingLabelText,
        p.buildingLabelHalo,
        p.destinationLabelText,
        p.destinationLabelHalo,
        p.destinationCircleFill,
        p.destinationCircleStroke,
        p.destinationOriginRing,
        p.destinationDestinationRing,
        p.poiLabelText,
        p.poiLabelHalo,
        p.poiFallbackCircle,
        p.poiFallbackCircleStroke,
        p.userLocationGood,
        p.userLocationFair,
        p.userLocationPoor,
        p.userLocationLost,
        p.userLocationDotRing,
        p.connectorColor,
        p.routeLine,
        p.routeCasing,
      ];

      for (final raw in colors) {
        final c = parseColorString(raw);
        expect(c, isA<Color>(), reason: '$raw should parse successfully');
      }
    });

    test('dark label text vs halo has sufficient contrast >= 4.5:1', () {
      const p = MapPalette.dark;

      final destText = parseColorString(p.destinationLabelText);
      final destHalo = parseColorString(p.destinationLabelHalo);
      final destRatio = contrastRatio(destText, destHalo);
      expect(destRatio, greaterThanOrEqualTo(4.5));

      final poiText = parseColorString(p.poiLabelText);
      final poiHalo = parseColorString(p.poiLabelHalo);
      final poiRatio = contrastRatio(poiText, poiHalo);
      expect(poiRatio, greaterThanOrEqualTo(4.5));

      final suppText = parseColorString(p.buildingLabelText);
      final suppHalo = parseColorString(p.buildingLabelHalo);
      final suppRatio = contrastRatio(suppText, suppHalo);
      expect(suppRatio, greaterThanOrEqualTo(4.5));
    });
  });

  group('MapPalette.forBrightness & mapStyleFor', () {
    test('MapPalette.forBrightness returns light and dark palettes', () {
      expect(MapPalette.forBrightness(Brightness.light), MapPalette.light);
      expect(MapPalette.forBrightness(Brightness.dark), MapPalette.dark);
    });

    test('mapStyleFor returns OpenFreeMap Liberty for light and asset path for dark', () {
      expect(mapStyleFor(Brightness.light), MapConstants.openFreeMapLibertyStyle);
      expect(mapStyleFor(Brightness.dark), MapConstants.darkStyleAsset);
    });
  });

  group('Layer Building Functions Emit Palette Colours', () {
    test('supplementary layer paints emit palette colours for light and dark', () {
      for (final palette in [MapPalette.light, MapPalette.dark]) {
        final fill = fillBuildingPaintFor(palette).toJson();
        expect(fill['fill-color'], palette.buildingFill);

        final extrusion = fillExtrusionBuildingPaintFor(palette).toJson();
        expect(extrusion['fill-extrusion-color'], palette.buildingExtrusion);

        final symbol = symbolBuildingLabelPropertiesFor(palette).toJson();
        expect(symbol['text-color'], palette.buildingLabelText);
        expect(symbol['text-halo-color'], palette.buildingLabelHalo);
      }
    });

    test('destination layer paints emit palette colours for light and dark', () {
      for (final palette in [MapPalette.light, MapPalette.dark]) {
        final circle = destinationCirclePaintFor(palette).toJson();
        expect(circle['circle-color'], palette.destinationCircleFill);
        expect(circle['circle-stroke-color'], palette.destinationCircleStroke);

        final origin = destinationOriginPaintFor(palette).toJson();
        expect(origin['circle-color'], palette.destinationOriginRing);
        expect(origin['circle-stroke-color'], palette.destinationOriginRing);

        final destination = destinationDestinationPaintFor(palette).toJson();
        expect(destination['circle-color'], palette.destinationDestinationRing);
        expect(destination['circle-stroke-color'], palette.destinationDestinationRing);

        final label = destinationLabelPaintFor(palette).toJson();
        expect(label['text-color'], palette.destinationLabelText);
        expect(label['text-halo-color'], palette.destinationLabelHalo);
      }
    });

    test('poi layer paints emit palette colours for light and dark', () {
      for (final palette in [MapPalette.light, MapPalette.dark]) {
        final symbol = poiSymbolPaintFor(1.0, palette).toJson();
        expect(symbol['text-color'], palette.poiLabelText);
        expect(symbol['text-halo-color'], palette.poiLabelHalo);

        final circle = poiFallbackCirclePaintFor(palette).toJson();
        expect(circle['circle-color'], palette.poiFallbackCircle);
        expect(circle['circle-stroke-color'], palette.poiFallbackCircleStroke);
      }
    });

    test('user location layer paints emit palette colours for light and dark', () {
      for (final palette in [MapPalette.light, MapPalette.dark]) {
        final fill = userLocationAccuracyFillPaintFor(palette).toJson();
        final outline = userLocationAccuracyOutlinePaintFor(palette).toJson();
        final dot = userLocationDotPaintFor(palette).toJson();

        expect(fill['fill-color'], contains(palette.userLocationGood));
        expect(outline['line-color'], contains(palette.userLocationFair));
        expect(dot['circle-color'], contains(palette.userLocationPoor));
        expect(dot['circle-stroke-color'], palette.userLocationDotRing);
      }
    });

    test('route start connector emits palette color and opacity', () async {
      for (final palette in [MapPalette.light, MapPalette.dark]) {
        final map = FakeMapController();
        final connector = RouteStartConnector();
        const user = LatLng(26.8435, 75.5645);
        const routeStart = LatLng(26.8450, 75.5660);

        await connector.update(map, user, routeStart, palette: palette);
        expect(map.addedLines.length, 1);
        final line = map.addedLines.first;
        expect(line.lineColor, palette.connectorColor);
        expect(line.lineOpacity, palette.connectorOpacity);
      }
    });
  });
}
