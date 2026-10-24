import 'package:flutter/material.dart';

import '../../core/constants/map_constants.dart';

/// Returns the map style URI or asset path for the given [brightness].
String mapStyleFor(Brightness brightness) {
  switch (brightness) {
    case Brightness.light:
      return MapConstants.openFreeMapLibertyStyle;
    case Brightness.dark:
      return MapConstants.darkStyleAsset;
  }
}
