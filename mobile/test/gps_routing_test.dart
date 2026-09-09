import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/repositories/routing_repository.dart';
import 'package:uniway_mobile/presentation/controllers/routing_controller.dart';
import 'package:uniway_mobile/presentation/widgets/route_picker_card.dart';

class StubLocationService implements LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationResult> getCurrentLocation() async {
    return const LocationResult(latitude: 26.8438, longitude: 75.5652);
  }
}

void main() {
  group('GPS Routing End-to-End Tests', () {
    test('RoutingRepository sends live GPS coordinates in query parameters', () async {
      late Uri capturedUri;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          json.encode({
            'data': {
              'type': 'Feature',
              'properties': {'distance_meters': 180.0},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [75.5652, 26.8438],
                  [75.5660, 26.8445],
                ],
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RoutingRepository(client: mockClient);

      const destination = Destination(
        id: 'AB1',
        routingNodeId: 'OUT_AB1_0_001',
        name: 'Academic Block 1',
        category: 'academic',
        latitude: 26.8445,
        longitude: 75.5660,
      );

      final result = await repo.getRoute(
        campusId: '11111111-1111-4111-8111-111111111111',
        fromLng: 75.5652,
        fromLat: 26.8438,
        destination: destination,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedUri.queryParameters['fromLng'], '75.5652');
      expect(capturedUri.queryParameters['fromLat'], '26.8438');
      expect(capturedUri.queryParameters['toNodeId'], 'OUT_AB1_0_001');
    });

    testWidgets('RoutePickerCard renders From selector (with Your Location default) and To picker with swap', (tester) async {
      final controller = RoutingController(
        locationService: StubLocationService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutePickerCard(controller: controller),
          ),
        ),
      );

      expect(find.text('From'), findsOneWidget);
      expect(find.text('Your Location'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);

      controller.dispose();
    });
  });
}
