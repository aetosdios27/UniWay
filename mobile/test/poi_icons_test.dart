import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/core/constants/poi_icons.dart';

void main() {
  group('POI Icons Constants', () {
    test('contains the planned icon keys', () {
      expect(kPoiIconKeys, [
        'default',
        'academic',
        'dome',
        'food',
        'entrance',
        'amenities',
        'auditorium',
        'sports',
      ]);
      expect(kPoiIconFallback, 'default');
    });

    test('poiIconImageId prefixes with uniway-poi-', () {
      expect(poiIconImageId('food'), 'uniway-poi-food');
      expect(poiIconImageId('default'), 'uniway-poi-default');
    });
  });

  group('resolvePoiIconKey', () {
    test('valid explicit iconKey wins over category', () {
      expect(
        resolvePoiIconKey(iconKey: 'dome', category: 'food'),
        'dome',
      );
      expect(
        resolvePoiIconKey(iconKey: 'sports', category: 'academic'),
        'sports',
      );
    });

    test('explicit iconKey is case-insensitive and trimmed', () {
      expect(
        resolvePoiIconKey(iconKey: '  FOOD  ', category: 'sports'),
        'food',
      );
      expect(
        resolvePoiIconKey(iconKey: 'Auditorium', category: 'academic'),
        'auditorium',
      );
    });

    test('every contract category maps to the expected icon key', () {
      const expectedMappings = {
        'academic': 'academic',
        'library': 'academic',
        'dome': 'dome',
        'food': 'food',
        'canteen': 'food',
        'mess': 'food',
        'entrance': 'entrance',
        'exit': 'entrance',
        'gate': 'entrance',
        'entrance/exit': 'entrance',
        'amenities': 'amenities',
        'amenity': 'amenities',
        'toilet': 'amenities',
        'restroom': 'amenities',
        'atm': 'amenities',
        'parking': 'amenities',
        'medical': 'amenities',
        'auditorium': 'auditorium',
        'amphitheatre': 'auditorium',
        'amphitheater': 'auditorium',
        'ampi/audi': 'auditorium',
        'sports': 'sports',
        'sport': 'sports',
      };

      for (final entry in expectedMappings.entries) {
        expect(
          resolvePoiIconKey(category: entry.key),
          entry.value,
          reason: 'Category "${entry.key}" should resolve to "${entry.value}"',
        );
      }
    });

    test('every mapped icon key is a supported key', () {
      for (final key in kCategoryToIconKey.values) {
        expect(kPoiIconKeys, contains(key));
      }
    });

    test('category resolution is case-insensitive and trimmed', () {
      expect(resolvePoiIconKey(category: '  CANTEEN  '), 'food');
      expect(resolvePoiIconKey(category: 'Dome'), 'dome');
      expect(resolvePoiIconKey(category: '  restroom '), 'amenities');
      expect(resolvePoiIconKey(category: 'GATE'), 'entrance');
      expect(resolvePoiIconKey(category: ' Ampi/Audi '), 'auditorium');
    });

    test('unknown explicit iconKey falls back to category', () {
      expect(
        resolvePoiIconKey(iconKey: 'non_existent_key', category: 'canteen'),
        'food',
      );
      expect(
        resolvePoiIconKey(iconKey: '', category: 'sport'),
        'sports',
      );
    });

    test('unknown category falls back to default', () {
      expect(resolvePoiIconKey(category: 'something_random'), 'default');
      expect(resolvePoiIconKey(category: ''), 'default');
      expect(resolvePoiIconKey(category: null), 'default');
      expect(resolvePoiIconKey(), 'default');
    });

    test('unknown explicit iconKey and unknown category fall back to default', () {
      expect(
        resolvePoiIconKey(iconKey: 'fake', category: 'unknown'),
        'default',
      );
    });
  });

  group('poiIconSizeExpression', () {
    test('draws the icon at the requested dp on any screen density', () {
      // A 64px asset is device-scaled, so icon-size 1 is 64 / pixelRatio dp.
      for (final ratio in [1.0, 2.0, 2.625, 3.0]) {
        final expr = poiIconSizeExpression(
          pixelRatio: ratio,
          minZoom: 14,
          minDp: 26,
          maxZoom: 19,
          maxDp: 34,
        );
        expect(expr.sublist(0, 3), [
          'interpolate',
          ['linear'],
          ['zoom'],
        ]);
        final minScale = expr[4] as double;
        final maxScale = expr[6] as double;
        expect(expr[3], 14);
        expect(expr[5], 19);
        expect(kPoiIconAssetPx / ratio * minScale, closeTo(26, 1e-9));
        expect(kPoiIconAssetPx / ratio * maxScale, closeTo(34, 1e-9));
      }
    });
  });
}
