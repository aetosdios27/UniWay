/// Shared POI icon keys and resolution logic.
///
/// Single source of truth is data/poi-icon-keys.json.
const List<String> kPoiIconKeys = [
  'default',
  'academic',
  'dome',
  'food',
  'entrance',
  'amenities',
  'auditorium',
  'sports',
];

const String kPoiIconFallback = 'default';

/// Prefix used when registering images with MapLibre's style.
String poiIconImageId(String key) => 'uniway-poi-$key';

/// Vocabulary of category aliases mapped to supported icon keys.
const Map<String, String> kCategoryToIconKey = {
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

/// Resolves an icon key from an explicit [iconKey] or [category].
///
/// 1. A valid explicit [iconKey] (matching [kPoiIconKeys], trimmed & case-insensitive) wins.
/// 2. Otherwise falls back to [category] mapping from the contract (trimmed & case-insensitive).
/// 3. Otherwise returns [kPoiIconFallback] ('default').
String resolvePoiIconKey({String? iconKey, String? category}) {
  if (iconKey != null) {
    final normalized = iconKey.trim().toLowerCase();
    if (kPoiIconKeys.contains(normalized)) {
      return normalized;
    }
  }

  if (category != null) {
    final normalizedCategory = category.trim().toLowerCase();
    final mapped = kCategoryToIconKey[normalizedCategory];
    if (mapped != null) {
      return mapped;
    }
  }

  return kPoiIconFallback;
}

/// Pixel width of the exported icon PNGs (a 32 dp frame exported at @2x).
const double kPoiIconAssetPx = 64;

/// Fallback screen density used before the real one is known.
const double kDefaultPixelRatio = 2.0;

/// MapLibre treats a registered image as device-scaled, so `icon-size` 1 draws
/// it at `assetPx / pixelRatio` dp. This builds the zoom-interpolated
/// `icon-size` that draws the icon at [minDp] and [maxDp] on any screen density.
List<Object> poiIconSizeExpression({
  required double pixelRatio,
  required double minZoom,
  required double minDp,
  required double maxZoom,
  required double maxDp,
}) {
  double scale(double dp) => dp * pixelRatio / kPoiIconAssetPx;
  return [
    'interpolate',
    ['linear'],
    ['zoom'],
    minZoom,
    scale(minDp),
    maxZoom,
    scale(maxDp),
  ];
}
