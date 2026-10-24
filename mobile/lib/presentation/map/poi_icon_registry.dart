import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/poi_icons.dart';

/// Registers POI icon assets with the map controller's style.
///
/// Missing or failing assets are skipped and logged with [debugPrint] without
/// aborting the remaining keys. Returns the set of successfully registered keys.
Future<Set<String>> registerPoiIcons(
  MapLibreMapController controller, {
  AssetBundle? bundle,
}) async {
  final assetBundle = bundle ?? rootBundle;
  final registered = <String>{};

  for (final key in kPoiIconKeys) {
    try {
      final byteData = await assetBundle.load('assets/icons/poi/$key.png');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await controller.addImage(poiIconImageId(key), bytes);
      registered.add(key);
    } catch (e) {
      debugPrint('registerPoiIcons: failed to register icon "$key": $e');
    }
  }

  return registered;
}

/// Returns the map style image id for [key] if registered, else falls back to
/// the fallback icon image id if registered, else null.
String? effectiveIconImageId(String key, Set<String> registered) {
  if (registered.contains(key)) {
    return poiIconImageId(key);
  }
  if (registered.contains(kPoiIconFallback)) {
    return poiIconImageId(kPoiIconFallback);
  }
  return null;
}
