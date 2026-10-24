const bool kHideBasemapPois = true;

class MapConstants {
  static const bool kHideBasemapPois = true;

  static const String openFreeMapLibertyStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  static const String openFreeMapBrightStyle =
      'https://tiles.openfreemap.org/styles/bright';

  static const String darkStyleAsset =
      'assets/map/uniway_dark_style.json';

  static const double mujLatitude = 26.8435;
  static const double mujLongitude = 75.5645;
  static const double defaultZoom = 16.5;

  static const String campusGeometrySourceId = 'uniway-campus-geometry-source';
  static const String campusBuildingsLayerId = 'uniway-campus-buildings-layer';
  static const String campusBuildings3dLayerId =
      'uniway-campus-buildings-3d-layer';
  static const String campusBuildingsLabelLayerId =
      'uniway-campus-buildings-label-layer';
  static const String supplementaryGeoJsonAssetPath =
      'assets/geo/supplementary_layer.geojson';

  static const String destinationsSourceId = 'uniway-destinations-source';
  static const String destinationsLayerId = 'uniway-destinations-layer';
  static const String destinationsLabelsLayerId = 'uniway-destinations-labels';
  static const String destinationsOriginLayerId =
      'uniway-destinations-origin-layer';
  static const String destinationsDestinationLayerId =
      'uniway-destinations-destination-layer';

  static const String poisSourceId = 'uniway-pois-source';
  static const String poisLayerId = 'uniway-pois-layer';

  static const String routeSourceId = 'uniway-active-route-source';
  static const String routeLineLayerId = 'uniway-active-route-line';
  static const String routeCasingLayerId = 'uniway-active-route-casing';
}
