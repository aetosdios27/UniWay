import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/map_poi.dart';

void main() {
  group('MapPoi Model Parsing', () {
    test('parses full POI with GeoJSON Point geom', () {
      final json = {
        'id': 'POI_01',
        'name': 'Student Center ATM',
        'category': 'bank',
        'icon_key': 'amenities',
        'tags': ['cash', 'finance'],
        'routing_node_id': 'NODE_101',
        'geom': {
          'type': 'Point',
          'coordinates': [75.5645, 26.8435],
        },
      };

      final poi = MapPoi.fromJson(json);

      expect(poi.id, 'POI_01');
      expect(poi.name, 'Student Center ATM');
      expect(poi.category, 'bank');
      expect(poi.iconKey, 'amenities');
      expect(poi.resolvedIconKey, 'amenities');
      expect(poi.tags, ['cash', 'finance']);
      expect(poi.routingNodeId, 'NODE_101');
      expect(poi.longitude, closeTo(75.5645, 1e-6));
      expect(poi.latitude, closeTo(26.8435, 1e-6));
    });

    test('parses coordinates from flat lat/lng fallback', () {
      final json = {
        'id': 'POI_02',
        'name': 'Tennis Court',
        'category': 'sports',
        'latitude': 26.845,
        'longitude': 75.566,
      };

      final poi = MapPoi.fromJson(json);
      expect(poi.latitude, 26.845);
      expect(poi.longitude, 75.566);
      expect(poi.resolvedIconKey, 'sports');
    });

    test('lenient about missing optional fields', () {
      final json = {
        'id': 'POI_03',
        'name': 'Main Gate',
        'geom': {
          'type': 'Point',
          'coordinates': [75.56, 26.84],
        },
      };

      final poi = MapPoi.fromJson(json);
      expect(poi.category, 'default');
      expect(poi.iconKey, isNull);
      expect(poi.resolvedIconKey, 'default');
      expect(poi.tags, isEmpty);
      expect(poi.routingNodeId, isNull);
    });

    test('strict: missing id throws FormatException', () {
      final json = {
        'name': 'Missing ID',
        'geom': {
          'type': 'Point',
          'coordinates': [75.56, 26.84],
        },
      };

      expect(() => MapPoi.fromJson(json), throwsFormatException);
    });

    test('strict: missing name throws FormatException', () {
      final json = {
        'id': 'POI_X',
        'geom': {
          'type': 'Point',
          'coordinates': [75.56, 26.84],
        },
      };

      expect(() => MapPoi.fromJson(json), throwsFormatException);
    });

    test('strict: missing coordinates throws FormatException', () {
      final json = {
        'id': 'POI_X',
        'name': 'No Coordinates',
      };

      expect(() => MapPoi.fromJson(json), throwsFormatException);
    });

    test('toJson serializes correctly', () {
      const poi = MapPoi(
        id: 'POI_T',
        name: 'Test POI',
        category: 'food',
        iconKey: 'food',
        tags: ['tag1'],
        routingNodeId: 'NODE_T',
        latitude: 26.84,
        longitude: 75.56,
      );

      final json = poi.toJson();
      expect(json['id'], 'POI_T');
      expect(json['name'], 'Test POI');
      expect(json['category'], 'food');
      expect(json['icon_key'], 'food');
      expect(json['tags'], ['tag1']);
      expect(json['routing_node_id'], 'NODE_T');
      expect(json['latitude'], 26.84);
      expect(json['longitude'], 75.56);
    });

    test('equality and hashCode are based on id', () {
      const poi1 = MapPoi(
        id: 'SAME_ID',
        name: 'Name 1',
        category: 'food',
        latitude: 26.84,
        longitude: 75.56,
      );
      const poi2 = MapPoi(
        id: 'SAME_ID',
        name: 'Name 2',
        category: 'medical',
        latitude: 26.85,
        longitude: 75.57,
      );

      expect(poi1, equals(poi2));
      expect(poi1.hashCode, equals(poi2.hashCode));
    });
  });

  group('Destination Model Category & Icon Updates', () {
    test('prefers non-empty category over type', () {
      final json = {
        'id': 'DEST_CAT',
        'name': 'Central Library',
        'type': 'destination',
        'category': 'library',
        'routing_node_id': 'NODE_LIB',
        'geom': {
          'type': 'Point',
          'coordinates': [75.565, 26.842],
        },
      };

      final destination = Destination.fromJson(json);
      expect(destination.category, 'library');
      expect(destination.resolvedIconKey, 'academic');
    });

    test('falls back to type when category is missing or empty', () {
      final json = {
        'id': 'DEST_TYPE',
        'name': 'Old Block',
        'type': 'academic',
        'category': '  ',
        'routing_node_id': 'NODE_OLD',
        'geom': {
          'type': 'Point',
          'coordinates': [75.565, 26.842],
        },
      };

      final destination = Destination.fromJson(json);
      expect(destination.category, 'academic');
      expect(destination.resolvedIconKey, 'academic');
    });

    test('parses icon_key and iconKey', () {
      final json1 = {
        'id': 'DEST_IK1',
        'name': 'Gym',
        'type': 'destination',
        'icon_key': 'sports',
        'routing_node_id': 'NODE_GYM',
        'geom': {
          'type': 'Point',
          'coordinates': [75.565, 26.842],
        },
      };
      final d1 = Destination.fromJson(json1);
      expect(d1.iconKey, 'sports');
      expect(d1.resolvedIconKey, 'sports');

      final json2 = {
        'id': 'DEST_IK2',
        'name': 'Clinic',
        'type': 'destination',
        'iconKey': 'dome',
        'routing_node_id': 'NODE_MED',
        'geom': {
          'type': 'Point',
          'coordinates': [75.565, 26.842],
        },
      };
      final d2 = Destination.fromJson(json2);
      expect(d2.iconKey, 'dome');
      expect(d2.resolvedIconKey, 'dome');
    });
  });
}
