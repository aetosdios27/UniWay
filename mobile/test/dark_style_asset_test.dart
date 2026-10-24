import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/constants/map_constants.dart';
import 'package:uniway_mobile/presentation/map/basemap_pois.dart';
import 'package:uniway_mobile/presentation/map/map_palette.dart';
import 'package:uniway_mobile/presentation/map/supplementary_layers.dart';

/// The dark style is generated from Liberty by `bun run build:dark-style`.
/// These tests keep our own overlay layers visually consistent with it.
void main() {
  late Map<String, dynamic> style;
  late Map<String, Map<String, dynamic>> layers;

  setUpAll(() {
    style = jsonDecode(File(MapConstants.darkStyleAsset).readAsStringSync())
        as Map<String, dynamic>;
    layers = {
      for (final layer in (style['layers'] as List).cast<Map<String, dynamic>>())
        layer['id'] as String: layer,
    };
  });

  Map<String, dynamic> paint(String id) =>
      (layers[id]!['paint'] as Map).cast<String, dynamic>();

  String hex(Object? value) => (value as String).toLowerCase();

  test('is a valid MapLibre style that keeps the remote sources', () {
    expect(style['version'], 8);
    expect(style['sprite'], isNotNull);
    expect(style['glyphs'], isNotNull);
    expect((style['sources'] as Map).keys, contains('openmaptiles'));
    expect(layers, isNotEmpty);
  });

  test('keeps every layer our code anchors to or hides', () {
    expect(layers.keys, contains(belowBuildingLayerId));
    for (final id in kBasemapPoiLayerIds) {
      expect(layers.keys, contains(id), reason: 'basemap layer $id is missing');
    }
  });

  test('the library building matches the surrounding dark buildings', () {
    const dark = MapPalette.dark;

    expect(hex(paint('building')['fill-color']), hex(dark.buildingFill));

    final outline = (paint('building')['fill-outline-color'] as List).cast<Object>();
    expect(hex(outline[4]), hex(dark.buildingOutlineLowZoom));
    expect(hex(outline[6]), hex(dark.buildingOutline));

    expect(
      hex(paint('building-3d')['fill-extrusion-color']),
      hex(dark.buildingExtrusion),
    );
  });
}
