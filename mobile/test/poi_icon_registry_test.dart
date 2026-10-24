import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:uniway_mobile/core/constants/poi_icons.dart';
import 'package:uniway_mobile/presentation/map/poi_icon_registry.dart';

class FakeIconMapController extends Fake implements MapLibreMapController {
  final Map<String, Uint8List> addedImages = {};
  int addImageCallCount = 0;

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {
    addImageCallCount++;
    addedImages[name] = bytes;
  }
}

class FakeAssetBundle extends Fake implements AssetBundle {
  final Set<String> missingPaths;
  final Map<String, Uint8List> dataByPath;

  FakeAssetBundle({
    this.missingPaths = const {},
    Map<String, Uint8List>? dataByPath,
  }) : dataByPath = dataByPath ?? {};

  @override
  Future<ByteData> load(String key) async {
    if (missingPaths.contains(key)) {
      throw Exception('Asset not found: $key');
    }
    final bytes = dataByPath[key] ?? Uint8List.fromList([1, 2, 3, 4]);
    return ByteData.sublistView(bytes);
  }
}

void main() {
  group('POI Icon Registry', () {
    test('registers all icons when all assets are available', () async {
      final controller = FakeIconMapController();
      final bundle = FakeAssetBundle();

      final registered = await registerPoiIcons(controller, bundle: bundle);

      expect(registered.length, kPoiIconKeys.length);
      expect(registered, containsAll(kPoiIconKeys));
      expect(controller.addImageCallCount, kPoiIconKeys.length);

      for (final key in kPoiIconKeys) {
        expect(controller.addedImages, contains(poiIconImageId(key)));
      }
    });

    test('passes exact bytes to addImage', () async {
      final controller = FakeIconMapController();
      final customBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final bundle = FakeAssetBundle(
        dataByPath: {
          'assets/icons/poi/academic.png': customBytes,
        },
      );

      final registered = await registerPoiIcons(controller, bundle: bundle);

      expect(registered, contains('academic'));
      expect(controller.addedImages[poiIconImageId('academic')], customBytes);
    });

    test('missing asset does not abort others and returns registered set', () async {
      final controller = FakeIconMapController();
      final bundle = FakeAssetBundle(
        missingPaths: {'assets/icons/poi/dome.png'},
      );

      final registered = await registerPoiIcons(controller, bundle: bundle);

      expect(registered.contains('dome'), isFalse);
      expect(registered.contains('academic'), isTrue);
      expect(registered.contains('default'), isTrue);
      expect(registered.length, kPoiIconKeys.length - 1);
      expect(controller.addedImages.containsKey(poiIconImageId('dome')), isFalse);
    });

    test('is idempotent: safe to call a second time after style reload', () async {
      final controller = FakeIconMapController();
      final bundle = FakeAssetBundle();

      final firstCall = await registerPoiIcons(controller, bundle: bundle);
      expect(firstCall.length, kPoiIconKeys.length);
      expect(controller.addImageCallCount, kPoiIconKeys.length);

      final secondCall = await registerPoiIcons(controller, bundle: bundle);
      expect(secondCall.length, kPoiIconKeys.length);
      expect(controller.addImageCallCount, kPoiIconKeys.length * 2);
    });
  });

  group('effectiveIconImageId', () {
    test('returns exact image id when key is registered', () {
      final registered = {'academic', 'food', 'default'};
      expect(
        effectiveIconImageId('academic', registered),
        poiIconImageId('academic'),
      );
      expect(
        effectiveIconImageId('food', registered),
        poiIconImageId('food'),
      );
    });

    test('returns fallback image id when key is not registered but fallback is', () {
      final registered = {'food', 'default'};
      expect(
        effectiveIconImageId('dome', registered),
        poiIconImageId('default'),
      );
    });

    test('returns null when neither key nor fallback is registered', () {
      final registered = {'food', 'sports'};
      expect(effectiveIconImageId('dome', registered), isNull);
    });

    test('returns null on empty registered set', () {
      expect(effectiveIconImageId('food', {}), isNull);
    });
  });
}
