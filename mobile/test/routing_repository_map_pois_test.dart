import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';

void main() {
  group('RoutingRepository.getMapPois', () {
    test('loads map POIs successfully on 200 response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/campus/camp-uuid/map-pois');
        expect(request.headers['Accept'], 'application/json');

        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'POI_1',
                'name': 'Library Cafe',
                'category': 'food',
                'icon_key': 'food',
                'tags': ['coffee', 'snacks'],
                'routing_node_id': 'NODE_1',
                'geom': {
                  'type': 'Point',
                  'coordinates': [75.564, 26.843],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);
      final result = await repo.getMapPois(campusId: 'camp-uuid');

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, 200);
      expect(result.pois.length, 1);
      expect(result.pois.first.id, 'POI_1');
      expect(result.pois.first.name, 'Library Cafe');
      expect(result.pois.first.resolvedIconKey, 'food');
    });

    test('passes category query parameter when supplied', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/campus/camp-uuid/map-pois');
        expect(request.url.queryParameters['category'], 'medical');

        return http.Response(
          jsonEncode({'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);
      final result = await repo.getMapPois(
        campusId: 'camp-uuid',
        category: 'medical',
      );

      expect(result.isSuccess, isTrue);
      expect(result.pois, isEmpty);
    });

    test('handles 400 error response with server error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Campus ID must be a valid UUID'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);
      final result = await repo.getMapPois(campusId: 'invalid-id');

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 400);
      expect(result.errorMessage, 'Campus ID must be a valid UUID');
      expect(result.pois, isEmpty);
    });

    test('handles network exceptions gracefully', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final repo = RoutingRepository(client: mockClient);
      final result = await repo.getMapPois(campusId: 'camp-uuid');

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 0);
      expect(result.errorMessage, contains('Connection refused'));
      expect(result.pois, isEmpty);
    });
  });
}
