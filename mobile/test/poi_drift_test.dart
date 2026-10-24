import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/constants/poi_icons.dart';

void main() {
  group('POI Icon Drift Test', () {
    test('kPoiIconKeys matches ../data/poi-icon-keys.json single source of truth', () {
      final jsonFile = File('../data/poi-icon-keys.json');
      expect(
        jsonFile.existsSync(),
        isTrue,
        reason: 'Expected ../data/poi-icon-keys.json to exist from mobile/ cwd',
      );

      final content = jsonFile.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;

      final keys = (decoded['keys'] as List<dynamic>).cast<String>();
      final fallback = decoded['fallback'] as String;

      expect(
        kPoiIconKeys,
        keys,
        reason: 'kPoiIconKeys in Dart must match keys in ../data/poi-icon-keys.json',
      );
      expect(
        kPoiIconFallback,
        fallback,
        reason: 'kPoiIconFallback in Dart must match fallback in ../data/poi-icon-keys.json',
      );
    });

    test('every key has a corresponding valid 64x64 PNG in assets/icons/poi/', () {
      const pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

      for (final key in kPoiIconKeys) {
        final assetFile = File('assets/icons/poi/$key.png');
        expect(
          assetFile.existsSync(),
          isTrue,
          reason: 'Missing icon asset file: assets/icons/poi/$key.png',
        );

        final bytes = assetFile.readAsBytesSync();
        expect(
          bytes.length,
          greaterThanOrEqualTo(24),
          reason: 'Icon $key.png is too short to be a valid PNG',
        );

        expect(
          bytes.sublist(0, 8),
          pngMagic,
          reason: 'Icon $key.png does not start with standard PNG signature',
        );

        final byteData = ByteData.sublistView(bytes);

        final chunkType = String.fromCharCodes(bytes.sublist(12, 16));
        expect(
          chunkType,
          'IHDR',
          reason: 'First chunk of $key.png must be IHDR',
        );

        final width = byteData.getUint32(16, Endian.big);
        final height = byteData.getUint32(20, Endian.big);

        expect(width, 64, reason: 'Icon $key.png width must be 64px');
        expect(height, 64, reason: 'Icon $key.png height must be 64px');
      }
    });
  });
}
