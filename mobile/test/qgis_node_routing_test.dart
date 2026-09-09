import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniway_mobile/data/models/campus_route.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';

void main() {
  group('QGIS Node Routing Integration Contract Tests', () {
    test('Destination.fromJson parses QGIS destination payload', () {
      final qgisJson = {
        'id': 'DEST_AB1_OUT',
        'name': 'Academic Block 1 Entrance',
        'type': 'destination',
        'routing_node_id': 'OUT_AB1_0_001',
        'geom': {
          'type': 'Point',
          'coordinates': [75.5652, 26.8438],
        },
      };

      final dest = Destination.fromJson(qgisJson);

      expect(dest.id, 'DEST_AB1_OUT');
      expect(dest.name, 'Academic Block 1 Entrance');
      expect(dest.routingNodeId, 'OUT_AB1_0_001');
      expect(dest.roomId, 'OUT_AB1_0_001');
      expect(dest.longitude, 75.5652);
      expect(dest.latitude, 26.8438);
      expect(dest.category, 'destination');
    });

    test('Destination.fromJson rejects malformed payloads without inventing coordinates or node IDs', () {
      final missingCoords = {
        'id': 'DEST_BAD',
        'name': 'Bad Node',
        'routing_node_id': 'OUT_BAD',
      };
      expect(() => Destination.fromJson(missingCoords), throwsFormatException);

      final missingNode = {
        'id': 'DEST_BAD_2',
        'name': 'Bad Node 2',
        'geom': {
          'type': 'Point',
          'coordinates': [75.5, 26.8],
        },
      };
      expect(() => Destination.fromJson(missingNode), throwsFormatException);

      final missingId = {
        'name': 'No ID',
        'routing_node_id': 'OUT_1',
        'geom': {
          'type': 'Point',
          'coordinates': [75.5, 26.8],
        },
      };
      expect(() => Destination.fromJson(missingId), throwsFormatException);
    });

    test('Destination.fromJson retains backwards compatibility with room format', () {
      final legacyJson = {
        'id': 'room-dome-001',
        'room_id': 'ROOM_DOME_001',
        'name': 'Dome Central Hall',
        'category': 'academic',
        'lat': 26.8429,
        'lng': 75.5645,
      };

      final dest = Destination.fromJson(legacyJson);

      expect(dest.id, 'room-dome-001');
      expect(dest.routingNodeId, 'ROOM_DOME_001');
      expect(dest.roomId, 'ROOM_DOME_001');
      expect(dest.name, 'Dome Central Hall');
      expect(dest.latitude, 26.8429);
      expect(dest.longitude, 75.5645);
    });

    test('CampusRoute.fromGeoJson parses QGIS node-route response', () {
      final nodeRouteJson = {
        'data': {
          'type': 'Feature',
          'properties': {
            'distance_meters': 312.5,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [75.5645, 26.8429],
              [75.5648, 26.8432],
              [75.5652, 26.8438],
            ],
          },
        },
      };

      final route = CampusRoute.fromGeoJson(nodeRouteJson);

      expect(route.distanceMeters, 312.5);
      expect(route.points.length, 3);
      expect(route.points.first.latitude, closeTo(26.8429, 0.00001));
      expect(route.points.first.longitude, closeTo(75.5645, 0.00001));
      expect(route.points.last.latitude, closeTo(26.8438, 0.00001));
      expect(route.points.last.longitude, closeTo(75.5652, 0.00001));
      expect(route.formattedDistance, '312.5 m');
    });

    test('RoutingRepository calls node-route with QGIS query parameters', () async {
      late Uri capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          json.encode({
            'data': {
              'type': 'Feature',
              'properties': {'distance_meters': 150.0},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [75.564, 26.843],
                  [75.565, 26.844],
                ],
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);

      const origin = Destination(
        id: 'DOME',
        routingNodeId: 'OUT_DOME_0_001',
        name: 'Dome',
        category: 'academic',
        latitude: 26.843,
        longitude: 75.564,
      );

      const destination = Destination(
        id: 'AB1',
        routingNodeId: 'OUT_AB1_0_005',
        name: 'AB1',
        category: 'academic',
        latitude: 26.844,
        longitude: 75.565,
      );

      final result = await repo.getRoute(
        campusId: '11111111-1111-4111-8111-111111111111',
        origin: origin,
        destination: destination,
        accessible: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.route!.distanceMeters, 150.0);
      expect(capturedUri.path, '/api/campus/11111111-1111-4111-8111-111111111111/node-route');
      expect(capturedUri.queryParameters['fromLng'], '75.564');
      expect(capturedUri.queryParameters['fromLat'], '26.843');
      expect(capturedUri.queryParameters['toNodeId'], 'OUT_AB1_0_005');
      expect(capturedUri.queryParameters['floor'], '0');
      expect(capturedUri.queryParameters['accessible'], 'true');
    });

    test('RoutingRepository calls destinations endpoint and distinguishes success from error', () async {
      late Uri capturedUri;
      int statusCodeToReturn = 200;
      String responseBody = json.encode({
        'data': [
          {
            'id': 'DEST_1',
            'name': 'Library',
            'type': 'destination',
            'routing_node_id': 'NODE_LIB_001',
            'geom': {
              'type': 'Point',
              'coordinates': [75.566, 26.845],
            },
          },
        ],
      });

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          responseBody,
          statusCodeToReturn,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);
      final result = await repo.getDestinations(
        campusId: '11111111-1111-4111-8111-111111111111',
      );

      expect(capturedUri.path, '/api/campus/11111111-1111-4111-8111-111111111111/destinations');
      expect(result.isSuccess, isTrue);
      expect(result.destinations.length, 1);
      expect(result.destinations.first.id, 'DEST_1');
      expect(result.destinations.first.name, 'Library');

      // Test error response
      statusCodeToReturn = 500;
      responseBody = json.encode({'error': 'Database unavailable'});
      final errorResult = await repo.getDestinations(
        campusId: '11111111-1111-4111-8111-111111111111',
      );
      expect(errorResult.isSuccess, isFalse);
      expect(errorResult.destinations, isEmpty);
      expect(errorResult.errorMessage, 'Database unavailable');

      // Test empty successful response
      statusCodeToReturn = 200;
      responseBody = json.encode({'data': []});
      final emptyResult = await repo.getDestinations(
        campusId: '11111111-1111-4111-8111-111111111111',
      );
      expect(emptyResult.isSuccess, isTrue);
      expect(emptyResult.destinations, isEmpty);
      expect(emptyResult.errorMessage, isNull);
    });
  });
}
