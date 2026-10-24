import '../../core/constants/poi_icons.dart';

class MapPoi {
  final String id;
  final String name;
  final String category;
  final String? iconKey;
  final List<String> tags;
  final String? routingNodeId;
  final double latitude;
  final double longitude;

  String get resolvedIconKey =>
      resolvePoiIconKey(iconKey: iconKey, category: category);

  const MapPoi({
    required this.id,
    required this.name,
    required this.category,
    this.iconKey,
    this.tags = const [],
    this.routingNodeId,
    required this.latitude,
    required this.longitude,
  });

  factory MapPoi.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('MapPoi missing required id');
    }

    final name = json['name'] as String?;
    if (name == null || name.isEmpty) {
      throw FormatException('MapPoi $id missing required name');
    }

    double? lat;
    double? lng;

    if (json.containsKey('geom') && json['geom'] is Map<String, dynamic>) {
      final geom = json['geom'] as Map<String, dynamic>;
      final coords = geom['coordinates'];
      if (coords is List &&
          coords.length >= 2 &&
          coords[0] is num &&
          coords[1] is num) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    } else {
      final rawLat = json['lat'] ?? json['latitude'];
      final rawLng = json['lng'] ?? json['longitude'];
      if (rawLat is num && rawLng is num) {
        lat = rawLat.toDouble();
        lng = rawLng.toDouble();
      }
    }

    if (lat == null || lng == null) {
      throw FormatException('MapPoi $id missing valid geographic coordinates');
    }

    final rawCat = json['category'];
    final category = (rawCat is String && rawCat.trim().isNotEmpty)
        ? rawCat.trim()
        : 'default';

    final rawIconKey = json['icon_key'] ?? json['iconKey'];
    final iconKey = (rawIconKey is String && rawIconKey.trim().isNotEmpty)
        ? rawIconKey.trim()
        : null;

    final rawNode = json['routing_node_id'] ?? json['routingNodeId'];
    final routingNodeId = (rawNode is String && rawNode.trim().isNotEmpty)
        ? rawNode.trim()
        : null;

    return MapPoi(
      id: id,
      name: name,
      category: category,
      iconKey: iconKey,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          const [],
      routingNodeId: routingNodeId,
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      if (iconKey != null) 'icon_key': iconKey,
      'tags': tags,
      if (routingNodeId != null) 'routing_node_id': routingNodeId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoi && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($category)';
}
