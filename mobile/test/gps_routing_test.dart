import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniway_mobile/core/services/location_fix.dart';
import 'package:uniway_mobile/core/services/location_service.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/phase0_destinations.dart';
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

  @override
  Stream<LocationFix> positionStream() => const Stream.empty();
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
        repository: _FakeRoutingRepository(),
        locationService: StubLocationService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutePickerCard(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('From'), findsOneWidget);
      expect(find.text('Your Location'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.text('Navigate'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping To opens destination search and reports the pick', (tester) async {
      final controller = RoutingController(
        repository: _FakeRoutingRepository(),
        locationService: StubLocationService(),
      );
      Destination? focused;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoutePickerCard(
              controller: controller,
              onDestinationFocused: (d) => focused = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Academic Block 1 (AB1)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'central');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.widgetWithText(ListTile, 'Central Library'));
      await tester.pumpAndSettle();

      expect(controller.destination?.name, 'Central Library');
      expect(focused?.name, 'Central Library');
      expect(find.byType(TextField), findsNothing);

      controller.dispose();
    });

    testWidgets('From search sets origin, and Your Location resets it without reporting focus', (tester) async {
      final controller = RoutingController(
        repository: _FakeRoutingRepository(),
        locationService: StubLocationService(),
      );
      final focused = <Destination>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => RoutePickerCard(
                controller: controller,
                onDestinationFocused: focused.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your Location'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'central');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.widgetWithText(ListTile, 'Central Library'));
      await tester.pumpAndSettle();

      expect(controller.isGpsOrigin, isFalse);
      expect(controller.origin?.name, 'Central Library');
      expect(focused.map((d) => d.name), ['Central Library']);

      await tester.tap(find.text('Central Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Your Location'));
      await tester.pumpAndSettle();

      expect(controller.isGpsOrigin, isTrue);
      expect(focused.length, 1);

      controller.dispose();
    });
  });
}

class _FakeRoutingRepository extends RoutingRepository {
  @override
  Future<DestinationsResult> getDestinations({required String campusId}) async {
    return const DestinationsResult(destinations: Phase0Destinations.all, statusCode: 200);
  }
}
