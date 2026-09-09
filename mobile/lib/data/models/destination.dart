class Destination {
  final String id;
  final String routingNodeId;
  final String name;
  final String category;
  final double latitude;
  final double longitude;
  final List<String> tags;

  String get roomId => routingNodeId;

  const Destination({
    required this.id,
    String? routingNodeId,
    String? roomId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.tags = const [],
  }) : routingNodeId = routingNodeId ?? roomId ?? id;

  factory Destination.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('Destination missing required id');
    }

    final name = json['name'] as String?;
    if (name == null || name.isEmpty) {
      throw FormatException('Destination $id missing required name');
    }

    final rawNode = json['routing_node_id'] ??
        json['routingNodeId'] ??
        json['room_id'] ??
        json['roomId'];
    if (rawNode == null || rawNode is! String || rawNode.trim().isEmpty) {
      throw FormatException('Destination $id missing valid routing_node_id');
    }
    final node = rawNode.trim();

    double? lat;
    double? lng;

    if (json.containsKey('geom') && json['geom'] is Map<String, dynamic>) {
      final geom = json['geom'] as Map<String, dynamic>;
      final coords = geom['coordinates'];
      if (coords is List && coords.length >= 2 && coords[0] is num && coords[1] is num) {
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
      throw FormatException('Destination $id missing valid geographic coordinates');
    }

    return Destination(
      id: id,
      routingNodeId: node,
      name: name,
      category: (json['type'] ?? json['category'] ?? 'destination') as String,
      latitude: lat,
      longitude: lng,
      tags: (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routing_node_id': routingNodeId,
      'room_id': roomId,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'tags': tags,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Destination &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($roomId)';
}
